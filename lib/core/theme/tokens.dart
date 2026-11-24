import 'package:flutter/material.dart';
export 'theme_extension.dart';
export 'staggered_entrance.dart';

/// Cash-IO Design Tokens
/// Strictly enforces a 4pt grid, sleek Midnight Obsidian Slate palette,
/// luminous solar gold accents, slightly rounded modern luxury edges (10-22px),
/// and smooth cinematic staggered animations.
class CashIOTokens {
  CashIOTokens._();

  // ---------------------------------------------------------------------------
  // SPACING (4pt grid)
  // ---------------------------------------------------------------------------
  static const double space0 = 0.0;
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
  static const double space10 = 40.0;
  static const double space12 = 48.0;
  static const double space16 = 64.0;

  // ---------------------------------------------------------------------------
  // SLIGHTLY ROUNDED CORNERS (Refined Modern Luxury Standard: 6px - 22px)
  // ---------------------------------------------------------------------------
  static const double radiusNone = 0.0;
  static const double radiusXs = 6.0;
  static const double radiusSm = 10.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 22.0;
  static const double radiusXl = 28.0;
  static const double radiusPill = 999.0;
  static const double radiusFull = 999.0;

  // ---------------------------------------------------------------------------
  // USER-SPECIFIED PALETTE: Teal (#00ABB3), Charcoal (#3C4048), Silver (#B2B2B2), Off-White (#EAEAEA)
  // ---------------------------------------------------------------------------
  static const Color brand = Color(0xFF00ABB3);           // Primary Teal Turquoise
  static const Color brandLight = Color(0xFF4DD0D7);      // Light Cyan-Teal
  static const Color brandDark = Color(0xFF007E85);       // Deep Teal
  static const Color brandBg = Color(0x2600ABB3);         // Teal 15% opacity

  // ---------------------------------------------------------------------------
  // SEMANTIC FINANCIAL STATUS
  // ---------------------------------------------------------------------------
  static const Color income = Color(0xFF00ABB3);          // Teal Turquoise (Positive / Surplus)
  static const Color incomeBg = Color(0x2600ABB3);
  static const Color expense = Color(0xFFEF4444);         // Crisp Red (Negative / Outflow / Deficit)
  static const Color expenseBg = Color(0x26EF4444);
  static const Color asset = Color(0xFF00ABB3);           // Teal
  static const Color liability = Color(0xFFB2B2B2);       // Neutral Silver Grey

  // ---------------------------------------------------------------------------
  // DARK PALETTE (#3C4048 Charcoal, #EAEAEA Off-White, #B2B2B2 Silver)
  // ---------------------------------------------------------------------------
  static const Color darkBg = Color(0xFF22252A);             // Deep Charcoal Canvas
  static const Color darkSurface = Color(0xFF3C4048);        // Charcoal Slate Surface (#3C4048)
  static const Color darkSurfaceElevated = Color(0xFF494E57);// Elevated Slate Container
  static const Color darkBorder = Color(0x2BB2B2B2);         // Hairline Border from #B2B2B2
  static const Color darkBorderHighlight = Color(0x6600ABB3);// Teal Luminous Edge
  static const Color darkBorderSubtle = Color(0x1AB2B2B2);
  static const Color darkTextHigh = Color(0xFFEAEAEA);       // Crisp Off-White Text (#EAEAEA)
  static const Color darkTextMedium = Color(0xFFB2B2B2);     // Silver Grey Text (#B2B2B2)
  static const Color darkTextMuted = Color(0xFF8C929D);      // Muted Slate

  // ---------------------------------------------------------------------------
  // LIGHT PALETTE
  // ---------------------------------------------------------------------------
  static const Color lightBg = Color(0xFFEAEAEA);            // Off-White Background (#EAEAEA)
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF3F4F6);
  static const Color lightBorder = Color(0xFFB2B2B2);        // Silver Border (#B2B2B2)
  static const Color lightTextHigh = Color(0xFF3C4048);      // Charcoal Text (#3C4048)
  static const Color lightTextMedium = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFF9CA3AF);

  // ---------------------------------------------------------------------------
  // SMOOTH CINEMATIC ANIMATION DURATIONS
  // ---------------------------------------------------------------------------
  static const Duration animInstant = Duration(milliseconds: 90);
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animStandard = Duration(milliseconds: 380);
  static const Duration animSmooth = Duration(milliseconds: 600);
  static const Duration animSlow = Duration(milliseconds: 900);

  // ---------------------------------------------------------------------------
  // SECURITY & PIN SPECIFICATIONS
  // ---------------------------------------------------------------------------
  static const int pinLength = 6;
  static const int maxFailedAttempts = 5;
  static const Duration lockoutPenalty = Duration(seconds: 30);
}
