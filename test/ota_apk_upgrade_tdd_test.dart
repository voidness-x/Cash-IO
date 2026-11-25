import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/services/update_receiver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel otaChannel = MethodChannel('com.cashio.app/ota_installer');

  const String universalUrl =
      'https://github.com/voidness-x/Cash-IO/releases/download/v3.1.1/cashio-v3.1.1-android.apk';
  const String universalSha =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const String arm64Url =
      'https://github.com/voidness-x/Cash-IO/releases/download/v3.1.1/cashio-v3.1.1-android-arm64.apk';
  const String arm64Sha =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  setUp(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(otaChannel, null);
    await VaultRepository.instance.initializeProfile(
      name: 'OTA Upgrade TDD Vault',
      currency: 'IQD',
      onlineFx: false,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(otaChannel, null);
  });

  test('AppUpdateManifest preserves slim arm64 APK URL and SHA-256 from manifest.json and GitHub API', () {
    final fromManifest = AppUpdateManifest.tryParseJson({
      'version': '3.1.1',
      'build_number': 30101,
      'release_date': '2026-11-25',
      'title': 'Cash-IO v3.1.1 Release',
      'changelog': ['Verified Android OTA upgrade'],
      'sha256_checksum': universalSha,
      'download_url': universalUrl,
      'apk_download_url': universalUrl,
      'apk_sha256_checksum': universalSha,
      'apk_arm64_download_url': arm64Url,
      'apk_arm64_sha256_checksum': arm64Sha,
    });

    expect(fromManifest, isNotNull);
    expect(fromManifest!.toJson()['apk_arm64_download_url'], arm64Url);
    expect(fromManifest.toJson()['apk_arm64_sha256_checksum'], arm64Sha);

    // GitHub Releases API lists android-arm64.apk BEFORE android.apk; parser must not overwrite arm64 metadata
    final fromGhApi = AppUpdateManifest.tryParseJson({
      'tag_name': 'v3.1.1',
      'name': 'Cash-IO v3.1.1',
      'published_at': '2026-11-25T21:00:00Z',
      'assets': [
        {
          'name': 'cashio-v3.1.1-android-arm64.apk',
          'browser_download_url': arm64Url,
          'digest': 'sha256:$arm64Sha',
        },
        {
          'name': 'cashio-v3.1.1-android.apk',
          'browser_download_url': universalUrl,
          'digest': 'sha256:$universalSha',
        },
      ],
    });

    expect(fromGhApi, isNotNull);
    expect(fromGhApi!.toJson()['apk_arm64_download_url'], arm64Url);
    expect(fromGhApi.toJson()['apk_arm64_sha256_checksum'], arm64Sha);
  });

  test('Android applyUpdate aborts and removes truncated/corrupt APK instead of launching installer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(otaChannel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'getInstalledPackageInfo':
          return <String, dynamic>{
            'versionName': '3.0.1',
            'versionCode': 30001,
            'supportedAbis': <String>['arm64-v8a', 'armeabi-v7a'],
          };
        case 'enqueueApkDownload':
          return 42;
        case 'queryApkDownload':
          // Simulate a truncated / corrupt download whose SHA-256 does NOT match manifest
          return <String, dynamic>{
            'status': 'completed',
            'bytesDownloaded': 9761793,
            'totalBytes': 13857699,
            'sha256': '0000000000000000000000000000000000000000000000000000000000000000',
          };
        case 'removeApkDownload':
          return true;
        case 'openExternalUrl':
          return true;
        default:
          return null;
      }
    });

    final manifest = AppUpdateManifest.tryParseJson({
      'version': '3.1.2',
      'build_number': 30102,
      'release_date': '2026-11-25',
      'title': 'Cash-IO v3.1.2',
      'changelog': ['Fix truncated APK update'],
      'sha256_checksum': universalSha,
      'download_url': universalUrl,
      'apk_download_url': universalUrl,
      'apk_sha256_checksum': universalSha,
      'apk_arm64_download_url': arm64Url,
      'apk_arm64_sha256_checksum': arm64Sha,
    })!;

    final result = await UpdateReceiverService.instance.applyUpdate(manifest);

    expect(result.success, isFalse);
    expect(calls.any((c) => c.method == 'removeApkDownload'), isTrue);
    expect(calls.any((c) => c.method == 'openVerifiedApkInstaller'), isFalse);
  });

  test('Android applyUpdate on arm64-v8a downloads slim arm64 APK, verifies SHA-256, and opens verified installer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(otaChannel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'getInstalledPackageInfo':
          return <String, dynamic>{
            'versionName': '3.0.1',
            'versionCode': 30001,
            'supportedAbis': <String>['arm64-v8a', 'armeabi-v7a'],
          };
        case 'enqueueApkDownload':
          return 77;
        case 'queryApkDownload':
          return <String, dynamic>{
            'status': 'completed',
            'bytesDownloaded': 11500000,
            'totalBytes': 11500000,
            'sha256': arm64Sha,
          };
        case 'openVerifiedApkInstaller':
          return true;
        default:
          return null;
      }
    });

    final manifest = AppUpdateManifest.tryParseJson({
      'version': '3.1.2',
      'build_number': 30102,
      'release_date': '2026-11-25',
      'title': 'Cash-IO v3.1.2',
      'changelog': ['Slim arm64 verified OTA'],
      'sha256_checksum': universalSha,
      'download_url': universalUrl,
      'apk_download_url': universalUrl,
      'apk_sha256_checksum': universalSha,
      'apk_arm64_download_url': arm64Url,
      'apk_arm64_sha256_checksum': arm64Sha,
    })!;

    final result = await UpdateReceiverService.instance.applyUpdate(manifest);

    expect(result.success, isTrue);
    expect(result.launchedSystemInstaller, isTrue);

    final enqueueCall = calls.firstWhere((c) => c.method == 'enqueueApkDownload');
    final args = Map<String, dynamic>.from(enqueueCall.arguments as Map);
    expect(args['url'], arm64Url);
    expect(calls.any((c) => c.method == 'openVerifiedApkInstaller'), isTrue);
  });
}
