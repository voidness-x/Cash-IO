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

/// Main application shell featuring a clean, symmetrically labeled 5-tab
/// frosted floating navigation dock (`Wallets`, `Budgets`, `Home`, `Insights`, `Settings`)
/// with smooth pop-up screen transitions (zero sliding).
class MainScaffold extends StatefulWidget {
  final VoidCallback? onSwitchProfile;

  const MainScaffold({super.key, this.onSwitchProfile});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  /// Index 2 is the center Home tab.
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
    final isHome = _currentIndex == 2;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: disableAnim ? Duration.zero : const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                if (disableAnim) return child;
                final scale = Tween<double>(begin: 0.955, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                );
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: scale, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: _buildScreen(_currentIndex),
              ),
            ),
          ),

          // Detached Frosted Floating Pill Navigation Dock (Clear 5-Tab Standard Metaphor)
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: ClipRRect(
                key: const ValueKey('floating_nav_bar'),
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: tokens.bgSurfaceGlass,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: isHome
                            ? tokens.accentGold.withValues(alpha: 0.38)
                            : tokens.borderHairline,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.34),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        if (isHome)
                          BoxShadow(
                            color: tokens.accentGold.withValues(alpha: 0.14),
                            blurRadius: 16,
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
                        _buildDockTab(
                          tokens: tokens,
                          key: const ValueKey('center_dashboard_o_button'),
                          index: 2,
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: 'Home',
                          isPrimaryCenter: true,
                        ),
                        _buildDockTab(
                          tokens: tokens,
                          key: const ValueKey('nav_tab_forecast'),
                          index: 3,
                          icon: Icons.insights_outlined,
                          activeIcon: Icons.insights_rounded,
                          label: 'Insights',
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
    bool isPrimaryCenter = false,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(20),
            onTap: () => _selectTab(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? tokens.accentGold.withValues(alpha: isPrimaryCenter ? 0.18 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected ? tokens.accentChampagne : tokens.textTertiary,
                      size: isPrimaryCenter ? 22 : 20,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
