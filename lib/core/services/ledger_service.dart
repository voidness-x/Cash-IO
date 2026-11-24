import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/finance_models.dart';
import '../commands/finance_commands.dart';
import '../results/result.dart';
import '../storage/database_helper.dart';
import '../sync/crdt_sync_engine.dart';

abstract interface class ILedgerService {
  Future<Result<TransactionModel, AppError>> recordTransaction(RecordTransactionCommand cmd);
  Future<Result<AccountModel, AppError>> createAccount(CreateAccountCommand cmd);
  Future<Result<List<AccountModel>, AppError>> getAccounts(String profileId, {AccountType? filter});
  Future<Result<List<TransactionModel>, AppError>> getTransactions(String profileId, {int limit = 50, int offset = 0});
  Future<Result<int, AppError>> getNetWorthCents(String profileId);
  Future<Result<Map<String, int>, AppError>> get30DayCashFlow(String profileId);
}

class LedgerService implements ILedgerService {
  static final LedgerService instance = LedgerService._init();
  final DatabaseHelper _dbHelper;
  final CrdtSyncEngine _crdtEngine;

  LedgerService({DatabaseHelper? dbHelper, CrdtSyncEngine? crdtEngine})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _crdtEngine = crdtEngine ?? CrdtSyncEngine.instance;

  LedgerService._init()
      : _dbHelper = DatabaseHelper.instance,
        _crdtEngine = CrdtSyncEngine.instance;

  @override
  Future<Result<TransactionModel, AppError>> recordTransaction(RecordTransactionCommand cmd) async {
    // 1. Invariant: double-entry requires at least two posting legs
    if (cmd.postings.length < 2) {
      return const Failure(
        ValidationError(
          'A transaction requires at least 2 postings to satisfy double-entry accounting',
          field: 'postings',
          code: 'ERR_INSUFFICIENT_POSTINGS',
        ),
      );
    }

    // 2. Invariant: sum of all postings must equal zero (Zero-Sum Invariant)
    if (!cmd.isBalanced) {
      return Failure(
        InvariantViolationError(
          'Transaction postings are unbalanced. Sum of debit and credit must equal zero.',
          balanceDifferenceCents: cmd.balanceDiscrepancyCents,
          code: 'ERR_UNBALANCED_POSTINGS',
        ),
      );
    }

    // 3. Invariant: description cannot be blank
    if (cmd.description.trim().isEmpty) {
      return const Failure(
        ValidationError(
          'Transaction description cannot be blank',
          field: 'description',
          code: 'ERR_EMPTY_DESCRIPTION',
        ),
      );
    }

    try {
      final db = await _dbHelper.database;
      final txId = DateTime.now().millisecondsSinceEpoch.toString();

      final tx = TransactionModel(
        id: txId,
        timestamp: cmd.timestamp,
        description: cmd.description.trim(),
        postings: cmd.postings,
        receiptPaths: cmd.receiptPaths,
        note: cmd.note,
      );

      // Execute inside an atomic SQLite transaction
      await db.transaction((txn) async {
        // Insert transaction record
        await txn.insert(
          'transactions',
          {
            'id': tx.id,
            'profile_id': cmd.profileId,
            'timestamp_ms': tx.timestamp.millisecondsSinceEpoch,
            'description': tx.description,
            'note': tx.note,
            'receipt_paths': tx.receiptPaths.join(';'),
          },
        );

        // Insert postings and update account balances atomically
        for (final p in cmd.postings) {
          await txn.insert(
            'postings',
            {
              'transaction_id': tx.id,
              'account_id': p.accountId,
              'amount_cents': p.amountCents,
            },
          );

          // Fetch current account
          final accRows = await txn.query(
            'accounts',
            where: 'id = ? AND profile_id = ?',
            whereArgs: [p.accountId, cmd.profileId],
            limit: 1,
          );

          if (accRows.isNotEmpty) {
            final acc = accRows.first;
            final typeStr = acc['type'] as String;
            final currentBalance = acc['balance_cents'] as int;

            int newBalance = currentBalance;
            if (typeStr == AccountType.asset.name || typeStr == AccountType.expense.name) {
              newBalance += p.amountCents;
            } else {
              newBalance += (-p.amountCents);
            }

            await txn.update(
              'accounts',
              {'balance_cents': newBalance},
              where: 'id = ?',
              whereArgs: [p.accountId],
            );
          }
        }

        // CRDT Event Sourcing
        final mutation = _crdtEngine.createMutationEvent(
          profileId: cmd.profileId,
          entityType: 'transaction',
          entityId: tx.id,
          action: 'create',
          payload: {
            'description': tx.description,
            'timestamp_ms': tx.timestamp.millisecondsSinceEpoch,
            'postings': tx.postings
                .map((p) => {'account_id': p.accountId, 'amount_cents': p.amountCents})
                .toList(),
            'receipt_paths': tx.receiptPaths,
            'note': tx.note,
          },
        );

        await txn.insert(
          'crdt_events',
          mutation,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

      return Success(tx);
    } catch (e) {
      return Failure(
        StorageError('Failed to commit transaction to ledger: $e', cause: e),
      );
    }
  }

  static IconData _resolveAccountIcon(int codePoint) {
    if (codePoint == Icons.wallet_outlined.codePoint) return Icons.wallet_outlined;
    if (codePoint == Icons.account_balance_outlined.codePoint) return Icons.account_balance_outlined;
    if (codePoint == Icons.shopping_bag_outlined.codePoint) return Icons.shopping_bag_outlined;
    if (codePoint == Icons.payments_outlined.codePoint) return Icons.payments_outlined;
    if (codePoint == Icons.credit_card_outlined.codePoint) return Icons.credit_card_outlined;
    if (codePoint == Icons.savings_outlined.codePoint) return Icons.savings_outlined;
    return Icons.account_balance_wallet_outlined;
  }

  @override
  Future<Result<AccountModel, AppError>> createAccount(CreateAccountCommand cmd) async {
    if (cmd.name.trim().isEmpty) {
      return const Failure(
        ValidationError('Account name cannot be empty', field: 'name'),
      );
    }

    try {
      final db = await _dbHelper.database;
      final account = AccountModel(
        id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
        name: cmd.name.trim(),
        type: cmd.type,
        currency: cmd.currency,
        balanceCents: cmd.initialBalanceCents,
        icon: _resolveAccountIcon(cmd.iconCode),
      );

      await db.insert('accounts', {
        'id': account.id,
        'profile_id': cmd.profileId,
        'name': account.name,
        'type': account.type.name,
        'currency': account.currency,
        'balance_cents': account.balanceCents,
        'icon_code': cmd.iconCode,
      });

      // Append CRDT event
      final mutation = _crdtEngine.createMutationEvent(
        profileId: cmd.profileId,
        entityType: 'account',
        entityId: account.id,
        action: 'create',
        payload: {
          'name': account.name,
          'type': account.type.name,
          'currency': account.currency,
          'balance_cents': account.balanceCents,
          'icon_code': cmd.iconCode,
        },
      );
      await db.insert('crdt_events', mutation);

      return Success(account);
    } catch (e) {
      return Failure(
        StorageError('Failed to create account: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<List<AccountModel>, AppError>> getAccounts(String profileId, {AccountType? filter}) async {
    try {
      final db = await _dbHelper.database;
      final String whereClause = filter == null ? 'profile_id = ?' : 'profile_id = ? AND type = ?';
      final List<dynamic> whereArgs = filter == null ? [profileId] : [profileId, filter.name];

      final rows = await db.query(
        'accounts',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
      );

      final accounts = rows.map((m) {
        return AccountModel(
          id: m['id'] as String,
          name: m['name'] as String,
          type: AccountType.values.firstWhere(
            (t) => t.name == m['type'],
            orElse: () => AccountType.asset,
          ),
          currency: m['currency'] as String,
          balanceCents: m['balance_cents'] as int,
          icon: _resolveAccountIcon(m['icon_code'] as int),
        );
      }).toList();

      return Success(accounts);
    } catch (e) {
      return Failure(StorageError('Failed to query accounts: $e', cause: e));
    }
  }

  @override
  Future<Result<List<TransactionModel>, AppError>> getTransactions(
    String profileId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final db = await _dbHelper.database;
      final txRows = await db.query(
        'transactions',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'timestamp_ms DESC',
        limit: limit,
        offset: offset,
      );

      final List<TransactionModel> txList = [];
      for (final txMap in txRows) {
        final txId = txMap['id'] as String;
        final postingRows = await db.query(
          'postings',
          where: 'transaction_id = ?',
          whereArgs: [txId],
        );

        final postings = postingRows.map((p) {
          return PostingModel(
            accountId: p['account_id'] as String,
            amountCents: p['amount_cents'] as int,
          );
        }).toList();

        final rawPaths = txMap['receipt_paths'] as String?;
        final receiptPaths = rawPaths != null && rawPaths.isNotEmpty
            ? rawPaths.split(';')
            : <String>[];

        txList.add(TransactionModel(
          id: txId,
          timestamp: DateTime.fromMillisecondsSinceEpoch(txMap['timestamp_ms'] as int),
          description: txMap['description'] as String,
          postings: postings,
          receiptPaths: receiptPaths,
          note: txMap['note'] as String?,
        ));
      }

      return Success(txList);
    } catch (e) {
      return Failure(StorageError('Failed to query transactions: $e', cause: e));
    }
  }

  @override
  Future<Result<int, AppError>> getNetWorthCents(String profileId) async {
    final accResult = await getAccounts(profileId);
    return accResult.map((accounts) {
      final assets = accounts
          .where((a) => a.type == AccountType.asset)
          .fold<int>(0, (sum, a) => sum + a.balanceCents);
      final liabilities = accounts
          .where((a) => a.type == AccountType.liability)
          .fold<int>(0, (sum, a) => sum + a.balanceCents);
      return assets - liabilities;
    });
  }

  @override
  Future<Result<Map<String, int>, AppError>> get30DayCashFlow(String profileId) async {
    try {
      final txResult = await getTransactions(profileId, limit: 1000);
      final accResult = await getAccounts(profileId);

      if (txResult.isFailure) return Failure(txResult.errorOrNull!);
      if (accResult.isFailure) return Failure(accResult.errorOrNull!);

      final accounts = accResult.dataOrNull!;
      final accountMap = {for (var a in accounts) a.id: a};
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      int incomeCents = 0;
      int expenseCents = 0;

      for (final tx in txResult.dataOrNull!) {
        if (tx.timestamp.isAfter(thirtyDaysAgo)) {
          for (final p in tx.postings) {
            final acc = accountMap[p.accountId];
            if (acc != null) {
              if (acc.type == AccountType.income && p.amountCents < 0) {
                incomeCents += p.amountCents.abs();
              } else if (acc.type == AccountType.expense && p.amountCents > 0) {
                expenseCents += p.amountCents;
              }
            }
          }
        }
      }

      return Success({'income': incomeCents, 'expense': expenseCents});
    } catch (e) {
      return Failure(StorageError('Failed to compute cash flow: $e', cause: e));
    }
  }
}
