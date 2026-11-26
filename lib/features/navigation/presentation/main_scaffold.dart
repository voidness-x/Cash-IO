import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../envelopes/presentation/envelopes_screen.dart';
import '../../forecast/presentation/forecast_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/cashio_logo.dart';

/// Main application shell featuring a detached floating bottom dock with the
/// Cash-IO spinning 'O' medallion raised in the center as a pop-up Dashboard hub.
class MainScaffold extends StatefulWidget {
  final VoidCallback? onSwitchProfile;

  const MainScaffold({super.key, this.onSwitchProfile});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  /// Index 2 is the center raised Dashboard ('O' logo button).
  int _currentIndex = 2;

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const AccountsScreen();
      case 1:
        return const EnvelopesScreen();
      case 2:
        return DashboardScreen(onSwitchProfile: widget.onSwitchProfile);
      case 3:
        return const ForecastScreen();
      case 4:
        return SettingsScreen(onSwitchProfile: widget.onSwitchProfile);
      default:
        return DashboardScreen(onSwitchProfile: widget.onSwitchProfile);
    }
  }

  void _selectTab(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final isDashboard = _currentIndex == 2;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: disableAnim ? Duration.zero : const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final childKey = child.key;
                final isCenterPopUp = childKey is ValueKey<int> && childKey.value == 2;
                if (isCenterPopUp && !disableAnim) {
                  // Distinct pop-up emergence from the raised center 'O' hub
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.055),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  final scale = Tween<double>(begin: 0.965, end: 1.0)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slide,
                      child: ScaleTransition(scale: scale, child: child),
                    ),
                  );
                }
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: _buildScreen(_currentIndex),
              ),
            ),
          ),

          // Detached Floating Pill Navigation Dock + Raised Center Cash-IO 'O' Medallion
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 80,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Frosted Floating Bar
                    ClipRRect(
                      key: const ValueKey('floating_nav_bar'),
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          height: 62,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: tokens.bgSurfaceGlass,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDashboard
                                  ? tokens.accentGold.withValues(alpha: 0.42)
                                  : tokens.borderHairline,
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.38),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                              if (isDashboard)
                                BoxShadow(
                                  color: tokens.accentGold.withValues(alpha: 0.16),
                                  blurRadius: 18,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _buildDockTab(
                                tokens: tokens,
                                key: const ValueKey('nav_tab_wallets'),
                                index: 0,
                                icon: Icons.account_balance_wallet_outlined,
                                activeIcon: Icons.account_balance_wallet_rounded,
                                label: 'Wallets',
                              ),
                              _buildDockTab(
                                tokens: tokens,
                                key: const ValueKey('nav_tab_budgets'),
                                index: 1,
                                icon: Icons.pie_chart_outline_rounded,
                                activeIcon: Icons.pie_chart_rounded,
                                label: 'Budgets',
                              ),
                              // Spacer cradle directly beneath the raised center 'O' button
                              const SizedBox(width: 72),
                              _buildDockTab(
                                tokens: tokens,
                                key: const ValueKey('nav_tab_forecast'),
                                index: 3,
                                icon: Icons.trending_up_outlined,
                                activeIcon: Icons.trending_up_rounded,
                                label: 'Forecast',
                              ),
                              _buildDockTab(
                                tokens: tokens,
                                key: const ValueKey('nav_tab_settings'),
                                index: 4,
                                icon: Icons.tune_outlined,
                                activeIcon: Icons.tune_rounded,
                                label: 'Settings',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Raised Center Pop-Up Dashboard Button with exact Cash-IO 'O' logo
                    Positioned(
                      top: 0,
                      child: Semantics(
                        label: 'Dashboard Home',
                        button: true,
                        selected: isDashboard,
                        child: GestureDetector(
                          key: const ValueKey('center_dashboard_o_button'),
                          onTap: () => _selectTab(2),
                          child: AnimatedScale(
                            scale: isDashboard ? 1.07 : 0.98,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDashboard
                                      ? [
                                          Color.alphaBlend(
                                            tokens.accentGold.withValues(alpha: 0.28),
                                            tokens.bgSurfaceElevated,
                                          ),
                                          tokens.bgPrimary,
                                        ]
                                      : [
                                          tokens.bgSurfaceElevated,
                                          tokens.bgSurface,
                                        ],
                                ),
                                border: Border.all(
                                  color: isDashboard
                                      ? tokens.accentChampagne
                                      : tokens.accentGold.withValues(alpha: 0.55),
                                  width: isDashboard ? 2.2 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.accentGold.withValues(
                                      alpha: isDashboard ? 0.48 : 0.22,
                                    ),
                                    blurRadius: isDashboard ? 20 : 10,
                                    spreadRadius: isDashboard ? 1 : 0,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: VaultOMark(
                                  size: 30,
                                  animate: isDashboard,
                                  color: tokens.accentGold,
                                  accentColor: tokens.accentChampagne,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockTab({
    required CashIOThemeExtension tokens,
    required Key key,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectTab(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? tokens.accentChampagne : tokens.textTertiary,
                    size: 21,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: GoogleFonts.mukta(
                      color: isSelected ? tokens.textPrimary : tokens.textTertiary,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 2.5,
                  width: isSelected ? 18 : 0,
                  decoration: BoxDecoration(
                    color: tokens.accentGold,
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: tokens.accentGold.withValues(alpha: 0.65),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
