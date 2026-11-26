import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/pop_up_route.dart';
import 'theme_controller.dart';
import 'tokens.dart';

class CashIOTheme {
  CashIOTheme._();

  static const PageTransitionsTheme _popUpTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: PopUpPageTransitionsBuilder(),
      TargetPlatform.iOS: PopUpPageTransitionsBuilder(),
      TargetPlatform.windows: PopUpPageTransitionsBuilder(),
      TargetPlatform.macOS: PopUpPageTransitionsBuilder(),
      TargetPlatform.linux: PopUpPageTransitionsBuilder(),
    },
  );

  static ThemeData get darkTheme => buildDarkTheme(ThemeController.instance.darkExtension);

  static ThemeData get lightTheme => buildLightTheme(ThemeController.instance.lightExtension);

  static ThemeData buildDarkTheme(CashIOThemeExtension ext) {
    final baseTextTheme = ThemeData.dark().textTheme;
    final muktaTheme = GoogleFonts.muktaTextTheme(baseTextTheme).apply(
      bodyColor: ext.textPrimary,
      displayColor: ext.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      pageTransitionsTheme: _popUpTransitions,
      extensions: [ext],
      scaffoldBackgroundColor: ext.bgPrimary,
      primaryColor: ext.accentGold,
      textTheme: muktaTheme,
      colorScheme: ColorScheme.dark(
        primary: ext.accentGold,
        secondary: ext.accentChampagne,
        surface: ext.bgSurface,
        error: ext.statusExpense,
        onPrimary: ext.bgPrimary,
        onSurface: ext.textPrimary,
        outline: ext.borderHairline,
      ),
      cardTheme: CardThemeData(
        color: ext.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.radiusMd),
          side: BorderSide(color: ext.borderHairline, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ext.textPrimary),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: ext.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ext.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ext.radiusLg)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ext.bgPrimary,
        selectedItemColor: ext.accentChampagne,
        unselectedItemColor: ext.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: ext.borderHairline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.bgSurfaceElevated,
        contentPadding: EdgeInsets.symmetric(
          horizontal: ext.space4,
          vertical: ext.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
          borderSide: BorderSide(color: ext.borderHairline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
          borderSide: BorderSide(color: ext.borderHairline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
          borderSide: BorderSide(color: ext.accentChampagne, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
          borderSide: BorderSide(color: ext.statusExpense, width: 1.0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ext.accentGold,
          foregroundColor: ext.bgPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
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
          foregroundColor: ext.textPrimary,
          side: BorderSide(color: ext.borderHairline, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
          textStyle: GoogleFonts.mukta(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ext.bgSurfaceElevated,
        selectedColor: ext.accentGold,
        disabledColor: ext.bgSurface,
        labelStyle: GoogleFonts.mukta(color: ext.textPrimary, fontSize: 12),
        secondaryLabelStyle: GoogleFonts.mukta(color: ext.bgPrimary, fontWeight: FontWeight.bold),
        padding: EdgeInsets.symmetric(horizontal: ext.space3, vertical: ext.space1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.radiusPill),
          side: BorderSide(color: ext.borderHairline, width: 1.0),
        ),
      ),
    );
  }

  static ThemeData buildLightTheme(CashIOThemeExtension ext) {
    final baseTextTheme = ThemeData.light().textTheme;
    final muktaTheme = GoogleFonts.muktaTextTheme(baseTextTheme).apply(
      bodyColor: ext.textPrimary,
      displayColor: ext.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      pageTransitionsTheme: _popUpTransitions,
      extensions: [ext],
      scaffoldBackgroundColor: ext.bgPrimary,
      primaryColor: ext.accentGold,
      textTheme: muktaTheme,
      colorScheme: ColorScheme.light(
        primary: ext.accentGold,
        secondary: ext.accentChampagne,
        surface: ext.bgSurface,
        error: ext.statusExpense,
        onPrimary: Colors.white,
        onSurface: ext.textPrimary,
        outline: ext.borderHairline,
      ),
      cardTheme: CardThemeData(
        color: ext.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.radiusMd),
          side: BorderSide(color: ext.borderHairline, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ext.textPrimary),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: ext.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ext.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ext.radiusLg)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ext.bgSurface,
        selectedItemColor: ext.accentGold,
        unselectedItemColor: ext.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: ext.borderHairline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.bgSurfaceElevated,
        contentPadding: EdgeInsets.symmetric(
          horizontal: ext.space4,
          vertical: ext.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
          borderSide: BorderSide(color: ext.borderHairline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
          borderSide: BorderSide(color: ext.borderHairline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
          borderSide: BorderSide(color: ext.accentGold, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ext.accentGold,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 14),
          elevation: 0,
        ),
      ),
    );
  }
}
