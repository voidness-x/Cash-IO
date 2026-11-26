# Cash-IO v3.3 Cashew-Inspired UX, Pop-Up Transitions & Theme Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan phase-by-phase. Invoke `systematic-debugging`, `ui-ux-pro-max`, `test-driven-development`, and `verification-before-completion` throughout. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all screenshot-reported UI/theme bugs, switch the default brand & loading screen to Indigo Purple (`#6366F1`) + Obsidian (`#0B0F17`/`#161D2B`), shrink & integrate the center `"O"` nav button, replace all sliding transitions with smooth pop-ups, and adopt Cashew's cleaner, calmer Dashboard hierarchy — verified via TDD and live browser inspection after every phase.

**Architecture:** Three independent, browser-verifiable phases touching only the targeted UI/theme/splash/navigation widgets while leaving storage, cryptography, biometrics, and OTA pipelines untouched. Each phase ends with full test suite green, `flutter analyze` zero issues, fresh `build/web` deployment on `http://localhost:8095`, and a live browser visual verification screenshot for user review before starting the next phase.

**Tech Stack:** Flutter 3.47.8, Dart 3.13.7, `google_fonts`, `flutter_test`, local Web preview (`http://localhost:8095`).

**Spec:** `docs/superpowers/specs/2026-11-26-cashio-v33-cashew-ux-and-polish-design.md`

---

## Global Constraints
- Strictly surgical edits — never rewrite untouched working modules (`vault_repository.dart`, `database_helper.dart`, `update_receiver_service.dart`, `hardware_vault_service.dart`).
- Strict TDD (`test-driven-development`): write failing behavioral test → confirm RED → implement minimal code → confirm GREEN → refactor.
- Zero RenderFlex overflow on `360×640 @ 1.2x` text scale across all modified widgets (`ui-ux-pro-max`).
- Respect `MediaQuery.disableAnimationsOf(context)` on all pop-up & bar animations.
- Zero warnings/infos from `flutter analyze --fatal-infos --fatal-warnings`.
- After **each** phase: rebuild `build/web --release --no-web-resources-cdn`, inspect live on `http://localhost:8095` via the `browser` subagent, and share results with the user to inspect before proceeding.

## Review Focus (Pinned Edge Cases)
1. **Unconfirmed Theme Exit:** Dismissing `ThemeCustomizerSheet` via Cancel or system Back without tapping **Confirm & Apply** must revert both preset/colors and `ThemeMode` back to what they were before opening the sheet.
2. **Live Light-Mode Sheet Surface:** Toggling `Light` inside `ThemeCustomizerSheet` must immediately re-render the sheet's own outer surface color to `lightSurface` (not stay frozen in dark mode) with readable dark text and top status-bar `SafeArea` padding.
3. **Logo Optical Alignment at All Sizes:** `CashIOLogo` must render `VaultOMark` optically aligned with `CASH-I` cap-height at both `fontSize: 18` (AppBar) and `fontSize: 32` (Auth/Setup) with zero clipping or overflow.
4. **Zero Sliding Transitions & Integrated `48px` Center `"O"`:** `MainScaffold` and route transitions must contain zero `SlideTransition` animations and fit the `48px` integrated center `"O"` button cleanly inside the floating dock at `360×640 @ 1.2x`.
5. **Cashew Dashboard Empty & Populated States:** `DashboardScreen` must render cleanly at `360×640 @ 1.2x` with 0 budgets, 3 budgets, and mixed income/expense transactions showing color-coded amounts and animated bars.

---

## Phase 1: Default Indigo-Purple + Obsidian Theme, Live Light-Mode Fix, Confirm Theme Studio, Logo Alignment & Savings Spacing

**Skills Invoked:** `systematic-debugging`, `test-driven-development`, `ui-ux-pro-max`, `verification-before-completion`

**Files:**
- Modify: `lib/core/theme/theme_controller.dart` (add `'indigo_obsidian'` default preset `#6366F1` + Obsidian `#0B0F17` / `#161D2B`, keep `'cyber_teal_original'` preserved in presets & reset)
- Modify: `lib/core/theme/frosted_scaffold.dart` (bind overlay & ambient orbs to `context.tokens.bgPrimary` and `context.tokens.accentGold` instead of hardcoded Charcoal/Emerald)
- Modify: `lib/features/settings/presentation/settings_screen.dart` (pass `backgroundColor: Colors.transparent` when opening `ThemeCustomizerSheet`)
- Modify: `lib/features/settings/presentation/theme_customizer_sheet.dart` (live surface container reading `context.tokens.bgSurface`, top `SafeArea` + breathing room, draft-then-confirm state with `PopScope`, **Cancel** revert button, and **Confirm & Apply** button)
- Modify: `lib/core/widgets/cashio_logo.dart` (optical cap-height alignment of `_CenteredVaultO` with `CASH-I`)
- Modify: `lib/features/savings/presentation/savings_goals_deck.dart` (add bottom spacing below empty-state card before `SPARE-CHANGE ROUND-UPS`)
- Modify: `android/app/src/main/res/drawable/launch_background.xml`, `android/app/src/main/res/drawable-v21/launch_background.xml`, `android/app/src/main/res/values/styles.xml`, `android/app/src/main/res/values-night/styles.xml`, `web/index.html` (Obsidian `#0B0F17` + Indigo Purple `#6366F1` cold-start loading screen)
- Test: `test/v33_cashew_ux_polish_test.dart` (new focused TDD suite)

**Interfaces:**
- Produces: `ThemeController.defaultPresetId == 'indigo_obsidian'`, `ThemeController.applyPreview(...)` / draft commit-or-revert behavior in `ThemeCustomizerSheet` with keys `ValueKey('theme_confirm_button')`, `ValueKey('theme_cancel_button')`, `ValueKey('theme_sheet_surface')`.

### Phase 1 Steps
- [ ] **Step 1.1 (RED):** Create `test/v33_cashew_ux_polish_test.dart` with Phase 1 tests:
  1. Default `ThemeController` preset is `'indigo_obsidian'` (`accentColor == Color(0xFF6366F1)`, `darkBg == Color(0xFF0B0F17)`, `darkSurface == Color(0xFF161D2B)`), distinct from `'royal_amethyst'` (`#8B5CF6`), while `resetToOriginal()` still restores `OriginalCashIOThemeSnapshot`.
  2. Opening `ThemeCustomizerSheet`, switching to `Light` mode updates `ValueKey('theme_sheet_surface')` container background to light surface (`Color(0xFFFFFFFF)`) immediately, and `SafeArea` top padding is enabled.
  3. Selecting a preset in `ThemeCustomizerSheet` and tapping `ValueKey('theme_cancel_button')` reverts `ThemeController` back to the prior theme; selecting a preset and tapping `ValueKey('theme_confirm_button')` commits it.
  4. `CashIOLogo` centers `_CenteredVaultO` optically aligned with `CASH-I` (vertical center delta ≤ 2.5px) at `18px` and `32px`.
  5. `SavingsGoalsDeck` with empty goals maintains ≥12px vertical gap between the empty-state card and `SPARE-CHANGE ROUND-UPS`.
- [ ] **Step 1.2 (Verify RED):** Run `flutter test test/v33_cashew_ux_polish_test.dart` and verify expected failures.
- [ ] **Step 1.3 (GREEN):** Apply the surgical edits to `theme_controller.dart`, `frosted_scaffold.dart`, `settings_screen.dart`, `theme_customizer_sheet.dart`, `cashio_logo.dart`, `savings_goals_deck.dart`, Android launch drawables/styles, and `web/index.html`.
- [ ] **Step 1.4 (Verify GREEN):** Run `flutter analyze --fatal-infos --fatal-warnings` and `flutter test test/v33_cashew_ux_polish_test.dart test/v32_redesign_theme_vault_nav_ota_test.dart`.
- [ ] **Step 1.5 (Browser Check Gate #1):** Rebuild `flutter build web --release --no-web-resources-cdn --no-tree-shake-icons`, copy `sqlite3.wasm` + `sqflite_sw.js`, visually inspect on `http://localhost:8095` via the `browser` subagent (Default Indigo-Purple + Obsidian look, aligned `CASH-IO` logo, Savings gap, Theme Studio top clearance + live Light Mode toggle + Confirm/Cancel), and report to user for Phase 1 approval!

---

## Phase 2: Compact Integrated `"O"` Floating Bar & Smooth Pop-Up Screen Transitions (Zero Sliding)

**Skills Invoked:** `ui-ux-pro-max`, `test-driven-development`, `verification-before-completion`

**Files:**
- Create: `lib/core/widgets/pop_up_route.dart` (`PopUpPageRoute<T>` and `PopUpPageTransitionsBuilder` using scale `0.94 -> 1.0` + fade, `240ms`, `Curves.easeOutCubic`, zero `SlideTransition`, reduced-motion safe)
- Modify: `lib/core/theme/app_theme.dart` (register `PopUpPageTransitionsBuilder` in `pageTransitionsTheme` for both dark & light themes so every pushed route uses smooth pop-up instead of sliding)
- Modify: `lib/features/navigation/presentation/main_scaffold.dart` (compact integrated `48×48` center `"O"` medallion with `VaultOMark(size: 24)` nestled cleanly into the floating bar; replace `SlideTransition` with pure scale + fade pop-up across all 5 tabs)
- Test: `test/v33_cashew_ux_polish_test.dart` (append Phase 2 tests)

**Interfaces:**
- Produces: `PopUpPageRoute<T>`, `PopUpPageTransitionsBuilder`.

### Phase 2 Steps
- [ ] **Step 2.1 (RED):** Append Phase 2 tests to `test/v33_cashew_ux_polish_test.dart`:
  1. `MainScaffold` renders the center button (`ValueKey('center_dashboard_o_button')`) with compact integrated dimensions (`width <= 52`, `height <= 52`) and zero overflow across all 5 tabs at `360×640 @ 1.2x`.
  2. Switching tabs in `MainScaffold` uses smooth `ScaleTransition` + `FadeTransition` with **zero `SlideTransition`** widgets.
  3. Pushing a route via `MaterialPageRoute` under `CashIOTheme.darkTheme` uses `PopUpPageTransitionsBuilder` (scale + fade, zero `SlideTransition`).
- [ ] **Step 2.2 (Verify RED):** Run `flutter test test/v33_cashew_ux_polish_test.dart` and verify Phase 2 tests fail.
- [ ] **Step 2.3 (GREEN):** Implement `pop_up_route.dart`, register `PopUpPageTransitionsBuilder` in `app_theme.dart`, and refine `main_scaffold.dart`.
- [ ] **Step 2.4 (Verify GREEN):** Run `flutter analyze --fatal-infos --fatal-warnings` and `flutter test test/v33_cashew_ux_polish_test.dart test/v32_redesign_theme_vault_nav_ota_test.dart`.
- [ ] **Step 2.5 (Browser Check Gate #2):** Rebuild `build/web`, visually verify on `http://localhost:8095` via the `browser` subagent (sleek smaller integrated `"O"` floating bar + smooth pop-up screen transitions across tabs), and report to user for Phase 2 approval!

---

## Phase 3: Cashew-Inspired Clean, Minimalist Dashboard & De-Cluttered UX

**Skills Invoked:** `ui-ux-pro-max`, `test-driven-development`, `verification-before-completion`

**Files:**
- Modify: `lib/features/dashboard/presentation/dashboard_screen.dart` (Cashew-inspired calm hierarchy: streamlined glowing `TOTAL MONEY` card → side-by-side **Income** & **Spent** 30-day summary cards with `AnimatedMoneyBar` → horizontal glanceable **Monthly Budgets** strip with `AnimatedMoneyBar` → clean compact Focus drawer for Insights/Savings/Breakdown → color-coded **Recent Activity** feed with soft circular category badges and `+$` / `−$` color coding)
- Test: `test/v33_cashew_ux_polish_test.dart` (append Phase 3 tests)

**Interfaces:**
- Preserves existing `DashboardScreen(onSwitchProfile: ...)` constructor, `'TOTAL MONEY'`, `ValueKey('dashboard_move_button')`, `'Insights'`, `'Savings'`, `'Breakdown'` labels so all existing tests stay 100% green.
- Adds `ValueKey('cashew_income_card')`, `ValueKey('cashew_spent_card')`, `ValueKey('cashew_budgets_strip')`.

### Phase 3 Steps
- [ ] **Step 3.1 (RED):** Append Phase 3 tests to `test/v33_cashew_ux_polish_test.dart`:
  1. `DashboardScreen` renders Cashew-style side-by-side `ValueKey('cashew_income_card')` and `ValueKey('cashew_spent_card')` with `AnimatedMoneyBar`s, plus horizontal glanceable `ValueKey('cashew_budgets_strip')` showing active Monthly Budgets right on the home screen.
  2. `DashboardScreen` renders cleanly at `360×640 @ 1.2x` in both empty-budgets and populated-budgets states with color-coded transaction rows (`+` income vs `-` expense) and zero RenderFlex overflow.
- [ ] **Step 3.2 (Verify RED):** Run `flutter test test/v33_cashew_ux_polish_test.dart` and verify Phase 3 tests fail.
- [ ] **Step 3.3 (GREEN):** Implement the Cashew-inspired Dashboard refinement in `dashboard_screen.dart`.
- [ ] **Step 3.4 (Full Verification Gate):**
  - Run `flutter analyze --fatal-infos --fatal-warnings` (must be 0 issues).
  - Run full test suite `flutter test --concurrency=1` (every single test across the entire repo must pass; delete stray `cashio_vault.db*`).
  - Rebuild `build/web --release --no-web-resources-cdn --no-tree-shake-icons` and copy WASM/SW files.
- [ ] **Step 3.5 (Browser Check Gate #3 & Release Readiness):** Inspect the finished Cashew-inspired Cash-IO v3.3 live on `http://localhost:8095` via the `browser` subagent, share screenshots & full verification report with the user, and (once approved) commit and push so Vercel + Shorebird silently ship the update!
