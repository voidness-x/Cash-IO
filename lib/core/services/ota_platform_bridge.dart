import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native bridge to `MainActivity.kt` (`com.cashio.app/ota_installer`)
/// for Android self-updating APK installation and permission verification.
class OtaPlatformBridge {
  OtaPlatformBridge._();

  static const MethodChannel _channel = MethodChannel('com.cashio.app/ota_installer');

  static bool get isAndroidNative => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOSNative => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Checks whether the OS permits this app to launch APK package installation (`REQUEST_INSTALL_PACKAGES`).
  static Future<bool> canInstallPackages() async {
    if (!isAndroidNative) return true;
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstallPackages');
      return allowed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the Android system settings screen to grant "Install unknown apps" for Cash-IO.
  static Future<bool> openInstallPermissionSettings() async {
    if (!isAndroidNative) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Hands a SHA-256-verified APK file inside the app sandbox to Android's native PackageInstaller.
  static Future<bool> installVerifiedApk(String filePath) async {
    if (!isAndroidNative) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
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

  /// Reads the installed OS package versionName & versionCode on Android when available.
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
