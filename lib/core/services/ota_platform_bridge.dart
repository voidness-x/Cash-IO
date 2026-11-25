import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native bridge to `MainActivity.kt` (`com.cashio.app/ota_installer`)
/// for Play-Protect-safe Android DownloadManager APK delivery, streaming SHA-256 verification,
/// and system installer handoff.
class OtaPlatformBridge {
  OtaPlatformBridge._();

  static const MethodChannel _channel = MethodChannel('com.cashio.app/ota_installer');

  static bool get isAndroidNative => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOSNative => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Checks whether the OS permits package installation handoff.
  static Future<bool> canInstallPackages() async {
    if (!isAndroidNative) return true;
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstallPackages');
      return allowed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Enqueues a resumable HTTPS APK download via Android's privileged system `DownloadManager`.
  /// Returns the positive system `downloadId`, or `null` if unavailable.
  static Future<int?> enqueueApkDownload({
    required String url,
    required String filename,
    required String title,
  }) async {
    if (!isAndroidNative) return null;
    try {
      final id = await _channel.invokeMethod<num>('enqueueApkDownload', {
        'url': url,
        'filename': filename,
        'title': title,
      });
      return id?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Queries live byte progress and (upon completion) the computed SHA-256 hex digest of `downloadId`.
  static Future<Map<String, dynamic>?> queryApkDownload(int downloadId) async {
    if (!isAndroidNative) return null;
    try {
      return await _channel.invokeMapMethod<String, dynamic>('queryApkDownload', {
        'downloadId': downloadId,
      });
    } catch (_) {
      return null;
    }
  }

  /// Deletes an incomplete or SHA-256-mismatched download from Android `DownloadManager`.
  static Future<bool> removeApkDownload(int downloadId) async {
    if (!isAndroidNative) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('removeApkDownload', {
        'downloadId': downloadId,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's system Downloads view so the user can tap the SHA-256-verified APK
  /// to upgrade in-place via Android's trusted system `DocumentsUI` installer.
  static Future<bool> openVerifiedApkInstaller(int downloadId) async {
    if (!isAndroidNative) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openVerifiedApkInstaller', {
        'downloadId': downloadId,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens an HTTPS GitHub Release URL in the device's system browser (used on iOS / fallback).
  static Future<bool> openHttpsReleaseUrl(String url) async {
    if (kIsWeb) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openExternalUrl', {'url': url});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Reads the installed OS package `versionName`, `versionCode`, and `supportedAbis` on Android.
  static Future<Map<String, dynamic>?> getInstalledPackageInfo() async {
    if (!isAndroidNative) return null;
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getInstalledPackageInfo');
      return info;
    } catch (_) {
      return null;
    }
  }
}
