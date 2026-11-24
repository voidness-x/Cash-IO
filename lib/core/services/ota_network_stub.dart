/// Web / Stub implementation for OTA file & network operations.
/// Allows Flutter Web builds to compile without `dart:io` dependencies.
library;

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

Future<String?> fetchTrustedHttpsText(
  String url, {
  required bool Function(String candidateUrl) isAllowedRedirectUrl,
}) async {
  return null;
}

Future<DownloadedOtaArtifact?> downloadTrustedApkToSandbox({
  required String url,
  required String targetFilename,
  required bool Function(String candidateUrl) isAllowedRedirectUrl,
  void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
}) async {
  return null;
}

Future<void> deleteSandboxFileIfExists(String filePath) async {}

Future<void> persistEmergencySnapshotToDisk(String snapshotId, String encryptedOrJsonPayload) async {}

Future<List<String>> loadPersistedEmergencySnapshotsFromDisk() async => const [];
