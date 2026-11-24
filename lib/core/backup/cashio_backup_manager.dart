import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../storage/database_helper.dart';
import '../sync/e2ee_packager.dart';

class CashIOBackupManager {
  static final CashIOBackupManager instance = CashIOBackupManager._init();
  CashIOBackupManager._init();

  /// Compiles a complete, self-contained offline backup bundle (.cashio)
  /// Encrypted with AES-256-GCM using the user's master key.
  Future<File> exportEncryptedBackup({
    required String profileId,
    required String backupPassword,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Export all tables for this profile
    final accounts = await db.query('accounts', where: 'profile_id = ?', whereArgs: [profileId]);
    final transactions = await db.query('transactions', where: 'profile_id = ?', whereArgs: [profileId]);
    final postings = await db.rawQuery('''
      SELECT p.* FROM postings p
      JOIN transactions t ON p.transaction_id = t.id
      WHERE t.profile_id = ?
    ''', [profileId]);
    final envelopes = await db.query('envelopes', where: 'profile_id = ?', whereArgs: [profileId]);
    final crdtEvents = await db.query('crdt_events', where: 'profile_id = ?', whereArgs: [profileId]);

    final backupPayload = {
      'format': 'cashio_vault_v1',
      'profile_id': profileId,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts,
      'transactions': transactions,
      'postings': postings,
      'envelopes': envelopes,
      'crdt_events': crdtEvents,
    };

    // 2. Encrypt with AES-256-GCM
    final jsonStr = jsonEncode(backupPayload);
    final encryptedBundle = E2eePackager.instance.encryptPayload(
      plaintextJson: jsonStr,
      vaultKeyHash: backupPassword,
    );

    // 3. Save to file
    final docs = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(docs.path, 'backup_$timestamp.cashio'));
    await file.writeAsBytes(encryptedBundle);

    return file;
  }

  /// Restores data from an encrypted .cashio backup bundle
  Future<bool> importEncryptedBackup({
    required File backupFile,
    required String backupPassword,
  }) async {
    try {
      if (!await backupFile.exists()) return false;

      final encryptedBytes = await backupFile.readAsBytes();
      final decryptedJson = E2eePackager.instance.decryptPayload(
        encryptedData: encryptedBytes,
        vaultKeyHash: backupPassword,
      );

      if (decryptedJson == null) return false; // Authentication failed (wrong password or corrupt file)

      final data = jsonDecode(decryptedJson) as Map<String, dynamic>;
      if (data['format'] != 'cashio_vault_v1') return false;

      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // Restore accounts
        for (final acc in (data['accounts'] as List)) {
          await txn.insert('accounts', Map<String, dynamic>.from(acc as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Restore transactions
        for (final tx in (data['transactions'] as List)) {
          await txn.insert('transactions', Map<String, dynamic>.from(tx as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Restore postings
        for (final p in (data['postings'] as List)) {
          await txn.insert('postings', Map<String, dynamic>.from(p as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Restore envelopes
        for (final env in (data['envelopes'] as List)) {
          await txn.insert('envelopes', Map<String, dynamic>.from(env as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Restore CRDT events
        for (final event in (data['crdt_events'] as List)) {
          await txn.insert('crdt_events', Map<String, dynamic>.from(event as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }
}
