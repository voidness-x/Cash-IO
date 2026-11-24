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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(tokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: tokens.statusIncome),
                  const SizedBox(width: 8),
                  Text(
                    'FINANCIAL INTELLIGENCE',
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.statusIncome.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '100% On-Device',
                  style: GoogleFonts.mukta(
                    color: tokens.statusIncome,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space4),

          // 50/30/20 Segmented Metric Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '50/30/20 CASHFLOW BALANCE',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Needs: $needsPct% • Wants: $wantsPct% • Savings: $savingsPct%',
                style: GoogleFonts.jetBrainsMono(
                  color: tokens.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space2),

          // Segmented Progress Bar
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
                      child: Container(color: tokens.statusExpense.withValues(alpha: 0.8)),
                    ),
                  if (savingsPct > 0)
                    Expanded(
                      flex: savingsPct,
                      child: Container(color: tokens.accentGold),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.space3),

          // Runway & Solvency Quick Pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: tokens.space3, vertical: tokens.space2),
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
                      : (runway.tier == RunwayTier.fortified
                          ? Icons.verified_user_outlined
                          : Icons.shield_outlined),
                  size: 16,
                  color: runway.tier == RunwayTier.critical
                      ? tokens.statusExpense
                      : tokens.statusIncome,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Runway: ${runway.runwayMonths.toStringAsFixed(1)} Months (${runway.tier.name.toUpperCase()})',
                    style: GoogleFonts.mukta(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  CurrencyUtils.format(runway.liquidAssetsCents, currency: repo.baseCurrency),
                  style: GoogleFonts.jetBrainsMono(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Top Actionable Advisory Card
          if (topSuggestion != null) ...[
            SizedBox(height: tokens.space3),
            Container(
              padding: EdgeInsets.all(tokens.space3),
              decoration: BoxDecoration(
                color: _getSeverityColor(topSuggestion.severity, tokens).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: _getSeverityColor(topSuggestion.severity, tokens).withValues(alpha: 0.35),
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
                  SizedBox(width: tokens.space3),
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
                            fontSize: 11,
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
                                Text(
                                  topSuggestion.actionLabel!,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: tokens.statusIncome,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
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
