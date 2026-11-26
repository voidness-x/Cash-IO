import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';

/// Clean typographic Cash-IO wordmark with a normal matching 'O' tinted in the
/// active theme accent so every letter shares the exact same baseline and weight.
class CashIOLogo extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final primaryTextColor = textColor ?? tokens.textPrimary;
    final primaryAccent = accentColor ?? tokens.accentGold;
    final baseStyle = GoogleFonts.spaceGrotesk(
      color: primaryTextColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
      height: 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          key: const ValueKey('cashio_logo_wordmark'),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(text: 'CASH-I'),
              TextSpan(
                text: 'O',
                style: baseStyle.copyWith(color: primaryAccent),
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 6),
          Text(
            'AIR-GAPPED ZERO-KNOWLEDGE LEDGER',
            style: GoogleFonts.mukta(
              color: tokens.textSecondary,
              fontSize: fontSize * 0.36,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Standalone spinning Cash-IO vault 'O' emblem reused in the raised center
/// Dashboard button of the floating navigation bar.
class VaultOMark extends StatefulWidget {
  final double size;
  final bool animate;
  final Color? color;
  final Color? accentColor;

  const VaultOMark({
    super.key,
    this.size = 28.0,
    this.animate = true,
    this.color,
    this.accentColor,
  });

  @override
  State<VaultOMark> createState() => _VaultOMarkState();
}

class _VaultOMarkState extends State<VaultOMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    if (disableAnim || !widget.animate) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VaultOMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    if (widget.animate && !disableAnim && !_controller.isAnimating) {
      _controller.repeat();
    } else if ((!widget.animate || disableAnim) && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _CenteredVaultO(
      animation: _controller,
      color: widget.color ?? tokens.accentGold,
      accentColor: widget.accentColor ?? tokens.accentChampagne,
      size: widget.size,
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
