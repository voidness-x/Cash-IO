import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

/// OS-level Privacy Shield Widget.
/// Protects the application from OS task-switcher / recents snapshot scraping.
/// Uses pure zero-network typography and dynamically matches the user's active
/// theme preset/custom colors and Dark/Light appearance mode on the very first frame.
class AppPrivacyShield extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const AppPrivacyShield({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<AppPrivacyShield> createState() => AppPrivacyShieldState();
}

class AppPrivacyShieldState extends State<AppPrivacyShield> with WidgetsBindingObserver {
  bool _isShieldVisible = false;

  bool get isShieldVisible => _isShieldVisible;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didUpdateWidget(covariant AppPrivacyShield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        WidgetsBinding.instance.addObserver(this);
      } else {
        WidgetsBinding.instance.removeObserver(this);
        _isShieldVisible = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;

    // Inactive (app switcher preview), Paused (backgrounded), Hidden
    final shouldShield = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;

    if (shouldShield != _isShieldVisible) {
      setState(() {
        _isShieldVisible = shouldShield;
      });
    }
  }

  /// Manually activate shield (for security tests or deep privacy modes)
  void setShieldVisible(bool visible) {
    if (_isShieldVisible != visible) {
      setState(() {
        _isShieldVisible = visible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_isShieldVisible)
          Positioned.fill(
            child: ListenableBuilder(
              listenable: ThemeController.instance,
              builder: (context, _) {
                final ctrl = ThemeController.instance;
                final platformBrightness = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.dark;
                final isDark = ctrl.themeMode == ThemeMode.dark ||
                    (ctrl.themeMode == ThemeMode.system && platformBrightness == Brightness.dark);
                final tokens = isDark ? ctrl.darkExtension : ctrl.lightExtension;

                final wordmarkStyle = TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  height: 1.0,
                );

                return Material(
                  key: const ValueKey('privacy_shield_surface'),
                  color: tokens.bgPrimary,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.25),
                        radius: 1.05,
                        colors: [
                          tokens.accentGold.withValues(alpha: isDark ? 0.14 : 0.10),
                          tokens.bgPrimary,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: tokens.bgSurface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: tokens.accentGold.withValues(alpha: 0.45),
                                    width: 1.6,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.accentGold.withValues(alpha: 0.24),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.lock_rounded,
                                  key: const ValueKey('privacy_shield_lock_icon'),
                                  size: 36,
                                  color: tokens.accentGold,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text.rich(
                                key: const ValueKey('cashio_logo_wordmark'),
                                TextSpan(
                                  style: wordmarkStyle,
                                  children: [
                                    const TextSpan(text: 'CASH-I'),
                                    TextSpan(
                                      text: 'O',
                                      style: wordmarkStyle.copyWith(color: tokens.accentGold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'AIR-GAPPED PRIVACY SHIELD',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.accentGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Screen snapshot shielded from OS recents caching',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
