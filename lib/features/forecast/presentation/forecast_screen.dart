import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/widgets/animated_money_bar.dart';
import '../../advisory/presentation/financial_advisory_card.dart';
import '../../analytics/presentation/category_spending_donut_card.dart';
import '../../savings/presentation/savings_goal_sheets.dart';

/// Unified Insights & Forecast hub hosting the interactive Future Balance Timeline
/// (with single-source-of-truth linear scrubber), 30-day Cashflow, Money Health,
/// and Category Spending Breakdown.
class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  static const int _maxTimelineDays = 180;

  /// Single source of truth for BOTH the chart scrubber line AND the PROJECTION readout.
  int _selectedDay = 90;

  void _setSelectedDayFromLocalX(double localX, double canvasWidth) {
    if (canvasWidth <= 0) return;
    final progress = (localX / canvasWidth).clamp(0.0, 1.0);
    final nextDay = (progress * _maxTimelineDays).round().clamp(0, _maxTimelineDays);
    if (nextDay != _selectedDay) {
      setState(() => _selectedDay = nextDay);
    }
  }

  void _openCreateGoalSheet(BuildContext context, String currency) {
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

  @override
  Widget build(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;
    final currency = repo.baseCurrency;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final liquidAssetsCents = repo.totalAssetsCents;
        final pastExpenseCents = repo.last30DaysExpenseCents;
        final pastIncomeCents = repo.last30DaysIncomeCents;

        // Daily Burn & Income
        final dailyBurnCents = pastExpenseCents > 0
            ? (pastExpenseCents / 30.0).round()
            : (currency == 'IQD' ? 2500000 : 3500);
        final dailyIncomeCents = pastIncomeCents > 0
            ? (pastIncomeCents / 30.0).round()
            : (currency == 'IQD' ? 4000000 : 5000);
        final netDailyCents = dailyIncomeCents - dailyBurnCents;

        // Runway Days Calculation
        final runwayDays = dailyBurnCents > 0 && liquidAssetsCents > 0
            ? (liquidAssetsCents / dailyBurnCents).floor()
            : 0;

        // Single-Source-of-Truth Scrubbed Projection
        final scrubberProgress = _selectedDay / _maxTimelineDays;
        final scrubbedDate = DateTime.now().add(Duration(days: _selectedDay));
        final scrubbedBalanceCents = liquidAssetsCents + (netDailyCents * _selectedDay);

        // Milestone Balances
        final proj30dCents = liquidAssetsCents + (netDailyCents * 30);
        final proj60dCents = liquidAssetsCents + (netDailyCents * 60);
        final proj90dCents = liquidAssetsCents + (netDailyCents * 90);
        final proj180dCents = liquidAssetsCents + (netDailyCents * 180);

        final totalFlow30d = pastIncomeCents + pastExpenseCents;
        final incomeRatio30d = totalFlow30d > 0 ? (pastIncomeCents / totalFlow30d) : 0.0;

        return FrostedScaffold(
          appBar: AppBar(
            title: Text(
              'INSIGHTS & FORECAST',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              tokens.space4,
              tokens.space4,
              tokens.space4,
              MediaQuery.paddingOf(context).bottom + 112,
            ),
            children: [
              // 1. Glowing Safety Buffer Hero Deck
              StaggeredEntrance(
                index: 0,
                child: Container(
                  decoration: tokens.heroGlowDecoration(
                    glowColor: netDailyCents >= 0 ? tokens.accentGold : tokens.statusExpense,
                  ),
                  padding: EdgeInsets.all(tokens.space5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timeline_rounded, size: 16, color: tokens.statusIncome),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'SAFETY BUFFER',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: tokens.statusIncome.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(tokens.radiusPill),
                            ),
                            child: Text(
                              'Local Estimate',
                              style: GoogleFonts.mukta(
                                color: tokens.statusIncome,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$runwayDays',
                            style: GoogleFonts.jetBrainsMono(
                              color: tokens.textPrimary,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: tokens.space2),
                          Expanded(
                            child: Text(
                              'Days of Expenses Covered',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.mukta(
                                color: tokens.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space4),
                      Divider(color: tokens.borderSubtle, height: 1),
                      SizedBox(height: tokens.space3),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Spending',
                                  style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '-${CurrencyUtils.formatCompact(dailyBurnCents, currency: currency, showSymbol: true)} / day',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: tokens.statusExpense,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 28, color: tokens.borderSubtle),
                          SizedBox(width: tokens.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Net Change',
                                  style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${netDailyCents >= 0 ? '+' : ''}${CurrencyUtils.formatCompact(netDailyCents, currency: currency, showSymbol: true)} / day',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: netDailyCents >= 0 ? tokens.statusIncome : tokens.statusExpense,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space4),

              // 2. Interactive Scrubber Chart Card (Single Source of Truth + Linear Axis)
              StaggeredEntrance(
                index: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.bgSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  padding: EdgeInsets.all(tokens.space5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'FUTURE BALANCE TIMELINE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Drag to inspect',
                            style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space3),

                      // Live Inspection Readout (borderless elevated surface to avoid border fatigue)
                      Container(
                        key: const ValueKey('forecast_projection_box'),
                        padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space3),
                        decoration: BoxDecoration(
                          color: tokens.bgSurfaceElevated,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PROJECTION: +$_selectedDay DAYS',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: tokens.accentGold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    '${_monthName(scrubbedDate.month)} ${scrubbedDate.day}, ${scrubbedDate.year}',
                                    style: GoogleFonts.mukta(
                                      color: tokens.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  CurrencyUtils.format(scrubbedBalanceCents, currency: currency),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: scrubbedBalanceCents >= 0 ? tokens.statusIncome : tokens.statusExpense,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: tokens.space4),

                      // Interactive Canvas using exact LayoutBuilder width
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasWidth = constraints.maxWidth;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) =>
                                _setSelectedDayFromLocalX(details.localPosition.dx, canvasWidth),
                            onTapDown: (details) {
                              HapticFeedback.selectionClick();
                              _setSelectedDayFromLocalX(details.localPosition.dx, canvasWidth);
                            },
                            child: SizedBox(
                              height: 140,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _InteractiveForecastPainter(
                                  progress: scrubberProgress,
                                  liquidAssetsCents: liquidAssetsCents,
                                  netDailyCents: netDailyCents,
                                  maxDays: _maxTimelineDays,
                                  curveColor: tokens.statusIncome,
                                  scrubberColor: tokens.accentGold,
                                  gridColor: tokens.borderSubtle,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: tokens.space2),

                      // Strictly Linear Axis Ticks matching 0%, 25%, 50%, 75%, 100% of 180 days
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Today', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('+45d', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('+90d', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('+135d', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('+180d', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space4),

              // 3. Milestone Runway Cards
              StaggeredEntrance(
                index: 2,
                child: Text(
                  'UPCOMING MILESTONES',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              SizedBox(height: tokens.space3),

              _buildProjectionCard(
                days: '30 Days',
                date: 'Next Month',
                projectedCents: proj30dCents,
                currency: currency,
                tokens: tokens,
                isSelected: _selectedDay == 30,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDay = 30);
                },
              ),
              SizedBox(height: tokens.space2),
              _buildProjectionCard(
                days: '60 Days',
                date: '2 Months Out',
                projectedCents: proj60dCents,
                currency: currency,
                tokens: tokens,
                isSelected: _selectedDay == 60,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDay = 60);
                },
              ),
              SizedBox(height: tokens.space2),
              _buildProjectionCard(
                days: '90 Days',
                date: 'Quarter End',
                projectedCents: proj90dCents,
                currency: currency,
                tokens: tokens,
                isSelected: _selectedDay == 90,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDay = 90);
                },
              ),
              SizedBox(height: tokens.space2),
              _buildProjectionCard(
                days: '180 Days',
                date: '6 Months Out',
                projectedCents: proj180dCents,
                currency: currency,
                tokens: tokens,
                isSelected: _selectedDay == 180,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDay = 180);
                },
              ),
              SizedBox(height: tokens.space5),

              // 4. 30-Day Cashflow & Money Health (De-nested from Home)
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
                        Expanded(
                          child: Text(
                            '30-DAY CASHFLOW',
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
                        Text(
                          pastIncomeCents >= pastExpenseCents ? 'NET SURPLUS' : 'NET DEFICIT',
                          style: GoogleFonts.mukta(
                            color: pastIncomeCents >= pastExpenseCents
                                ? tokens.statusIncome
                                : tokens.statusExpense,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (totalFlow30d == 0)
                      AnimatedMoneyBar(
                        value: 0.0,
                        height: 7,
                        fillColor: tokens.statusIncome,
                        glow: false,
                      )
                    else
                      AnimatedSegmentedMoneyBar(
                        height: 7,
                        segments: [
                          MoneyBarSegment(weight: incomeRatio30d.clamp(0.05, 0.95), color: tokens.statusIncome),
                          MoneyBarSegment(
                            weight: (1.0 - incomeRatio30d).clamp(0.05, 0.95),
                            color: tokens.statusExpense,
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'In: +${CurrencyUtils.formatCompact(pastIncomeCents, currency: currency, showSymbol: true)}',
                              style: GoogleFonts.jetBrainsMono(
                                color: tokens.statusIncome,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Out: -${CurrencyUtils.formatCompact(pastExpenseCents, currency: currency, showSymbol: true)}',
                              style: GoogleFonts.jetBrainsMono(
                                color: tokens.statusExpense,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.space3),

              FinancialAdvisoryCard(
                onOpenSavingsGoals: () => _openCreateGoalSheet(context, currency),
              ),
              SizedBox(height: tokens.space3),

              // 5. Spending Breakdown Donut Card (De-nested from Home)
              CategorySpendingDonutCard(currency: currency),
              SizedBox(height: tokens.space4),

              // Local Offline Guarantee Note (borderless subtle surface)
              Container(
                padding: EdgeInsets.all(tokens.space4),
                decoration: BoxDecoration(
                  color: tokens.bgSurfaceElevated.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: tokens.statusIncome),
                    SizedBox(width: tokens.space3),
                    Expanded(
                      child: Text(
                        'Forecast & analytics run 100% on local device hardware with zero network telemetry.',
                        style: GoogleFonts.mukta(
                          color: tokens.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectionCard({
    required String days,
    required String date,
    required int projectedCents,
    required String currency,
    required CashIOThemeExtension tokens,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isPositive = projectedCents >= 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      child: Container(
        padding: EdgeInsets.all(tokens.space4),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(
            color: isSelected ? tokens.accentGold.withValues(alpha: 0.55) : tokens.borderHairline,
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.statusIncome.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Text(
                      days.split(' ')[0],
                      style: GoogleFonts.jetBrainsMono(
                        color: tokens.statusIncome,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          days,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.mukta(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 135),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      CurrencyUtils.formatCompact(projectedCents, currency: currency, showSymbol: true),
                      style: GoogleFonts.jetBrainsMono(
                        color: isPositive ? tokens.statusIncome : tokens.statusExpense,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    isPositive ? 'Surplus Runway' : 'Deficit Risk',
                    style: GoogleFonts.spaceGrotesk(
                      color: isPositive ? tokens.statusIncome : tokens.statusExpense,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }
}

/// Custom Canvas Painter rendering interactive forecast curve and vertical scrubber
class _InteractiveForecastPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final int liquidAssetsCents;
  final int netDailyCents;
  final int maxDays;
  final Color curveColor;
  final Color scrubberColor;
  final Color gridColor;

  const _InteractiveForecastPainter({
    required this.progress,
    required this.liquidAssetsCents,
    required this.netDailyCents,
    required this.maxDays,
    required this.curveColor,
    required this.scrubberColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);

    final startVal = liquidAssetsCents.toDouble();
    final endVal = startVal + (netDailyCents * maxDays);
    final minVal = min(startVal, endVal);
    final maxVal = max(startVal, endVal);
    final range = (maxVal - minVal).abs() > 0 ? (maxVal - minVal).abs() : 1.0;

    double getY(double t) {
      final val = startVal + (netDailyCents * (t * maxDays));
      final norm = (val - minVal) / range;
      return size.height * (0.85 - (norm * 0.70));
    }

    final path = Path();
    final fillPath = Path();

    const stepCount = 30;
    path.moveTo(0, getY(0));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(0));

    for (int i = 1; i <= stepCount; i++) {
      final t = i / stepCount;
      final x = t * size.width;
      final y = getY(t);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [curveColor.withValues(alpha: 0.20), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    final scrubberX = progress * size.width;
    final scrubberY = getY(progress);

    final scrubberLinePaint = Paint()
      ..color = scrubberColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(scrubberX, 0), Offset(scrubberX, size.height), scrubberLinePaint);

    final glowPaint = Paint()
      ..color = scrubberColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(scrubberX, scrubberY), 10.0, glowPaint);

    final dotPaint = Paint()
      ..color = scrubberColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(scrubberX, scrubberY), 5.0, dotPaint);

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(scrubberX, scrubberY), 5.0, dotBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _InteractiveForecastPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.liquidAssetsCents != liquidAssetsCents ||
        oldDelegate.netDailyCents != netDailyCents;
  }
}
