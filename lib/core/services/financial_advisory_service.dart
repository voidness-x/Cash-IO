import 'dart:math';
import 'package:flutter/material.dart';
import '../models/finance_models.dart';
import '../storage/vault_repository.dart';

enum SuggestionSeverity {
  info,
  tip,
  warning,
  critical,
}

class FinancialSuggestion {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final SuggestionSeverity severity;
  final String? actionLabel;
  final String? actionRoute;

  const FinancialSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.severity = SuggestionSeverity.info,
    this.actionLabel,
    this.actionRoute,
  });
}

enum FiftyThirtyTwentyStatus {
  balanced,
  needsHeavy,
  wantsHeavy,
  savingsDeficit,
  insufficientData,
}

class FiftyThirtyTwentyResult {
  final int totalIncomeCents;
  final int needsCents;
  final int wantsCents;
  final int savingsCents;
  final double needsRatio;
  final double wantsRatio;
  final double savingsRatio;
  final FiftyThirtyTwentyStatus status;
  final String message;

  const FiftyThirtyTwentyResult({
    required this.totalIncomeCents,
    required this.needsCents,
    required this.wantsCents,
    required this.savingsCents,
    required this.needsRatio,
    required this.wantsRatio,
    required this.savingsRatio,
    required this.status,
    required this.message,
  });
}

enum RunwayTier {
  critical, // < 1 month
  building, // 1 - 2.9 months
  healthy,  // 3 - 5.9 months
  fortified // >= 6 months
}

class RunwayAdequacyResult {
  final int liquidAssetsCents;
  final int monthlyBurnCents;
  final double runwayMonths;
  final RunwayTier tier;
  final String message;

  const RunwayAdequacyResult({
    required this.liquidAssetsCents,
    required this.monthlyBurnCents,
    required this.runwayMonths,
    required this.tier,
    required this.message,
  });
}

/// Zero-Knowledge, 100% on-device financial advisory and heuristics engine
class FinancialAdvisoryService {
  static final FinancialAdvisoryService instance = FinancialAdvisoryService._internal();
  FinancialAdvisoryService._internal();

  // Known categorization keywords for Needs vs Wants
  static final Set<String> _needsKeywords = {
    'rent', 'mortgage', 'groceries', 'supermarket', 'utilities', 'electricity',
    'water', 'gas', 'bill', 'health', 'hospital', 'medicine', 'pharmacy',
    'insurance', 'transport', 'fuel', 'petrol', 'bus', 'metro', 'loan', 'debt',
  };

  static final Set<String> _wantsKeywords = {
    'dining', 'restaurant', 'cafe', 'coffee', 'entertainment', 'netflix', 'game',
    'shopping', 'clothes', 'fashion', 'vacation', 'flight', 'hotel', 'spa', 'bar',
  };

  /// Analyzes the last 30 days against the 50/30/20 financial rule
  FiftyThirtyTwentyResult evaluate503020Rule(VaultRepository repo) {
    final incomeCents = repo.last30DaysIncomeCents;
    final categorySpending = repo.getCategorySpendingCents(days: 30);

    int needsCents = 0;
    int wantsCents = 0;

    for (final entry in categorySpending.entries) {
      final nameLower = entry.key.toLowerCase();
      final isNeed = _needsKeywords.any((k) => nameLower.contains(k));
      final isWant = _wantsKeywords.any((k) => nameLower.contains(k));

      if (isNeed) {
        needsCents += entry.value;
      } else if (isWant) {
        wantsCents += entry.value;
      } else {
        // Fallback: split evenly if unknown category
        needsCents += (entry.value * 0.6).round();
        wantsCents += (entry.value * 0.4).round();
      }
    }

    final totalExpenses = needsCents + wantsCents;
    final effectiveIncome = incomeCents > 0 ? incomeCents : max(totalExpenses, 10000);
    final savingsCents = max(0, effectiveIncome - totalExpenses);

    final needsRatio = needsCents / effectiveIncome;
    final wantsRatio = wantsCents / effectiveIncome;
    final savingsRatio = savingsCents / effectiveIncome;

    if (totalExpenses == 0 && incomeCents == 0) {
      return FiftyThirtyTwentyResult(
        totalIncomeCents: 0,
        needsCents: 0,
        wantsCents: 0,
        savingsCents: 0,
        needsRatio: 0.5,
        wantsRatio: 0.3,
        savingsRatio: 0.2,
        status: FiftyThirtyTwentyStatus.insufficientData,
        message: 'Record your first income and expenses to unlock 50/30/20 balance analytics.',
      );
    }

    FiftyThirtyTwentyStatus status = FiftyThirtyTwentyStatus.balanced;
    String message = 'Your cashflow aligns closely with the recommended 50/30/20 benchmark.';

    if (needsRatio > 0.60) {
      status = FiftyThirtyTwentyStatus.needsHeavy;
      message = 'Essential expenses consume ${(needsRatio * 100).toStringAsFixed(0)}% of inflows (ideal <= 50%). Consider trimming fixed overhead.';
    } else if (wantsRatio > 0.35) {
      status = FiftyThirtyTwentyStatus.wantsHeavy;
      message = 'Discretionary spending reaches ${(wantsRatio * 100).toStringAsFixed(0)}% of inflows (ideal <= 30%). Reallocating to savings will accelerate runway.';
    } else if (savingsRatio < 0.10) {
      status = FiftyThirtyTwentyStatus.savingsDeficit;
      message = 'Savings margin is under 10%. Build an automated round-up or dedicated goal vault to fortify reserves.';
    }

    return FiftyThirtyTwentyResult(
      totalIncomeCents: effectiveIncome,
      needsCents: needsCents,
      wantsCents: wantsCents,
      savingsCents: savingsCents,
      needsRatio: needsRatio.clamp(0.0, 1.0),
      wantsRatio: wantsRatio.clamp(0.0, 1.0),
      savingsRatio: savingsRatio.clamp(0.0, 1.0),
      status: status,
      message: message,
    );
  }

  /// Calculates emergency runway adequacy
  RunwayAdequacyResult evaluateEmergencyRunway(VaultRepository repo) {
    final liquidAssetsCents = repo.totalAssetsCents;
    final monthlyBurnCents = max(repo.last30DaysExpenseCents, repo.baseCurrency == 'IQD' ? 1000000 : 1000);
    final runwayMonths = liquidAssetsCents / monthlyBurnCents.toDouble();

    RunwayTier tier;
    String message;

    if (runwayMonths < 1.0) {
      tier = RunwayTier.critical;
      message = 'Liquid assets cover less than 1 month of expenses (${runwayMonths.toStringAsFixed(1)} mo). Prioritize an emergency fund goal immediately.';
    } else if (runwayMonths < 3.0) {
      tier = RunwayTier.building;
      message = 'Runway covers ${runwayMonths.toStringAsFixed(1)} months. Aim to accumulate a 3-month baseline to withstand income shocks.';
    } else if (runwayMonths < 6.0) {
      tier = RunwayTier.healthy;
      message = 'Healthy liquidity buffer of ${runwayMonths.toStringAsFixed(1)} months of expenses. You meet standard institutional personal safety metrics.';
    } else {
      tier = RunwayTier.fortified;
      message = 'Exceptional runway buffer of ${runwayMonths.toStringAsFixed(1)} months. You have substantial capital insulation.';
    }

    return RunwayAdequacyResult(
      liquidAssetsCents: liquidAssetsCents,
      monthlyBurnCents: monthlyBurnCents,
      runwayMonths: runwayMonths,
      tier: tier,
      message: message,
    );
  }

  /// Detects abnormal 7-day spending velocity spikes
  bool detectVelocitySpike(VaultRepository repo) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    int sevenDaySpend = 0;
    int thirtyDaySpend = 0;

    for (final tx in repo.transactions) {
      if (tx.timestamp.isAfter(sevenDaysAgo)) {
        for (final p in tx.postings) {
          if (p.amountCents > 0) sevenDaySpend += p.amountCents;
        }
      }
      if (tx.timestamp.isAfter(thirtyDaysAgo)) {
        for (final p in tx.postings) {
          if (p.amountCents > 0) thirtyDaySpend += p.amountCents;
        }
      }
    }

    if (thirtyDaySpend == 0) return false;
    final expectedSevenDaySpend = (thirtyDaySpend / 30.0) * 7.0;
    return sevenDaySpend > (expectedSevenDaySpend * 1.30); // >30% spike
  }

  /// Detects budget leaks (envelopes >75% depleted in first 10 days of the month)
  List<EnvelopeModel> detectBudgetLeaks(VaultRepository repo) {
    final dayOfMonth = DateTime.now().day;
    final leaks = <EnvelopeModel>[];

    for (final env in repo.envelopes) {
      if (env.assignedCents > 0) {
        final spentRatio = env.spentCents / env.assignedCents.toDouble();
        if (dayOfMonth <= 12 && spentRatio >= 0.70) {
          leaks.add(env);
        } else if (spentRatio >= 1.0) {
          leaks.add(env);
        }
      }
    }
    return leaks;
  }

  /// Generates top contextual financial suggestions for the user
  List<FinancialSuggestion> generateSuggestions(VaultRepository repo) {
    final suggestions = <FinancialSuggestion>[];

    // 1. Runway Adequacy Check
    final runway = evaluateEmergencyRunway(repo);
    if (runway.tier == RunwayTier.critical) {
      suggestions.add(FinancialSuggestion(
        id: 'sug_emergency_fund',
        title: 'Emergency Cushion Alert',
        description: runway.message,
        icon: Icons.shield_outlined,
        severity: SuggestionSeverity.critical,
        actionLabel: 'Create Emergency Goal',
        actionRoute: 'create_savings_goal',
      ));
    }

    // 2. 50/30/20 Rule Suggestions
    final rule = evaluate503020Rule(repo);
    if (rule.status == FiftyThirtyTwentyStatus.wantsHeavy) {
      suggestions.add(FinancialSuggestion(
        id: 'sug_wants_heavy',
        title: 'Discretionary Outflow Alert',
        description: rule.message,
        icon: Icons.trending_up_rounded,
        severity: SuggestionSeverity.warning,
        actionLabel: 'Review Spending',
        actionRoute: 'view_analytics',
      ));
    } else if (rule.status == FiftyThirtyTwentyStatus.savingsDeficit) {
      suggestions.add(FinancialSuggestion(
        id: 'sug_savings_deficit',
        title: 'Accelerate Savings Margin',
        description: rule.message,
        icon: Icons.savings_outlined,
        severity: SuggestionSeverity.tip,
        actionLabel: 'Explore Goal Vaults',
        actionRoute: 'create_savings_goal',
      ));
    }

    // 3. Velocity Spike Check
    if (detectVelocitySpike(repo)) {
      suggestions.add(const FinancialSuggestion(
        id: 'sug_velocity_spike',
        title: 'Unusual Spending Velocity Detected',
        description: 'Spending over the past 7 days is 30% above your 30-day baseline. Consider pacing non-essential purchases.',
        icon: Icons.speed_rounded,
        severity: SuggestionSeverity.warning,
      ));
    }

    // 4. Budget Leaks Check
    final leaks = detectBudgetLeaks(repo);
    if (leaks.isNotEmpty) {
      final leakNames = leaks.map((e) => e.name).take(2).join(', ');
      suggestions.add(FinancialSuggestion(
        id: 'sug_budget_leaks',
        title: 'Envelope Exhaustion Alert',
        description: 'Budget envelopes ($leakNames) are near depletion early in the cycle. Use "Move Budget" to balance categories.',
        icon: Icons.warning_amber_rounded,
        severity: SuggestionSeverity.warning,
        actionLabel: 'Move Budget',
        actionRoute: 'move_budget',
      ));
    }

    // 5. Positive Reinforcement
    if (runway.tier == RunwayTier.fortified) {
      suggestions.add(FinancialSuggestion(
        id: 'sug_institutional_cushion',
        title: 'Institutional Solvency Achieved',
        description: 'With ${runway.runwayMonths.toStringAsFixed(1)} months of expenses secured, your capital is resilient against market shocks.',
        icon: Icons.verified_user_outlined,
        severity: SuggestionSeverity.info,
      ));
    }

    // Fallback friendly tip if no warnings
    if (suggestions.isEmpty) {
      suggestions.add(const FinancialSuggestion(
        id: 'sug_roundup_tip',
        title: 'Spare-Change Round-Up Tip',
        description: 'Simulate rounding up everyday cash purchases to the nearest integer to systematically fund your savings goals.',
        icon: Icons.auto_graph_rounded,
        severity: SuggestionSeverity.tip,
        actionLabel: 'Simulate Round-Ups',
        actionRoute: 'savings_goals',
      ));
    }

    return suggestions;
  }

  /// Calculates simulated spare change round-ups from transactions
  int calculateSimulatedRoundUpsCents(VaultRepository repo) {
    int totalSpareCents = 0;
    for (final tx in repo.transactions) {
      for (final p in tx.postings) {
        if (p.amountCents < 0) { // Asset outflow
          final absCents = p.amountCents.abs();
          // Round up to nearest whole unit (100 cents)
          final remainder = absCents % 100;
          if (remainder > 0) {
            totalSpareCents += (100 - remainder);
          }
        }
      }
    }
    return totalSpareCents;
  }
}
