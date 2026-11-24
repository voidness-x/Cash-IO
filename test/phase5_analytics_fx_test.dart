import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/storage/vault_repository.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  group('Phase 5: Category Analytics Tests', () {
    test('getCategorySpendingCents aggregates spending by category correctly', () async {
      final repo = VaultRepository.instance;

      // Ensure accounts exist
      await repo.addAccount(
        name: 'Wallet Asset',
        type: AccountType.asset,
        currency: 'USD',
        initialBalanceCents: 100000,
      );
      await repo.addAccount(
        name: 'Expenses: Groceries',
        type: AccountType.expense,
        currency: 'USD',
      );
      await repo.addAccount(
        name: 'Expenses: Dining',
        type: AccountType.expense,
        currency: 'USD',
      );

      final asset = repo.accounts.firstWhere((a) => a.name == 'Wallet Asset');
      final groceries = repo.accounts.firstWhere((a) => a.name == 'Expenses: Groceries');
      final dining = repo.accounts.firstWhere((a) => a.name == 'Expenses: Dining');

      await repo.recordTransaction(
        description: 'Supermarket',
        postings: [
          PostingModel(accountId: groceries.id, amountCents: 7500),
          PostingModel(accountId: asset.id, amountCents: -7500),
        ],
      );

      await repo.recordTransaction(
        description: 'Dinner',
        postings: [
          PostingModel(accountId: dining.id, amountCents: 4500),
          PostingModel(accountId: asset.id, amountCents: -4500),
        ],
      );

      final spending = repo.getCategorySpendingCents(days: 30);
      expect(spending['Groceries'], 7500);
      expect(spending['Dining'], 4500);
    });
  });

  group('Phase 5: Multi-Currency FX Matrix Tests', () {
    test('convertCents calculates precise conversions based on exchange matrix', () {
      final repo = VaultRepository.instance;

      // 100.00 USD (10000 cents) -> IQD (1 USD = 1310 IQD -> 131,000 IQD)
      final iqdCents = repo.convertCents(10000, 'USD', 'IQD');
      expect(iqdCents, 13100000); // 131,000.00 IQD in cents

      // Reverse: 131,000.00 IQD -> USD
      final usdCents = repo.convertCents(13100000, 'IQD', 'USD');
      expect(usdCents, 10000);

      // Identity conversion
      expect(repo.convertCents(5000, 'EUR', 'EUR'), 5000);

      // Cross-currency: 100 EUR -> USD -> GBP
      final gbpCents = repo.convertCents(10000, 'EUR', 'GBP');
      expect(gbpCents > 0, isTrue);
    });
  });

  group('Phase 5: Recurring Subscriptions Engine Tests', () {
    test('RecurringTransactionModel calculates next dates for monthly and weekly intervals', () {
      final now = DateTime(2026, 11, 23);
      final monthlyItem = RecurringTransactionModel(
        id: 'rec_1',
        title: 'Gym',
        amountCents: 5000,
        sourceAccountId: 'acc_asset',
        destinationAccountId: 'acc_exp',
        interval: RecurringInterval.monthly,
        nextDueDate: now,
      );

      final nextMonthly = monthlyItem.calculateNextDate();
      expect(nextMonthly.month, 12);
      expect(nextMonthly.day, 23);

      final weeklyItem = monthlyItem.copyWith(interval: RecurringInterval.weekly);
      final nextWeekly = weeklyItem.calculateNextDate();
      expect(nextWeekly.difference(now).inDays, 7);
    });

    test('addRecurringTransaction and postDueRecurringTransaction updates ledger and advances date', () async {
      final repo = VaultRepository.instance;

      final asset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final expense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);

      final initialTxCount = repo.transactions.length;

      await repo.addRecurringTransaction(
        title: 'Cloud Storage',
        amountCents: 1500,
        sourceAccountId: asset.id,
        destinationAccountId: expense.id,
        interval: RecurringInterval.monthly,
        nextDueDate: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(repo.recurringTransactions.any((r) => r.title == 'Cloud Storage'), isTrue);

      final item = repo.recurringTransactions.firstWhere((r) => r.title == 'Cloud Storage');
      expect(item.isDue, isTrue);

      final success = await repo.postDueRecurringTransaction(item.id);
      expect(success, isTrue);
      expect(repo.transactions.length, initialTxCount + 1);
      expect(repo.transactions.first.description, 'Scheduled: Cloud Storage');

      // Date advanced
      final updatedItem = repo.recurringTransactions.firstWhere((r) => r.id == item.id);
      expect(updatedItem.nextDueDate.isAfter(DateTime.now()), isTrue);
    });
  });
}
