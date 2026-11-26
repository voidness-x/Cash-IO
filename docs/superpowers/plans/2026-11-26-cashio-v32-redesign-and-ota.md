# Cash-IO v3.2.0 Redesign, Theme Studio, Vault Fix & Shorebird/Vercel OTA Implementation Plan

> **For agentic workers:** Implementing inline via strict Red-Green-Refactor TDD. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Deliver a cleaner, brother-proof Cash-IO UX with a floating bottom navigation bar (raised center `O` Dashboard), left-to-right animated money bars, consistent hero card glow across screens, a Settings Theme Studio (with original theme archived), a fix for the phantom `'default_profile'` vault bug, and Choice 1 updates (Shorebird in-app patches for Android + Vercel auto-deploy for Web/iOS PWA).

**Architecture:** Minimal surgical changes layered over the existing double-entry `VaultRepository`, SQLite `DatabaseHelper`, and `CashIOThemeExtension` token architecture. No rewrites of crypto, SQLite schema, or CRDT internals.

**Tech Stack:** Flutter 3.47.8, Dart 3.13.7, `shorebird_code_push`, Vercel static PWA (`vercel.json`), `flutter_test`.

**Spec:** [2026-11-26-cashio-v32-redesign-and-ota-design.md](file:///d:/CashIO/docs/superpowers/specs/2026-11-26-cashio-v32-redesign-and-ota-design.md)

## Global Constraints
- Strict Red-Green-Refactor TDD for every task.
- Zero `RenderFlex` overflow at `360×640` with `1.2x` font scale.
- Respect `MediaQuery.disableAnimationsOf(context)` in all new animations.
- Zero emoji icons; use Material vector icons / custom `VaultOMark` canvas.
- Zero analyzer warnings/infos (`flutter analyze --fatal-infos --fatal-warnings`).
- Floating dock clearance: scrollable bodies add `bottom: 112` padding so cards/FABs never collide with the floating navigation bar.

## Review Focus
1. Cold-start vault load must never inject `'default_profile'` into Vault Switcher.
2. Theme switching must dynamically re-color `tokens.accent`, hero glow, FABs, buttons, and floating nav without app restart.
3. Spending cash linked to a Monthly Budget must increment `spentCents` and reduce `remainingCents` while keeping double-entry postings balanced ($\sum = 0$).
4. Floating bottom nav center `O` button must remain accessible (`≥48dp` hit area) and never clip on `360dp` screens.
5. Shorebird patch check must gracefully report unavailable/no-patch on Web/Desktop/unpatched debug builds without throwing.

---

### Task 1: Fix Phantom `'default_profile'` Vault Bug & Spend-to-Budget Link
- **Files:** Modify `lib/core/storage/vault_repository.dart`, Test `test/v32_redesign_theme_vault_nav_ota_test.dart`
- [ ] Write failing tests reproducing `'default_profile'` leak in `getAvailableProfiles()` and verifying `recordEnvelopeSpend`.
- [ ] Run test to confirm RED.
- [ ] Guard `_snapshotCurrentVault()` against uninitialized `'default_profile'` and add `recordEnvelopeSpend(String envelopeId, int spentCents)`.
- [ ] Run tests to confirm GREEN.

### Task 2: Archive Original Theme & Build Theme Studio (`ThemeController` + 7 Presets + Custom Picker)
- **Files:** Create `lib/core/theme/original_theme_snapshot.dart`, `lib/core/theme/theme_controller.dart`, `lib/features/settings/presentation/theme_customizer_sheet.dart`; Modify `lib/core/theme/theme_extension.dart`, `lib/core/theme/app_theme.dart`, `lib/main.dart`, `lib/features/settings/presentation/settings_screen.dart`
- [ ] Archive exact untouched original palette in `original_theme_snapshot.dart`.
- [ ] Write failing TDD tests for `ThemeController` presets, custom accent color, brightness mode, reset-to-original, and persistence.
- [ ] Implement `ThemeController`, dynamic `CashIOTheme.fromPreset`, `accent => accentGold`, and Settings Theme Studio sheet.
- [ ] Verify GREEN.

### Task 3: `VaultOMark`, `AnimatedMoneyBar` & Floating Bottom Nav Bar (Center Pop-Up Dashboard)
- **Files:** Create `lib/core/widgets/animated_money_bar.dart`; Modify `lib/core/widgets/cashio_logo.dart`, `lib/features/navigation/presentation/main_scaffold.dart`
- [ ] Write failing widget tests for `AnimatedMoneyBar` (left-to-right fill + reduced motion) and `MainScaffold` (floating pill dock, center Dashboard default at index 2 with `VaultOMark`, 5-tab switching at `360×640 @ 1.2x`).
- [ ] Implement `VaultOMark`, `AnimatedMoneyBar` + `AnimatedSegmentedMoneyBar`, and floating `MainScaffold`.
- [ ] Verify GREEN.

### Task 4: Simplified Intuitive UX, Consistent Hero Glow & Effortless Money Movement
- **Files:** Modify `dashboard_screen.dart`, `cash_action_sheets.dart`, `accounts_screen.dart`, `envelopes_screen.dart`, `forecast_screen.dart`, `financial_advisory_card.dart`, `savings_goals_deck.dart`, `settings_screen.dart`
- [ ] Write failing widget tests checking simplified plain labels (`Wallets`, `Monthly Budgets`, `Move`), budget-linked spending UI, and zero overflow at `360×640 @ 1.2x`.
- [ ] Apply shared `heroGlowDecoration` to Dashboard, Wallets, Budgets, and Forecast hero cards; replace static progress bars with `AnimatedMoneyBar`; add `MoveMoneySheet` and budget-link chips in `SpendCashSheet`; clarify copy across all screens.
- [ ] Verify GREEN.

### Task 5: Shorebird In-App Silent Code Push + Vercel PWA Deployment Config
- **Files:** Create `shorebird.yaml`, `vercel.json`, `.github/workflows/shorebird_patch.yml`; Modify `pubspec.yaml`, `lib/core/services/update_receiver_service.dart`, `lib/features/settings/presentation/update_receiver_sheet.dart`
- [ ] Write failing TDD tests for in-app Shorebird patch detection, silent patch download (no browser), and restart-ready status.
- [ ] Add `shorebird_code_push` dependency, `InAppPatchDriver` abstraction, `shorebird.yaml`, `vercel.json`, and wire into `UpdateReceiverService` + `UpdateReceiverSheet`.
- [ ] Verify GREEN.

### Task 6: Full Verification Gate, Release Push & Live Preview
- [ ] Run `flutter analyze --fatal-infos --fatal-warnings`, `flutter test --concurrency=1`, `flutter build web --release --no-web-resources-cdn`, and `flutter build apk --release --target-platform android-arm64`.
- [ ] Commit & push to `main` (and tag `v3.2.0`), verify GitHub Actions, and inspect live app at `http://localhost:8095`.
