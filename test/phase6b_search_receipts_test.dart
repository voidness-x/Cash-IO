import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/services/ledger_search_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    await VaultRepository.instance.initializeProfile(
      name: 'Search Test Profile',
      currency: 'USD',
      onlineFx: false,
    );
  });

  group('Phase 6B: Ledger Search & Date Scrubber Engine Tests', () {
    test('filters transactions by case-insensitive text search on description and note', () async {
      final repo = VaultRepository.instance;
      final searchService = LedgerSearchService.instance;

      final asset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final expense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);

      await repo.recordTransaction(
        description: 'Apple Store Hardware',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 150000),
          PostingModel(accountId: asset.id, amountCents: -150000),
        ],
        note: 'New M3 MacBook sleeve',
      );

      await repo.recordTransaction(
        description: 'Starbucks Coffee',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 850),
          PostingModel(accountId: asset.id, amountCents: -850),
        ],
      );

      // Search 'apple'
      final results1 = searchService.filterTransactions(
        repo.transactions,
        const LedgerFilterCriteria(searchQuery: 'apple'),
        repo,
      );
      expect(results1.length, 1);
      expect(results1.first.description, 'Apple Store Hardware');

      // Search 'sleeve' (inside note)
      final results2 = searchService.filterTransactions(
        repo.transactions,
        const LedgerFilterCriteria(searchQuery: 'sleeve'),
        repo,
      );
      expect(results2.length, 1);
      expect(results2.first.description, 'Apple Store Hardware');

      // Search non-existent
      final results3 = searchService.filterTransactions(
        repo.transactions,
        const LedgerFilterCriteria(searchQuery: 'Netflix'),
        repo,
      );
      expect(results3.isEmpty, isTrue);
    });

    test('filters transactions by hasReceiptsOnly flag', () async {
      final repo = VaultRepository.instance;
      final searchService = LedgerSearchService.instance;

      final asset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final expense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);

      await repo.recordTransaction(
        description: 'Office Depot',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 4500),
          PostingModel(accountId: asset.id, amountCents: -4500),
        ],
        receiptPaths: ['enc_receipt_1234.bin'],
      );

      await repo.recordTransaction(
        description: 'Subway Sandwich',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 1200),
          PostingModel(accountId: asset.id, amountCents: -1200),
        ],
      );

      final receiptsOnly = searchService.filterTransactions(
        repo.transactions,
        const LedgerFilterCriteria(hasReceiptsOnly: true),
        repo,
      );

      expect(receiptsOnly.length, 1);
      expect(receiptsOnly.first.description, 'Office Depot');
      expect(receiptsOnly.first.receiptPaths.isNotEmpty, isTrue);
    });

    test('filters transactions by min and max amount range', () async {
      final repo = VaultRepository.instance;
      final searchService = LedgerSearchService.instance;

      final asset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final expense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);

      await repo.recordTransaction(
        description: 'Candy',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 200),
          PostingModel(accountId: asset.id, amountCents: -200),
        ],
      );

      await repo.recordTransaction(
        description: 'Headphones',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 15000),
          PostingModel(accountId: asset.id, amountCents: -15000),
        ],
      );

      await repo.recordTransaction(
        description: 'Used Car Downpayment',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 250000),
          PostingModel(accountId: asset.id, amountCents: -250000),
        ],
      );

      // Min: $100 ($10,000 cents), Max: $500 ($50,000 cents)
      final midRange = searchService.filterTransactions(
        repo.transactions,
        const LedgerFilterCriteria(
          minAmountCents: 10000,
          maxAmountCents: 50000,
        ),
        repo,
      );

      expect(midRange.length, 1);
      expect(midRange.first.description, 'Headphones');
    });

    test('sorts transactions by highest and lowest amounts', () async {
      final repo = VaultRepository.instance;
      final searchService = LedgerSearchService.instance;

      final asset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final expense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);

      await repo.recordTransaction(
        description: 'Small Lunch',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 1500),
          PostingModel(accountId: asset.id, amountCents: -1500),
        ],
      );

      await repo.recordTransaction(
        description: 'Big TV',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 80000),
          PostingModel(accountId: asset.id, amountCents: -80000),
        ],
      );

      final highestFirst = searchService.filterTransactions(
        repo.transactions,
        const LedgerFilterCriteria(sortBy: SortOption.highestAmount),
        repo,
      );
      expect(highestFirst.first.description, 'Big TV');

      final lowestFirst = searchService.filterTransactions(
        repo.transactions,
        const LedgerFilterCriteria(sortBy: SortOption.lowestAmount),
        repo,
      );
      expect(lowestFirst.first.description, 'Small Lunch');
    });
  });
}
