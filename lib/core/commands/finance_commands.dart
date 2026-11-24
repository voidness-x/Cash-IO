import 'package:flutter/foundation.dart';
import '../models/finance_models.dart';

@immutable
class RecordTransactionCommand {
  final String profileId;
  final String description;
  final DateTime timestamp;
  final List<PostingModel> postings;
  final List<String> receiptPaths;
  final String? note;

  const RecordTransactionCommand({
    required this.profileId,
    required this.description,
    required this.timestamp,
    required this.postings,
    this.receiptPaths = const [],
    this.note,
  });

  /// Invariant verification: sum of postings must be zero in double-entry bookkeeping
  bool get isBalanced {
    if (postings.length < 2) return false;
    final sum = postings.fold<int>(0, (acc, p) => acc + p.amountCents);
    return sum == 0;
  }

  /// Calculates total imbalance in cents (0 if balanced)
  int get balanceDiscrepancyCents {
    return postings.fold<int>(0, (acc, p) => acc + p.amountCents);
  }
}

@immutable
class CreateAccountCommand {
  final String profileId;
  final String name;
  final AccountType type;
  final String currency;
  final int initialBalanceCents;
  final int iconCode;

  const CreateAccountCommand({
    required this.profileId,
    required this.name,
    required this.type,
    required this.currency,
    this.initialBalanceCents = 0,
    required this.iconCode,
  });
}

@immutable
class CreateEnvelopeCommand {
  final String profileId;
  final String name;
  final int assignedCents;
  final int targetCents;

  const CreateEnvelopeCommand({
    required this.profileId,
    required this.name,
    this.assignedCents = 0,
    this.targetCents = 0,
  });
}

@immutable
class AssignEnvelopeFundsCommand {
  final String profileId;
  final String envelopeId;
  final int amountCents;

  const AssignEnvelopeFundsCommand({
    required this.profileId,
    required this.envelopeId,
    required this.amountCents,
  });
}
