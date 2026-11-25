import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/finance_models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cashio_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      try {
        return await databaseFactory.openDatabase(
          filePath,
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: _createDB,
            onUpgrade: _onUpgrade,
          ),
        );
      } catch (_) {
        return await databaseFactory.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: _createDB,
            onUpgrade: _onUpgrade,
          ),
        );
      }
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final path = p.join(dbFolder.path, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Profiles Table (multi-user profile isolation)
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        currency TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        recovery_seed_hash TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // 2. Double-Entry Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        currency TEXT NOT NULL,
        balance_cents INTEGER NOT NULL DEFAULT 0,
        icon_code INTEGER NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles (id) ON DELETE CASCADE
      )
    ''');

    // 3. Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        description TEXT NOT NULL,
        note TEXT,
        receipt_paths TEXT,
        FOREIGN KEY (profile_id) REFERENCES profiles (id) ON DELETE CASCADE
      )
    ''');

    // 4. Postings Table (Double-Entry zero-sum postings)
    await db.execute('''
      CREATE TABLE postings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // 5. Budget Envelopes Table (Zero-Based Budgeting)
    await db.execute('''
      CREATE TABLE envelopes (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        name TEXT NOT NULL,
        assigned_cents INTEGER NOT NULL DEFAULT 0,
        spent_cents INTEGER NOT NULL DEFAULT 0,
        target_cents INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (profile_id) REFERENCES profiles (id) ON DELETE CASCADE
      )
    ''');

    // 6. CRDT Mutation Event Log (Append-Only Event Sourcing)
    await db.execute('''
      CREATE TABLE crdt_events (
        event_id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        lamport_clock INTEGER NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL
      )
    ''');

    // Create high-performance composite indices
    await _createIndices(db);
  }

  Future<void> _createIndices(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_profile ON accounts(profile_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_profile_time ON transactions(profile_id, timestamp_ms DESC);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_postings_tx ON postings(transaction_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_postings_acc_amount ON postings(account_id, amount_cents);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_envelopes_profile ON envelopes(profile_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_crdt_profile_clock ON crdt_events(profile_id, lamport_clock ASC);');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createIndices(db);
    }
  }

  // ---------------------------------------------------------------------------
  // Profile Queries
  // ---------------------------------------------------------------------------
  Future<bool> hasAnyProfile() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM profiles');
    final count = Sqflite.firstIntValue(res) ?? 0;
    return count > 0;
  }

  Future<Map<String, dynamic>?> getProfile(String id) async {
    final db = await database;
    final res = await db.query('profiles', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>?> getPrimaryProfile() async {
    final db = await database;
    final res = await db.query('profiles', orderBy: 'created_at DESC', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    final db = await database;
    return await db.query('profiles', orderBy: 'created_at ASC');
  }

  Future<void> saveProfile({
    required String id,
    required String name,
    required String currency,
    required String pinSalt,
    required String seedHash,
  }) async {
    final db = await database;
    await db.insert(
      'profiles',
      {
        'id': id,
        'name': name,
        'currency': currency,
        'pin_salt': pinSalt,
        'recovery_seed_hash': seedHash,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // Account Queries
  // ---------------------------------------------------------------------------
  Future<List<AccountModel>> getAccounts(String profileId) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );

    return maps.map((m) {
      return AccountModel(
        id: m['id'] as String,
        name: m['name'] as String,
        type: AccountType.values.firstWhere(
          (t) => t.name == (m['type'] as String),
          orElse: () => AccountType.asset,
        ),
        currency: m['currency'] as String,
        balanceCents: m['balance_cents'] as int,
      );
    }).toList();
  }

  Future<void> insertAccount(String profileId, AccountModel account) async {
    final db = await database;
    await db.insert('accounts', {
      'id': account.id,
      'profile_id': profileId,
      'name': account.name,
      'type': account.type.name,
      'currency': account.currency,
      'balance_cents': account.balanceCents,
      'icon_code': account.icon.codePoint,
    });
  }

  Future<void> updateAccountBalance(String accountId, int newBalanceCents) async {
    final db = await database;
    await db.update(
      'accounts',
      {'balance_cents': newBalanceCents},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  // ---------------------------------------------------------------------------
  // Transaction & Posting Queries
  // ---------------------------------------------------------------------------
  Future<List<TransactionModel>> getTransactions(String profileId) async {
    final db = await database;
    final txMaps = await db.query(
      'transactions',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'timestamp_ms DESC',
    );

    final List<TransactionModel> txs = [];
    for (final m in txMaps) {
      final txId = m['id'] as String;
      final postingMaps = await db.query(
        'postings',
        where: 'transaction_id = ?',
        whereArgs: [txId],
      );

      final postings = postingMaps.map((pm) {
        return PostingModel(
          accountId: pm['account_id'] as String,
          amountCents: pm['amount_cents'] as int,
        );
      }).toList();

      final receiptsRaw = m['receipt_paths'] as String?;
      final receipts = receiptsRaw != null && receiptsRaw.isNotEmpty
          ? receiptsRaw.split(',')
          : <String>[];

      txs.add(TransactionModel(
        id: txId,
        timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp_ms'] as int),
        description: m['description'] as String,
        postings: postings,
        receiptPaths: receipts,
        note: m['note'] as String?,
      ));
    }
    return txs;
  }

  Future<void> insertTransaction(String profileId, TransactionModel tx) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': tx.id,
        'profile_id': profileId,
        'timestamp_ms': tx.timestamp.millisecondsSinceEpoch,
        'description': tx.description,
        'note': tx.note,
        'receipt_paths': tx.receiptPaths.join(','),
      });

      for (final p in tx.postings) {
        await txn.insert('postings', {
          'transaction_id': tx.id,
          'account_id': p.accountId,
          'amount_cents': p.amountCents,
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Envelopes Queries
  // ---------------------------------------------------------------------------
  Future<List<EnvelopeModel>> getEnvelopes(String profileId) async {
    final db = await database;
    final maps = await db.query(
      'envelopes',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );

    return maps.map((m) {
      return EnvelopeModel(
        id: m['id'] as String,
        name: m['name'] as String,
        assignedCents: m['assigned_cents'] as int,
        spentCents: m['spent_cents'] as int,
        targetCents: m['target_cents'] as int,
      );
    }).toList();
  }

  Future<void> insertEnvelope(String profileId, EnvelopeModel env) async {
    final db = await database;
    await db.insert('envelopes', {
      'id': env.id,
      'profile_id': profileId,
      'name': env.name,
      'assigned_cents': env.assignedCents,
      'spent_cents': env.spentCents,
      'target_cents': env.targetCents,
    });
  }

  Future<void> updateEnvelopeAssigned(String envelopeId, int newAssignedCents) async {
    final db = await database;
    await db.update(
      'envelopes',
      {'assigned_cents': newAssignedCents},
      where: 'id = ?',
      whereArgs: [envelopeId],
    );
  }

  // ---------------------------------------------------------------------------
  // CRDT Event Queries
  // ---------------------------------------------------------------------------
  Future<void> insertCrdtEvent(Map<String, dynamic> event) async {
    final db = await database;
    await db.insert('crdt_events', event);
  }

  Future<List<Map<String, dynamic>>> getCrdtEvents(String profileId) async {
    final db = await database;
    return await db.query(
      'crdt_events',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'lamport_clock DESC',
      limit: 50,
    );
  }
}
