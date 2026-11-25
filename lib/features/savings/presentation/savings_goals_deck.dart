import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/services/financial_advisory_service.dart';
import '../../../core/utils/currency_utils.dart';
import 'savings_goal_sheets.dart';

/// Interactive Goal Vaults deck & Spare-Change Round-Up Simulator (100% Flex Overflow Safe)
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
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: tokens.statusIncome),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'SAVINGS GOALS & LOCKED VAULTS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openCreateGoalSheet(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(Icons.add, size: 15, color: tokens.statusIncome),
              label: Text(
                'New Vault',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.statusIncome,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (goals.isEmpty)
          Container(
            padding: EdgeInsets.all(tokens.space4),
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_clock_outlined, size: 28, color: tokens.textTertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No savings goals created yet',
                            style: GoogleFonts.spaceGrotesk(
                              color: tokens.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Create a locked savings vault for emergencies or upcoming purchases.',
                            style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCreateGoalSheet(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Savings Goal Vault'),
                  ),
                ),
              ],
            ),
          )
        else
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tokens.bgSurfaceElevated,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          border: Border.all(color: tokens.borderHairline),
                        ),
                        child: Icon(goal.icon, color: tokens.statusIncome, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    goal.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.mukta(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (goal.isLocked) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: tokens.accentGold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(tokens.radiusXs),
                                    ),
                                    child: Icon(Icons.lock, size: 11, color: tokens.accentGold),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              'Target: ${CurrencyUtils.format(goal.targetAmountCents, currency: currency)} • ${goal.daysRemaining}d left',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 115),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                CurrencyUtils.format(goal.currentBalanceCents, currency: currency),
                                style: GoogleFonts.jetBrainsMono(
                                  color: tokens.statusIncome,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.textTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: tokens.bgSurfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(tokens.statusIncome),
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.space2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pace: ${CurrencyUtils.format(goal.requiredMonthlyCents, currency: currency)}/mo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                        ),
                      ),
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
                      FilledButton.tonal(
                        onPressed: () => _openDepositSheet(context, goal),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('+ Deposit', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

        // Spare-Change Round-Up Simulator Card
        Container(
          padding: EdgeInsets.all(tokens.space3),
          decoration: BoxDecoration(
            color: tokens.bgSurfaceElevated,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(color: tokens.borderHairline),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: tokens.accentGold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPARE-CHANGE ROUND-UPS',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.accentGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Estimated +${CurrencyUtils.format(simulatedRoundUps > 0 ? simulatedRoundUps : (currency == 'IQD' ? 500000 : 1500), currency: currency)} in spare change.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (goals.isNotEmpty) ...[
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final depositAmt = simulatedRoundUps > 0
                        ? simulatedRoundUps
                        : (currency == 'IQD' ? 500000 : 1500);
                    repo.depositToGoal(goals.first.id, depositAmt);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Saved +${CurrencyUtils.format(depositAmt, currency: currency)} into "${goals.first.name}"!',
                        ),
                        backgroundColor: tokens.statusIncome,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
