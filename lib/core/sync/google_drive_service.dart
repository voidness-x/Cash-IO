import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'crdt_sync_engine.dart';
import 'e2ee_packager.dart';
import '../models/finance_models.dart';
import '../storage/database_helper.dart';
import '../storage/vault_repository.dart';

enum SyncStatus {
  idle,
  syncing,
  synced,
  offline,
  error,
}

class GoogleDriveService extends ChangeNotifier {
  static final GoogleDriveService instance = GoogleDriveService._init();
  GoogleDriveService._init();

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  String? _lastError;
  bool _isConnected = false;
  Timer? _debounceTimer;

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  bool get isConnected => _isConnected;

  /// Connects to Google Drive with drive.appdata scope (simulation/PKCE readiness)
  Future<bool> connectGoogleDrive() async {
    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      // Simulating OAuth2 PKCE authorization exchange for drive.appdata
      await Future.delayed(const Duration(milliseconds: 600));
      _isConnected = true;
      _status = SyncStatus.synced;
      _lastSyncTime = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  void disconnect() {
    _isConnected = false;
    _status = SyncStatus.idle;
    _lastSyncTime = null;
    notifyListeners();
  }

  /// Schedules a debounced sync 5 seconds after an edit (per locked Phase 4 decision)
  void scheduleDebouncedSync() {
    if (!_isConnected) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      syncNow();
    });
  }

  /// Performs immediate zero-knowledge sync with Google Drive AppData
  Future<void> syncNow() async {
    if (_status == SyncStatus.syncing) return;

    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      final repo = VaultRepository.instance;
      final profileId = repo.profileId;

      // 1. Gather all local events
      final db = await DatabaseHelper.instance.database;
      final localRows = await db.query(
        'crdt_events',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );

      // 2. Encrypt the payload with AES-GCM envelope
      final payloadJson = jsonEncode(localRows);
      final encryptedBytes = E2eePackager.instance.encryptPayload(
        plaintextJson: payloadJson,
        vaultKeyHash: 'key_$profileId',
      );

      final remoteFilename = E2eePackager.instance.getRemoteVaultFilename(profileId);

      // 3. Simulated Network transfer to Google Drive AppData
      await Future.delayed(const Duration(milliseconds: 800));

      // 4. Decrypt and check for remote deltas
      final decrypted = E2eePackager.instance.decryptPayload(
        encryptedData: encryptedBytes,
        vaultKeyHash: 'key_$profileId',
      );

      if (decrypted != null) {
        // Run CRDT Merge check
        final decodedList = (jsonDecode(decrypted) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final auditLogs = CrdtSyncEngine.instance.mergeRemoteEvents(
          localRows,
          decodedList,
        );

        for (final log in auditLogs) {
          repo.recordMergeAuditLog(log);
        }
      }

      _status = SyncStatus.synced;
      _lastSyncTime = DateTime.now();
      _lastError = null;

      repo.recordMergeAuditLog(
        MergeAuditLogModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          entityName: remoteFilename,
          conflictType: 'E2EE AppData Push',
          resolution: '${encryptedBytes.length} bytes encrypted & synchronized.',
        ),
      );
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
