import 'package:flutter/material.dart';

/// Archived snapshot of Cash-IO's original Cyber Teal theme files
/// (`tokens.dart`, `theme_extension.dart`, `app_theme.dart` as of v3.1.1).
/// Preserved untouched so the user can always restore or reference the original palette.
class OriginalCashIOThemeSnapshot {
  OriginalCashIOThemeSnapshot._();

  static const String presetId = 'cyber_teal_original';
  static const String presetName = 'Cyber Teal (Original)';

  // Original Brand & Semantic Colors
  static const Color brand = Color(0xFF00ABB3);
  static const Color brandLight = Color(0xFF4DD0D7);
  static const Color brandDark = Color(0xFF007E85);
  static const Color expense = Color(0xFFEF4444);

  // Original Dark Surfaces & Text
  static const Color darkBg = Color(0xFF22252A);
  static const Color darkSurface = Color(0xFF3C4048);
  static const Color darkSurfaceElevated = Color(0xFF494E57);
  static const Color darkSurfaceGlass = Color(0xCC3C4048);
  static const Color darkBorder = Color(0x2BB2B2B2);
  static const Color darkBorderHighlight = Color(0x6600ABB3);
  static const Color darkBorderSubtle = Color(0x1AB2B2B2);
  static const Color darkTextHigh = Color(0xFFEAEAEA);
  static const Color darkTextMedium = Color(0xFFB2B2B2);
  static const Color darkTextMuted = Color(0xFF8C929D);

  // Original Light Surfaces & Text
  static const Color lightBg = Color(0xFFEAEAEA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF3F4F6);
  static const Color lightSurfaceGlass = Color(0xE6FFFFFF);
  static const Color lightBorder = Color(0xFFB2B2B2);
  static const Color lightBorderSubtle = Color(0xFFE0E0E0);
  static const Color lightTextHigh = Color(0xFF3C4048);
  static const Color lightTextMedium = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFF9CA3AF);
}
