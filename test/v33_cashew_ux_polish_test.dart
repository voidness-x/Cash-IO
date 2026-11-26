import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/theme/app_theme.dart';
import 'package:cash_io/core/theme/frosted_scaffold.dart';
import 'package:cash_io/core/theme/original_theme_snapshot.dart';
import 'package:cash_io/core/theme/theme_controller.dart';
import 'package:cash_io/core/widgets/animated_money_bar.dart';
import 'package:cash_io/core/widgets/cashio_logo.dart';
import 'package:cash_io/core/widgets/pop_up_route.dart';
import 'package:cash_io/features/auth/presentation/pin_screen.dart';
import 'package:cash_io/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cash_io/features/navigation/presentation/main_scaffold.dart';
import 'package:cash_io/features/profile_setup/presentation/profile_setup_screen.dart';
import 'package:cash_io/features/savings/presentation/savings_goals_deck.dart';
import 'package:cash_io/features/settings/presentation/theme_customizer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 & 1.5 TDD: Lighter Purple Obsidian Default, Live Light-Mode Confirm Sheet, Normal O Logo & Savings Gap',
      () {
    tearDown(() {
      ThemeController.instance.previewTheme(
        preset: ThemeController.builtInPresets.first,
        mode: ThemeMode.system,
      );
    });

    test('Default preset is Lighter Purple (#9D8DF1) + Obsidian (#0B0F17 / #161D2B), distinct from Royal Amethyst',
        () async {
      final ctrl = ThemeController.instance;
      await ctrl.resetToDefault();

      expect(ThemeController.defaultPresetId, 'indigo_obsidian');
      expect(ctrl.activePreset.id, 'indigo_obsidian');
      expect(ctrl.activePreset.accentColor, const Color(0xFF9D8DF1));
      expect(ctrl.activePreset.accentColor, isNot(const Color(0xFF8B5CF6))); // Not Royal Amethyst
      expect(ctrl.activePreset.darkBg, const Color(0xFF0B0F17));
      expect(ctrl.activePreset.darkSurface, const Color(0xFF161D2B));

      // Original Cyber Teal snapshot remains safely restorable
      await ctrl.resetToOriginal();
      expect(ctrl.activePreset.id, OriginalCashIOThemeSnapshot.presetId);
      expect(ctrl.activePreset.accentColor, OriginalCashIOThemeSnapshot.brand);
    });

    testWidgets('ThemeCustomizerSheet switches whole sheet surface to Light live, has top SafeArea, and supports Cancel vs Confirm',
        (tester) async {
      final ctrl = ThemeController.instance;
      ctrl.previewTheme(
        preset: ThemeController.builtInPresets.first,
        mode: ThemeMode.dark,
      );

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: ctrl,
          builder: (context, _) {
            return MaterialApp(
              theme: CashIOTheme.buildLightTheme(ctrl.lightExtension),
              darkTheme: CashIOTheme.buildDarkTheme(ctrl.darkExtension),
              themeMode: ctrl.themeMode,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: ctx,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const ThemeCustomizerSheet(),
                        );
                      },
                      child: const Text('Open Theme Studio'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Open Theme Studio
      await tester.tap(find.text('Open Theme Studio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verify top SafeArea is enabled so header clears status bar
      final safeArea = tester.widget<SafeArea>(find.descendant(
        of: find.byType(ThemeCustomizerSheet),
        matching: find.byType(SafeArea),
      ));
      expect(safeArea.top, isTrue);

      // Verify initial dark surface
      Container surfaceBox = tester.widget<Container>(find.byKey(const ValueKey('theme_sheet_surface')));
      expect((surfaceBox.decoration as BoxDecoration).color, const Color(0xFF161D2B));

      // Switch to Light mode live -> entire sheet surface turns white immediately!
      await tester.ensureVisible(find.text('Light'));
      await tester.pump();
      await tester.tap(find.text('Light'));
      await tester.pump(const Duration(milliseconds: 300));
      surfaceBox = tester.widget<Container>(find.byKey(const ValueKey('theme_sheet_surface')));
      expect((surfaceBox.decoration as BoxDecoration).color, const Color(0xFFFFFFFF));

      // Preview Emerald Vault then tap Cancel -> reverts both preset and ThemeMode!
      await tester.ensureVisible(find.byKey(const ValueKey('theme_preset_emerald_vault')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('theme_preset_emerald_vault')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('theme_cancel_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(ctrl.activePreset.id, 'indigo_obsidian');
      expect(ctrl.themeMode, ThemeMode.dark);

      // Re-open, select Emerald Vault + Light, tap Confirm & Apply -> commits both!
      await tester.tap(find.text('Open Theme Studio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.ensureVisible(find.text('Light'));
      await tester.pump();
      await tester.tap(find.text('Light'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.ensureVisible(find.byKey(const ValueKey('theme_preset_emerald_vault')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('theme_preset_emerald_vault')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('theme_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(ctrl.activePreset.id, 'emerald_vault');
      expect(ctrl.themeMode, ThemeMode.light);
    });

    testWidgets('CashIOLogo renders normal matching typographic O in CASH-IO wordmark (no offset custom ring)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CashIOLogo(fontSize: 18, animateO: false),
                SizedBox(height: 16),
                CashIOLogo(fontSize: 32, animateO: false),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('cashio_logo_wordmark')), findsNWidgets(2));
      expect(find.text('CASH-IO', findRichText: true), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('SavingsGoalsDeck maintains clean gap between empty goals card and Spare-Change Round-Ups',
        (tester) async {
      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Savings Gap Vault', currency: 'IQD', onlineFx: false);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: SavingsGoalsDeck(currency: 'IQD'),
            ),
          ),
        ),
      );
      await tester.pump();

      final emptyRect = tester.getRect(find.byKey(const ValueKey('savings_empty_card')));
      final roundupsRect = tester.getRect(find.byKey(const ValueKey('savings_roundups_card')));
      expect(
        roundupsRect.top - emptyRect.bottom,
        greaterThanOrEqualTo(12.0),
        reason: 'Spare-Change Round-Ups card must never touch the empty Savings Goals card above it',
      );
    });

    testWidgets('FrostedScaffold uses dynamic tokens.bgPrimary (Obsidian) instead of hardcoded Charcoal',
        (tester) async {
      ThemeController.instance.previewTheme(
        preset: ThemeController.builtInPresets.first,
        mode: ThemeMode.dark,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.buildDarkTheme(ThemeController.instance.darkExtension),
          home: const FrostedScaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      final overlay = tester.widget<Container>(find.byKey(const ValueKey('frosted_scaffold_overlay')));
      expect(overlay.color!.toARGB32() & 0x00FFFFFF, const Color(0xFF0B0F17).toARGB32() & 0x00FFFFFF);
    });

    testWidgets('Lock screen (PinAuthScreen) and Setup screen (ProfileSetupScreen) use lighter-purple Obsidian theme and normal O wordmark',
        (tester) async {
      ThemeController.instance.previewTheme(
        preset: ThemeController.builtInPresets.first,
        mode: ThemeMode.dark,
      );

      // 1. Lock Screen uses Obsidian FrostedScaffold + CashIOLogo normal wordmark
      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.buildDarkTheme(ThemeController.instance.darkExtension),
          home: PinAuthScreen(onAuthenticated: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('cashio_logo_wordmark')), findsOneWidget);
      final lockOverlay = tester.widget<Container>(find.byKey(const ValueKey('frosted_scaffold_overlay')));
      expect(lockOverlay.color!.toARGB32() & 0x00FFFFFF, const Color(0xFF0B0F17).toARGB32() & 0x00FFFFFF);

      // 2. Setup Screen uses lighter purple (#9D8DF1) + Obsidian + zero SlideTransition
      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.buildDarkTheme(ThemeController.instance.darkExtension),
          home: ProfileSetupScreen(onProfileCreated: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1400));
      final setupOverlay = tester.widget<Container>(find.byKey(const ValueKey('frosted_scaffold_overlay')));
      expect(setupOverlay.color!.toARGB32() & 0x00FFFFFF, const Color(0xFF0B0F17).toARGB32() & 0x00FFFFFF);
      final subtitle = tester.widget<Text>(find.text('AIR-GAPPED ZERO-KNOWLEDGE LEDGER'));
      expect(
        subtitle.style!.color!.toARGB32() & 0x00FFFFFF,
        const Color(0xFF9D8DF1).toARGB32() & 0x00FFFFFF,
      );
      expect(find.byType(SlideTransition), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Phase 2 TDD: Compact Integrated O-Dock & Smooth Pop-Up Transitions (Zero Sliding)', () {
    testWidgets('MainScaffold center O button is compact (<=52px), integrated into floating dock, and switches tabs via smooth pop-up (zero SlideTransition)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'PopUp Nav Vault', currency: 'USD', onlineFx: false);
        await repo.setupInitialFinancialData(startingCashCents: 100000, createStarterEnvelopes: true);
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

      final oSize = tester.getSize(find.byKey(const ValueKey('center_dashboard_o_button')));
      expect(oSize.width, lessThanOrEqualTo(52.0));
      expect(oSize.height, lessThanOrEqualTo(52.0));

      // Switch tab mid-transition and verify smooth pop-up (ScaleTransition + FadeTransition, ZERO SlideTransition!)
      await tester.tap(find.byKey(const ValueKey('nav_tab_wallets')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.descendant(of: find.byType(AnimatedSwitcher), matching: find.byType(SlideTransition)), findsNothing);
      expect(find.descendant(of: find.byType(AnimatedSwitcher), matching: find.byType(ScaleTransition)),
          findsAtLeastNWidgets(1));

      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byKey(const ValueKey('center_dashboard_o_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.descendant(of: find.byType(AnimatedSwitcher), matching: find.byType(SlideTransition)), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('App themes use PopUpPageTransitionsBuilder so pushed screens pop up smoothly without sliding',
        (tester) async {
      final darkTheme = CashIOTheme.darkTheme;
      expect(
        darkTheme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PopUpPageTransitionsBuilder>(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    PopUpPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Popped Screen')))),
                  );
                },
                child: const Text('Open Screen'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Screen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SlideTransition), findsNothing);
      expect(find.byType(ScaleTransition), findsAtLeastNWidgets(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Popped Screen'), findsOneWidget);
    });
  });

  group('Phase 3 TDD: Cashew-Inspired Minimalist Dashboard & De-Cluttered Activity Feed', () {
    testWidgets('DashboardScreen displays Cashew side-by-side Income & Spent cards, horizontal Monthly Budgets strip, and color-coded Recent Activity without overflow at 360x640 @ 1.2x',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Cashew UX Vault', currency: 'USD', onlineFx: false);
        await repo.setupInitialFinancialData(
          startingCashCents: 250000, // $2,500
          createStarterEnvelopes: true,
        );
        // Record a real expense so both + income and - expense rows appear
        final cash = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
        final expenseAcc = repo.accounts.firstWhere((a) => a.type == AccountType.expense);
        await repo.recordTransaction(
          description: 'Morning Coffee',
          postings: [
            PostingModel(accountId: expenseAcc.id, amountCents: 650),
            PostingModel(accountId: cash.id, amountCents: -650),
          ],
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: const MediaQuery(
            data: MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.2)),
            child: DashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Side-by-side Cashew Income & Spent summary cards
      final incomeFinder = find.byKey(const ValueKey('cashew_income_card'));
      final spentFinder = find.byKey(const ValueKey('cashew_spent_card'));
      expect(incomeFinder, findsOneWidget);
      expect(spentFinder, findsOneWidget);
      final incomeRect = tester.getRect(incomeFinder);
      final spentRect = tester.getRect(spentFinder);
      expect(
        (incomeRect.top - spentRect.top).abs(),
        lessThanOrEqualTo(2.0),
        reason: 'Income and Spent summary cards must sit side-by-side in one calm row',
      );
      expect(find.descendant(of: incomeFinder, matching: find.byType(AnimatedMoneyBar)), findsOneWidget);
      expect(find.descendant(of: spentFinder, matching: find.byType(AnimatedMoneyBar)), findsOneWidget);

      // Horizontal Monthly Budgets strip directly on Dashboard
      final budgetsStrip = find.byKey(const ValueKey('cashew_budgets_strip'));
      expect(budgetsStrip, findsOneWidget);
      expect(find.descendant(of: budgetsStrip, matching: find.byType(AnimatedMoneyBar)), findsAtLeastNWidgets(1));

      // Scroll down to Recent Activity and verify color-coded +/- amounts
      await tester.scrollUntilVisible(
        find.text('Morning Coffee'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Morning Coffee'), findsOneWidget);
      final coffeeTile = find.ancestor(of: find.text('Morning Coffee'), matching: find.byType(ListTile));
      expect(find.descendant(of: coffeeTile, matching: find.text('-\$6.50')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify empty-budgets state also renders cleanly at 360x640 @ 1.2x with zero overflow
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Empty Budgets Vault', currency: 'USD', onlineFx: false);
        await repo.setupInitialFinancialData(startingCashCents: 50000, createStarterEnvelopes: false);
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cashew_budgets_strip')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('cashew_budgets_strip')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
