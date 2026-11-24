import 'dart:math';
import 'package:flutter/material.dart';

/// Professional staggered fade + slide entrance animation
/// Reveals items one by one with customizable delay, smooth easing curve,
/// and slight vertical rise for a cinematic, refined feel.
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delayStep;
  final Duration duration;
  final double slideOffset;
  final Curve curve;
  final int maxDelayIndex;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.delayStep = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 420),
    this.slideOffset = 16.0,
    this.curve = Curves.easeOutCubic,
    this.maxDelayIndex = 10,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<double>(begin: widget.slideOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    final cappedIndex = min(widget.index, widget.maxDelayIndex);
    final totalDelay = widget.delayStep * cappedIndex;
    Future.delayed(totalDelay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
