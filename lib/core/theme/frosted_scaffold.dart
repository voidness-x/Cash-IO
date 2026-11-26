import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'tokens.dart';

/// A bank-grade frosted glass container that renders a textured background
/// with three slowly moving dynamic glowing orbs and heavy gaussian blur.
class FrostedScaffold extends StatefulWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final double blurSigma;
  final double overlayOpacity;

  const FrostedScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.blurSigma = 16.0,
    this.overlayOpacity = 0.84,
  });

  @override
  State<FrostedScaffold> createState() => _FrostedScaffoldState();
}

class _FrostedScaffoldState extends State<FrostedScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    // Ultra-slow, smooth organic loop (24 seconds)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.tokens;
    final overlayColor = tokens.bgPrimary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.appBar,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Base Canvas Layer aligned to active theme tone
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.bgPrimary,
                  Color.alphaBlend(tokens.accentGold.withValues(alpha: isDark ? 0.08 : 0.05), tokens.bgPrimary),
                  tokens.bgPrimary,
                ],
              ),
            ),
          ),

          // 2. Three Dynamic Blurry Glowing Orbs tinted by active accent
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final t = _glowController.value * 2 * pi;

              return CustomPaint(
                painter: _TripleGlowPainter(
                  t: t,
                  isDark: isDark,
                  primaryAccent: tokens.accentGold,
                  secondaryAccent: tokens.accentChampagne,
                ),
                size: Size.infinite,
              );
            },
          ),

          // 3. Blur / BackdropFilter Layer bound live to tokens.bgPrimary
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
              child: Container(
                key: const ValueKey('frosted_scaffold_overlay'),
                color: overlayColor.withValues(alpha: widget.overlayOpacity),
              ),
            ),
          ),

          // 4. Foreground Content
          SafeArea(child: widget.body),
        ],
      ),
    );
  }
}

class _TripleGlowPainter extends CustomPainter {
  final double t;
  final bool isDark;
  final Color primaryAccent;
  final Color secondaryAccent;

  _TripleGlowPainter({
    required this.t,
    required this.isDark,
    required this.primaryAccent,
    required this.secondaryAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Orb 1: Primary Theme Accent Glow
    final orb1X = width * (0.35 + 0.25 * sin(t));
    final orb1Y = height * (0.30 + 0.20 * cos(t * 0.8));
    final orb1Radius = width * 0.55;
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryAccent.withValues(alpha: isDark ? 0.22 : 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(orb1X, orb1Y), radius: orb1Radius));
    canvas.drawCircle(Offset(orb1X, orb1Y), orb1Radius, orb1Paint);

    // Orb 2: Secondary Luminous Glow
    final orb2X = width * (0.65 + 0.25 * cos(t * 1.1));
    final orb2Y = height * (0.70 + 0.22 * sin(t * 0.7));
    final orb2Radius = width * 0.65;
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          secondaryAccent.withValues(alpha: isDark ? 0.18 : 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(orb2X, orb2Y), radius: orb2Radius));
    canvas.drawCircle(Offset(orb2X, orb2Y), orb2Radius, orb2Paint);

    // Orb 3: Soft Ambient Depth Glow
    final orb3X = width * (0.50 + 0.30 * sin(t * 0.6 + 1.2));
    final orb3Y = height * (0.45 + 0.28 * sin(t * 0.9 + 2.0));
    final orb3Radius = width * 0.50;
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryAccent.withValues(alpha: isDark ? 0.14 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(orb3X, orb3Y), radius: orb3Radius));
    canvas.drawCircle(Offset(orb3X, orb3Y), orb3Radius, orb3Paint);
  }

  @override
  bool shouldRepaint(covariant _TripleGlowPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.isDark != isDark ||
      oldDelegate.primaryAccent != primaryAccent ||
      oldDelegate.secondaryAccent != secondaryAccent;
}
