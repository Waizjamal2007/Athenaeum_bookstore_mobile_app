import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const ink = Color(0xFF171411);
  static const paper = Color(0xFFF7F3EC);
  static const card = Color(0xFFFFFCF7);
  static const muted = Color(0xFF7D746B);
  static const line = Color(0xFFE1D9CF);
  static const accent = Color(0xFFA94C2C);
  static const softAccent = Color(0xFFF1E0D8);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
    );

    return _common(base, paper, card, ink, muted, line, softAccent);
  }

  static ThemeData dark() {
    const bg = Color(0xFF11100F);
    const surface = Color(0xFF1B1917);
    const darkText = Color(0xFFF5EFE8);
    const darkMuted = Color(0xFFB8AEA4);
    const darkLine = Color(0xFF39332E);
    const darkSoft = Color(0xFF33241E);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: bg,
      ),
    );

    return _common(base, bg, surface, darkText, darkMuted, darkLine, darkSoft);
  }

  static ThemeData _common(
    ThemeData base,
    Color background,
    Color surface,
    Color text,
    Color mutedText,
    Color border,
    Color soft,
  ) {
    return base.copyWith(
      scaffoldBackgroundColor: background,

      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: text),
        bodyMedium: GoogleFonts.inter(fontSize: 13, color: text),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      dividerTheme: DividerThemeData(color: border),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: soft,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          TextStyle(fontSize: 11, color: text),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: TextStyle(color: background),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),

          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),

          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),

          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),

          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
