import '../models/finance_models.dart';
import '../storage/vault_repository.dart';

enum DateFilterOption {
  all,
  today,
  last7Days,
  last30Days,
  custom,
}

enum SortOption {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
}

class LedgerFilterCriteria {
  final String searchQuery;
  final DateFilterOption dateFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final int? minAmountCents;
  final int? maxAmountCents;
  final String? accountId;
  final bool hasReceiptsOnly;
  final SortOption sortBy;

  const LedgerFilterCriteria({
    this.searchQuery = '',
    this.dateFilter = DateFilterOption.all,
    this.customStartDate,
    this.customEndDate,
    this.minAmountCents,
    this.maxAmountCents,
    this.accountId,
    this.hasReceiptsOnly = false,
    this.sortBy = SortOption.newestFirst,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      dateFilter != DateFilterOption.all ||
      minAmountCents != null ||
      maxAmountCents != null ||
      accountId != null ||
      hasReceiptsOnly ||
      sortBy != SortOption.newestFirst;

  LedgerFilterCriteria copyWith({
    String? searchQuery,
    DateFilterOption? dateFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    int? minAmountCents,
    int? maxAmountCents,
    String? accountId,
    bool? hasReceiptsOnly,
    SortOption? sortBy,
    bool clearAccountId = false,
    bool clearMinMax = false,
  }) {
    return LedgerFilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      dateFilter: dateFilter ?? this.dateFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      minAmountCents: clearMinMax ? null : (minAmountCents ?? this.minAmountCents),
      maxAmountCents: clearMinMax ? null : (maxAmountCents ?? this.maxAmountCents),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      hasReceiptsOnly: hasReceiptsOnly ?? this.hasReceiptsOnly,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

/// Zero-Knowledge, 100% on-device ledger search and parametric filter service
class LedgerSearchService {
  static final LedgerSearchService instance = LedgerSearchService._internal();
  LedgerSearchService._internal();

  List<TransactionModel> filterTransactions(
    List<TransactionModel> transactions,
    LedgerFilterCriteria criteria,
    VaultRepository repo,
  ) {
    final query = criteria.searchQuery.trim().toLowerCase();
    final now = DateTime.now();

    DateTime? startDate;
    DateTime? endDate;

    switch (criteria.dateFilter) {
      case DateFilterOption.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case DateFilterOption.last7Days:
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case DateFilterOption.last30Days:
        startDate = now.subtract(const Duration(days: 30));
        endDate = now;
        break;
      case DateFilterOption.custom:
        startDate = criteria.customStartDate;
        endDate = criteria.customEndDate;
        break;
      case DateFilterOption.all:
        startDate = null;
        endDate = null;
        break;
    }

    final filtered = transactions.where((tx) {
      // 1. Text Query Filter
      if (query.isNotEmpty) {
        final descMatch = tx.description.toLowerCase().contains(query);
        final noteMatch = tx.note?.toLowerCase().contains(query) ?? false;
        
        // Match against account names in postings
        final accountMatch = tx.postings.any((p) {
          final acc = repo.accounts.cast<AccountModel?>().firstWhere(
                (a) => a?.id == p.accountId,
                orElse: () => null,
              );
          return acc != null && acc.name.toLowerCase().contains(query);
        });

        if (!descMatch && !noteMatch && !accountMatch) {
          return false;
        }
      }

      // 2. Date Scrubber Range Filter
      if (startDate != null && tx.timestamp.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && tx.timestamp.isAfter(endDate)) {
        return false;
      }

      // 3. Has Receipts Filter
      if (criteria.hasReceiptsOnly && tx.receiptPaths.isEmpty) {
        return false;
      }

      // 4. Account ID Filter
      if (criteria.accountId != null &&
          !tx.postings.any((p) => p.accountId == criteria.accountId)) {
        return false;
      }

      // 5. Amount Range Filter
      final maxPostingCents = tx.postings.fold<int>(
        0,
        (maxVal, p) => p.amountCents.abs() > maxVal ? p.amountCents.abs() : maxVal,
      );

      if (criteria.minAmountCents != null && maxPostingCents < criteria.minAmountCents!) {
        return false;
      }
      if (criteria.maxAmountCents != null && maxPostingCents > criteria.maxAmountCents!) {
        return false;
      }

      return true;
    }).toList();

    // 6. Sorting
    switch (criteria.sortBy) {
      case SortOption.newestFirst:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortOption.oldestFirst:
        filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SortOption.highestAmount:
        filtered.sort((a, b) {
          final maxA = a.postings.fold<int>(0, (m, p) => p.amountCents.abs() > m ? p.amountCents.abs() : m);
          final maxB = b.postings.fold<int>(0, (m, p) => p.amountCents.abs() > m ? p.amountCents.abs() : m);
          return maxB.compareTo(maxA);
        });
        break;
      case SortOption.lowestAmount:
        filtered.sort((a, b) {
          final maxA = a.postings.fold<int>(0, (m, p) => p.amountCents.abs() > m ? p.amountCents.abs() : m);
          final maxB = b.postings.fold<int>(0, (m, p) => p.amountCents.abs() > m ? p.amountCents.abs() : m);
          return maxA.compareTo(maxB);
        });
        break;
    }

    return filtered;
  }
}
