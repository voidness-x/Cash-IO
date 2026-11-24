import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cash_io/core/results/result.dart';
import 'package:cash_io/core/commands/finance_commands.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/services/ledger_service.dart';
import 'package:cash_io/core/services/envelope_service.dart';
import 'package:cash_io/core/services/sync_service.dart';
import 'package:cash_io/core/security/crypto_isolate_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LedgerService Invariant & Transaction Tests', () {
    const profileId = 'test_prof_phase2';

    test('Fails when transaction has fewer than 2 postings', () async {
      final cmd = RecordTransactionCommand(
        profileId: profileId,
        description: 'Single leg attempt',
        timestamp: DateTime.now(),
        postings: const [
          PostingModel(accountId: 'acc1', amountCents: 1000),
        ],
      );

      final result = await LedgerService.instance.recordTransaction(cmd);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
      expect((result.errorOrNull as ValidationError).field, 'postings');
    });

    test('Fails when transaction postings do not balance to zero', () async {
      final cmd = RecordTransactionCommand(
        profileId: profileId,
        description: 'Unbalanced purchase',
        timestamp: DateTime.now(),
        postings: const [
          PostingModel(accountId: 'acc1', amountCents: -5000),
          PostingModel(accountId: 'acc2', amountCents: 4000), // Off by 1000 cents
        ],
      );

      final result = await LedgerService.instance.recordTransaction(cmd);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<InvariantViolationError>());
      expect((result.errorOrNull as InvariantViolationError).balanceDifferenceCents, -1000);
    });

    test('Succeeds and updates balances atomically for balanced transaction', () async {
      // Create source and dest accounts
      final assetAcc = await LedgerService.instance.createAccount(
        const CreateAccountCommand(
          profileId: profileId,
          name: 'Checking Account',
          type: AccountType.asset,
          currency: 'USD',
          initialBalanceCents: 10000,
          iconCode: 0xe000,
        ),
      );
      expect(assetAcc.isSuccess, isTrue);

      final expenseAcc = await LedgerService.instance.createAccount(
        const CreateAccountCommand(
          profileId: profileId,
          name: 'Supermarket',
          type: AccountType.expense,
          currency: 'USD',
          initialBalanceCents: 0,
          iconCode: 0xe001,
        ),
      );
      expect(expenseAcc.isSuccess, isTrue);

      final sourceId = assetAcc.dataOrNull!.id;
      final destId = expenseAcc.dataOrNull!.id;

      // Execute balanced double-entry transaction ($25.00)
      final txResult = await LedgerService.instance.recordTransaction(
        RecordTransactionCommand(
          profileId: profileId,
          description: 'Weekly Groceries',
          timestamp: DateTime.now(),
          postings: [
            PostingModel(accountId: sourceId, amountCents: -2500), // Asset decreases by 2500
            PostingModel(accountId: destId, amountCents: 2500),   // Expense increases by 2500
          ],
        ),
      );

      expect(txResult.isSuccess, isTrue);
      expect(txResult.dataOrNull!.description, 'Weekly Groceries');

      // Verify updated account balances
      final accountsResult = await LedgerService.instance.getAccounts(profileId);
      expect(accountsResult.isSuccess, isTrue);

      final accounts = accountsResult.dataOrNull!;
      final updatedAsset = accounts.firstWhere((a) => a.id == sourceId);
      final updatedExpense = accounts.firstWhere((a) => a.id == destId);

      expect(updatedAsset.balanceCents, 7500); // 10000 - 2500
      expect(updatedExpense.balanceCents, 2500); // 0 + 2500
    });
  });

  group('EnvelopeService Zero-Based Budgeting Tests', () {
    const profileId = 'test_prof_phase2_env';

    test('Creates envelope and assigns funds', () async {
      final createResult = await EnvelopeService.instance.createEnvelope(
        const CreateEnvelopeCommand(
          profileId: profileId,
          name: 'Dining Out',
          assignedCents: 0,
          targetCents: 15000,
        ),
      );

      expect(createResult.isSuccess, isTrue);
      final envId = createResult.dataOrNull!.id;
      expect(createResult.dataOrNull!.name, 'Dining Out');

      // Assign $50.00
      final assignResult = await EnvelopeService.instance.assignFunds(
        AssignEnvelopeFundsCommand(
          profileId: profileId,
          envelopeId: envId,
          amountCents: 5000,
        ),
      );

      expect(assignResult.isSuccess, isTrue);
      expect(assignResult.dataOrNull!.assignedCents, 5000);
      expect(assignResult.dataOrNull!.remainingCents, 5000);
    });
  });

  group('CryptoIsolateService Asynchronous Offloading Tests', () {
    test('Derives encryption key in background isolate', () async {
      final keyResult = await CryptoIsolateService.instance.deriveKeyAsync(
        pin: '891011',
        salt: 'random_salt_for_testing_12345',
      );

      expect(keyResult.isSuccess, isTrue);
      expect(keyResult.dataOrNull, isNotEmpty);
      expect(keyResult.dataOrNull!.length, 64); // 256-bit SHA-256 hex
    });

    test('Encrypts and decrypts payload with HMAC integrity verification', () async {
      const plaintext = '{"vault_id":"v1","secret_balance":450000}';
      const keyHash = 'test_vault_key_hash_64_bytes_long_abcdef1234567890abcdef1234567890';

      final encResult = await CryptoIsolateService.instance.encryptPayloadAsync(
        plaintextJson: plaintext,
        vaultKeyHash: keyHash,
      );

      expect(encResult.isSuccess, isTrue);
      final encryptedBytes = encResult.dataOrNull!;
      expect(encryptedBytes.length, greaterThan(28)); // 12 nonce + cipher + 16 tag

      final decResult = await CryptoIsolateService.instance.decryptPayloadAsync(
        encryptedData: encryptedBytes,
        vaultKeyHash: keyHash,
      );

      expect(decResult.isSuccess, isTrue);
      expect(decResult.dataOrNull, plaintext);
    });

    test('Detects ciphertext tampering during decryption', () async {
      const plaintext = '{"secure_data": true}';
      const keyHash = 'test_vault_key_hash_64_bytes_long_abcdef1234567890abcdef1234567890';

      final encResult = await CryptoIsolateService.instance.encryptPayloadAsync(
        plaintextJson: plaintext,
        vaultKeyHash: keyHash,
      );

      final corruptedBytes = Uint8List.fromList(encResult.dataOrNull!);
      corruptedBytes[15] ^= 0xFF; // Flip a bit inside ciphertext

      final decResult = await CryptoIsolateService.instance.decryptPayloadAsync(
        encryptedData: corruptedBytes,
        vaultKeyHash: keyHash,
      );

      expect(decResult.isFailure, isTrue);
      expect(decResult.errorOrNull, isA<CryptographicError>());
      expect((decResult.errorOrNull as CryptographicError).code, 'ERR_TAMPER_DETECTED');
    });
  });

  group('SyncService Event Log & Export Tests', () {
    const profileId = 'test_prof_phase2_sync';

    test('Exports sync payload containing profile events', () async {
      final exportResult = await SyncService.instance.exportSyncPayload(profileId);
      expect(exportResult.isSuccess, isTrue);
      expect(exportResult.dataOrNull!.contains('profile_id'), isTrue);
    });
  });
}
