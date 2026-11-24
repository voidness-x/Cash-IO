import 'dart:ui';
import 'package:flutter/material.dart';

/// Cash-IO Modern Midnight Obsidian Titanium & Electric Gold/Cyan Design Tokens
/// Features slightly rounded modern curves (10-22px) and high-contrast fintech aesthetics.
@immutable
class CashIOThemeExtension extends ThemeExtension<CashIOThemeExtension> {
  // ---------------------------------------------------------------------------
  // SURFACES & BACKGROUNDS
  // ---------------------------------------------------------------------------
  final Color bgPrimary;
  final Color bgSurface;
  final Color bgSurfaceElevated;
  final Color bgSurfaceGlass;

  Color get bgCanvas => bgPrimary;
  Color get accent => const Color(0xFF00ABB3);

  // ---------------------------------------------------------------------------
  // ARCHITECTURAL BORDERS
  // ---------------------------------------------------------------------------
  final Color borderHairline;
  final Color borderHighlight;
  final Color borderSubtle;

  // ---------------------------------------------------------------------------
  // LUXURY ACCENTS (Solar Amber Gold & Sunlight Champagne)
  // ---------------------------------------------------------------------------
  final Color accentGold;
  final Color accentChampagne;
  final Color accentBrass;
  final Color accentGoldBg;

  // ---------------------------------------------------------------------------
  // FINANCIAL STATUS COLORS
  // ---------------------------------------------------------------------------
  final Color statusIncome;
  final Color statusIncomeBg;
  final Color statusExpense;
  final Color statusExpenseBg;
  final Color statusNeutral;
  final Color statusLiability;

  // ---------------------------------------------------------------------------
  // TYPOGRAPHY COLORS
  // ---------------------------------------------------------------------------
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // ---------------------------------------------------------------------------
  // MODERN SLIGHTLY ROUNDED CORNER RADII (Refined Luxury Standard)
  // ---------------------------------------------------------------------------
  final double radiusNone;
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusPill;

  // ---------------------------------------------------------------------------
  // 4PT SPATIAL GRID
  // ---------------------------------------------------------------------------
  final double space1;
  final double space2;
  final double space3;
  final double space4;
  final double space5;
  final double space6;
  final double space8;
  final double space10;
  final double space12;

  const CashIOThemeExtension({
    required this.bgPrimary,
    required this.bgSurface,
    required this.bgSurfaceElevated,
    required this.bgSurfaceGlass,
    required this.borderHairline,
    required this.borderHighlight,
    required this.borderSubtle,
    required this.accentGold,
    required this.accentChampagne,
    required this.accentBrass,
    required this.accentGoldBg,
    required this.statusIncome,
    required this.statusIncomeBg,
    required this.statusExpense,
    required this.statusExpenseBg,
    required this.statusNeutral,
    required this.statusLiability,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    this.radiusNone = 0.0,
    this.radiusXs = 6.0,
    this.radiusSm = 10.0,
    this.radiusMd = 16.0,
    this.radiusLg = 22.0,
    this.radiusPill = 999.0,
    this.space1 = 4.0,
    this.space2 = 8.0,
    this.space3 = 12.0,
    this.space4 = 16.0,
    this.space5 = 20.0,
    this.space6 = 24.0,
    this.space8 = 32.0,
    this.space10 = 40.0,
    this.space12 = 48.0,
  });

  // ---------------------------------------------------------------------------
  // USER-SPECIFIED PALETTE: Teal (#00ABB3), Charcoal (#3C4048), Silver (#B2B2B2), Off-White (#EAEAEA)
  // ---------------------------------------------------------------------------
  static const CashIOThemeExtension dark = CashIOThemeExtension(
    bgPrimary: Color(0xFF22252A),             // Deep Charcoal Canvas
    bgSurface: Color(0xFF3C4048),             // Charcoal Slate Surface (#3C4048)
    bgSurfaceElevated: Color(0xFF494E57),     // Elevated Slate Container
    bgSurfaceGlass: Color(0xCC3C4048),        // Frosted Slate Glass
    borderHairline: Color(0x2BB2B2B2),        // Hairline Border from #B2B2B2
    borderHighlight: Color(0x6600ABB3),       // Teal Luminous Edge
    borderSubtle: Color(0x1AB2B2B2),          // Subdued Divider
    accentGold: Color(0xFF00ABB3),            // Teal Turquoise Primary Accent (#00ABB3)
    accentChampagne: Color(0xFF4DD0D7),       // Luminous Light Aqua Teal
    accentBrass: Color(0xFF007E85),           // Deep Cyan Accent
    accentGoldBg: Color(0x2600ABB3),          // Teal 15% opacity
    statusIncome: Color(0xFF00ABB3),          // Teal (Surplus / Positive Assets)
    statusIncomeBg: Color(0x2600ABB3),        // Teal 15% opacity
    statusExpense: Color(0xFFEF4444),         // Crisp Red (Negative / Outflow / Deficit)
    statusExpenseBg: Color(0x26EF4444),       // Red 15% opacity
    statusNeutral: Color(0xFFB2B2B2),         // Silver Grey (#B2B2B2)
    statusLiability: Color(0xFFB2B2B2),       // Silver Grey
    textPrimary: Color(0xFFEAEAEA),           // Crisp Off-White (#EAEAEA)
    textSecondary: Color(0xFFB2B2B2),         // Silver Grey (#B2B2B2)
    textTertiary: Color(0xFF8C929D),          // Subdued Slate
  );

  // ---------------------------------------------------------------------------
  // LIGHT TITANIUM SLATE (LIGHT THEME)
  // ---------------------------------------------------------------------------
  static const CashIOThemeExtension light = CashIOThemeExtension(
    bgPrimary: Color(0xFFEAEAEA),             // Off-White Canvas (#EAEAEA)
    bgSurface: Color(0xFFFFFFFF),             // Pure White Card Surface
    bgSurfaceElevated: Color(0xFFF3F4F6),     // Elevated Light Container
    bgSurfaceGlass: Color(0xE6FFFFFF),        // Frosted Light Glass
    borderHairline: Color(0xFFB2B2B2),        // Silver Border (#B2B2B2)
    borderHighlight: Color(0xFF00ABB3),       // Teal Highlight Edge
    borderSubtle: Color(0xFFE0E0E0),          // Subdued Divider
    accentGold: Color(0xFF00ABB3),            // Teal Primary Accent
    accentChampagne: Color(0xFF007E85),       // Deep Teal
    accentBrass: Color(0xFF005B60),           // Dark Teal
    accentGoldBg: Color(0x1A00ABB3),
    statusIncome: Color(0xFF00ABB3),          // Teal
    statusIncomeBg: Color(0x1A00ABB3),
    statusExpense: Color(0xFFDC2626),         // Crisp Red
    statusExpenseBg: Color(0x1ADC2626),
    statusNeutral: Color(0xFF6B7280),
    statusLiability: Color(0xFF6B7280),
    textPrimary: Color(0xFF3C4048),           // Charcoal Text (#3C4048)
    textSecondary: Color(0xFF6B7280),         // Medium Slate
    textTertiary: Color(0xFF9CA3AF),          // Subdued Caption
  );

  @override
  CashIOThemeExtension copyWith({
    Color? bgPrimary,
    Color? bgSurface,
    Color? bgSurfaceElevated,
    Color? bgSurfaceGlass,
    Color? borderHairline,
    Color? borderHighlight,
    Color? borderSubtle,
    Color? accentGold,
    Color? accentChampagne,
    Color? accentBrass,
    Color? accentGoldBg,
    Color? statusIncome,
    Color? statusIncomeBg,
    Color? statusExpense,
    Color? statusExpenseBg,
    Color? statusNeutral,
    Color? statusLiability,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    double? radiusNone,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusPill,
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space5,
    double? space6,
    double? space8,
    double? space10,
    double? space12,
  }) {
    return CashIOThemeExtension(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSurface: bgSurface ?? this.bgSurface,
      bgSurfaceElevated: bgSurfaceElevated ?? this.bgSurfaceElevated,
      bgSurfaceGlass: bgSurfaceGlass ?? this.bgSurfaceGlass,
      borderHairline: borderHairline ?? this.borderHairline,
      borderHighlight: borderHighlight ?? this.borderHighlight,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accentGold: accentGold ?? this.accentGold,
      accentChampagne: accentChampagne ?? this.accentChampagne,
      accentBrass: accentBrass ?? this.accentBrass,
      accentGoldBg: accentGoldBg ?? this.accentGoldBg,
      statusIncome: statusIncome ?? this.statusIncome,
      statusIncomeBg: statusIncomeBg ?? this.statusIncomeBg,
      statusExpense: statusExpense ?? this.statusExpense,
      statusExpenseBg: statusExpenseBg ?? this.statusExpenseBg,
      statusNeutral: statusNeutral ?? this.statusNeutral,
      statusLiability: statusLiability ?? this.statusLiability,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      radiusNone: radiusNone ?? this.radiusNone,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusPill: radiusPill ?? this.radiusPill,
      space1: space1 ?? this.space1,
      space2: space2 ?? this.space2,
      space3: space3 ?? this.space3,
      space4: space4 ?? this.space4,
      space5: space5 ?? this.space5,
      space6: space6 ?? this.space6,
      space8: space8 ?? this.space8,
      space10: space10 ?? this.space10,
      space12: space12 ?? this.space12,
    );
  }

  @override
  CashIOThemeExtension lerp(ThemeExtension<CashIOThemeExtension>? other, double t) {
    if (other is! CashIOThemeExtension) return this;

    return CashIOThemeExtension(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgSurfaceElevated: Color.lerp(bgSurfaceElevated, other.bgSurfaceElevated, t)!,
      bgSurfaceGlass: Color.lerp(bgSurfaceGlass, other.bgSurfaceGlass, t)!,
      borderHairline: Color.lerp(borderHairline, other.borderHairline, t)!,
      borderHighlight: Color.lerp(borderHighlight, other.borderHighlight, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
      accentChampagne: Color.lerp(accentChampagne, other.accentChampagne, t)!,
      accentBrass: Color.lerp(accentBrass, other.accentBrass, t)!,
      accentGoldBg: Color.lerp(accentGoldBg, other.accentGoldBg, t)!,
      statusIncome: Color.lerp(statusIncome, other.statusIncome, t)!,
      statusIncomeBg: Color.lerp(statusIncomeBg, other.statusIncomeBg, t)!,
      statusExpense: Color.lerp(statusExpense, other.statusExpense, t)!,
      statusExpenseBg: Color.lerp(statusExpenseBg, other.statusExpenseBg, t)!,
      statusNeutral: Color.lerp(statusNeutral, other.statusNeutral, t)!,
      statusLiability: Color.lerp(statusLiability, other.statusLiability, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      radiusNone: lerpDouble(radiusNone, other.radiusNone, t)!,
      radiusXs: lerpDouble(radiusXs, other.radiusXs, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t)!,
      space1: lerpDouble(space1, other.space1, t)!,
      space2: lerpDouble(space2, other.space2, t)!,
      space3: lerpDouble(space3, other.space3, t)!,
      space4: lerpDouble(space4, other.space4, t)!,
      space5: lerpDouble(space5, other.space5, t)!,
      space6: lerpDouble(space6, other.space6, t)!,
      space8: lerpDouble(space8, other.space8, t)!,
      space10: lerpDouble(space10, other.space10, t)!,
      space12: lerpDouble(space12, other.space12, t)!,
    );
  }
}

/// Convenience context extension for instant typed access to design tokens
extension CashIOThemeContext on BuildContext {
  CashIOThemeExtension get tokens =>
      Theme.of(this).extension<CashIOThemeExtension>() ?? CashIOThemeExtension.dark;
}
