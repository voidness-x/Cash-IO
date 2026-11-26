# Cash-IO v3.3 — Cashew-Inspired UX, Theme Studio Fixes & Pop-Up Polish Design

**Date:** 2026-11-26  
**Scope:** Surgical, TDD-driven UI/UX upgrade preserving Cash-IO's encrypted SQLite vault, double-entry ledger, biometrics, and Shorebird/GitHub OTA pipelines untouched.

## Intent & Goals
1. **Eliminate visual defects observed on physical Android device:**
   - Optically align the spinning `O` in `CASH-IO` level with `CASH-I`.
   - Restore clean vertical spacing between the empty Savings Goals card and the Spare-Change Round-Ups card.
   - Fix `Theme & Colors` sheet Light Mode switching (whole sheet background updates live, not just inner cards), add top status-bar clearance (`SafeArea`), and enforce an explicit **Confirm & Apply** vs **Cancel** draft workflow so users cannot exit with unconfirmed changes.
2. **New Default Brand Look (Indigo Purple + Obsidian):**
   - Default theme preset, default logo accent, Android launch splash screen, and Web loader use **Indigo Purple (`#6366F1`, distinct from Royal Amethyst `#8B5CF6`)** with **Obsidian (`#0B0F17` canvas / `#161D2B` surface)**.
   - Original Cyber Teal palette remains preserved untouched in `original_theme_snapshot.dart` and selectable in presets.
   - `FrostedScaffold` binds dynamically to `context.tokens.bgPrimary` and `context.tokens.accentGold`.
3. **Integrated Floating `"O"` Dock & Pop-Up Transitions (Zero Sliding):**
   - Shrink the center Dashboard `"O"` medallion from `62px` protruding `-18px` to a sleek `48px` integrated into the floating pill bar.
   - Replace all slide transitions (`MainScaffold` tab switches + `MaterialPageRoute` page pushes) with smooth **scale + fade pop-up** animations (`Curves.easeOutCubic`, respecting reduced motion).
4. **Cashew-Inspired Cleaner, Less Cluttered UX:**
   - Streamline Dashboard into Cashew's calm hierarchy: Glowing Total Balance card → Side-by-side **Income vs. Spent** cards with animated bars → Horizontal glanceable **Monthly Budgets** strip → Clean color-coded **Recent Activity** feed (with Insights/Savings/Breakdown accessible cleanly without visual clutter).

## Non-Goals & Constraints
- Do **not** rewrite `VaultRepository`, `DatabaseHelper`, `HardwareVaultService`, or `UpdateReceiverService`.
- Maintain 100% overflow safety at `360×640 @ 1.2x` text scale and respect `MediaQuery.disableAnimationsOf(context)`.
- Every phase follows strict Red → Green → Refactor TDD, passes `flutter analyze --fatal-infos --fatal-warnings`, rebuilds Web (`http://localhost:8095`), and pauses for live browser verification by the user.

## Approaches Considered
- **Approach A (Chosen — Surgical 3-Phase Upgrade):** Keep existing clean data layer and widgets, apply targeted fixes to `CashIOLogo`, `SavingsGoalsDeck`, `ThemeController`, `ThemeCustomizerSheet`, `FrostedScaffold`, `MainScaffold`, `PopUpPageRoute`, and `DashboardScreen` across 3 browser-verified phases.
- **Approach B (Rejected — Ground-Up UI Rewrite):** Rewriting all 5 screens from scratch violates the minimal-change rule and risks regressions in already-tested sheets and vault flows.
