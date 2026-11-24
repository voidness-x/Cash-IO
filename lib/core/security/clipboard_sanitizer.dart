import 'dart:async';
import 'package:flutter/services.dart';

/// DevSecOps Auto-Sanitizing Clipboard Manager.
/// Automatically wipes sensitive data (e.g. 12-word BIP-39 mnemonic, export passwords, PINs)
/// from the system clipboard after a 30-second window to prevent background clipboard inspection.
class ClipboardSanitizer {
  ClipboardSanitizer._();

  static Timer? _wipeTimer;
  static String? _trackedContent;

  /// Copies sensitive text to the OS clipboard and schedules automatic memory zeroization.
  static Future<void> copySensitive({
    required String text,
    Duration timeout = const Duration(seconds: 30),
    VoidCallback? onAutoWiped,
  }) async {
    _wipeTimer?.cancel();
    _trackedContent = text;

    await Clipboard.setData(ClipboardData(text: text));

    _wipeTimer = Timer(timeout, () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        // Only clear if the user hasn't overwritten the clipboard with something else
        if (current?.text == _trackedContent) {
          await Clipboard.setData(const ClipboardData(text: ''));
          onAutoWiped?.call();
        }
      } catch (_) {
        // Fallback safety
      } finally {
        _trackedContent = null;
        _wipeTimer = null;
      }
    });
  }

  /// Immediately zeroes out tracked clipboard contents.
  static Future<void> wipeImmediately() async {
    _wipeTimer?.cancel();
    _wipeTimer = null;
    _trackedContent = null;
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  /// Whether an auto-wipe timer is currently ticking.
  static bool get isTracking => _wipeTimer != null && _wipeTimer!.isActive;

  /// Cancels any active wipe timer (useful in unit test teardowns).
  static void cancelTracking() {
    _wipeTimer?.cancel();
    _wipeTimer = null;
    _trackedContent = null;
  }
}
