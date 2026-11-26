import 'package:flutter/material.dart';

enum AccountType {
  asset,      // Cash, Checking, Savings, Investment
  liability,  // Credit Card, Loan, Mortgage
  income,     // Salary, Freelance, Dividends
  expense,    // Groceries, Rent, Utilities, Dining
}

class AccountModel {
  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final int balanceCents; // Stored in cents (minor units) to prevent float rounding errors
  final IconData icon;

  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    this.balanceCents = 0,
    this.icon = Icons.account_balance_wallet_outlined,
  });

  double get balanceInUnits => balanceCents / 100.0;

  AccountModel copyWith({
    String? name,
    AccountType? type,
    String? currency,
    int? balanceCents,
    IconData? icon,
  }) {
    return AccountModel(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      balanceCents: balanceCents ?? this.balanceCents,
      icon: icon ?? this.icon,
    );
  }
}

class PostingModel {
  final String accountId;
  /// Amount in minor currency units (cents).
  /// Positive = Debit, Negative = Credit.
  final int amountCents;

  const PostingModel({
    required this.accountId,
    required this.amountCents,
  });
}

class TransactionModel {
  final String id;
  final DateTime timestamp;
  final String description;
  final List<PostingModel> postings;
  final List<String> receiptPaths;
  final String? note;

  const TransactionModel({
    required this.id,
    required this.timestamp,
    required this.description,
    required this.postings,
    this.receiptPaths = const [],
    this.note,
  });

  /// Invariant verification: sum of postings must be zero in double-entry bookkeeping.
  bool get isBalanced {
    final sum = postings.fold<int>(0, (acc, p) => acc + p.amountCents);
    return sum == 0;
  }

  int get totalCents => postings.isNotEmpty
      ? postings.fold<int>(0, (sum, p) => sum + p.amountCents.abs()) ~/ 2
      : 0;
}

class EnvelopeModel {
  final String id;
  final String name;
  final int assignedCents;
  final int spentCents;
  final int targetCents;
  final IconData icon;

  const EnvelopeModel({
    required this.id,
    required this.name,
    required this.assignedCents,
    this.spentCents = 0,
    this.targetCents = 0,
    this.icon = Icons.folder_outlined,
  });

  int get remainingCents => assignedCents - spentCents;

  EnvelopeModel copyWith({
    String? name,
    int? assignedCents,
    int? spentCents,
    int? targetCents,
    IconData? icon,
  }) {
    return EnvelopeModel(
      id: id,
      name: name ?? this.name,
      assignedCents: assignedCents ?? this.assignedCents,
      spentCents: spentCents ?? this.spentCents,
      targetCents: targetCents ?? this.targetCents,
      icon: icon ?? this.icon,
    );
  }
}

class MergeAuditLogModel {
  final String id;
  final DateTime timestamp;
  final String entityName;
  final String conflictType;
  final String resolution;

  const MergeAuditLogModel({
    required this.id,
    required this.timestamp,
    required this.entityName,
    required this.conflictType,
    required this.resolution,
  });
}

enum RecurringInterval {
  daily,
  weekly,
  biweekly,
  monthly,
  yearly,
}

class RecurringTransactionModel {
  final String id;
  final String title;
  final int amountCents;
  final String sourceAccountId;
  final String destinationAccountId;
  final RecurringInterval interval;
  final DateTime nextDueDate;
  final bool isExpense;
  final bool autoPost;
  final bool isActive;
  final IconData icon;

  const RecurringTransactionModel({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.interval,
    required this.nextDueDate,
    this.isExpense = true,
    this.autoPost = false,
    this.isActive = true,
    this.icon = Icons.repeat_rounded,
  });

  bool get isDue => DateTime.now().isAfter(nextDueDate) || DateTime.now().difference(nextDueDate).inHours.abs() < 12;

  DateTime calculateNextDate() {
    switch (interval) {
      case RecurringInterval.daily:
        return nextDueDate.add(const Duration(days: 1));
      case RecurringInterval.weekly:
        return nextDueDate.add(const Duration(days: 7));
      case RecurringInterval.biweekly:
        return nextDueDate.add(const Duration(days: 14));
      case RecurringInterval.monthly:
        return DateTime(nextDueDate.year, nextDueDate.month + 1, nextDueDate.day);
      case RecurringInterval.yearly:
        return DateTime(nextDueDate.year + 1, nextDueDate.month, nextDueDate.day);
    }
  }

  RecurringTransactionModel copyWith({
    String? title,
    int? amountCents,
    String? sourceAccountId,
    String? destinationAccountId,
    RecurringInterval? interval,
    DateTime? nextDueDate,
    bool? isExpense,
    bool? autoPost,
    bool? isActive,
    IconData? icon,
  }) {
    return RecurringTransactionModel(
      id: id,
      title: title ?? this.title,
      amountCents: amountCents ?? this.amountCents,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      interval: interval ?? this.interval,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      isExpense: isExpense ?? this.isExpense,
      autoPost: autoPost ?? this.autoPost,
      isActive: isActive ?? this.isActive,
      icon: icon ?? this.icon,
    );
  }
}

class FxRate {
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime lastUpdated;

  const FxRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.lastUpdated,
  });
}

class SavingsGoalModel {
  final String id;
  final String name;
  final int targetAmountCents;
  final int currentBalanceCents;
  final DateTime targetDate;
  final bool isLocked;
  final IconData icon;
  final String? accountId;

  const SavingsGoalModel({
    required this.id,
    required this.name,
    required this.targetAmountCents,
    this.currentBalanceCents = 0,
    required this.targetDate,
    this.isLocked = false,
    this.icon = Icons.savings_outlined,
    this.accountId,
  });

  double get progressPercentage => targetAmountCents > 0
      ? (currentBalanceCents / targetAmountCents).clamp(0.0, 1.0)
      : 0.0;

  int get remainingCents => (targetAmountCents - currentBalanceCents).clamp(0, targetAmountCents);

  int get daysRemaining => targetDate.difference(DateTime.now()).inDays.clamp(0, 3650);

  int get requiredMonthlyCents {
    final months = (daysRemaining / 30.0).ceil();
    if (months <= 0) return remainingCents;
    return (remainingCents / months).ceil();
  }

  SavingsGoalModel copyWith({
    String? name,
    int? targetAmountCents,
    int? currentBalanceCents,
    DateTime? targetDate,
    bool? isLocked,
    IconData? icon,
    String? accountId,
  }) {
    return SavingsGoalModel(
      id: id,
      name: name ?? this.name,
      targetAmountCents: targetAmountCents ?? this.targetAmountCents,
      currentBalanceCents: currentBalanceCents ?? this.currentBalanceCents,
      targetDate: targetDate ?? this.targetDate,
      isLocked: isLocked ?? this.isLocked,
      icon: icon ?? this.icon,
      accountId: accountId ?? this.accountId,
    );
  }
}
