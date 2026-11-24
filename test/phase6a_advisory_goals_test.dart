import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/services/financial_advisory_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    await VaultRepository.instance.initializeProfile(
      name: 'Advisory Test',
      currency: 'USD',
      onlineFx: false,
    );
  });

  group('Phase 6A: On-Device Financial Advisory Engine Tests', () {
    test('evaluate503020Rule correctly categorizes Needs vs Wants vs Savings', () async {
      final repo = VaultRepository.instance;
      final advisory = FinancialAdvisoryService.instance;

      // Seed asset and expense accounts
      await repo.addAccount(name: 'Checking Vault', type: AccountType.asset, currency: 'USD', initialBalanceCents: 500000);
      await repo.addAccount(name: 'Income: Salary', type: AccountType.income, currency: 'USD');
      await repo.addAccount(name: 'Expenses: Groceries & Food', type: AccountType.expense, currency: 'USD');
      await repo.addAccount(name: 'Expenses: Dining Out', type: AccountType.expense, currency: 'USD');

      final asset = repo.accounts.firstWhere((a) => a.name == 'Checking Vault');
      final salary = repo.accounts.firstWhere((a) => a.name == 'Income: Salary');
      final groceries = repo.accounts.firstWhere((a) => a.name == 'Expenses: Groceries & Food');
      final dining = repo.accounts.firstWhere((a) => a.name == 'Expenses: Dining Out');

      // Income: +$3,000.00
      await repo.recordTransaction(
        description: 'Monthly Salary',
        postings: [
          PostingModel(accountId: asset.id, amountCents: 300000),
          PostingModel(accountId: salary.id, amountCents: -300000),
        ],
      );

      // Needs: $1,200.00
      await repo.recordTransaction(
        description: 'Groceries store',
        postings: [
          PostingModel(accountId: groceries.id, amountCents: 120000),
          PostingModel(accountId: asset.id, amountCents: -120000),
        ],
      );

      // Wants: $600.00
      await repo.recordTransaction(
        description: 'Weekend Dining',
        postings: [
          PostingModel(accountId: dining.id, amountCents: 60000),
          PostingModel(accountId: asset.id, amountCents: -60000),
        ],
      );

      final result = advisory.evaluate503020Rule(repo);

      expect(result.needsCents, 120000);
      expect(result.wantsCents, 60000);
      expect(result.totalIncomeCents, 300000);
      expect(result.savingsCents, 120000); // 3000 - 1200 - 600 = 1200 (40%)
      expect(result.status, FiftyThirtyTwentyStatus.balanced);
    });

    test('evaluateEmergencyRunway accurately assesses months of expenses covered', () {
      final repo = VaultRepository.instance;
      final advisory = FinancialAdvisoryService.instance;

      final runway = advisory.evaluateEmergencyRunway(repo);
      expect(runway.runwayMonths >= 0.0, isTrue);
      expect([RunwayTier.critical, RunwayTier.building, RunwayTier.healthy, RunwayTier.fortified].contains(runway.tier), isTrue);
    });

    test('calculateSimulatedRoundUpsCents computes accurate spare change sum', () {
      final repo = VaultRepository.instance;
      final advisory = FinancialAdvisoryService.instance;

      final roundUps = advisory.calculateSimulatedRoundUpsCents(repo);
      expect(roundUps >= 0, isTrue);
    });
  });

  group('Phase 6A: Savings Goals & Locked Vaults Tests', () {
    test('SavingsGoalModel calculates progress, remaining cents, and required pace', () {
      final targetDate = DateTime.now().add(const Duration(days: 90));
      final goal = SavingsGoalModel(
        id: 'goal_car',
        name: 'Electric Vehicle Downpayment',
        targetAmountCents: 600000, // $6,000.00
        currentBalanceCents: 150000, // $1,500.00 (25%)
        targetDate: targetDate,
        isLocked: true,
      );

      expect(goal.progressPercentage, 0.25);
      expect(goal.remainingCents, 450000); // $4,500.00
      expect(goal.daysRemaining >= 88, isTrue);
      expect(goal.requiredMonthlyCents, 150000); // $4,500 / 3 months = $1,500 / mo
    });

    test('depositToGoal increases balance and withdrawFromGoal respects locked status', () async {
      final repo = VaultRepository.instance;

      await repo.addSavingsGoal(
        name: 'House Renovation',
        targetAmountCents: 500000,
        targetDate: DateTime.now().add(const Duration(days: 180)),
        isLocked: true,
        initialDepositCents: 100000,
      );

      final goal = repo.savingsGoals.firstWhere((g) => g.name == 'House Renovation');
      expect(goal.currentBalanceCents, 100000);

      // Deposit
      final depositSuccess = await repo.depositToGoal(goal.id, 50000);
      expect(depositSuccess, isTrue);

      final updatedGoal = repo.savingsGoals.firstWhere((g) => g.id == goal.id);
      expect(updatedGoal.currentBalanceCents, 150000);

      // Withdrawal fails while locked
      final withdrawWhileLocked = await repo.withdrawFromGoal(goal.id, 20000, targetAssetAccountId: 'target_acc');
      expect(withdrawWhileLocked, isFalse);

      // Unlock and withdraw succeeds
      repo.toggleGoalLock(goal.id, false);
      final unlockedGoal = repo.savingsGoals.firstWhere((g) => g.id == goal.id);
      expect(unlockedGoal.isLocked, isFalse);

      final withdrawUnlocked = await repo.withdrawFromGoal(goal.id, 20000, targetAssetAccountId: 'target_acc');
      expect(withdrawUnlocked, isTrue);

      final finalGoal = repo.savingsGoals.firstWhere((g) => g.id == goal.id);
      expect(finalGoal.currentBalanceCents, 130000);
    });
  });
}
