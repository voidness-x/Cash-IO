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
    final overlayColor = isDark ? CashIOTokens.darkBg : CashIOTokens.lightBg;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.appBar,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Base Texture Layer: Sourced from user's deep emerald oil-slate image
          Image.asset(
            'assets/images/theme_background.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF041211), // Deep Spruce Noir
                            const Color(0xFF081F1D), // Dark Forest
                            const Color(0xFF0B2623), // Deep Slate Emerald
                          ]
                        : [
                            const Color(0xFFF2F7F5),
                            const Color(0xFFE5EFEB),
                            const Color(0xFFD4E5DF),
                          ],
                  ),
                ),
              );
            },
          ),

          // 2. Three Dynamic Blurry Glowing Orbs moving very slowly
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final t = _glowController.value * 2 * pi;

              return CustomPaint(
                painter: _TripleGlowPainter(t: t, isDark: isDark),
                size: Size.infinite,
              );
            },
          ),

          // 3. Blur / BackdropFilter Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
              child: Container(
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

  _TripleGlowPainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Orb 1: Warm Champagne Gold Glow (Slow Lissajous path)
    final orb1X = width * (0.35 + 0.25 * sin(t));
    final orb1Y = height * (0.30 + 0.20 * cos(t * 0.8));
    final orb1Radius = width * 0.55;
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFFD4AF37) : const Color(0xFFE5C778))
              .withValues(alpha: isDark ? 0.22 : 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(orb1X, orb1Y), radius: orb1Radius));
    canvas.drawCircle(Offset(orb1X, orb1Y), orb1Radius, orb1Paint);

    // Orb 2: Deep Forest Emerald Glow (Opposing sinusoidal path)
    final orb2X = width * (0.65 + 0.25 * cos(t * 1.1));
    final orb2Y = height * (0.70 + 0.22 * sin(t * 0.7));
    final orb2Radius = width * 0.65;
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFF14534A) : const Color(0xFF2DD4BF))
              .withValues(alpha: isDark ? 0.26 : 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(orb2X, orb2Y), radius: orb2Radius));
    canvas.drawCircle(Offset(orb2X, orb2Y), orb2Radius, orb2Paint);

    // Orb 3: Luminous Sea-Glass / Sage Glow (Floating vertical cycle)
    final orb3X = width * (0.50 + 0.30 * sin(t * 0.6 + 1.2));
    final orb3Y = height * (0.45 + 0.28 * sin(t * 0.9 + 2.0));
    final orb3Radius = width * 0.50;
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFF0F3D36) : const Color(0xFF6EE7B7))
              .withValues(alpha: isDark ? 0.20 : 0.14),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(orb3X, orb3Y), radius: orb3Radius));
    canvas.drawCircle(Offset(orb3X, orb3Y), orb3Radius, orb3Paint);
  }

  @override
  bool shouldRepaint(covariant _TripleGlowPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.isDark != isDark;
}
