import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/security/app_privacy_shield.dart';
import 'package:cash_io/core/security/hardware_vault_service.dart';
import 'package:cash_io/core/services/in_app_patch_driver.dart';
import 'package:cash_io/core/services/update_receiver_service.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/theme/app_theme.dart';
import 'package:cash_io/core/theme/theme_controller.dart';
import 'package:cash_io/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cash_io/features/settings/presentation/settings_screen.dart';
import 'package:cash_io/features/vaults/presentation/vault_switcher_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Theme-Matched AppPrivacyShield (App Switcher / Screenshot Lock)', () {
    tearDown(() {
      ThemeController.instance.previewTheme(
        preset: ThemeController.builtInPresets.first,
        mode: ThemeMode.system,
      );
    });

    testWidgets('AppPrivacyShield dynamically matches user-selected preset & Dark/Light mode (never hardcoded teal/charcoal)',
        (tester) async {
      final ctrl = ThemeController.instance;
      ctrl.previewTheme(
        preset: ThemeController.builtInPresets.firstWhere((p) => p.id == 'rose_quartz'),
        mode: ThemeMode.dark,
      );

      final shieldKey = GlobalKey<AppPrivacyShieldState>();
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: ctrl,
          builder: (context, _) {
            return MaterialApp(
              theme: CashIOTheme.buildLightTheme(ctrl.lightExtension),
              darkTheme: CashIOTheme.buildDarkTheme(ctrl.darkExtension),
              themeMode: ctrl.themeMode,
              home: AppPrivacyShield(
                key: shieldKey,
                child: const Scaffold(body: Text('Vault Content')),
              ),
            );
          },
        ),
      );

      shieldKey.currentState!.setShieldVisible(true);
      await tester.pump();

      // Must match Rose Quartz Dark canvas (#1C1217) & accent (#F43F5E)
      final darkMat = tester.widget<Material>(find.byKey(const ValueKey('privacy_shield_surface')));
      expect(darkMat.color, const Color(0xFF1C1217));
      final lockIcon = tester.widget<Icon>(find.byKey(const ValueKey('privacy_shield_lock_icon')));
      expect(lockIcon.color, const Color(0xFFF43F5E));
      expect(find.byKey(const ValueKey('cashio_logo_wordmark')), findsOneWidget);
      expect(find.text('AIR-GAPPED PRIVACY SHIELD'), findsOneWidget);

      // Switch to Light mode live -> Shield immediately turns light (#F3F4F6) with light accent (#E11D48)
      ctrl.previewTheme(mode: ThemeMode.light);
      await tester.pump();

      final lightMat = tester.widget<Material>(find.byKey(const ValueKey('privacy_shield_surface')));
      expect(lightMat.color, ctrl.lightExtension.bgPrimary);
      final lightIcon = tester.widget<Icon>(find.byKey(const ValueKey('privacy_shield_lock_icon')));
      expect(lightIcon.color, ctrl.lightExtension.accentGold);
    });
  });

  group('2. Polished Floating Top Bar Matching Bottom Floating Dock', () {
    testWidgets('DashboardScreen renders floating_top_bar with normal CASH-IO logo, vault pill, and boxed actions without overflow at 360x640 @ 1.2x',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'Personal Vault', currency: 'USD', onlineFx: false);
        await repo.setupInitialFinancialData(startingCashCents: 100000, createStarterEnvelopes: true);
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
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey('floating_top_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('top_bar_vault_pill')), findsOneWidget);
      expect(find.byKey(const ValueKey('cashio_logo_wordmark')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('3. Delete Account / Vault (PIN-Guarded Storage + UI)', () {
    test('VaultRepository.deleteVault enforces PIN verification, removes vault & keys, and falls back or clears cleanly',
        () async {
      final repo = VaultRepository.instance;
      await repo.initializeProfile(name: 'Primary Vault', currency: 'USD', onlineFx: false);
      final firstId = repo.profileId;
      await HardwareVaultService.instance.saveProfileVaultCredentials(
        profileId: firstId,
        pin: '111111',
        salt: HardwareVaultService.instance.generateProfileSalt(),
        mnemonic: 'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu',
      );

      final secondId = await repo.createSecondaryVault(
        name: 'Burner Vault',
        currency: 'EUR',
        pin: '222222',
      );

      // 1. Wrong PIN must fail and preserve the vault
      final badAttempt = await repo.deleteVault(secondId, pin: '999999');
      expect(badAttempt.success, isFalse);
      final profilesAfterBad = await repo.getAvailableProfiles();
      expect(profilesAfterBad.any((p) => p['id'] == secondId), isTrue);

      // 2. Correct PIN deletes active Burner Vault and switches cleanly to Primary Vault
      final deleteSecond = await repo.deleteVault(secondId, pin: '222222');
      expect(deleteSecond.success, isTrue);
      expect(deleteSecond.hasRemainingVaults, isTrue);
      expect(repo.profileId, isNot(secondId));
      final profilesAfterDelete = await repo.getAvailableProfiles();
      expect(profilesAfterDelete.any((p) => p['id'] == secondId), isFalse);
      expect(await HardwareVaultService.instance.getRecoveryMnemonic(secondId), isNull);
    });

    testWidgets('VaultSwitcherSheet and SettingsScreen expose PIN-protected Delete Vault controls', (tester) async {
      final repo = VaultRepository.instance;
      await tester.runAsync(() async {
        await repo.initializeProfile(name: 'My Delete Test Vault', currency: 'USD', onlineFx: false);
      });
      final activeId = repo.profileId;

      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: Scaffold(
            body: VaultSwitcherSheet(onAllVaultsDeleted: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('delete_vault_$activeId')), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: CashIOTheme.darkTheme,
          home: SettingsScreen(onSwitchProfile: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings_delete_vault_tile')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('settings_delete_vault_tile')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('4. Silent Shorebird Patch Auto-Heal After Cache Clear', () {
    test('UpdateReceiverService.autoHealInAppPatchIfOutdated silently re-stages missing Shorebird patch', () async {
      final service = UpdateReceiverService.instance;
      var downloaded = false;
      service.setPatchDriverForTesting(_MockPatchDriver(
        onDownload: () async {
          downloaded = true;
        },
      ));

      final healed = await service.autoHealInAppPatchIfOutdated();
      expect(healed, isTrue);
      expect(downloaded, isTrue);
      expect(service.inAppPatchRestartRequired, isTrue);

      service.resetPatchDriverForTesting();
    });
  });
}

class _MockPatchDriver implements InAppPatchDriver {
  final Future<void> Function() onDownload;
  _MockPatchDriver({required this.onDownload});

  @override
  bool get isSupported => true;

  @override
  Future<int?> readCurrentPatchNumber() async => null;

  @override
  Future<InAppPatchStatus> checkForPatch() async => InAppPatchStatus.outdated;

  @override
  Future<void> downloadAndStagePatch() => onDownload();
}
