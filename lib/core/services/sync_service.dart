import 'dart:convert';
import '../models/finance_models.dart';
import '../results/result.dart';
import '../storage/database_helper.dart';
import '../sync/crdt_sync_engine.dart';

abstract interface class ISyncService {
  Future<Result<List<MergeAuditLogModel>, AppError>> processRemoteEvents({
    required String profileId,
    required List<Map<String, dynamic>> remoteEvents,
  });
  Future<Result<String, AppError>> exportSyncPayload(String profileId);
  Future<Result<List<Map<String, dynamic>>, AppError>> getEventLog(String profileId);
}

class SyncService implements ISyncService {
  static final SyncService instance = SyncService._init();
  final DatabaseHelper _dbHelper;
  final CrdtSyncEngine _crdtEngine;

  SyncService({DatabaseHelper? dbHelper, CrdtSyncEngine? crdtEngine})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _crdtEngine = crdtEngine ?? CrdtSyncEngine.instance;

  SyncService._init()
      : _dbHelper = DatabaseHelper.instance,
        _crdtEngine = CrdtSyncEngine.instance;

  @override
  Future<Result<List<MergeAuditLogModel>, AppError>> processRemoteEvents({
    required String profileId,
    required List<Map<String, dynamic>> remoteEvents,
  }) async {
    try {
      final db = await _dbHelper.database;
      final localRows = await db.query(
        'crdt_events',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );

      final auditLogs = _crdtEngine.mergeRemoteEvents(localRows, remoteEvents);

      // Insert any new events from remote into local event log
      final localEventIds = localRows.map((e) => e['event_id'] as String).toSet();
      for (final event in remoteEvents) {
        if (!localEventIds.contains(event['event_id'])) {
          await db.insert('crdt_events', event);
        }
      }

      return Success(auditLogs);
    } catch (e) {
      return Failure(SyncError('CRDT event synchronization failed: $e', cause: e));
    }
  }

  @override
  Future<Result<String, AppError>> exportSyncPayload(String profileId) async {
    try {
      final eventsResult = await getEventLog(profileId);
      if (eventsResult.isFailure) return Failure(eventsResult.errorOrNull!);

      final events = eventsResult.dataOrNull!;
      final payload = {
        'profile_id': profileId,
        'device_id': _crdtEngine.deviceId,
        'lamport_clock': _crdtEngine.lamportClock,
        'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
        'events': events,
      };

      return Success(jsonEncode(payload));
    } catch (e) {
      return Failure(SyncError('Failed to serialize export payload: $e', cause: e));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getEventLog(String profileId) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'crdt_events',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'lamport_clock ASC',
      );
      return Success(rows);
    } catch (e) {
      return Failure(StorageError('Failed to read CRDT event log: $e', cause: e));
    }
  }
}
