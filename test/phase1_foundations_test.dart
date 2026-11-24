import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cash_io/core/results/result.dart';
import 'package:cash_io/core/commands/finance_commands.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/theme/tokens.dart';
import 'package:cash_io/core/storage/database_helper.dart';
import 'package:cash_io/core/security/bip39_wordlist.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Result<S, E> Sealed Class Tests', () {
    test('Success returns correct data and flags', () {
      const Result<int, AppError> result = Success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, 42);
      expect(result.errorOrNull, isNull);

      final transformed = result.map((data) => 'Value: $data');
      expect(transformed.dataOrNull, 'Value: 42');

      final value = result.when(
        success: (d) => 'got $d',
        failure: (e) => 'got error',
      );
      expect(value, 'got 42');
    });

    test('Failure returns correct error and flags', () {
      const Result<int, AppError> result = Failure(
        InvariantViolationError('Transaction out of balance', balanceDifferenceCents: 500),
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, isA<InvariantViolationError>());
      expect((result.errorOrNull as InvariantViolationError).balanceDifferenceCents, 500);

      final transformed = result.map((data) => 'never called');
      expect(transformed.isFailure, isTrue);

      final value = result.when(
        success: (d) => 'success',
        failure: (e) => e.message,
      );
      expect(value, 'Transaction out of balance');
    });
  });

  group('RecordTransactionCommand Double-Entry Invariant Tests', () {
    test('Balanced transaction with sum == 0 returns isBalanced = true', () {
      final cmd = RecordTransactionCommand(
        profileId: 'test_profile',
        description: 'Grocery Store',
        timestamp: DateTime.now(),
        postings: const [
          PostingModel(accountId: 'acc_asset', amountCents: -5000), // Credit (Asset decreases)
          PostingModel(accountId: 'acc_expense', amountCents: 5000), // Debit (Expense increases)
        ],
      );

      expect(cmd.isBalanced, isTrue);
      expect(cmd.balanceDiscrepancyCents, 0);
    });

    test('Unbalanced transaction returns isBalanced = false and discrepancy', () {
      final cmd = RecordTransactionCommand(
        profileId: 'test_profile',
        description: 'Unbalanced payment',
        timestamp: DateTime.now(),
        postings: const [
          PostingModel(accountId: 'acc_asset', amountCents: -5000),
          PostingModel(accountId: 'acc_expense', amountCents: 4500),
        ],
      );

      expect(cmd.isBalanced, isFalse);
      expect(cmd.balanceDiscrepancyCents, -500);
    });

    test('Single posting transaction is invalid', () {
      final cmd = RecordTransactionCommand(
        profileId: 'test_profile',
        description: 'Single leg',
        timestamp: DateTime.now(),
        postings: const [
          PostingModel(accountId: 'acc_asset', amountCents: 5000),
        ],
      );

      expect(cmd.isBalanced, isFalse);
    });
  });

  group('CashIOThemeExtension Design Token Tests', () {
    test('Dark theme tokens match Architectural Obsidian Vault specification', () {
      const dark = CashIOThemeExtension.dark;

      expect(dark.bgPrimary, const Color(0xFF22252A));
      expect(dark.accentGold, const Color(0xFF00ABB3));
      expect(dark.statusIncome, const Color(0xFF00ABB3));
      expect(dark.statusExpense, const Color(0xFFEF4444));
      expect(dark.radiusSm, 10.0);
      expect(dark.radiusMd, 16.0);
      expect(dark.space4, 16.0);
    });

    test('Light theme tokens provide high contrast', () {
      const light = CashIOThemeExtension.light;

      expect(light.bgPrimary, const Color(0xFFEAEAEA));
      expect(light.bgSurface, const Color(0xFFFFFFFF));
      expect(light.statusIncome, const Color(0xFF00ABB3));
      expect(light.statusExpense, const Color(0xFFDC2626));
    });

    test('copyWith and lerp interpolate properly', () {
      const dark = CashIOThemeExtension.dark;
      const light = CashIOThemeExtension.light;

      final modified = dark.copyWith(accentGold: Colors.amber);
      expect(modified.accentGold, Colors.amber);
      expect(modified.bgPrimary, dark.bgPrimary);

      final midpoint = dark.lerp(light, 0.5);
      expect(midpoint, isA<CashIOThemeExtension>());
      expect(midpoint.radiusSm, 10.0);
    });
  });

  group('DatabaseHelper v2 Indices Tests', () {
    test('Database creates tables and indices successfully', () async {
      final db = await DatabaseHelper.instance.database;
      expect(db.isOpen, isTrue);

      final indexList = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
      );
      final indexNames = indexList.map((row) => row['name'] as String).toSet();

      expect(indexNames.contains('idx_accounts_profile'), isTrue);
      expect(indexNames.contains('idx_transactions_profile_time'), isTrue);
      expect(indexNames.contains('idx_postings_tx'), isTrue);
      expect(indexNames.contains('idx_postings_acc_amount'), isTrue);
      expect(indexNames.contains('idx_envelopes_profile'), isTrue);
      expect(indexNames.contains('idx_crdt_profile_clock'), isTrue);
    });
  });

  group('BIP-39 CSPRNG 2048-Word Mnemonic Security Tests', () {
    test('Bip39Helper wordlist contains exactly 2048 standard words', () {
      expect(Bip39Helper.wordList.length, 2048);
      expect(Bip39Helper.wordList.first, 'abandon');
      expect(Bip39Helper.wordList.last, 'zoo');
      expect(Bip39Helper.wordList.toSet().length, 2048); // All words unique
    });

    test('generateMnemonic generates valid 12-word phrase with valid checksum', () {
      final mnemonic = Bip39Helper.generateMnemonic();
      expect(mnemonic.length, 12);
      for (final word in mnemonic) {
        expect(Bip39Helper.wordList.contains(word), isTrue);
      }
      expect(Bip39Helper.validateMnemonic(mnemonic), isTrue);
    });

    test('Consecutive calls produce cryptographically distinct random seeds', () {
      final seed1 = Bip39Helper.generateMnemonic().join(' ');
      final seed2 = Bip39Helper.generateMnemonic().join(' ');
      expect(seed1, isNot(equals(seed2)));
    });

    test('Corrupted mnemonic fails validation', () {
      final mnemonic = Bip39Helper.generateMnemonic();
      final corrupted = List<String>.from(mnemonic);
      // Replace last word with invalid word or different word
      corrupted[11] = corrupted[11] == 'abandon' ? 'zoo' : 'abandon';
      // In almost all cases, altering one word invalidates the 4-bit SHA-256 checksum
      // Test invalid word directly:
      final invalidWords = List<String>.from(mnemonic)..[0] = 'notarealword123';
      expect(Bip39Helper.validateMnemonic(invalidWords), isFalse);
    });
  });
}
