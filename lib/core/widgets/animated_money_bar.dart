import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Money progress bar that smoothly fills from left to right on screen load.
/// Respects system reduced-motion settings ([MediaQuery.disableAnimationsOf]).
class AnimatedMoneyBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? fillColor;
  final Color? trackColor;
  final Duration duration;
  final bool glow;
  final BorderRadius? borderRadius;

  const AnimatedMoneyBar({
    super.key,
    required this.value,
    this.height = 7.0,
    this.fillColor,
    this.trackColor,
    this.duration = const Duration(milliseconds: 700),
    this.glow = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final target = value.clamp(0.0, 1.0);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final resolvedFill = fillColor ?? tokens.accentGold;
    final resolvedTrack = trackColor ?? tokens.bgSurfaceElevated;
    final radius = borderRadius ?? BorderRadius.circular(tokens.radiusPill);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        width: double.infinity,
        color: resolvedTrack,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: disableAnimations ? target : 0.0, end: target),
          duration: disableAnimations ? Duration.zero : duration,
          curve: Curves.easeOutCubic,
          builder: (context, animatedFraction, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: animatedFraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: resolvedFill,
                  borderRadius: radius,
                  boxShadow: glow
                      ? [
                          BoxShadow(
                            color: resolvedFill.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Segment descriptor for [AnimatedSegmentedMoneyBar].
class MoneyBarSegment {
  final double weight;
  final Color color;

  const MoneyBarSegment({required this.weight, required this.color});
}

/// Multi-segment money bar (e.g. Inflow/Outflow or 50/30/20 Needs/Wants/Savings)
/// that reveals left-to-right smoothly on screen load.
class AnimatedSegmentedMoneyBar extends StatelessWidget {
  final List<MoneyBarSegment> segments;
  final double height;
  final Color? trackColor;
  final Duration duration;

  const AnimatedSegmentedMoneyBar({
    super.key,
    required this.segments,
    this.height = 7.0,
    this.trackColor,
    this.duration = const Duration(milliseconds: 750),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final activeSegments = segments.where((s) => s.weight > 0).toList();
    final radius = BorderRadius.circular(tokens.radiusPill);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        width: double.infinity,
        color: trackColor ?? tokens.bgSurfaceElevated,
        child: activeSegments.isEmpty
            ? const SizedBox.shrink()
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: disableAnimations ? 1.0 : 0.0, end: 1.0),
                duration: disableAnimations ? Duration.zero : duration,
                curve: Curves.easeOutCubic,
                builder: (context, reveal, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: reveal.clamp(0.0, 1.0),
                    child: Row(
                      children: activeSegments.map((seg) {
                        final flex = (seg.weight * 1000).round().clamp(1, 100000);
                        return Expanded(
                          flex: flex,
                          child: Container(color: seg.color),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
