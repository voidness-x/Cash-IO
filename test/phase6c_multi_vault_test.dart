import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/security/hardware_vault_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    await VaultRepository.instance.initializeProfile(
      name: 'Primary Vault',
      currency: 'USD',
      onlineFx: false,
      pin: '111111',
    );
  });

  group('Phase 6C: Multi-Vault Cryptographic Enclave Tests', () {
    test('creates secondary vault with isolated PIN and credentials', () async {
      final repo = VaultRepository.instance;
      final primaryProfileId = repo.profileId;

      final secondaryId = await repo.createSecondaryVault(
        name: 'Business Reserve',
        currency: 'EUR',
        pin: '222222',
      );

      expect(secondaryId, isNot(primaryProfileId));
      expect(repo.profileId, secondaryId);
      expect(repo.profileName, 'Business Reserve');
      expect(repo.baseCurrency, 'EUR');

      // Verify PIN verification for both vaults
      final isSecondaryPinValid = await HardwareVaultService.instance.verifyPin(secondaryId, '222222');
      expect(isSecondaryPinValid, isTrue);

      final isSecondaryPinWrong = await HardwareVaultService.instance.verifyPin(secondaryId, '000000');
      expect(isSecondaryPinWrong, isFalse);

      final isPrimaryPinValid = await HardwareVaultService.instance.verifyPin(primaryProfileId, '111111');
      expect(isPrimaryPinValid, isTrue);
    });

    test('switchVault enforces PIN barrier before switching namespaces', () async {
      final repo = VaultRepository.instance;
      final primaryProfileId = repo.profileId;

      final secondaryId = await repo.createSecondaryVault(
        name: 'Decoy Stash',
        currency: 'USD',
        pin: '333333',
      );

      // Attempt to switch back to primary with wrong PIN
      final failSwitch = await repo.switchVault(primaryProfileId, 'wrong9');
      expect(failSwitch, isFalse);
      expect(repo.profileId, secondaryId); // remains in secondary

      // Switch back with correct PIN
      final successSwitch = await repo.switchVault(primaryProfileId, '111111');
      expect(successSwitch, isTrue);
      expect(repo.profileId, primaryProfileId);
      expect(repo.profileName, 'Primary Vault');
    });

    test('double-entry data in secondary vault is isolated from primary vault', () async {
      final repo = VaultRepository.instance;
      final primaryId = repo.profileId;

      // Seed transaction in primary vault
      final primaryAsset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final primaryExpense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);

      await repo.recordTransaction(
        description: 'Primary Vault Expense',
        postings: [
          PostingModel(accountId: primaryExpense.id, amountCents: 5000),
          PostingModel(accountId: primaryAsset.id, amountCents: -5000),
        ],
      );
      expect(repo.transactions.length, 1);

      // Create and switch to secondary vault
      await repo.createSecondaryVault(
        name: 'Isolated Business Vault',
        currency: 'USD',
        pin: '444444',
      );

      // In secondary vault, transaction list must be empty
      expect(repo.transactions.isEmpty, isTrue);

      // Add transaction in secondary vault
      final secAsset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final secExpense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);

      await repo.recordTransaction(
        description: 'Business Server Bill',
        postings: [
          PostingModel(accountId: secExpense.id, amountCents: 12000),
          PostingModel(accountId: secAsset.id, amountCents: -12000),
        ],
      );

      expect(repo.transactions.length, 1);
      expect(repo.transactions.first.description, 'Business Server Bill');

      // Switch back to primary vault
      await repo.switchVault(primaryId, '111111');
      expect(repo.transactions.length, 1);
      expect(repo.transactions.first.description, 'Primary Vault Expense');
    });
  });
}
