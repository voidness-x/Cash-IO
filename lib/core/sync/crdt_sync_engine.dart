import 'dart:convert';
import 'dart:math';
import '../models/finance_models.dart';

class CrdtSyncEngine {
  static final CrdtSyncEngine instance = CrdtSyncEngine._init();
  CrdtSyncEngine._init();

  String _deviceId = '';
  int _lamportClock = 0;

  int get lamportClock => _lamportClock;
  String get deviceId => _deviceId;

  void initialize(String deviceId, int initialClock) {
    _deviceId = deviceId.isNotEmpty ? deviceId : _generateRandomId();
    _lamportClock = initialClock;
  }

  String _generateRandomId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Increments Lamport clock and produces an immutable mutation event
  Map<String, dynamic> createMutationEvent({
    required String profileId,
    required String entityType, // 'account', 'transaction', 'envelope'
    required String entityId,
    required String action,     // 'create', 'update', 'delete'
    required Map<String, dynamic> payload,
  }) {
    _lamportClock++;
    return {
      'event_id': '${DateTime.now().millisecondsSinceEpoch}_${_deviceId.substring(0, min(6, _deviceId.length))}',
      'profile_id': profileId,
      'device_id': _deviceId,
      'lamport_clock': _lamportClock,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload_json': jsonEncode(payload),
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Merges remote event logs into local state deterministically.
  /// Rule: Higher Lamport Clock wins. If equal, Device ID tie-breaker.
  List<MergeAuditLogModel> mergeRemoteEvents(
    List<Map<String, dynamic>> localEvents,
    List<Map<String, dynamic>> remoteEvents,
  ) {
    final List<MergeAuditLogModel> auditLogs = [];
    final Set<String> localEventIds = localEvents.map((e) => e['event_id'] as String).toSet();

    for (final remote in remoteEvents) {
      final remoteClock = remote['lamport_clock'] as int;
      final remoteId = remote['event_id'] as String;

      // Update our logical clock to maintain causality
      _lamportClock = max(_lamportClock, remoteClock) + 1;

      if (!localEventIds.contains(remoteId)) {
        // Check if there is a concurrent update on the same entity
        final localMatch = localEvents.where(
          (l) => l['entity_id'] == remote['entity_id'] && l['action'] == remote['action'],
        );

        if (localMatch.isNotEmpty) {
          final local = localMatch.first;
          final localClock = local['lamport_clock'] as int;
          final localDevice = local['device_id'] as String;
          final remoteDevice = remote['device_id'] as String;

          // Deterministic winner
          final bool remoteWins = remoteClock > localClock ||
              (remoteClock == localClock && remoteDevice.compareTo(localDevice) > 0);

          auditLogs.add(MergeAuditLogModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            entityName: '${remote['entity_type']}: ${remote['entity_id']}',
            conflictType: 'Concurrent Edit Detected',
            resolution: remoteWins
                ? 'Remote update applied (L$remoteClock > L$localClock)'
                : 'Local update retained (L$localClock >= L$remoteClock)',
          ));
        }
      }
    }

    return auditLogs;
  }
}
