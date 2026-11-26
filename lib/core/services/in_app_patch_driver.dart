import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart' as sb;

/// Status returned when checking for silent in-app Dart patches.
enum InAppPatchStatus {
  upToDate,
  outdated,
  restartRequired,
  unavailable,
}

/// Summary of an in-app silent patch check.
class InAppPatchCheckResult {
  final bool isSupported;
  final InAppPatchStatus status;
  final int? currentPatchNumber;

  const InAppPatchCheckResult({
    required this.isSupported,
    required this.status,
    this.currentPatchNumber,
  });

  bool get isAvailable => status == InAppPatchStatus.outdated;
  bool get restartRequired => status == InAppPatchStatus.restartRequired;
}

/// Abstract driver for silent in-app Dart/UI code-push updates (e.g. Shorebird).
/// Decoupled so tests can verify snapshot creation, integrity checks, and patch
/// staging deterministically without native engine dependencies.
abstract interface class InAppPatchDriver {
  bool get isSupported;
  Future<int?> readCurrentPatchNumber();
  Future<InAppPatchStatus> checkForPatch();
  Future<void> downloadAndStagePatch();
}

/// Production driver backed by `shorebird_code_push`.
/// Gracefully reports `unavailable` on web, tests, or standard non-Shorebird builds.
class ShorebirdInAppPatchDriver implements InAppPatchDriver {
  sb.ShorebirdUpdater? _updater;
  bool _initialized = false;

  sb.ShorebirdUpdater? _getUpdater() {
    if (kIsWeb) return null;
    if (!_initialized) {
      _initialized = true;
      try {
        _updater = sb.ShorebirdUpdater();
      } catch (_) {
        _updater = null;
      }
    }
    return _updater;
  }

  @override
  bool get isSupported {
    try {
      return _getUpdater()?.isAvailable ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int?> readCurrentPatchNumber() async {
    final updater = _getUpdater();
    if (updater == null || !updater.isAvailable) return null;
    try {
      final patch = await updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<InAppPatchStatus> checkForPatch() async {
    final updater = _getUpdater();
    if (updater == null || !updater.isAvailable) {
      return InAppPatchStatus.unavailable;
    }
    try {
      final status = await updater.checkForUpdate();
      switch (status) {
        case sb.UpdateStatus.upToDate:
          return InAppPatchStatus.upToDate;
        case sb.UpdateStatus.outdated:
          return InAppPatchStatus.outdated;
        case sb.UpdateStatus.restartRequired:
          return InAppPatchStatus.restartRequired;
        case sb.UpdateStatus.unavailable:
          return InAppPatchStatus.unavailable;
      }
    } catch (_) {
      return InAppPatchStatus.unavailable;
    }
  }

  @override
  Future<void> downloadAndStagePatch() async {
    final updater = _getUpdater();
    if (updater == null || !updater.isAvailable) {
      throw StateError('Shorebird silent patch engine is not active in this build.');
    }
    await updater.update();
  }
}
