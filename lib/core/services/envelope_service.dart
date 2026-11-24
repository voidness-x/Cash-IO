import 'package:flutter/material.dart';
import '../models/finance_models.dart';
import '../commands/finance_commands.dart';
import '../results/result.dart';
import '../storage/database_helper.dart';
import '../sync/crdt_sync_engine.dart';
import 'ledger_service.dart';

abstract interface class IEnvelopeService {
  Future<Result<EnvelopeModel, AppError>> createEnvelope(CreateEnvelopeCommand cmd);
  Future<Result<EnvelopeModel, AppError>> assignFunds(AssignEnvelopeFundsCommand cmd);
  Future<Result<List<EnvelopeModel>, AppError>> getEnvelopes(String profileId);
  Future<Result<int, AppError>> getAvailableToAssignCents(String profileId);
  Future<Result<EnvelopeModel, AppError>> recordExpense(String envelopeId, int expenseCents);
}

class EnvelopeService implements IEnvelopeService {
  static final EnvelopeService instance = EnvelopeService._init();
  final DatabaseHelper _dbHelper;
  final CrdtSyncEngine _crdtEngine;
  final ILedgerService _ledgerService;

  EnvelopeService({
    DatabaseHelper? dbHelper,
    CrdtSyncEngine? crdtEngine,
    ILedgerService? ledgerService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _crdtEngine = crdtEngine ?? CrdtSyncEngine.instance,
        _ledgerService = ledgerService ?? LedgerService.instance;

  EnvelopeService._init()
      : _dbHelper = DatabaseHelper.instance,
        _crdtEngine = CrdtSyncEngine.instance,
        _ledgerService = LedgerService.instance;

  @override
  Future<Result<EnvelopeModel, AppError>> createEnvelope(CreateEnvelopeCommand cmd) async {
    if (cmd.name.trim().isEmpty) {
      return const Failure(
        ValidationError('Envelope category name cannot be empty', field: 'name'),
      );
    }

    try {
      final db = await _dbHelper.database;
      final envelope = EnvelopeModel(
        id: 'env_${DateTime.now().millisecondsSinceEpoch}',
        name: cmd.name.trim(),
        assignedCents: cmd.assignedCents,
        spentCents: 0,
        targetCents: cmd.targetCents,
        icon: Icons.folder_outlined,
      );

      await db.insert('envelopes', {
        'id': envelope.id,
        'profile_id': cmd.profileId,
        'name': envelope.name,
        'assigned_cents': envelope.assignedCents,
        'spent_cents': envelope.spentCents,
        'target_cents': envelope.targetCents,
      });

      // Append CRDT mutation event
      final mutation = _crdtEngine.createMutationEvent(
        profileId: cmd.profileId,
        entityType: 'envelope',
        entityId: envelope.id,
        action: 'create',
        payload: {
          'name': envelope.name,
          'assigned_cents': envelope.assignedCents,
          'target_cents': envelope.targetCents,
        },
      );
      await db.insert('crdt_events', mutation);

      return Success(envelope);
    } catch (e) {
      return Failure(StorageError('Failed to create envelope: $e', cause: e));
    }
  }

  @override
  Future<Result<EnvelopeModel, AppError>> assignFunds(AssignEnvelopeFundsCommand cmd) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'envelopes',
        where: 'id = ? AND profile_id = ?',
        whereArgs: [cmd.envelopeId, cmd.profileId],
        limit: 1,
      );

      if (rows.isEmpty) {
        return Failure(
          NotFoundError(
            'Envelope not found',
            entityType: 'Envelope',
            entityId: cmd.envelopeId,
          ),
        );
      }

      final envData = rows.first;
      final currentSpent = envData['spent_cents'] as int;
      final targetCents = envData['target_cents'] as int;
      final name = envData['name'] as String;

      final updatedEnvelope = EnvelopeModel(
        id: cmd.envelopeId,
        name: name,
        assignedCents: cmd.amountCents,
        spentCents: currentSpent,
        targetCents: targetCents,
      );

      await db.update(
        'envelopes',
        {'assigned_cents': cmd.amountCents},
        where: 'id = ?',
        whereArgs: [cmd.envelopeId],
      );

      // Append CRDT mutation event
      final mutation = _crdtEngine.createMutationEvent(
        profileId: cmd.profileId,
        entityType: 'envelope',
        entityId: cmd.envelopeId,
        action: 'update',
        payload: {
          'assigned_cents': cmd.amountCents,
        },
      );
      await db.insert('crdt_events', mutation);

      return Success(updatedEnvelope);
    } catch (e) {
      return Failure(StorageError('Failed to assign funds to envelope: $e', cause: e));
    }
  }

  @override
  Future<Result<List<EnvelopeModel>, AppError>> getEnvelopes(String profileId) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'envelopes',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'name ASC',
      );

      final envelopes = rows.map((m) {
        return EnvelopeModel(
          id: m['id'] as String,
          name: m['name'] as String,
          assignedCents: m['assigned_cents'] as int,
          spentCents: m['spent_cents'] as int,
          targetCents: m['target_cents'] as int,
          icon: Icons.folder_outlined,
        );
      }).toList();

      return Success(envelopes);
    } catch (e) {
      return Failure(StorageError('Failed to query envelopes: $e', cause: e));
    }
  }

  @override
  Future<Result<int, AppError>> getAvailableToAssignCents(String profileId) async {
    try {
      final accountsResult = await _ledgerService.getAccounts(profileId);
      final envelopesResult = await getEnvelopes(profileId);

      if (accountsResult.isFailure) return Failure(accountsResult.errorOrNull!);
      if (envelopesResult.isFailure) return Failure(envelopesResult.errorOrNull!);

      final totalAssets = accountsResult.dataOrNull!
          .where((a) => a.type == AccountType.asset)
          .fold<int>(0, (sum, a) => sum + a.balanceCents);

      final totalAssigned = envelopesResult.dataOrNull!
          .fold<int>(0, (sum, e) => sum + e.assignedCents);

      return Success(totalAssets - totalAssigned);
    } catch (e) {
      return Failure(StorageError('Failed to compute available funds: $e', cause: e));
    }
  }

  @override
  Future<Result<EnvelopeModel, AppError>> recordExpense(String envelopeId, int expenseCents) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'envelopes',
        where: 'id = ?',
        whereArgs: [envelopeId],
        limit: 1,
      );

      if (rows.isEmpty) {
        return Failure(
          NotFoundError('Envelope not found', entityType: 'Envelope', entityId: envelopeId),
        );
      }

      final envData = rows.first;
      final currentSpent = envData['spent_cents'] as int;
      final newSpent = currentSpent + expenseCents;

      await db.update(
        'envelopes',
        {'spent_cents': newSpent},
        where: 'id = ?',
        whereArgs: [envelopeId],
      );

      return Success(EnvelopeModel(
        id: envelopeId,
        name: envData['name'] as String,
        assignedCents: envData['assigned_cents'] as int,
        spentCents: newSpent,
        targetCents: envData['target_cents'] as int,
      ));
    } catch (e) {
      return Failure(StorageError('Failed to record envelope expense: $e', cause: e));
    }
  }
}
