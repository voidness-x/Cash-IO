# Cash-IO v3.2.0 — Intuitive UX, Floating Navigation, Theme Studio & Shorebird/Vercel OTA Design

**Date:** 2026-11-26  
**Scope:** Surgical, test-driven upgrade preserving existing encrypted storage, double-entry ledger core, biometric auth, and CRDT engine.

---

## 1. Intent & Why

Cash-IO's core ledger and security are solid, but real-world testing (including a first-time user trying the app) surfaced five concrete friction points:
1. **Confusing jargon & unclear money flow:** Terms like *"Chart of Accounts"*, *"Envelope Budgeting Studio"*, *"Available to Assign"*, and *"Double-Entry Postings"* confuse non-accountants, and spending money didn't visibly explain or connect to budgets.
2. **Navigation & visual hierarchy:** The edge-to-edge bottom bar feels utilitarian and puts Dashboard on the far left instead of elevating it as the centerpiece home screen; only the Budgets card had the signature accent glow; money bars rendered statically instead of animating left-to-right on load.
3. **Phantom `"default_profile"` vault bug:** Opening the Vault Switcher shows an un-openable `"Personal Vault"` (`default_profile`) that the user never created because `VaultRepository.loadPersistentVault()` snapshots the placeholder `_profileId` before loading the real profile.
4. **Fixed color theme:** Users cannot customize Cash-IO's theme colors or pick alternate palettes while keeping the original Cyber Teal theme safely archived.
5. **In-app updates without manual browser downloads:** Updates should happen inside the app (Android silent Dart/UI patches via Shorebird) while also offering an instant auto-updating Web/iOS PWA hosted on Vercel.

---

## 2. Goals, Non-Goals & Anti-Goals

### Goals
- **Surgical changes only:** Modify only the screens, navigation shell, theme layer, vault switcher repository bug, and update/deployment layer—do **not** rewrite working database, crypto, receipt, FX, or CRDT internals.
- **Strict TDD:** Every behavior change and bug fix starts with a failing behavioral test (`RED`), minimal passing implementation (`GREEN`), and clean refactor.
- **True in-app updates (Choice 1):**
  - Integrate **Shorebird Code Push** (`shorebird_code_push` + `shorebird.yaml` + GitHub Actions patch workflow) inside `UpdateReceiverService` / `UpdateReceiverSheet` so Android APK builds download and apply Dart/UI patches directly inside the app with zero external browser downloads.
  - Add **`vercel.json`** + clean Web PWA config so pushing to `main` deploys an auto-updating Web/iOS PWA on Vercel with persistent IndexedDB storage.
- **Floating Bottom Nav + Raised Center `O` Dashboard:**
  - Floating rounded pill navigation bar detached from the bottom edge (`16px` horizontal/bottom safe-area margins, frosted glass surface, soft elevation).
  - 5 tabs ordered: **`Wallets`** (`0`) | **`Budgets`** (`1`) | **`[Raised Center Cash-IO "O" Home]`** (`2`, default active) | **`Forecast`** (`3`) | **`Settings`** (`4`).
  - Center Dashboard button rises above the pill bar as a glowing circular medallion rendering the exact spinning **`O` ring mark** from `CashIOLogo` (`VaultOMark`), with a subtle upward pop-in transition when returning to Home.
- **Left-to-Right Filling Money Bars (`AnimatedMoneyBar`):**
  - Reusable widget using `TweenAnimationBuilder<double>` (`0.0 → value`, `700ms`, `Curves.easeOutCubic`, instant when `MediaQuery.disableAnimationsOf(context)` is true) applied to all money progress bars: Dashboard 30-Day Cashflow, Financial Guidance 50/30/20 split, Savings Goal progress bars, Wallet share bars, and Monthly Budget bars.
- **Consistent Hero Money Glow Across Screens:**
  - Extract a shared `HeroGlowCard` / glow decoration helper matching the signature accent shadow + luminous border from the Budgets hero card, applied consistently to the top summary money card on **Dashboard**, **Wallets**, **Budgets**, and **Forecast**.
- **Brother-Proof Simplified UX & Hierarchy:**
  - Clear 3-tier hierarchy on every screen: **1) Glowing Hero Summary Card → 2) Primary Plain-Language Actions → 3) Clean Categorized List**.
  - Plain everyday naming across the UI:
    - `Accounts` → **`Wallets`** (`Cash Wallet`, `Bank Account`, easy 1-tap **`Move Money`** between wallets)
    - `Envelopes` → **`Budgets`** (clear 1-line helper: *"Set a monthly spending limit for each category so you always know what's left."*, with **`Safe to Budget`** instead of cryptic accounting labels, and direct **`+ Add Limit`** / **`Move Limit`** actions)
    - `Spend Cash` sheet optionally lets the user link an expense to a Monthly Budget so spending visibly updates the budget bar immediately.
    - `Dashboard` focuses on **Total Money**, **+ Add Money**, **− Spend**, **⇄ Move**, **Recent Activity**, and clean segmented views (**Insights** | **Savings** | **Breakdown**).
    - `Forecast` uses plain terms (**Money Runway**, **Daily Spending**, **Expected Balance**) while preserving the interactive 180-day curve.
- **Fix Phantom Default Vault Bug:**
  - Prevent `VaultRepository` from snapshotting or listing the uninitialized `'default_profile'` placeholder when real profiles exist; delete/ignore orphan profiles without valid credentials in `getAvailableProfiles()`.
- **Preserve Original Theme + Theme Customizer in Settings:**
  - Save an untouched snapshot copy of the original theme files under `lib/core/theme/presets/original_theme_backup.dart` (preserving exact original `tokens.dart` / `theme_extension.dart` / `app_theme.dart` values as **"Cyber Teal (Original)"**).
  - Add `ThemeController` (persisted via `HardwareVaultService` / secure storage) wired into `CashIOApp` (`main.dart`) + a **Theme & Colors** section in Settings offering:
    - **7 curated presets:** *Cyber Teal (Original)*, *Emerald Vault*, *Ocean Sapphire*, *Solar Amber*, *Royal Amethyst*, *Rose Quartz*, and *Midnight Mono*
    - **Custom Color Picker:** User-selectable Accent Color, Background Tone (Dark / Midnight / Light), and instant live preview + 1-tap *"Reset to Original Theme"*.

### Non-Goals / Anti-Goals
- Do **not** rewrite `DatabaseHelper`, SQLite schema, AES-256-GCM encryption, BIP-39 recovery, or CRDT sync logic.
- Do **not** break any existing 72 automated tests (update only assertions that explicitly test old tab indices or old renamed labels if needed, keeping double-entry and security invariants untouched).
- Do **not** introduce layout overflow on `360×640` phones at `1.2x` font scale.

---

## 3. Navigation & Hierarchy Visual Sketch

```text
+--------------------------------------------------+
| CASH-IO   [Personal Vault v]          [OTA] [Vlt]|
+--------------------------------------------------+
|  ╭────────────────────────────────────────────╮  |
|  │  ✦ TOTAL MONEY  (Accent Glow Card)         │  |
|  │  250,000 IQD                  ≈ $190.84    │  |
|  │  [ + Add ]   [ - Spend ]   [ ⇄ Move ]      │  |
|  │  Cash & Bank: 250,000  |  Owed: 0          │  |
|  ╰────────────────────────────────────────────╯  |
|  [ Insights ]  [ Savings ]  [ Breakdown ]        |
|  ╭────────────────────────────────────────────╮  |
|  │  THIS MONTH'S FLOW                         │  |
|  │  [████████████░░░░░░] <-- fills L->R       │  |
|  ╰────────────────────────────────────────────╯  |
|  RECENT ACTIVITY                                 |
|  ...                                             |
|                                                  |
|                    ╭─────────╮                   |
|  ╭─────────────────┤  ((O))  ├────────────────╮  |
|  │ 💼       📊     │  Home   │   📈      ⚙️   │  |
|  │Wallets  Budgets │ (PopUp) │ Forecast Settings │
|  ╰─────────────────┴─────────┴────────────────╯  |
+--------------------------------------------------+
```

---

## 4. Approaches Considered (In-App Updates)

| Approach | Hosting Needed | Pros | Trade-offs | Decision |
|---|---|---|---|---|
| **1. Shorebird (Android APK) + Vercel (Web/iOS PWA)** | Free Shorebird patch server + Free Vercel static deploy | Silent in-app Dart/UI patches on Android (keeps hardware Fingerprint & SQLite) + instant auto-updating Web/iOS PWA on Vercel | Requires one-time free Shorebird account + `SHOREBIRD_TOKEN` secret for live patches; Kotlin changes still use APK | **Selected** |
| **2. Shorebird Only** | Free Shorebird | Native Android silent patches | No instant hosted Web/iOS PWA | Rejected |
| **3. Vercel PWA Only** | Free Vercel | Zero APKs ever | Loses native Android hardware `BiometricPrompt` fingerprint | Rejected |

---

## 5. Surgical File Map (Minimal Footprint)

- **Preserve & Theme Engine:**
  - Create: `lib/core/theme/original_theme_snapshot.dart` (archived untouched Cyber Teal original palette)
  - Create: `lib/core/theme/theme_controller.dart` (presets + custom color picker state + persistence)
  - Create: `lib/features/settings/presentation/theme_customizer_sheet.dart`
  - Modify: `lib/core/theme/theme_extension.dart` (`accent => accentGold`, helper `heroGlowShadows`), `lib/core/theme/app_theme.dart` (build `ThemeData` dynamically from `CashIOThemePreset`), `lib/main.dart` (listen to `ThemeController`).
- **Reusable UI Primitives:**
  - Create: `lib/core/widgets/animated_money_bar.dart` (left-to-right animated fill bar + segmented multi-bar with reduced-motion support)
  - Modify: `lib/core/widgets/cashio_logo.dart` (export reusable `VaultOMark` widget for the floating center Dashboard button).
- **Floating Navigation:**
  - Modify: `lib/features/navigation/presentation/main_scaffold.dart` (floating pill dock, 5 tabs with Dashboard at index `2` popping up above the dock with `VaultOMark`).
- **Phantom Vault Bug Fix:**
  - Modify: `lib/core/storage/vault_repository.dart` (never snapshot/list uninitialized `'default_profile'`, track `_hasLoadedRealProfile`, clean `getAvailableProfiles()`).
- **Simplified Hierarchy, Glow & Animated Bars:**
  - Modify: `lib/features/dashboard/presentation/dashboard_screen.dart` (Hero glow, `+ Add` / `− Spend` / `⇄ Move`, animated bars, plain labels)
  - Modify: `lib/features/dashboard/presentation/cash_action_sheets.dart` (add optional budget link on `SpendCashSheet` + reusable `MoveMoneySheet`)
  - Modify: `lib/features/accounts/presentation/accounts_screen.dart` (Hero glow, plain "Wallets" copy, animated share bars)
  - Modify: `lib/features/envelopes/presentation/envelopes_screen.dart` (Hero glow, plain "Monthly Budgets" + 1-line explainer, animated fill bars)
  - Modify: `lib/features/forecast/presentation/forecast_screen.dart` (Hero glow, simplified plain-English labels)
  - Modify: `lib/features/advisory/presentation/financial_advisory_card.dart` & `lib/features/savings/presentation/savings_goals_deck.dart` (animated left-to-right bars)
  - Modify: `lib/features/settings/presentation/settings_screen.dart` (add **Theme & Colors** tile + clean simplified section copy).
- **Shorebird + Vercel OTA:**
  - Create: `shorebird.yaml`, `vercel.json`, `.github/workflows/shorebird_patch.yml`
  - Modify: `pubspec.yaml` (add `shorebird_code_push`), `lib/core/services/update_receiver_service.dart` & `lib/features/settings/presentation/update_receiver_sheet.dart` (check/download/apply Shorebird in-app patches first, falling back cleanly to GitHub Releases for native binary upgrades).
- **Tests (TDD):**
  - Create: `test/v32_redesign_theme_vault_nav_ota_test.dart` (phantom vault regression, ThemeController presets/custom colors/persistence, Floating Nav center Dashboard & `VaultOMark`, `AnimatedMoneyBar` fill animation + reduced-motion, Spend-to-Budget link, Shorebird patch flow).

---

## 6. Constraints & Review Focus

- Preserve exact `360×640 @ 1.2x` zero-overflow guarantee across all screens (including floating bottom nav clearance via `bottom: 112` list padding so no card or FAB hides behind the floating dock).
- Preserve `flutter analyze --fatal-infos --fatal-warnings` (`0` issues) and all existing 72+ tests.
- Keep `Cash-IO` strictly zero-telemetry (`vercel.json` serves static files only; Shorebird only checks patch version when requested).
