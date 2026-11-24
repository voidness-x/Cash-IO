import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';

/// Clean, high-end typographic Cash-IO Logo with a mathematically centered spinning vault 'O'.
/// Zero wobbles, zero font-metric offsets, perfectly balanced.
class CashIOLogo extends StatefulWidget {
  final double fontSize;
  final bool animateO;
  final Color? textColor;
  final Color? accentColor;
  final bool showSubtitle;

  const CashIOLogo({
    super.key,
    this.fontSize = 32.0,
    this.animateO = true,
    this.textColor,
    this.accentColor,
    this.showSubtitle = false,
  });

  @override
  State<CashIOLogo> createState() => _CashIOLogoState();
}

class _CashIOLogoState extends State<CashIOLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    if (widget.animateO) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CashIOLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateO && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!widget.animateO && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final primaryTextColor = widget.textColor ?? tokens.textPrimary;
    final primaryAccent = widget.accentColor ?? tokens.accentGold;
    final oSize = widget.fontSize * 0.76;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'CASH-I',
              style: GoogleFonts.spaceGrotesk(
                color: primaryTextColor,
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2.0),
            _CenteredVaultO(
              animation: _rotationController,
              color: primaryAccent,
              accentColor: tokens.accentChampagne,
              size: oSize,
            ),
          ],
        ),
        if (widget.showSubtitle) ...[
          const SizedBox(height: 6),
          Text(
            'AIR-GAPPED ZERO-KNOWLEDGE LEDGER',
            style: GoogleFonts.mukta(
              color: tokens.textSecondary,
              fontSize: widget.fontSize * 0.36,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// A geometrically centered circular vault ring that rotates around exact (width/2, height/2).
class _CenteredVaultO extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final Color accentColor;
  final double size;

  const _CenteredVaultO({
    required this.animation,
    required this.color,
    required this.accentColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Transform.rotate(
          angle: animation.value * 2 * pi,
          alignment: Alignment.center,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _VaultOPainter(
                color: color,
                accentColor: accentColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VaultOPainter extends CustomPainter {
  final Color color;
  final Color accentColor;

  _VaultOPainter({required this.color, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeW = size.width * 0.16;
    final radius = (size.width - strokeW) / 2;

    final basePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    // 270-degree main ring arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.35,
      4.6,
      false,
      basePaint,
    );

    // 60-degree luminous accent highlight arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      5.2,
      1.1,
      false,
      accentPaint,
    );

    // Center focal pivot dot
    final centerDotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, strokeW * 0.55, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _VaultOPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accentColor != accentColor;
}
