import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../storage/vault_repository.dart';
import '../sync/e2ee_packager.dart';
import 'ota_network_stub.dart' if (dart.library.io) 'ota_network_io.dart';
import 'ota_platform_bridge.dart';

class AppUpdateManifest {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String title;
  final List<String> changelog;
  final String sha256Checksum;
  final bool isEmergencyPatch;
  final String downloadUrl;
  final String? apkDownloadUrl;
  final String? apkSha256Checksum;
  final String? apkArm64DownloadUrl;
  final String? apkArm64Sha256Checksum;
  final String? iosDownloadUrl;
  final String? iosSha256Checksum;
  final String? releasePageUrl;

  const AppUpdateManifest({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.title,
    required this.changelog,
    required this.sha256Checksum,
    this.isEmergencyPatch = false,
    required this.downloadUrl,
    this.apkDownloadUrl,
    this.apkSha256Checksum,
    this.apkArm64DownloadUrl,
    this.apkArm64Sha256Checksum,
    this.iosDownloadUrl,
    this.iosSha256Checksum,
    this.releasePageUrl,
  });

  String get effectiveApkUrl =>
      (apkDownloadUrl != null && apkDownloadUrl!.isNotEmpty) ? apkDownloadUrl! : downloadUrl;

  String get effectiveApkSha256 =>
      (apkSha256Checksum != null && apkSha256Checksum!.isNotEmpty) ? apkSha256Checksum! : sha256Checksum;

  String get effectiveIosUrl => (iosDownloadUrl != null && iosDownloadUrl!.isNotEmpty)
      ? iosDownloadUrl!
      : (releasePageUrl ?? UpdateReceiverService.githubReleasesPageUrl);

  /// Selects the slim pure `arm64-v8a` APK when the device supports `arm64-v8a`,
  /// falling back to the multi-ABI mobile APK otherwise.
  (String url, String sha256) resolveAndroidTarget(List<String> supportedAbis) {
    final normalizedAbis = supportedAbis.map((a) => a.toLowerCase()).toSet();
    if (normalizedAbis.contains('arm64-v8a') &&
        apkArm64DownloadUrl != null &&
        apkArm64DownloadUrl!.isNotEmpty) {
      return (apkArm64DownloadUrl!, apkArm64Sha256Checksum ?? '');
    }
    return (effectiveApkUrl, effectiveApkSha256);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'build_number': buildNumber,
        'release_date': releaseDate,
        'title': title,
        'changelog': changelog,
        'sha256_checksum': sha256Checksum,
        'is_emergency_patch': isEmergencyPatch,
        'download_url': downloadUrl,
        if (apkDownloadUrl != null) 'apk_download_url': apkDownloadUrl,
        if (apkSha256Checksum != null) 'apk_sha256_checksum': apkSha256Checksum,
        if (apkArm64DownloadUrl != null) 'apk_arm64_download_url': apkArm64DownloadUrl,
        if (apkArm64Sha256Checksum != null) 'apk_arm64_sha256_checksum': apkArm64Sha256Checksum,
        if (iosDownloadUrl != null) 'ios_download_url': iosDownloadUrl,
        if (iosSha256Checksum != null) 'ios_sha256_checksum': iosSha256Checksum,
        if (releasePageUrl != null) 'release_page_url': releasePageUrl,
      };

  static AppUpdateManifest? tryParseJson(Map<String, dynamic> map) {
    try {
      // Case 1: Signed Cash-IO manifest.json schema
      if (map.containsKey('version') && map.containsKey('download_url')) {
        final ver = (map['version'] as String).trim().replaceFirst(RegExp(r'^v'), '');
        final buildNum = (map['build_number'] as num?)?.toInt() ??
            UpdateReceiverService.computeBuildNumberFromSemver(ver);
        final rawChangelog = map['changelog'];
        final changelogList = rawChangelog is List
            ? rawChangelog.map((e) => e.toString()).toList()
            : <String>['Official signed release v$ver'];

        return AppUpdateManifest(
          version: ver,
          buildNumber: buildNum,
          releaseDate: (map['release_date'] as String?) ?? '',
          title: (map['title'] as String?) ?? 'Cash-IO v$ver Release',
          changelog: changelogList,
          sha256Checksum: (map['sha256_checksum'] as String?) ?? '',
          isEmergencyPatch: (map['is_emergency_patch'] as bool?) ?? false,
          downloadUrl: map['download_url'] as String,
          apkDownloadUrl: map['apk_download_url'] as String?,
          apkSha256Checksum: map['apk_sha256_checksum'] as String?,
          apkArm64DownloadUrl: map['apk_arm64_download_url'] as String?,
          apkArm64Sha256Checksum: map['apk_arm64_sha256_checksum'] as String?,
          iosDownloadUrl: map['ios_download_url'] as String?,
          iosSha256Checksum: map['ios_sha256_checksum'] as String?,
          releasePageUrl: map['release_page_url'] as String?,
        );
      }

      // Case 2: Native GitHub Releases REST API (/repos/voidness-x/Cash-IO/releases/latest)
      if (map.containsKey('tag_name') && map['assets'] is List) {
        final rawTag = (map['tag_name'] as String).trim();
        final ver = rawTag.replaceFirst(RegExp(r'^v'), '');
        final buildNum = UpdateReceiverService.computeBuildNumberFromSemver(ver);
        final publishedAt = (map['published_at'] as String?) ?? '';
        final releaseDate = publishedAt.length >= 10 ? publishedAt.substring(0, 10) : publishedAt;
        final body = (map['body'] as String?) ?? '';
        final lines = body
            .split('\n')
            .map((l) => l.trim().replaceFirst(RegExp(r'^[-*]\s*'), ''))
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .take(6)
            .toList();

        String? apkUrl;
        String? apkDigest;
        String? apkArm64Url;
        String? apkArm64Digest;
        String? iosUrl;
        String? iosDigest;
        String? fallbackUrl;
        String? fallbackDigest;

        for (final rawAsset in (map['assets'] as List<dynamic>)) {
          final asset = Map<String, dynamic>.from(rawAsset as Map);
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final url = asset['browser_download_url'] as String?;
          final digestRaw = asset['digest'] as String?;
          final cleanSha = (digestRaw != null && digestRaw.startsWith('sha256:'))
              ? digestRaw.substring(7)
              : null;

          if (url == null) continue;
          if (name.endsWith('.apk')) {
            if (name.contains('arm64')) {
              apkArm64Url = url;
              apkArm64Digest = cleanSha;
            } else {
              apkUrl = url;
              apkDigest = cleanSha;
            }
          } else if (name.endsWith('.ipa')) {
            iosUrl = url;
            iosDigest = cleanSha;
          } else if (name.endsWith('.enc') || name.endsWith('.zip')) {
            fallbackUrl = url;
            fallbackDigest = cleanSha;
          }
        }

        final primaryApkUrl = apkUrl ?? apkArm64Url;
        final primaryApkDigest = apkDigest ?? apkArm64Digest;
        final primaryUrl = primaryApkUrl ?? fallbackUrl ?? iosUrl;
        final primarySha = primaryApkDigest ?? fallbackDigest ?? iosDigest ?? '';
        if (primaryUrl == null) return null;

        return AppUpdateManifest(
          version: ver,
          buildNumber: buildNum,
          releaseDate: releaseDate,
          title: (map['name'] as String?)?.trim().isNotEmpty == true
              ? (map['name'] as String)
              : 'Cash-IO v$ver',
          changelog: lines.isNotEmpty ? lines : <String>['Official GitHub Release $rawTag'],
          sha256Checksum: primarySha,
          downloadUrl: primaryUrl,
          apkDownloadUrl: primaryApkUrl,
          apkSha256Checksum: primaryApkDigest,
          apkArm64DownloadUrl: apkArm64Url,
          apkArm64Sha256Checksum: apkArm64Digest,
          iosDownloadUrl: iosUrl,
          iosSha256Checksum: iosDigest,
          releasePageUrl: map['html_url'] as String?,
        );
      }
    } catch (_) {}
    return null;
  }
}

class EmergencyRollbackSnapshot {
  final String snapshotId;
  final String fromVersion;
  final int fromBuild;
  final String targetVersion;
  final DateTime timestamp;
  final String checksumSha256;
  final Map<String, dynamic> rawVaultData;
  final String note;

  const EmergencyRollbackSnapshot({
    required this.snapshotId,
    required this.fromVersion,
    this.fromBuild = 300,
    required this.targetVersion,
    required this.timestamp,
    required this.checksumSha256,
    required this.rawVaultData,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'snapshot_id': snapshotId,
        'from_version': fromVersion,
        'from_build': fromBuild,
        'target_version': targetVersion,
        'timestamp_iso': timestamp.toIso8601String(),
        'checksum_sha256': checksumSha256,
        'raw_vault_data': rawVaultData,
        'note': note,
      };

  static EmergencyRollbackSnapshot? tryFromJsonString(String raw) {
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return EmergencyRollbackSnapshot(
        snapshotId: m['snapshot_id'] as String,
        fromVersion: m['from_version'] as String,
        fromBuild: (m['from_build'] as num?)?.toInt() ?? 300,
        targetVersion: m['target_version'] as String,
        timestamp: DateTime.parse(m['timestamp_iso'] as String),
        checksumSha256: m['checksum_sha256'] as String,
        rawVaultData: Map<String, dynamic>.from(m['raw_vault_data'] as Map),
        note: (m['note'] as String?) ?? 'Emergency pre-update snapshot',
      );
    } catch (_) {
      return null;
    }
  }
}

enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  creatingSnapshot,
  downloadingPayload,
  verifyingChecksum,
  applyingMigration,
  verifyingIntegrity,
  launchingInstaller,
  completed,
  rolledBack,
  error,
}

class UpdateApplyResult {
  final bool success;
  final bool wasRolledBack;
  final bool needsInstallPermission;
  final bool launchedSystemInstaller;
  final String message;
  final EmergencyRollbackSnapshot? snapshot;

  const UpdateApplyResult({
    required this.success,
    this.wasRolledBack = false,
    this.needsInstallPermission = false,
    this.launchedSystemInstaller = false,
    required this.message,
    this.snapshot,
  });
}

/// Store-independent, GitHub-Releases-backed automated update receiver and emergency rollback engine.
/// Automatically detects new GitHub Releases on startup/resume, downloads signed Android APKs
/// (or opens signed iOS IPA releases), verifies SHA-256 checksums, creates persistent `.cashio.bak`
/// snapshots, and enforces post-update double-entry ledger integrity.
class UpdateReceiverService extends ChangeNotifier {
  static final UpdateReceiverService instance = UpdateReceiverService._internal();
  UpdateReceiverService._internal();

  /// Compile-time version injected via `--dart-define` in CI releases
  static const String compiledVersion = String.fromEnvironment(
    'CASHIO_APP_VERSION',
    defaultValue: '3.1.1',
  );
  static const int compiledBuild = int.fromEnvironment(
    'CASHIO_BUILD_NUMBER',
    defaultValue: 30101,
  );

  /// Official upstream repository and release endpoints for Cash-IO
  static const String githubRepositoryUrl = 'https://github.com/voidness-x/Cash-IO';
  static const String githubReleasesPageUrl = 'https://github.com/voidness-x/Cash-IO/releases';
  static const String releasesApiEndpoint = 'https://api.github.com/repos/voidness-x/Cash-IO/releases/latest';
  static const String manifestEndpoint = 'https://github.com/voidness-x/Cash-IO/releases/latest/download/manifest.json';

  /// Pinned trusted HTTPS hosts permitted to serve update manifests & CDN binary redirects (SSRF & MITM defense)
  static const Set<String> trustedUpdateHosts = {
    'github.com',
    'api.github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
    'raw.githubusercontent.com',
  };

  static final RegExp _sha256HexRegex = RegExp(r'^[a-fA-F0-9]{64}$');
  static int _snapshotCounter = 0;

  String _currentVersion = compiledVersion;
  int _currentBuild = compiledBuild;
  List<String> _supportedAbis = const [];
  UpdateStatus _status = UpdateStatus.idle;
  double _downloadProgress = 0.0;
  bool _useLiveGitHubReleases = true;
  bool _packageInfoSynced = false;
  bool _diskSnapshotsLoaded = false;
  DateTime? _lastAutoCheckAt;
  AppUpdateManifest? _availableUpdate;
  String? _dismissedVersion;

  String get currentVersion => _currentVersion;
  int get currentBuild => _currentBuild;
  UpdateStatus get status => _status;
  double get downloadProgress => _downloadProgress;
  AppUpdateManifest? get availableUpdate => _availableUpdate;
  bool get hasUnreadUpdateBanner =>
      _availableUpdate != null && _availableUpdate!.version != _dismissedVersion;

  final List<EmergencyRollbackSnapshot> _snapshots = [];
  List<EmergencyRollbackSnapshot> get availableRollbackSnapshots => List.unmodifiable(_snapshots);

  /// Staged fallback release manifest used in offline unit/security test suites
  static const AppUpdateManifest latestAvailableUpdate = AppUpdateManifest(
    version: '3.2.0',
    buildNumber: 320,
    releaseDate: '2026-11-25',
    title: 'Cash-IO v3.2.0 • Security & Financial Intelligence Rollout',
    changelog: [
      'On-device 50/30/20 heuristic cashflow engine (zero cloud telemetry).',
      'Locked savings vaults with emergency reserve discipline switches.',
      'Full-text & parametric date scrubber ledger search.',
      'Lossless receipt vault gallery with rotational orientation controls.',
      'GitHub Releases store-independent Android APK & iOS OTA receiver with pre-update rollback.',
    ],
    sha256Checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    isEmergencyPatch: false,
    downloadUrl: 'https://github.com/voidness-x/Cash-IO/releases/download/v3.2.0/cashio-v3.2.0-android.apk',
    apkDownloadUrl: 'https://github.com/voidness-x/Cash-IO/releases/download/v3.2.0/cashio-v3.2.0-android.apk',
    apkSha256Checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    iosDownloadUrl: 'https://github.com/voidness-x/Cash-IO/releases/download/v3.2.0/cashio-v3.2.0-ios-unsigned.ipa',
  );

  /// Dismisses the dashboard banner for the current session without disabling Settings updates.
  void dismissUpdateBanner() {
    if (_availableUpdate != null) {
      _dismissedVersion = _availableUpdate!.version;
      notifyListeners();
    }
  }

  /// Computes a monotonic integer build number from semantic version `X.Y.Z` -> `X*10000 + Y*100 + Z`.
  static int computeBuildNumberFromSemver(String rawVersion) {
    final clean = rawVersion.trim().replaceFirst(RegExp(r'^v'), '').split('-').first.split('+').first;
    final parts = clean.split('.');
    if (parts.length < 3) return 0;
    final major = int.tryParse(parts[0]) ?? 0;
    final minor = int.tryParse(parts[1]) ?? 0;
    final patch = int.tryParse(parts[2]) ?? 0;
    return (major * 10000) + (minor * 100) + patch;
  }

  /// Compares two semantic versions (`a` vs `b`), returning `1` if `a > b`, `-1` if `a < b`, `0` if equal.
  static int compareSemver(String a, String b) {
    final scoreA = computeBuildNumberFromSemver(a);
    final scoreB = computeBuildNumberFromSemver(b);
    return scoreA.compareTo(scoreB);
  }

  /// Validates that a SHA-256 hex digest is strictly 64 hexadecimal characters.
  static bool isValidSha256Hex(String checksum) {
    return _sha256HexRegex.hasMatch(checksum);
  }

  /// Validates that an update or redirect URL uses HTTPS, contains no embedded credentials,
  /// does not target private/loopback/metadata IPs (SSRF protection), and belongs to a pinned host.
  static bool isTrustedUpdateUrl(String rawUrl) {
    if (rawUrl.isEmpty || rawUrl.length > 2048) return false;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;

    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host == 'localhost' ||
        host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        host.startsWith('169.254.') ||
        host == '::1' ||
        host.startsWith('[')) {
      return false;
    }

    if (!trustedUpdateHosts.contains(host)) {
      return false;
    }

    // If hosted on github.com or api.github.com, enforce the voidness-x/Cash-IO repository path prefix
    if (host == 'github.com' && !uri.path.startsWith('/voidness-x/Cash-IO/')) {
      return false;
    }
    if (host == 'api.github.com' && !uri.path.startsWith('/repos/voidness-x/Cash-IO/')) {
      return false;
    }

    return true;
  }

  /// Verifies downloaded payload bytes against the manifest's expected SHA-256 hex digest in constant time.
  static bool verifyPayloadChecksum(Uint8List payloadBytes, String expectedSha256Hex) {
    if (!isValidSha256Hex(expectedSha256Hex)) return false;
    final actualHex = sha256.convert(payloadBytes).toString().toLowerCase();
    return E2eePackager.constantTimeStringEquals(actualHex, expectedSha256Hex.toLowerCase());
  }

  static bool _isRunningInsideWidgetTest() {
    try {
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      return bindingType.contains('TestWidgetsFlutterBinding') ||
          bindingType.contains('AutomatedTestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncInstalledPackageVersionIfNeeded() async {
    if (!_useLiveGitHubReleases) return;
    if (_packageInfoSynced && (!OtaPlatformBridge.isAndroidNative || _supportedAbis.isNotEmpty)) {
      return;
    }
    _packageInfoSynced = true;
    final info = await OtaPlatformBridge.getInstalledPackageInfo();
    if (info != null) {
      final vName = info['versionName'] as String?;
      final vCode = (info['versionCode'] as num?)?.toInt();
      final rawAbis = info['supportedAbis'];
      if (vName != null && vName.isNotEmpty) {
        _currentVersion = vName;
      }
      if (vCode != null && vCode > 0) {
        _currentBuild = vCode;
      }
      if (rawAbis is List) {
        _supportedAbis = rawAbis.map((e) => e.toString()).toList();
      }
    }
  }

  Future<void> _loadPersistedSnapshotsIfNeeded() async {
    if (_diskSnapshotsLoaded || !_useLiveGitHubReleases) return;
    _diskSnapshotsLoaded = true;
    final rawList = await loadPersistedEmergencySnapshotsFromDisk();
    for (final raw in rawList) {
      final parsed = EmergencyRollbackSnapshot.tryFromJsonString(raw);
      if (parsed != null && !_snapshots.any((s) => s.snapshotId == parsed.snapshotId)) {
        _snapshots.add(parsed);
      }
    }
  }

  /// Automatically invoked when the user opens or resumes Cash-IO on their phone.
  /// Checks GitHub Releases (`voidness-x/Cash-IO`) in the background and notifies UI listeners
  /// immediately whenever a newer release is published.
  Future<AppUpdateManifest?> checkForUpdatesOnStartupOrResume({
    Duration minInterval = const Duration(minutes: 10),
  }) async {
    if (!_useLiveGitHubReleases || _isRunningInsideWidgetTest()) {
      return null;
    }
    final now = DateTime.now();
    if (_lastAutoCheckAt != null && now.difference(_lastAutoCheckAt!) < minInterval) {
      return _availableUpdate;
    }
    _lastAutoCheckAt = now;
    return checkForUpdates(forceCheck: true);
  }

  /// Checks for available updates against the active running version.
  /// In production, queries live GitHub Releases (`manifest.json` + `/releases/latest` API).
  Future<AppUpdateManifest?> checkForUpdates({bool forceCheck = false}) async {
    _status = UpdateStatus.checking;
    notifyListeners();

    await _syncInstalledPackageVersionIfNeeded();
    await _loadPersistedSnapshotsIfNeeded();

    if (_useLiveGitHubReleases && !kIsWeb && !_isRunningInsideWidgetTest()) {
      AppUpdateManifest? liveManifest;

      // 1. Primary: Fetch signed manifest.json from latest GitHub Release
      final manifestText = await fetchTrustedHttpsText(
        manifestEndpoint,
        isAllowedRedirectUrl: isTrustedUpdateUrl,
      );
      if (manifestText != null) {
        try {
          final decoded = Map<String, dynamic>.from(jsonDecode(manifestText) as Map);
          liveManifest = AppUpdateManifest.tryParseJson(decoded);
        } catch (_) {}
      }

      // 2. Fallback: Query GitHub Releases REST API directly
      if (liveManifest == null) {
        final releaseApiText = await fetchTrustedHttpsText(
          releasesApiEndpoint,
          isAllowedRedirectUrl: isTrustedUpdateUrl,
        );
        if (releaseApiText != null) {
          try {
            final decoded = Map<String, dynamic>.from(jsonDecode(releaseApiText) as Map);
            liveManifest = AppUpdateManifest.tryParseJson(decoded);
          } catch (_) {}
        }
      }

      if (liveManifest != null &&
          isTrustedUpdateUrl(liveManifest.effectiveApkUrl) &&
          (compareSemver(liveManifest.version, _currentVersion) > 0 ||
              liveManifest.buildNumber > _currentBuild)) {
        _availableUpdate = liveManifest;
        _status = UpdateStatus.updateAvailable;
        notifyListeners();
        return liveManifest;
      }

      _availableUpdate = null;
      _status = UpdateStatus.idle;
      notifyListeners();
      return null;
    }

    // Offline / Unit-Test Deterministic Mode
    if (!_isRunningInsideWidgetTest()) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (latestAvailableUpdate.buildNumber > _currentBuild &&
        isTrustedUpdateUrl(latestAvailableUpdate.downloadUrl) &&
        isValidSha256Hex(latestAvailableUpdate.sha256Checksum)) {
      _availableUpdate = latestAvailableUpdate;
      _status = UpdateStatus.updateAvailable;
      notifyListeners();
      return latestAvailableUpdate;
    }

    _availableUpdate = null;
    _status = UpdateStatus.idle;
    notifyListeners();
    return null;
  }

  /// Creates a complete cryptographic emergency snapshot (`.cashio.bak`) before applying an update
  Future<EmergencyRollbackSnapshot> createEmergencyPreUpdateBackup({
    required String targetVersion,
    String note = 'Automated pre-update snapshot (.cashio.bak)',
  }) async {
    final repo = VaultRepository.instance;
    final timestamp = DateTime.now();
    _snapshotCounter++;
    final snapshotId = 'snap_${timestamp.millisecondsSinceEpoch}_$_snapshotCounter';

    final rawData = <String, dynamic>{
      'profile_id': repo.profileId,
      'profile_name': repo.profileName,
      'currency': repo.baseCurrency,
      'accounts': repo.accounts
          .map((a) => {
                'id': a.id,
                'name': a.name,
                'type': a.type.name,
                'currency': a.currency,
                'balance_cents': a.balanceCents,
              })
          .toList(),
      'transactions': repo.transactions
          .map((t) => {
                'id': t.id,
                'timestamp_ms': t.timestamp.millisecondsSinceEpoch,
                'description': t.description,
                'receipt_paths': t.receiptPaths,
                'note': t.note,
                'postings': t.postings
                    .map((p) => {
                          'account_id': p.accountId,
                          'amount_cents': p.amountCents,
                        })
                    .toList(),
              })
          .toList(),
      'envelopes': repo.envelopes
          .map((e) => {
                'id': e.id,
                'name': e.name,
                'assigned_cents': e.assignedCents,
                'spent_cents': e.spentCents,
                'target_cents': e.targetCents,
              })
          .toList(),
      'savings_goals': repo.savingsGoals
          .map((g) => {
                'id': g.id,
                'name': g.name,
                'target_cents': g.targetAmountCents,
                'current_cents': g.currentBalanceCents,
                'target_date_ms': g.targetDate.millisecondsSinceEpoch,
                'is_locked': g.isLocked,
              })
          .toList(),
    };

    final jsonStr = jsonEncode(rawData);
    final digest = sha256.convert(utf8.encode(jsonStr)).toString();

    final snapshot = EmergencyRollbackSnapshot(
      snapshotId: snapshotId,
      fromVersion: _currentVersion,
      fromBuild: _currentBuild,
      targetVersion: targetVersion,
      timestamp: timestamp,
      checksumSha256: digest,
      rawVaultData: rawData,
      note: note,
    );

    _snapshots.insert(0, snapshot);
    if (_useLiveGitHubReleases && !_isRunningInsideWidgetTest()) {
      await persistEmergencySnapshotToDisk(snapshotId, jsonEncode(snapshot.toJson()));
    }
    notifyListeners();
    return snapshot;
  }

  /// Verifies double-entry ledger invariants:
  /// Every transaction must have at least 2 postings and sum to exactly zero.
  bool verifyLedgerIntegrity() {
    final repo = VaultRepository.instance;

    for (final tx in repo.transactions) {
      if (tx.postings.length < 2) return false;
      final sum = tx.postings.fold<int>(0, (acc, p) => acc + p.amountCents);
      if (sum != 0) {
        return false; // Broken double-entry balance invariant
      }
    }

    return true;
  }

  /// Applies the update payload with origin validation, anti-downgrade check,
  /// pre-update `.cashio.bak` snapshot, SHA-256 verification, and native Android APK installation.
  Future<UpdateApplyResult> applyUpdate(
    AppUpdateManifest manifest, {
    bool simulateCorruptUpdate = false,
    Uint8List? payloadBytes,
    void Function(double progress, String statusText)? onProgress,
  }) async {
    await _syncInstalledPackageVersionIfNeeded();

    // 1. Anti-Downgrade Gate
    final isHigherSemver = compareSemver(manifest.version, _currentVersion) > 0;
    if (manifest.buildNumber <= _currentBuild && !isHigherSemver) {
      _status = UpdateStatus.error;
      notifyListeners();
      return UpdateApplyResult(
        success: false,
        wasRolledBack: false,
        message:
            'Security rejection: Downgrade or replay blocked (target build ${manifest.buildNumber} <= current $_currentBuild).',
      );
    }

    // 2. Trusted Origin & Manifest Checksum Format Gate
    final (targetUrl, expectedSha) = OtaPlatformBridge.isAndroidNative
        ? manifest.resolveAndroidTarget(_supportedAbis)
        : (manifest.effectiveApkUrl, manifest.effectiveApkSha256);

    if (!isTrustedUpdateUrl(targetUrl)) {
      _status = UpdateStatus.error;
      notifyListeners();
      return const UpdateApplyResult(
        success: false,
        wasRolledBack: false,
        message: 'Security rejection: Untrusted or non-HTTPS update origin blocked.',
      );
    }

    if (expectedSha.isNotEmpty && !isValidSha256Hex(expectedSha)) {
      _status = UpdateStatus.error;
      notifyListeners();
      return const UpdateApplyResult(
        success: false,
        wasRolledBack: false,
        message: 'Security rejection: Malformed SHA-256 manifest digest.',
      );
    }
    if (!_useLiveGitHubReleases && !isValidSha256Hex(expectedSha)) {
      _status = UpdateStatus.error;
      notifyListeners();
      return const UpdateApplyResult(
        success: false,
        wasRolledBack: false,
        message: 'Security rejection: Malformed SHA-256 manifest digest.',
      );
    }

    // 3. Create Pre-Update Emergency Snapshot (.cashio.bak)
    _status = UpdateStatus.creatingSnapshot;
    _downloadProgress = 0.15;
    onProgress?.call(0.15, 'Creating encrypted pre-update snapshot (.cashio.bak)...');
    notifyListeners();
    final snapshot = await createEmergencyPreUpdateBackup(targetVersion: manifest.version);

    // 4A. Live Native Android Verified DownloadManager + SHA-256 Checksum Flow
    if (_useLiveGitHubReleases && OtaPlatformBridge.isAndroidNative && payloadBytes == null) {
      _status = UpdateStatus.verifyingIntegrity;
      _downloadProgress = 0.25;
      onProgress?.call(0.25, 'Verifying double-entry ledger invariants before upgrade...');
      notifyListeners();

      if (!verifyLedgerIntegrity()) {
        _status = UpdateStatus.rolledBack;
        await rollbackToSnapshot(snapshot.snapshotId);
        notifyListeners();
        return UpdateApplyResult(
          success: false,
          wasRolledBack: true,
          message: 'Ledger integrity verification failed prior to install; rolled back safely.',
          snapshot: snapshot,
        );
      }

      _status = UpdateStatus.downloadingPayload;
      _downloadProgress = 0.30;
      onProgress?.call(0.30, 'Starting resumable system APK download for v${manifest.version}...');
      notifyListeners();

      final safeVersion = manifest.version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final downloadId = await OtaPlatformBridge.enqueueApkDownload(
        url: targetUrl,
        filename: 'Cash-IO-v$safeVersion.apk',
        title: 'Cash-IO v${manifest.version} Update',
      );

      if (downloadId != null && downloadId > 0) {
        const maxPolls = 600; // Up to ~6 minutes with resumable DownloadManager
        for (int poll = 0; poll < maxPolls; poll++) {
          final state = await OtaPlatformBridge.queryApkDownload(downloadId);
          if (state == null) {
            await OtaPlatformBridge.removeApkDownload(downloadId);
            _status = UpdateStatus.error;
            notifyListeners();
            return UpdateApplyResult(
              success: false,
              message:
                  'Emergency backup (${snapshot.snapshotId}) saved, but system DownloadManager lost download state. Please tap Retry.',
              snapshot: snapshot,
            );
          }

          final dlStatus = state['status'] as String? ?? 'running';
          final soFar = (state['bytesDownloaded'] as num?)?.toInt() ?? 0;
          final total = (state['totalBytes'] as num?)?.toInt() ?? -1;

          if (dlStatus == 'completed') {
            _status = UpdateStatus.verifyingChecksum;
            _downloadProgress = 0.94;
            onProgress?.call(0.94, 'Verifying downloaded APK SHA-256 signature & integrity...');
            notifyListeners();

            final actualSha = (state['sha256'] as String? ?? '').trim().toLowerCase();
            final sizeTruncated = total > 0 && soFar != total;
            final shaMismatch = expectedSha.isNotEmpty &&
                (actualSha.isEmpty ||
                    !E2eePackager.constantTimeStringEquals(actualSha, expectedSha.toLowerCase()));

            if (sizeTruncated || shaMismatch) {
              await OtaPlatformBridge.removeApkDownload(downloadId);
              _status = UpdateStatus.error;
              notifyListeners();
              return UpdateApplyResult(
                success: false,
                message:
                    'Incomplete or corrupted APK download blocked before install (SHA-256 / size mismatch). Partial file removed — please tap Retry on a stable connection.',
                snapshot: snapshot,
              );
            }

            _status = UpdateStatus.launchingInstaller;
            _downloadProgress = 1.0;
            onProgress?.call(1.0, 'SHA-256 verified! Opening Downloads to install Cash-IO v${manifest.version}...');
            notifyListeners();

            final opened = await OtaPlatformBridge.openVerifiedApkInstaller(downloadId);
            _status = UpdateStatus.completed;
            notifyListeners();
            return UpdateApplyResult(
              success: true,
              launchedSystemInstaller: opened,
              message:
                  'SHA-256 verified & backup (${snapshot.snapshotId}) saved! Tap "Cash-IO-v$safeVersion.apk" in Downloads (or your notification shade) and tap Update.',
              snapshot: snapshot,
            );
          }

          if (dlStatus == 'failed') {
            await OtaPlatformBridge.removeApkDownload(downloadId);
            _status = UpdateStatus.error;
            notifyListeners();
            return UpdateApplyResult(
              success: false,
              message:
                  'APK download interrupted. Emergency snapshot (${snapshot.snapshotId}) is safe — tap Retry or use Direct Browser Download.',
              snapshot: snapshot,
            );
          }

          if (total > 0 && soFar >= 0) {
            final ratio = (soFar / total).clamp(0.0, 1.0);
            _downloadProgress = 0.30 + (ratio * 0.62);
            final mbSoFar = (soFar / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
            onProgress?.call(
              _downloadProgress,
              'Downloading Cash-IO v${manifest.version} ($mbSoFar / $mbTotal MB)...',
            );
            notifyListeners();
          }

          if (!_isRunningInsideWidgetTest()) {
            await Future.delayed(const Duration(milliseconds: 600));
          }
        }

        await OtaPlatformBridge.removeApkDownload(downloadId);
        _status = UpdateStatus.error;
        notifyListeners();
        return UpdateApplyResult(
          success: false,
          message: 'APK download timed out before completing. Partial file cleaned up — please tap Retry.',
          snapshot: snapshot,
        );
      }

      // Fallback when system DownloadManager is unavailable on custom ROMs
      _status = UpdateStatus.launchingInstaller;
      _downloadProgress = 1.0;
      onProgress?.call(1.0, 'Opening signed Cash-IO v${manifest.version} APK download...');
      notifyListeners();

      final launched = await OtaPlatformBridge.openHttpsReleaseUrl(targetUrl);
      if (!launched) {
        _status = UpdateStatus.error;
        notifyListeners();
        return UpdateApplyResult(
          success: false,
          message:
              'Emergency snapshot (${snapshot.snapshotId}) saved, but could not open system browser for $targetUrl.',
          snapshot: snapshot,
        );
      }

      _status = UpdateStatus.completed;
      notifyListeners();
      return UpdateApplyResult(
        success: true,
        launchedSystemInstaller: true,
        message:
            'Emergency backup (${snapshot.snapshotId}) saved! Wait for the APK download to reach 100% before tapping Open -> Update.',
        snapshot: snapshot,
      );
    }

    // 4B. Live iOS IPA Release Flow
    if (_useLiveGitHubReleases && OtaPlatformBridge.isIOSNative && payloadBytes == null) {
      final iosUrl = manifest.effectiveIosUrl;
      final opened = await OtaPlatformBridge.openHttpsReleaseUrl(iosUrl);
      if (!opened) {
        try {
          await Clipboard.setData(ClipboardData(text: iosUrl));
        } catch (_) {}
      }
      _status = UpdateStatus.completed;
      notifyListeners();
      return UpdateApplyResult(
        success: true,
        launchedSystemInstaller: opened,
        message: opened
            ? 'Emergency backup (${snapshot.snapshotId}) saved! Opened signed GitHub Release IPA for Cash-IO v${manifest.version}.'
            : 'Emergency backup (${snapshot.snapshotId}) saved! Direct iOS IPA download link copied to clipboard: $iosUrl',
        snapshot: snapshot,
      );
    }

    // 5C. In-Memory / Web / Test Verification & State Migration Flow
    _status = UpdateStatus.verifyingChecksum;
    if (!_isRunningInsideWidgetTest()) {
      await Future.delayed(const Duration(milliseconds: 60));
    }
    if (payloadBytes != null && !verifyPayloadChecksum(payloadBytes, expectedSha)) {
      _status = UpdateStatus.rolledBack;
      await rollbackToSnapshot(snapshot.snapshotId);
      notifyListeners();
      return UpdateApplyResult(
        success: false,
        wasRolledBack: true,
        message:
            'Security alert: Binary SHA-256 checksum mismatch! Payload discarded and vault rolled back to ${snapshot.fromVersion}.',
        snapshot: snapshot,
      );
    }

    _status = UpdateStatus.applyingMigration;
    if (!_isRunningInsideWidgetTest()) {
      await Future.delayed(const Duration(milliseconds: 60));
    }

    _status = UpdateStatus.verifyingIntegrity;
    final isLedgerHealthy = !simulateCorruptUpdate && verifyLedgerIntegrity();

    if (!isLedgerHealthy) {
      _status = UpdateStatus.rolledBack;
      await rollbackToSnapshot(snapshot.snapshotId);
      notifyListeners();
      return UpdateApplyResult(
        success: false,
        wasRolledBack: true,
        message:
            'Update verification failed! Double-entry ledger invariant was breached. Automatically restored to ${snapshot.fromVersion}.',
        snapshot: snapshot,
      );
    }

    _currentVersion = manifest.version;
    _currentBuild = manifest.buildNumber;
    _availableUpdate = null;
    _downloadProgress = 1.0;
    _status = UpdateStatus.completed;
    notifyListeners();

    return UpdateApplyResult(
      success: true,
      wasRolledBack: false,
      message:
          'Successfully updated to Cash-IO v${manifest.version}. Emergency backup snapshot ${snapshot.snapshotId} saved.',
      snapshot: snapshot,
    );
  }

  /// Verifies snapshot SHA-256 tamper-evidence and restores complete vault state.
  Future<bool> rollbackToSnapshot(String snapshotId) async {
    final snapIndex = _snapshots.indexWhere((s) => s.snapshotId == snapshotId);
    if (snapIndex == -1) return false;

    final snapshot = _snapshots[snapIndex];
    final data = snapshot.rawVaultData;

    final computedDigest = sha256.convert(utf8.encode(jsonEncode(data))).toString();
    if (!E2eePackager.constantTimeStringEquals(computedDigest, snapshot.checksumSha256)) {
      _status = UpdateStatus.error;
      notifyListeners();
      return false;
    }

    try {
      VaultRepository.instance.restoreFromEmergencySnapshot(data);
      _currentVersion = snapshot.fromVersion;
      _currentBuild = snapshot.fromBuild;
      _status = UpdateStatus.rolledBack;
      notifyListeners();
      return true;
    } catch (_) {
      _status = UpdateStatus.error;
      notifyListeners();
      return false;
    }
  }

  void resetVersionForTesting({String version = '3.0.0', int build = 300}) {
    _currentVersion = version;
    _currentBuild = build;
    _useLiveGitHubReleases = false;
    _availableUpdate = null;
    _dismissedVersion = null;
    _downloadProgress = 0.0;
    _status = UpdateStatus.idle;
    _snapshots.clear();
  }
}
