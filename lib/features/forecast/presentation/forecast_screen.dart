import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  // Scrubber progress from 0.0 (Today) to 1.0 (Day 180)
  double _scrubberProgress = 0.5; // defaults to Day 90
  static const int _maxTimelineDays = 180;

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

        // Scrubbed Calculation
        final scrubbedDay = (_scrubberProgress * _maxTimelineDays).round();
        final scrubbedDate = DateTime.now().add(Duration(days: scrubbedDay));
        final scrubbedBalanceCents = liquidAssetsCents + (netDailyCents * scrubbedDay);

        // Milestone Balances
        final proj30dCents = liquidAssetsCents + (netDailyCents * 30);
        final proj60dCents = liquidAssetsCents + (netDailyCents * 60);
        final proj90dCents = liquidAssetsCents + (netDailyCents * 90);
        final proj180dCents = liquidAssetsCents + (netDailyCents * 180);

        return FrostedScaffold(
          appBar: AppBar(
            title: Text(
              'CASHFLOW FORECASTING',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          body: ListView(
            padding: EdgeInsets.all(tokens.space4),
            children: [
              // 1. Runway Summary Deck
              StaggeredEntrance(
                index: 0,
                child: Container(
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
                      Row(
                        children: [
                          Icon(Icons.timeline_rounded, size: 16, color: tokens.statusIncome),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'PROJECTED RUNWAY',
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
                              color: tokens.statusIncome.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(tokens.radiusPill),
                              border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              'Local Regression',
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
                                  'Daily Burn Rate',
                                  style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '-${CurrencyUtils.format(dailyBurnCents, currency: currency)} / day',
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
                                  'Net Daily Flow',
                                  style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${netDailyCents >= 0 ? '+' : ''}${CurrencyUtils.format(netDailyCents, currency: currency)} / day',
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
              SizedBox(height: tokens.space5),

              // 2. Interactive Scrubber Chart Card
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
                              'INTERACTIVE RUNWAY SCRUBBER',
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

                      // Live Inspection Readout
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space3),
                        decoration: BoxDecoration(
                          color: tokens.bgSurfaceElevated,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          border: Border.all(color: tokens.borderHairline),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PROJECTION: +$scrubbedDay DAYS',
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

                      // Interactive Canvas
                      GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          // Clamp normalized position 0.0 to 1.0
                          final localX = details.localPosition.dx;
                          final width = box.size.width - (tokens.space5 * 2) - (tokens.space4 * 2);
                          if (width > 0) {
                            setState(() {
                              _scrubberProgress = (localX / width).clamp(0.0, 1.0);
                            });
                          }
                        },
                        onTapDown: (details) {
                          HapticFeedback.selectionClick();
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final localX = details.localPosition.dx;
                          final width = box.size.width - (tokens.space5 * 2) - (tokens.space4 * 2);
                          if (width > 0) {
                            setState(() {
                              _scrubberProgress = (localX / width).clamp(0.0, 1.0);
                            });
                          }
                        },
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _InteractiveForecastPainter(
                              progress: _scrubberProgress,
                              liquidAssetsCents: liquidAssetsCents,
                              netDailyCents: netDailyCents,
                              maxDays: _maxTimelineDays,
                              curveColor: tokens.statusIncome,
                              scrubberColor: tokens.accentGold,
                              gridColor: tokens.borderSubtle,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.space2),

                      // Day Labels Along Axis
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Today', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('+30d', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('+60d', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('+90d', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('+180d', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space5),

              // 3. Milestone Runway Cards
              StaggeredEntrance(
                index: 2,
                child: Text(
                  'MILESTONE RUNWAY TARGETS',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              SizedBox(height: tokens.space3),

              StaggeredEntrance(
                index: 3,
                child: _buildProjectionCard(
                  days: '30 Days',
                  date: 'Next Month',
                  projectedCents: proj30dCents,
                  currency: currency,
                  tokens: tokens,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _scrubberProgress = 30 / _maxTimelineDays);
                  },
                ),
              ),
              SizedBox(height: tokens.space2),
              StaggeredEntrance(
                index: 4,
                child: _buildProjectionCard(
                  days: '60 Days',
                  date: '2 Months Out',
                  projectedCents: proj60dCents,
                  currency: currency,
                  tokens: tokens,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _scrubberProgress = 60 / _maxTimelineDays);
                  },
                ),
              ),
              SizedBox(height: tokens.space2),
              StaggeredEntrance(
                index: 5,
                child: _buildProjectionCard(
                  days: '90 Days',
                  date: 'Quarter End',
                  projectedCents: proj90dCents,
                  currency: currency,
                  tokens: tokens,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _scrubberProgress = 90 / _maxTimelineDays);
                  },
                ),
              ),
              SizedBox(height: tokens.space2),
              StaggeredEntrance(
                index: 6,
                child: _buildProjectionCard(
                  days: '180 Days',
                  date: '6 Months Out',
                  projectedCents: proj180dCents,
                  currency: currency,
                  tokens: tokens,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _scrubberProgress = 1.0);
                  },
                ),
              ),
              SizedBox(height: tokens.space5),

              // Local Offline Guarantee Note
              StaggeredEntrance(
                index: 7,
                child: Container(
                  padding: EdgeInsets.all(tokens.space4),
                  decoration: BoxDecoration(
                    color: tokens.bgSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 20, color: tokens.statusIncome),
                      SizedBox(width: tokens.space3),
                      Expanded(
                        child: Text(
                          'Forecast runs entirely on local device hardware via linear double-entry regression with zero network leakage.',
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
              ),
              SizedBox(height: tokens.space10),
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
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.statusIncome.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.3)),
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
                      CurrencyUtils.format(projectedCents, currency: currency),
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

    // Draw horizontal reference grid lines
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);

    // Calculate curve points
    // Max and min projected amounts for normalized scaling
    final startVal = liquidAssetsCents.toDouble();
    final endVal = startVal + (netDailyCents * maxDays);
    final minVal = min(startVal, endVal);
    final maxVal = max(startVal, endVal);
    final range = (maxVal - minVal).abs() > 0 ? (maxVal - minVal).abs() : 1.0;

    double getY(double t) {
      final val = startVal + (netDailyCents * (t * maxDays));
      final norm = (val - minVal) / range;
      // Map norm (0 to 1) to canvas height (0.85 to 0.15)
      return size.height * (0.85 - (norm * 0.70));
    }

    final path = Path();
    final fillPath = Path();

    final stepCount = 30;
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

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [curveColor.withValues(alpha: 0.20), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke curve
    final strokePaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Scrubber Line & Dot
    final scrubberX = progress * size.width;
    final scrubberY = getY(progress);

    final scrubberLinePaint = Paint()
      ..color = scrubberColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(scrubberX, 0), Offset(scrubberX, size.height), scrubberLinePaint);

    // Outer glow circle
    final glowPaint = Paint()
      ..color = scrubberColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(scrubberX, scrubberY), 10.0, glowPaint);

    // Inner bright dot
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
