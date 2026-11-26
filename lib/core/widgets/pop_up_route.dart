import 'package:flutter/material.dart';

/// Smooth, Cashew-inspired pop-up page transition (gentle scale 0.94 -> 1.0 + fade)
/// replacing default horizontal/vertical sliding transitions across the entire app.
/// Automatically respects platform reduced-motion settings.
class PopUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const PopUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: scale,
        child: child,
      ),
    );
  }
}

/// Reusable smooth pop-up route for pushing dedicated screens without sliding.
class PopUpPageRoute<T> extends PageRouteBuilder<T> {
  PopUpPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
    super.transitionDuration = const Duration(milliseconds: 240),
    super.reverseTransitionDuration = const Duration(milliseconds: 180),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) {
              return child;
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: scale,
                child: child,
              ),
            );
          },
        );
}
