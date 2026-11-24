import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../envelopes/presentation/envelopes_screen.dart';
import '../../forecast/presentation/forecast_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../core/theme/tokens.dart';

class MainScaffold extends StatefulWidget {
  final VoidCallback? onSwitchProfile;

  const MainScaffold({super.key, this.onSwitchProfile});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(onSwitchProfile: widget.onSwitchProfile);
      case 1:
        return const AccountsScreen();
      case 2:
        return const EnvelopesScreen();
      case 3:
        return const ForecastScreen();
      case 4:
        return SettingsScreen(onSwitchProfile: widget.onSwitchProfile);
      default:
        return DashboardScreen(onSwitchProfile: widget.onSwitchProfile);
    }
  }

  static const _navItems = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
    (Icons.account_balance_outlined, Icons.account_balance_rounded, 'Accounts'),
    (Icons.folder_outlined, Icons.folder_rounded, 'Envelopes'),
    (Icons.trending_up_outlined, Icons.trending_up_rounded, 'Forecast'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _buildScreen(_currentIndex),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusMd)),
          border: Border(
            top: BorderSide(
              color: tokens.borderHairline,
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = _currentIndex == index;

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (_currentIndex != index) {
                          HapticFeedback.selectionClick();
                          setState(() => _currentIndex = index);
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Sliding Top Accent Indicator Bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            height: 2.5,
                            width: isSelected ? 28 : 0,
                            decoration: BoxDecoration(
                              color: tokens.accentGold,
                              borderRadius: BorderRadius.circular(tokens.radiusPill),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: tokens.accentGold.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const Spacer(),
                          AnimatedScale(
                            scale: isSelected ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              isSelected ? item.$2 : item.$1,
                              color: isSelected ? tokens.accentChampagne : tokens.textTertiary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$3,
                            style: GoogleFonts.mukta(
                              color: isSelected ? tokens.textPrimary : tokens.textTertiary,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
