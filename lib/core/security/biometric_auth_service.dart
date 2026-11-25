import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native hardware biometric bridge (`com.cashio.app/biometrics`)
/// connecting Flutter's Lock Screen to Android's `androidx.biometric.BiometricPrompt`.
class BiometricAuthService {
  BiometricAuthService._();

  static final BiometricAuthService instance = BiometricAuthService._();

  static const MethodChannel _channel = MethodChannel('com.cashio.app/biometrics');

  static bool get _isTestBinding {
    try {
      final type = WidgetsBinding.instance.runtimeType.toString();
      return type.contains('TestWidgetsFlutterBinding') ||
          type.contains('AutomatedTestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }

  /// Checks if the current device has enrolled fingerprint / biometric sensors ready for unlock.
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb || _isTestBinding) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      final available = await _channel
          .invokeMethod<bool>('isBiometricAvailable')
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      return available ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers the OS-level Fingerprint / Face biometric prompt.
  Future<bool> authenticate({
    String title = 'Unlock Cash-IO Vault',
    String subtitle = 'Touch the fingerprint sensor to sign in',
    String cancelText = 'Use 6-Digit PIN',
  }) async {
    if (kIsWeb || _isTestBinding) return false;
    try {
      final success = await _channel.invokeMethod<bool>('authenticate', {
        'title': title,
        'subtitle': subtitle,
        'cancelText': cancelText,
      });
      return success ?? false;
    } catch (_) {
      return false;
    }
  }
}
