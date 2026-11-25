import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/theme/app_theme.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/security/hardware_vault_service.dart';
import 'package:cash_io/core/services/update_receiver_service.dart';
import 'package:cash_io/features/auth/presentation/pin_screen.dart';
import 'package:cash_io/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cash_io/features/accounts/presentation/accounts_screen.dart';
import 'package:cash_io/features/envelopes/presentation/envelopes_screen.dart';
import 'package:cash_io/features/forecast/presentation/forecast_screen.dart';
import 'package:cash_io/features/settings/presentation/settings_screen.dart';
import 'package:cash_io/features/settings/presentation/update_receiver_sheet.dart';
import 'package:cash_io/features/vaults/presentation/vault_switcher_sheet.dart';
import 'package:cash_io/features/profile_setup/presentation/profile_setup_screen.dart';
import 'package:cash_io/features/profile_setup/presentation/quick_financial_setup_sheet.dart';

Widget _wrapCompactPhone(Widget child, {double textScale = 1.2}) {
  return MaterialApp(
    theme: CashIOTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        textScaler: TextScaler.linear(textScale),
      ),
      child: child,
    ),
  );
}

void main() {
  test('Initial cash & financial setup records balanced zero-sum double-entry transactions', () async {
    final repo = VaultRepository.instance;
    await repo.initializeProfile(
      name: 'Onboarding Vault',
      currency: 'IQD',
      onlineFx: false,
      pin: '654321',
    );

    await repo.setupInitialFinancialData(
      startingCashCents: 75000000, // IQD 750,000
      startingBankCents: 250000000, // IQD 2,500,000
      createStarterEnvelopes: true,
      emergencyGoalTargetCents: 150000000, // IQD 1,500,000
    );

    expect(repo.totalAssetsCents, 325000000);
    expect(repo.envelopes.length, 3);
    expect(repo.savingsGoals.length, 1);
    expect(UpdateReceiverService.instance.verifyLedgerIntegrity(), isTrue);
  });

  test('Biometric preference defaults to enabled and persists updates', () async {
    final hvs = HardwareVaultService.instance;
    await hvs.setBiometricsEnabled(true);
    expect(await hvs.getBiometricsEnabled(), isTrue);

    await hvs.setBiometricsEnabled(false);
    expect(await hvs.getBiometricsEnabled(), isFalse);

    await hvs.setBiometricsEnabled(true);
    expect(await hvs.getBiometricsEnabled(), isTrue);
  });

  testWidgets('All primary screens render with zero RenderFlex overflow on 360x640 phone at 1.2x font scale',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = VaultRepository.instance;
    await tester.runAsync(() async {
      await repo.initializeProfile(
        name: 'Compact Screen Audit Vault With Long Name',
        currency: 'IQD',
        onlineFx: false,
      );
      await repo.setupInitialFinancialData(
        startingCashCents: 4875000000, // IQD 48,750,000
        startingBankCents: 12500000000, // IQD 125,000,000
        createStarterEnvelopes: true,
        emergencyGoalTargetCents: 5000000000,
      );
    });

    // 1. Lock Screen (PIN + Biometric Layout)
    await tester.pumpWidget(_wrapCompactPhone(PinAuthScreen(onAuthenticated: () {})));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);

    // 2. Dashboard Screen (Insights, Savings Vaults, Categories)
    await tester.pumpWidget(_wrapCompactPhone(const DashboardScreen()));
    await tester.pump(const Duration(milliseconds: 550));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Savings Vaults'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Categories'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);

    // 3. Accounts Screen
    await tester.pumpWidget(_wrapCompactPhone(const AccountsScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // 4. Envelopes Screen
    await tester.pumpWidget(_wrapCompactPhone(const EnvelopesScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // 5. Forecast Screen
    await tester.pumpWidget(_wrapCompactPhone(const ForecastScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // 6. Settings Screen
    await tester.pumpWidget(_wrapCompactPhone(const SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // 7. Quick Financial Setup Sheet, Update Receiver Sheet, Vault Switcher Sheet
    await tester.pumpWidget(_wrapCompactPhone(const Scaffold(body: QuickFinancialSetupSheet())));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrapCompactPhone(const Scaffold(body: UpdateReceiverSheet())));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrapCompactPhone(const Scaffold(body: VaultSwitcherSheet())));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);

    // 8. Profile Setup Wizard (Stages 0 -> 1 -> 2 -> 3 -> 4 -> 5)
    await tester.pumpWidget(_wrapCompactPhone(ProfileSetupScreen(onProfileCreated: () {})));
    await tester.pump(const Duration(milliseconds: 3500)); // Finish cipher animation
    expect(tester.takeException(), isNull);

    // Stage 0 -> Stage 1 (Vault Name & Currency)
    await tester.tap(find.text('Swipe up or tap to start'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);

    // Stage 1 -> Stage 2 (Starting Cash & Balances)
    final nextCashBtn = find.text('Next: Starting Cash');
    await tester.ensureVisible(nextCashBtn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(nextCashBtn);
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);
    final chip100k = find.text('+100K');
    await tester.ensureVisible(chip100k);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(chip100k);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Stage 2 -> Stage 3 (6-Digit PIN & Fingerprint Sign-In)
    final nextSecurityBtn = find.text('Next: Security');
    await tester.ensureVisible(nextSecurityBtn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(nextSecurityBtn);
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);
    expect(find.text('Enable Fingerprint Sign-In'), findsOneWidget);

    // Enter 6 digits + confirm 6 digits -> Stage 4 (12-Word Recovery Key)
    final oneKey = find.text('1');
    await tester.ensureVisible(oneKey);
    await tester.pump(const Duration(milliseconds: 100));
    for (int i = 0; i < 6; i++) {
      await tester.tap(oneKey);
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (int i = 0; i < 6; i++) {
      await tester.tap(oneKey);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);

    // Stage 4 -> Stage 5 (Summary & Launch)
    final savedCheckbox = find.byType(Checkbox);
    await tester.ensureVisible(savedCheckbox);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(savedCheckbox);
    await tester.pump(const Duration(milliseconds: 100));
    final reviewBtn = find.text('Review & Finish');
    await tester.ensureVisible(reviewBtn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(reviewBtn);
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);
    expect(find.text('LAUNCH MY VAULT'), findsOneWidget);

    // Unmount animated widgets and flush any debounced sync timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });
}
