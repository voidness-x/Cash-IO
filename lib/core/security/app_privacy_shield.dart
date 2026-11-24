import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// OS-level Privacy Shield Widget.
/// Protects the application from OS task-switcher / recents snapshot scraping.
/// When the user enters the multitasking view, switches apps, or locks the device,
/// an opaque frosted shield is immediately rendered over the entire screen.
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
            child: Material(
              color: CashIOTokens.darkBg,
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(CashIOTokens.space4),
                        decoration: BoxDecoration(
                          color: CashIOTokens.darkSurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CashIOTokens.brand.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CashIOTokens.brand.withValues(alpha: 0.20),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 36,
                          color: CashIOTokens.brand,
                        ),
                      ),
                      const SizedBox(height: CashIOTokens.space5),
                      Text(
                        'CASH-IO',
                        style: TextStyle(
                          color: CashIOTokens.darkTextHigh,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: CashIOTokens.space2),
                      Text(
                        'AIR-GAPPED PRIVACY SHIELD',
                        style: TextStyle(
                          color: CashIOTokens.brand,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Screen snapshot shielded from OS recents caching',
                        style: TextStyle(
                          color: CashIOTokens.darkTextMedium,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
