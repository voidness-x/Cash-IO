import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class CashIOTheme {
  CashIOTheme._();

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final muktaTheme = GoogleFonts.muktaTextTheme(baseTextTheme).apply(
      bodyColor: CashIOTokens.darkTextHigh,
      displayColor: CashIOTokens.darkTextHigh,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: const [CashIOThemeExtension.dark],
      scaffoldBackgroundColor: CashIOTokens.darkBg,
      primaryColor: CashIOTokens.brand,
      textTheme: muktaTheme,
      colorScheme: const ColorScheme.dark(
        primary: CashIOTokens.brand,          // Solar Gold
        secondary: CashIOTokens.brandLight,   // Champagne
        surface: CashIOTokens.darkSurface,
        error: CashIOTokens.expense,
        onPrimary: CashIOTokens.darkBg,
        onSurface: CashIOTokens.darkTextHigh,
        outline: CashIOTokens.darkBorder,
      ),
      cardTheme: CardThemeData(
        color: CashIOTokens.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusMd),
          side: const BorderSide(color: CashIOTokens.darkBorder, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: CashIOTokens.darkTextHigh),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: CashIOTokens.darkTextHigh,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CashIOTokens.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(CashIOTokens.radiusLg)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CashIOTokens.darkBg,
        selectedItemColor: CashIOTokens.brandLight,
        unselectedItemColor: CashIOTokens.darkTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: CashIOTokens.darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CashIOTokens.darkSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CashIOTokens.space4,
          vertical: CashIOTokens.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          borderSide: const BorderSide(color: CashIOTokens.darkBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          borderSide: const BorderSide(color: CashIOTokens.darkBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          borderSide: const BorderSide(color: CashIOTokens.brandLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          borderSide: const BorderSide(color: CashIOTokens.expense, width: 1.0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CashIOTokens.brand,       // Solar Gold
          foregroundColor: CashIOTokens.darkBg,      // Dark text on gold
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.8,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CashIOTokens.darkTextHigh,
          side: const BorderSide(color: CashIOTokens.darkBorder, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          ),
          textStyle: GoogleFonts.mukta(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CashIOTokens.darkSurfaceElevated,
        selectedColor: CashIOTokens.brand,
        disabledColor: CashIOTokens.darkSurface,
        labelStyle: GoogleFonts.mukta(color: CashIOTokens.darkTextHigh, fontSize: 12),
        secondaryLabelStyle: GoogleFonts.mukta(color: CashIOTokens.darkBg, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: CashIOTokens.space3, vertical: CashIOTokens.space1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusPill),
          side: const BorderSide(color: CashIOTokens.darkBorder, width: 1.0),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    final muktaTheme = GoogleFonts.muktaTextTheme(baseTextTheme).apply(
      bodyColor: CashIOTokens.lightTextHigh,
      displayColor: CashIOTokens.lightTextHigh,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: const [CashIOThemeExtension.light],
      scaffoldBackgroundColor: CashIOTokens.lightBg,
      primaryColor: CashIOTokens.brandDark,
      textTheme: muktaTheme,
      colorScheme: const ColorScheme.light(
        primary: CashIOTokens.brandDark,
        secondary: CashIOTokens.brand,
        surface: CashIOTokens.lightSurface,
        error: CashIOTokens.expense,
        onPrimary: Colors.white,
        onSurface: CashIOTokens.lightTextHigh,
        outline: CashIOTokens.lightBorder,
      ),
      cardTheme: CardThemeData(
        color: CashIOTokens.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusMd),
          side: const BorderSide(color: CashIOTokens.lightBorder, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: CashIOTokens.lightTextHigh),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: CashIOTokens.lightTextHigh,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CashIOTokens.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(CashIOTokens.radiusLg)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CashIOTokens.lightSurface,
        selectedItemColor: CashIOTokens.brandDark,
        unselectedItemColor: CashIOTokens.lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: CashIOTokens.lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CashIOTokens.lightSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CashIOTokens.space4,
          vertical: CashIOTokens.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          borderSide: const BorderSide(color: CashIOTokens.lightBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          borderSide: const BorderSide(color: CashIOTokens.lightBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          borderSide: const BorderSide(color: CashIOTokens.brandDark, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CashIOTokens.brandDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          ),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 14),
          elevation: 0,
        ),
      ),
    );
  }
}
