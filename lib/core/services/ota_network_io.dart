import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class _SingleDigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

class DownloadedOtaArtifact {
  final String filePath;
  final String sha256Hex;
  final int sizeBytes;

  const DownloadedOtaArtifact({
    required this.filePath,
    required this.sha256Hex,
    required this.sizeBytes,
  });
}

const int _maxRedirects = 5;
const int _maxManifestBytes = 1024 * 1024; // 1 MiB cap for manifest JSON
const int _maxApkBytes = 250 * 1024 * 1024; // 250 MiB cap for APK bundle

/// Performs a strict HTTPS GET with manual hop-by-hop redirect validation
/// to defeat open-redirect SSRF while supporting GitHub Releases CDN redirects.
Future<String?> fetchTrustedHttpsText(
  String url, {
  required bool Function(String candidateUrl) isAllowedRedirectUrl,
}) async {
  if (!isAllowedRedirectUrl(url)) return null;

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..idleTimeout = const Duration(seconds: 12);

  try {
    Uri currentUri = Uri.parse(url);
    for (int hop = 0; hop <= _maxRedirects; hop++) {
      final request = await client.getUrl(currentUri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Cash-IO-OTA/3.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json, application/octet-stream, */*');

      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || location.isEmpty) return null;
        final nextUri = currentUri.resolve(location);
        if (!isAllowedRedirectUrl(nextUri.toString())) {
          return null; // Untrusted redirect blocked
        }
        currentUri = nextUri;
        continue;
      }

      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (builder.length + chunk.length > _maxManifestBytes) {
          return null;
        }
        builder.add(chunk);
      }
      return utf8.decode(builder.takeBytes());
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Streams a signed Android APK into the application's private `ota_updates` cache folder,
/// computing its SHA-256 hash and reporting live byte download progress.
Future<DownloadedOtaArtifact?> downloadTrustedApkToSandbox({
  required String url,
  required String targetFilename,
  required bool Function(String candidateUrl) isAllowedRedirectUrl,
  void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
}) async {
  if (!isAllowedRedirectUrl(url)) return null;
  if (!RegExp(r'^[A-Za-z0-9._-]+\.apk$').hasMatch(targetFilename) || targetFilename.contains('..')) {
    return null;
  }

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..idleTimeout = const Duration(seconds: 30);

  File? outFile;
  IOSink? sink;
  try {
    final baseDir = await getTemporaryDirectory();
    final otaDir = Directory(p.join(baseDir.path, 'ota_updates'));
    if (!await otaDir.exists()) {
      await otaDir.create(recursive: true);
    }

    outFile = File(p.join(otaDir.path, targetFilename));
    if (await outFile.exists()) {
      await outFile.delete();
    }

    Uri currentUri = Uri.parse(url);
    HttpClientResponse? finalResponse;

    for (int hop = 0; hop <= _maxRedirects; hop++) {
      final request = await client.getUrl(currentUri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Cash-IO-OTA/3.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream, */*');

      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || location.isEmpty) return null;
        final nextUri = currentUri.resolve(location);
        if (!isAllowedRedirectUrl(nextUri.toString())) {
          return null;
        }
        currentUri = nextUri;
        continue;
      }

      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      finalResponse = response;
      break;
    }

    if (finalResponse == null) return null;

    final totalBytes = finalResponse.contentLength;
    int receivedBytes = 0;
    final digestSink = _SingleDigestSink();
    final hashInput = sha256.startChunkedConversion(digestSink);

    final activeSink = outFile.openWrite();
    sink = activeSink;
    await for (final chunk in finalResponse) {
      receivedBytes += chunk.length;
      if (receivedBytes > _maxApkBytes) {
        await activeSink.close();
        sink = null;
        await outFile.delete();
        return null;
      }
      activeSink.add(chunk);
      hashInput.add(chunk);
      if (onProgress != null) {
        final ratio = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        onProgress(ratio, receivedBytes, totalBytes);
      }
    }

    await activeSink.flush();
    await activeSink.close();
    sink = null;
    hashInput.close();

    final hex = digestSink.value?.toString().toLowerCase();
    if (hex == null || hex.length != 64) {
      await outFile.delete();
      return null;
    }

    return DownloadedOtaArtifact(
      filePath: outFile.path,
      sha256Hex: hex,
      sizeBytes: receivedBytes,
    );
  } catch (_) {
    try {
      await sink?.close();
      if (outFile != null && await outFile.exists()) {
        await outFile.delete();
      }
    } catch (_) {}
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<void> deleteSandboxFileIfExists(String filePath) async {
  try {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

Future<void> persistEmergencySnapshotToDisk(String snapshotId, String jsonPayload) async {
  if (!RegExp(r'^snap_[A-Za-z0-9_-]+$').hasMatch(snapshotId)) return;
  try {
    final docs = await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 2));
    final dir = Directory(p.join(docs.path, 'ota_snapshots'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, '$snapshotId.cashio.bak'));
    await file.writeAsString(jsonPayload, flush: true);
  } catch (_) {
    // Gracefully fall back to in-memory snapshot during unit tests without path_provider
  }
}

Future<List<String>> loadPersistedEmergencySnapshotsFromDisk() async {
  try {
    final docs = await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 2));
    final dir = Directory(p.join(docs.path, 'ota_snapshots'));
    if (!await dir.exists()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.cashio.bak'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    final out = <String>[];
    for (final f in files) {
      out.add(await f.readAsString());
    }
    return out;
  } catch (_) {
    return const [];
  }
}
