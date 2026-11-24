import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/services/financial_advisory_service.dart';
import '../../../core/utils/currency_utils.dart';
import 'savings_goal_sheets.dart';

/// Interactive Goal Vaults deck & Spare-Change Round-Up Simulator
class SavingsGoalsDeck extends StatelessWidget {
  final String currency;

  const SavingsGoalsDeck({super.key, required this.currency});

  void _openCreateGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => CreateSavingsGoalSheet(baseCurrency: currency),
    );
  }

  void _openDepositSheet(BuildContext context, SavingsGoalModel goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => DepositToGoalSheet(goal: goal, baseCurrency: currency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final repo = VaultRepository.instance;
    final goals = repo.savingsGoals;
    final simulatedRoundUps = FinancialAdvisoryService.instance.calculateSimulatedRoundUpsCents(repo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: tokens.statusIncome),
                const SizedBox(width: 8),
                Text(
                  'SAVINGS GOALS & LOCKED VAULTS',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _openCreateGoalSheet(context),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 14, color: tokens.statusIncome),
                    const SizedBox(width: 4),
                    Text(
                      'New Vault',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.statusIncome,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.space3),

        // Goals List
        if (goals.isEmpty) ...[
          Container(
            padding: EdgeInsets.all(tokens.space5),
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_clock_outlined, size: 32, color: tokens.textTertiary),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No savings goals created',
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Create locked goal vaults to ring-fence emergency funds or capital purchases.',
                        style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _openCreateGoalSheet(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Add Goal'),
                ),
              ],
            ),
          ),
        ] else ...[
          ...goals.map((goal) {
            final progress = goal.progressPercentage;
            final isFullyFunded = goal.currentBalanceCents >= goal.targetAmountCents;

            return Container(
              margin: EdgeInsets.only(bottom: tokens.space3),
              padding: EdgeInsets.all(tokens.space4),
              decoration: BoxDecoration(
                color: tokens.bgSurface,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(
                  color: isFullyFunded ? tokens.statusIncome.withValues(alpha: 0.6) : tokens.borderHairline,
                  width: isFullyFunded ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tokens.bgSurfaceElevated,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          border: Border.all(color: tokens.borderHairline),
                        ),
                        child: Icon(goal.icon, color: tokens.statusIncome, size: 20),
                      ),
                      SizedBox(width: tokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  goal.name,
                                  style: GoogleFonts.mukta(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (goal.isLocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: tokens.accentGold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(tokens.radiusXs),
                                      border: Border.all(color: tokens.accentGold.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock, size: 9, color: tokens.accentGold),
                                        const SizedBox(width: 3),
                                        Text(
                                          'LOCKED',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: tokens.accentGold,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              'Target: ${CurrencyUtils.format(goal.targetAmountCents, currency: currency)} • Due in ${goal.daysRemaining} days',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyUtils.format(goal.currentBalanceCents, currency: currency),
                            style: GoogleFonts.jetBrainsMono(
                              color: tokens.statusIncome,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}% FUNDED',
                            style: GoogleFonts.spaceGrotesk(
                              color: tokens.textTertiary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space3),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: tokens.bgSurfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFullyFunded ? tokens.statusIncome : tokens.statusIncome.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.space3),

                  // Action Strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pace: ${CurrencyUtils.format(goal.requiredMonthlyCents, currency: currency)} / mo',
                        style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              goal.isLocked ? Icons.lock : Icons.lock_open,
                              size: 16,
                              color: goal.isLocked ? tokens.accentGold : tokens.textTertiary,
                            ),
                            tooltip: goal.isLocked ? 'Unlock Vault' : 'Lock Vault',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              repo.toggleGoalLock(goal.id, !goal.isLocked);
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _openDepositSheet(context, goal),
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.statusIncome.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(tokens.radiusPill),
                                border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.add, size: 12, color: tokens.statusIncome),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Deposit',
                                    style: GoogleFonts.mukta(
                                      color: tokens.statusIncome,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
        SizedBox(height: tokens.space2),

        // Spare-Change Round-Up Simulator Card
        Container(
          padding: EdgeInsets.all(tokens.space4),
          decoration: BoxDecoration(
            color: tokens.bgSurfaceElevated,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(color: tokens.borderHairline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.accentGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: tokens.accentGold, size: 18),
              ),
              SizedBox(width: tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPARE-CHANGE ROUND-UP SIMULATOR',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.accentGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Rounding daily purchases would yield +${CurrencyUtils.format(simulatedRoundUps > 0 ? simulatedRoundUps : 3850, currency: currency)} in automated savings.',
                      style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (goals.isNotEmpty)
                FilledButton.tonal(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final depositAmt = simulatedRoundUps > 0 ? simulatedRoundUps : 2500;
                    repo.depositToGoal(goals.first.id, depositAmt);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Transferred +${CurrencyUtils.format(depositAmt, currency: currency)} spare change into "${goals.first.name}"!',
                        ),
                        backgroundColor: tokens.statusIncome,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Save Change', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
