import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';

/// Interactive Category Spending Donut Chart Card with touch inspection
class CategorySpendingDonutCard extends StatefulWidget {
  final String currency;

  const CategorySpendingDonutCard({super.key, required this.currency});

  @override
  State<CategorySpendingDonutCard> createState() => _CategorySpendingDonutCardState();
}

class _CategorySpendingDonutCardState extends State<CategorySpendingDonutCard> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _sweepAnimation;
  int? _hoveredIndex;

  // Custom palette colors strictly following user requirements
  static const List<Color> _palette = [
    Color(0xFF00ABB3), // Primary Teal
    Color(0xFFEF4444), // Expense Red
    Color(0xFF3C4048), // Slate
    Color(0xFFB2B2B2), // Silver
    Color(0xFF14B8A6), // Mint
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFF64748B), // Slate Blue
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweepAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final repo = VaultRepository.instance;
    final spendingMap = repo.getCategorySpendingCents(days: 30);
    final totalSpentCents = spendingMap.values.fold<int>(0, (sum, v) => sum + v);

    final entries = spendingMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 16, color: tokens.accentGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SPENDING BY CATEGORY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.bgSurfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
                child: Text(
                  '30 Days',
                  style: GoogleFonts.mukta(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space4),

          if (entries.isEmpty || totalSpentCents <= 0) ...[
            Container(
              padding: EdgeInsets.all(tokens.space6),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.insights_rounded, size: 36, color: tokens.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    'No expenses recorded in the last 30 days',
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Spend" to log purchases and view your spending breakdown.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Donut Chart + Center Label
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: AnimatedBuilder(
                  animation: _sweepAnimation,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: _DonutChartPainter(
                            entries: entries,
                            totalCents: totalSpentCents,
                            sweepProgress: _sweepAnimation.value,
                            hoveredIndex: _hoveredIndex,
                            colors: _palette,
                          ),
                        ),
                        // Center Readout
                        Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _hoveredIndex != null && _hoveredIndex! < entries.length
                                    ? entries[_hoveredIndex!].key.toUpperCase()
                                    : 'TOTAL OUTFLOW',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  color: tokens.textTertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _hoveredIndex != null && _hoveredIndex! < entries.length
                                      ? CurrencyUtils.format(entries[_hoveredIndex!].value, currency: widget.currency)
                                      : CurrencyUtils.format(totalSpentCents, currency: widget.currency),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: tokens.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (_hoveredIndex != null && _hoveredIndex! < entries.length)
                                Text(
                                  '${((entries[_hoveredIndex!].value / totalSpentCents) * 100).toStringAsFixed(1)}%',
                                  style: GoogleFonts.mukta(
                                    color: tokens.statusExpense,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: tokens.space4),

            // Category Legend with Tap-to-Highlight
            Divider(color: tokens.borderSubtle, height: 1),
            SizedBox(height: tokens.space3),
            Wrap(
              spacing: tokens.space2,
              runSpacing: tokens.space2,
              children: entries.asMap().entries.map((item) {
                final idx = item.key;
                final cat = item.value;
                final color = _palette[idx % _palette.length];
                final isSelected = _hoveredIndex == idx;
                final pct = (cat.value / totalSpentCents) * 100;

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _hoveredIndex = isSelected ? null : idx;
                    });
                  },
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.18) : tokens.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: isSelected ? color : tokens.borderHairline,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            cat.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.mukta(
                              color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: GoogleFonts.jetBrainsMono(
                            color: tokens.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final int totalCents;
  final double sweepProgress;
  final int? hoveredIndex;
  final List<Color> colors;

  _DonutChartPainter({
    required this.entries,
    required this.totalCents,
    required this.sweepProgress,
    required this.hoveredIndex,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty || totalCents <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const baseStrokeWidth = 24.0;
    final totalSweep = 2 * pi * sweepProgress;

    double currentAngle = -pi / 2;

    for (int i = 0; i < entries.length; i++) {
      final value = entries[i].value;
      final sweepAngle = (value / totalCents) * totalSweep;
      final isHovered = hoveredIndex == i;
      final color = colors[i % colors.length];

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? baseStrokeWidth + 6 : baseStrokeWidth
        ..strokeCap = StrokeCap.butt;

      // Draw arc with tiny gap if multiple entries
      final gap = entries.length > 1 ? 0.04 : 0.0;
      final actualSweep = max(0.0, sweepAngle - gap);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle + (gap / 2),
        actualSweep,
        false,
        paint,
      );

      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.totalCents != totalCents;
  }
}
