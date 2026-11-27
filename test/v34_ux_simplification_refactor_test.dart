import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/theme/app_theme.dart';
import 'package:cash_io/core/utils/currency_utils.dart';
import 'package:cash_io/core/widgets/animated_money_bar.dart';
import 'package:cash_io/features/accounts/presentation/accounts_screen.dart';
import 'package:cash_io/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cash_io/features/envelopes/presentation/envelopes_screen.dart';
import 'package:cash_io/features/forecast/presentation/forecast_screen.dart';
import 'package:cash_io/features/navigation/presentation/main_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Compact IQD & Secondary Number Formatting', () {
    test('CurrencyUtils.formatCompact reduces repetitive IQD clutter cleanly', () {
      expect(CurrencyUtils.formatCompact(0, currency: 'IQD'), '0');
      expect(CurrencyUtils.formatCompact(500000, currency: 'IQD'), '5K');
      expect(CurrencyUtils.formatCompact(11250000, currency: 'IQD'), '112.5K');
      expect(CurrencyUtils.formatCompact(25000000, currency: 'IQD'), '250K');
      expect(CurrencyUtils.formatCompact(150000000, currency: 'IQD'), '1.5M');
      expect(CurrencyUtils.formatCompact(25000000, currency: 'IQD', showSymbol: true), '250K IQD');
      expect(CurrencyUtils.formatCompact(12550, currency: 'USD', showSymbol: true), '\$125.50');
    });
  });

  group('2. Eliminated Redundant Header Icons, Clear Home/Insights Nav & Clean Hero', () {
    testWidgets('EnvelopesScreen and AccountsScreen have no duplicate AppBar action icons, and Budgets tip is dismissible',
        (tester) async {
      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Clean Header Vault', currency: 'IQD', onlineFx: false);
        await repo.setupInitialFinancialData(
          startingCashCents: 25000000,
          startingBankCents: 10000000,
          createStarterEnvelopes: true,
        );
      });

      // Budgets screen: no duplicate header icons, dismissible tip banner
      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const EnvelopesScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final budgetsAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(budgetsAppBar.actions, anyOf(isNull, isEmpty));
      expect(find.byKey(const ValueKey('budgets_tip_banner')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dismiss_budgets_tip_button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('budgets_tip_banner')), findsNothing);

      // Wallets screen: no duplicate header icons, Savings Goals integrated cleanly
      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const AccountsScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final walletsAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(walletsAppBar.actions, anyOf(isNull, isEmpty));
      expect(find.text('Add Wallet'), findsOneWidget);
      expect(find.text('Move Money'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('SAVINGS GOALS & LOCKED VAULTS'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('SAVINGS GOALS & LOCKED VAULTS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('MainScaffold has labeled Home & Insights tabs in floating dock with zero overflow at 360x640 @ 1.2x',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Nav Clarity Vault', currency: 'IQD', onlineFx: false);
        await repo.setupInitialFinancialData(startingCashCents: 25000000, createStarterEnvelopes: true);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const MediaQuery(
            data: MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.2)),
            child: MainScaffold(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Wallets'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('3. Simplified Home Hierarchy, Zero-State Bar, Wide Budget Cards & Aligned Microcopy', () {
    testWidgets('Home removes nested 3-tab control & 4th unlabeled icon, renders 0% empty ratio track at 0 balance, wide budget cards, and aligned Add/Spend copy',
        (tester) async {
      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Zero State Vault', currency: 'IQD', onlineFx: false);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const DashboardScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // No mid-page Insights/Savings/Breakdown tab bar & no unlabeled repeat icon on hero card
      expect(find.text('Breakdown'), findsNothing);
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);

      // Zero-state Cash & Bank vs Debts bar must render empty (0.0), not ~94% filled
      final emptyBar = tester.widget<AnimatedMoneyBar>(find.byKey(const ValueKey('hero_zero_ratio_bar')));
      expect(emptyBar.value, 0.0);

      // Aligned empty-state copy matching actual "Add" and "Spend" buttons
      await tester.scrollUntilVisible(
        find.textContaining('Tap "Add" or "Spend"'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Tap "Add" or "Spend"'), findsOneWidget);
      expect(find.textContaining('Add Cash'), findsNothing);

      // Populated budgets: horizontal budget card is wide (>= 210px) so full category names fit
      await tester.runAsync(() async {
        await repo.setupInitialFinancialData(startingCashCents: 25000000, createStarterEnvelopes: true);
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cashew_budgets_strip')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      final firstBudgetCard = tester.getSize(find.byKey(const ValueKey('home_budget_card_0')));
      expect(firstBudgetCard.width, greaterThanOrEqualTo(210.0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('4. Insights & Forecast: Synced Linear Scrubber, Reduced Borders & Hosted Analytics', () {
    testWidgets('ForecastScreen uses linear synced axis ticks (+45d/+90d/+135d/+180d), borderless inner readout, and hosts Money Health & Breakdown',
        (tester) async {
      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Insights Vault', currency: 'IQD', onlineFx: false);
        await repo.setupInitialFinancialData(startingCashCents: 25000000, createStarterEnvelopes: true);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const ForecastScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Default 50% scrubber matches linear +90d center tick and +90 DAYS header
      expect(find.text('PROJECTION: +90 DAYS'), findsOneWidget);
      expect(find.text('+45d'), findsOneWidget);
      expect(find.text('+90d'), findsOneWidget);
      expect(find.text('+135d'), findsOneWidget);

      // Inner PROJECTION box has no redundant 1px border (elevation separates hierarchy)
      final projBox = tester.widget<Container>(find.byKey(const ValueKey('forecast_projection_box')));
      expect((projBox.decoration as BoxDecoration).border, isNull);

      // Tapping 30 Days milestone updates single source of truth to +30 DAYS
      await tester.scrollUntilVisible(
        find.text('30 Days'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('30 Days'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.scrollUntilVisible(
        find.text('PROJECTION: +30 DAYS'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PROJECTION: +30 DAYS'), findsOneWidget);

      // Insights tab now hosts Money Health & Spending Breakdown with aligned "Spend" microcopy
      await tester.scrollUntilVisible(
        find.text('SPENDING BY CATEGORY'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('SPENDING BY CATEGORY'), findsOneWidget);
      expect(find.textContaining('Spend Cash'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
