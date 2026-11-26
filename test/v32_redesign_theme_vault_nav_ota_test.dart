import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/theme/original_theme_snapshot.dart';
import 'package:cash_io/core/theme/theme_controller.dart';
import 'package:cash_io/core/theme/theme_extension.dart';
import 'package:cash_io/core/widgets/animated_money_bar.dart';
import 'package:cash_io/core/widgets/cashio_logo.dart';
import 'package:cash_io/features/navigation/presentation/main_scaffold.dart';
import 'package:cash_io/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cash_io/features/dashboard/presentation/cash_action_sheets.dart';
import 'package:cash_io/features/accounts/presentation/accounts_screen.dart';
import 'package:cash_io/features/envelopes/presentation/envelopes_screen.dart';
import 'package:cash_io/features/forecast/presentation/forecast_screen.dart';
import 'package:cash_io/features/settings/presentation/settings_screen.dart';
import 'package:cash_io/features/settings/presentation/theme_customizer_sheet.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/services/in_app_patch_driver.dart';
import 'package:cash_io/core/services/update_receiver_service.dart';
import 'package:cash_io/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 1 TDD: Phantom default vault elimination & budget spend tracking', () {
    test('loadPersistentVault never injects phantom default_profile into getAvailableProfiles', () async {
      final repo = VaultRepository.instance;
      // Simulate cold boot where _profileId starts as placeholder 'default_profile'
      // and main.dart immediately loads the user's real persisted vault.
      await repo.loadPersistentVault('profile_real_user_1');

      final profiles = await repo.getAvailableProfiles();
      final ids = profiles.map((p) => p['id']).toList();

      expect(ids, contains('profile_real_user_1'));
      expect(
        ids,
        isNot(contains('default_profile')),
        reason: 'Uninitialized placeholder default_profile must never leak into Vault Switcher',
      );
    });

    test('spending linked to a Monthly Budget updates spentCents and remainingCents immediately', () async {
      final repo = VaultRepository.instance;
      await repo.initializeProfile(
        name: 'Brother Test Vault',
        currency: 'IQD',
        onlineFx: false,
      );
      await repo.setupInitialFinancialData(
        startingCashCents: 50000000, // 500,000 IQD
        createStarterEnvelopes: true,
      );

      final foodBudget = repo.envelopes.first;
      final beforeAssigned = foodBudget.assignedCents;
      final beforeSpent = foodBudget.spentCents;

      await repo.recordEnvelopeSpend(foodBudget.id, 1500000); // 15,000 IQD

      final updated = repo.envelopes.firstWhere((e) => e.id == foodBudget.id);
      expect(updated.spentCents, beforeSpent + 1500000);
      expect(updated.remainingCents, beforeAssigned - (beforeSpent + 1500000));
    });
  });

  group('Task 2 TDD: ThemeController presets, custom colors & original backup', () {
    test('ThemeExtension.accent dynamically reflects accentGold instead of hardcoded teal', () {
      const customColor = Color(0xFFFF6B35);
      final customExt = CashIOThemeExtension.dark.copyWith(accentGold: customColor);
      expect(customExt.accent, customColor);
    });

    test('ThemeController provides >=7 presets, applies custom colors, and resets to Original Cyber Teal', () async {
      final controller = ThemeController.instance;
      await controller.resetToOriginal();

      expect(controller.activePreset.id, OriginalCashIOThemeSnapshot.presetId);
      expect(controller.activePreset.accentColor, OriginalCashIOThemeSnapshot.brand);
      expect(ThemeController.builtInPresets.length, greaterThanOrEqualTo(7));

      await controller.selectPreset('emerald_vault');
      expect(controller.activePreset.id, 'emerald_vault');
      expect(controller.darkExtension.accent, isNot(OriginalCashIOThemeSnapshot.brand));

      await controller.applyCustomColors(
        accent: const Color(0xFFE11D48),
        surface: const Color(0xFF1F1D2B),
        background: const Color(0xFF14131D),
      );
      expect(controller.activePreset.id, 'custom');
      expect(controller.darkExtension.accent, const Color(0xFFE11D48));
      expect(controller.darkExtension.bgSurface, const Color(0xFF1F1D2B));

      await controller.resetToOriginal();
      expect(controller.activePreset.id, OriginalCashIOThemeSnapshot.presetId);
      expect(controller.darkExtension.accent, OriginalCashIOThemeSnapshot.brand);
    });
  });

  group('Task 3 TDD: AnimatedMoneyBar & Floating Nav Bar with Center O Dashboard', () {
    testWidgets('AnimatedMoneyBar fills left-to-right on load and respects disableAnimations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: AnimatedMoneyBar(value: 0.8),
              ),
            ),
          ),
        ),
      );

      // On first frame, bar starts filling from near 0
      final fracStart = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(fracStart.widthFactor, lessThan(0.2));

      // After animation completes, bar reaches target 0.8
      await tester.pump(const Duration(milliseconds: 900));
      final fracEnd = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(fracEnd.widthFactor, closeTo(0.8, 0.01));

      // With reduced motion enabled, bar jumps immediately to target without animating
      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  child: AnimatedMoneyBar(value: 0.65),
                ),
              ),
            ),
          ),
        ),
      );
      final fracReduced = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(fracReduced.widthFactor, closeTo(0.65, 0.01));
    });

    testWidgets('MainScaffold floats at bottom, opens on center Dashboard with VaultOMark, and switches all 5 tabs cleanly at 360x640 @ 1.2x',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Nav Audit', currency: 'IQD', onlineFx: false);
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
      await tester.pump(const Duration(milliseconds: 500));

      // Center Dashboard button uses the signature VaultOMark from CashIOLogo
      expect(find.byType(VaultOMark), findsAtLeastNWidgets(1));
      expect(find.byKey(const ValueKey('floating_nav_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('center_dashboard_o_button')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Navigate across outer tabs and back to center Dashboard
      await tester.tap(find.byKey(const ValueKey('nav_tab_wallets')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('nav_tab_budgets')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('center_dashboard_o_button')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('nav_tab_forecast')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('nav_tab_settings')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Task 4 TDD: Simplified intuitive UX, Hero Glow, Animated Bars & MoveMoneySheet', () {
    testWidgets('Primary screens show intuitive plain-English headers, AnimatedMoneyBars, and Theme & Colors studio',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Simple UX Vault', currency: 'USD', onlineFx: false);
        await repo.setupInitialFinancialData(
          startingCashCents: 120000,
          startingBankCents: 80000,
          createStarterEnvelopes: true,
        );
      });

      Widget wrap(Widget child) => MaterialApp(
            theme: CashIOTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.2)),
              child: child,
            ),
          );

      // 1. Dashboard: TOTAL MONEY + Move button + AnimatedSegmentedMoneyBar
      await tester.pumpWidget(wrap(const DashboardScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TOTAL MONEY'), findsOneWidget);
      expect(find.byKey(const ValueKey('dashboard_move_button')), findsOneWidget);
      expect(find.byType(AnimatedSegmentedMoneyBar), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);

      // 2. Wallets (Accounts): WALLETS + AnimatedMoneyBar
      await tester.pumpWidget(wrap(const AccountsScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('WALLETS'), findsOneWidget);
      expect(find.byType(AnimatedMoneyBar), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);

      // 3. Monthly Budgets (Envelopes): MONTHLY BUDGETS + SAFE TO BUDGET + AnimatedMoneyBar
      await tester.pumpWidget(wrap(const EnvelopesScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MONTHLY BUDGETS'), findsOneWidget);
      expect(find.text('SAFE TO BUDGET'), findsOneWidget);
      expect(find.byType(AnimatedMoneyBar), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);

      // 4. Money Forecast: MONEY FORECAST
      await tester.pumpWidget(wrap(const ForecastScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MONEY FORECAST'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 5. Settings: Theme & Colors opens ThemeCustomizerSheet
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Theme & Colors'), findsOneWidget);
      await tester.tap(find.text('Theme & Colors'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ThemeCustomizerSheet), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('MoveMoneySheet transfers cash cleanly between two wallets', (tester) async {
      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Move Test', currency: 'USD', onlineFx: false);
        await repo.setupInitialFinancialData(
          startingCashCents: 100000, // $1,000 Cash
          startingBankCents: 50000,  // $500 Bank
          createStarterEnvelopes: false,
        );
      });

      final assetsBefore = repo.accounts.where((a) => a.type == AccountType.asset).toList();
      expect(assetsBefore.length, greaterThanOrEqualTo(2));
      final firstBefore = assetsBefore[0].balanceCents;
      final secondBefore = assetsBefore[1].balanceCents;

      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const Scaffold(
            body: MoveMoneySheet(baseCurrency: 'USD'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '200');
      await tester.ensureVisible(find.text('CONFIRM MOVE'));
      await tester.pump();
      await tester.tap(find.text('CONFIRM MOVE'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 120)));
      await tester.pump();

      final firstAfter = repo.accounts.firstWhere((a) => a.id == assetsBefore[0].id).balanceCents;
      final secondAfter = repo.accounts.firstWhere((a) => a.id == assetsBefore[1].id).balanceCents;

      expect(firstAfter, firstBefore - 20000);
      expect(secondAfter, secondBefore + 20000);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Task 5 TDD: Silent In-App Code Push (Shorebird) with Snapshot & Zero Browser Redirect', () {
    test('checkForInAppPatch detects available silent patch and applyInAppPatch downloads inside app with snapshot',
        () async {
      final service = UpdateReceiverService.instance;
      service.resetVersionForTesting(version: '3.2.0', build: 30200);

      var updateCalled = false;
      final fakeDriver = _FakeInAppPatchDriver(
        available: true,
        currentPatch: 1,
        onUpdate: () async {
          updateCalled = true;
        },
      );
      service.setPatchDriverForTesting(fakeDriver);

      final check = await service.checkForInAppPatch();
      expect(check.isAvailable, isTrue);
      expect(check.currentPatchNumber, 1);
      expect(service.inAppPatchAvailable, isTrue);

      final apply = await service.applyInAppPatch();
      expect(apply.success, isTrue);
      expect(apply.restartRequired, isTrue);
      expect(apply.launchedSystemInstaller, isFalse);
      expect(updateCalled, isTrue);
      expect(service.availableRollbackSnapshots.length, greaterThanOrEqualTo(1));
      expect(service.inAppPatchRestartRequired, isTrue);

      service.resetPatchDriverForTesting();
    });
  });
}

class _FakeInAppPatchDriver implements InAppPatchDriver {
  final bool available;
  final int? currentPatch;
  final Future<void> Function() onUpdate;

  _FakeInAppPatchDriver({
    required this.available,
    required this.currentPatch,
    required this.onUpdate,
  });

  @override
  bool get isSupported => true;

  @override
  Future<int?> readCurrentPatchNumber() async => currentPatch;

  @override
  Future<InAppPatchStatus> checkForPatch() async =>
      available ? InAppPatchStatus.outdated : InAppPatchStatus.upToDate;

  @override
  Future<void> downloadAndStagePatch() => onUpdate();
}
