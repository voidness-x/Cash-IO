import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/services/financial_advisory_service.dart';
import '../../../core/utils/currency_utils.dart';

/// Privacy-first on-device financial advisory and heuristics intelligence card
class FinancialAdvisoryCard extends StatelessWidget {
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onOpenSavingsGoals;
  final VoidCallback? onOpenMoveBudget;

  const FinancialAdvisoryCard({
    super.key,
    this.onOpenAnalytics,
    this.onOpenSavingsGoals,
    this.onOpenMoveBudget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final repo = VaultRepository.instance;
    final advisory = FinancialAdvisoryService.instance;

    final ruleResult = advisory.evaluate503020Rule(repo);
    final runway = advisory.evaluateEmergencyRunway(repo);
    final suggestions = advisory.generateSuggestions(repo);
    final topSuggestion = suggestions.isNotEmpty ? suggestions.first : null;

    final needsPct = (ruleResult.needsRatio * 100).toInt().clamp(0, 100);
    final wantsPct = (ruleResult.wantsRatio * 100).toInt().clamp(0, 100);
    final savingsPct = (100 - needsPct - wantsPct).clamp(0, 100);

    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.borderHairline),
      ),
      padding: EdgeInsets.all(tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: tokens.statusIncome),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FINANCIAL GUIDANCE',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.statusIncome.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
                child: Text(
                  'On-Device',
                  style: GoogleFonts.mukta(
                    color: tokens.statusIncome,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space3),

          // 50/30/20 Segmented Bar + Wrap Legend (Never Overflows on Small Phones)
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (needsPct > 0)
                    Expanded(
                      flex: needsPct,
                      child: Container(color: tokens.statusIncome),
                    ),
                  if (wantsPct > 0)
                    Expanded(
                      flex: wantsPct,
                      child: Container(color: tokens.statusExpense.withValues(alpha: 0.85)),
                    ),
                  if (savingsPct > 0 || (needsPct == 0 && wantsPct == 0))
                    Expanded(
                      flex: savingsPct > 0 ? savingsPct : 100,
                      child: Container(color: tokens.accentGold),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildRatioDot('Needs $needsPct%', tokens.statusIncome, tokens),
              _buildRatioDot('Wants $wantsPct%', tokens.statusExpense, tokens),
              _buildRatioDot('Savings $savingsPct%', tokens.accentGold, tokens),
            ],
          ),
          SizedBox(height: tokens.space3),

          // Runway & Solvency Quick Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Row(
              children: [
                Icon(
                  runway.tier == RunwayTier.critical
                      ? Icons.warning_amber_rounded
                      : Icons.shield_outlined,
                  size: 16,
                  color: runway.tier == RunwayTier.critical
                      ? tokens.statusExpense
                      : tokens.statusIncome,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Runway: ${runway.runwayMonths.toStringAsFixed(1)} mo (${runway.tier.name.toUpperCase()})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.mukta(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      CurrencyUtils.format(runway.liquidAssetsCents, currency: repo.baseCurrency),
                      style: GoogleFonts.jetBrainsMono(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (topSuggestion != null) ...[
            SizedBox(height: tokens.space3),
            Container(
              padding: EdgeInsets.all(tokens.space3),
              decoration: BoxDecoration(
                color: _getSeverityColor(topSuggestion.severity, tokens).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: _getSeverityColor(topSuggestion.severity, tokens).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    topSuggestion.icon,
                    size: 18,
                    color: _getSeverityColor(topSuggestion.severity, tokens),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topSuggestion.title,
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          topSuggestion.description,
                          style: GoogleFonts.mukta(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        if (topSuggestion.actionLabel != null) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (topSuggestion.actionRoute == 'create_savings_goal' ||
                                  topSuggestion.actionRoute == 'savings_goals') {
                                onOpenSavingsGoals?.call();
                              } else if (topSuggestion.actionRoute == 'move_budget') {
                                onOpenMoveBudget?.call();
                              } else {
                                onOpenAnalytics?.call();
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    topSuggestion.actionLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: tokens.statusIncome,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 12, color: tokens.statusIncome),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatioDot(String label, Color color, CashIOThemeExtension tokens) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.mukta(
            color: tokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(SuggestionSeverity severity, CashIOThemeExtension tokens) {
    switch (severity) {
      case SuggestionSeverity.critical:
        return tokens.statusExpense;
      case SuggestionSeverity.warning:
        return tokens.accentGold;
      case SuggestionSeverity.tip:
        return tokens.statusIncome;
      case SuggestionSeverity.info:
        return tokens.accentChampagne;
    }
  }
}
