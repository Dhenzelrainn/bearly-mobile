import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BearlyColors {
  const BearlyColors._();
  static const brown950 = Color(0xFF2C1A14);
  static const brown900 = Color(0xFF4A2C20);
  static const brown800 = Color(0xFF5A2C1E);
  static const brown700 = Color(0xFF7A351D);
  static const brown500 = Color(0xFF936148);
  static const gold = Color(0xFF95601F);
  static const orange = Color(0xFFED7717);
  static const cream50 = Color(0xFFFFFCF7);
  static const cream100 = Color(0xFFFFF8EF);
  static const cream200 = Color(0xFFF7EAD8);
  static const cream300 = Color(0xFFF3E7D5);
  static const line = Color(0xFFE5CFB7);
  static const lineSoft = Color(0xFFEADFD2);
  static const text = Color(0xFF292421);
  static const muted = Color(0xFF6A625D);
  static const success = Color(0xFF497B52);
  static const error = Color(0xFFB42318);
}

class BearlyTheme {
  const BearlyTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: BearlyColors.brown900,
        brightness: Brightness.light,
        primary: BearlyColors.brown900,
        secondary: BearlyColors.gold,
        surface: BearlyColors.cream50,
        error: BearlyColors.error,
      ),
      scaffoldBackgroundColor: BearlyColors.cream50,
    );

    final poppins = GoogleFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: poppins.copyWith(
        displaySmall: poppins.displaySmall?.copyWith(
          color: BearlyColors.brown950,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1.08,
        ),
        headlineLarge: poppins.headlineLarge?.copyWith(
          color: BearlyColors.brown950,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        headlineMedium: poppins.headlineMedium?.copyWith(
          color: BearlyColors.brown950,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: poppins.titleLarge?.copyWith(
          color: BearlyColors.brown950,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: poppins.titleMedium?.copyWith(
          color: BearlyColors.text,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: poppins.bodyLarge?.copyWith(color: BearlyColors.text, height: 1.55),
        bodyMedium: poppins.bodyMedium?.copyWith(color: BearlyColors.text, height: 1.5),
        bodySmall: poppins.bodySmall?.copyWith(color: BearlyColors.muted, height: 1.45),
        labelLarge: poppins.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: BearlyColors.cream50,
        foregroundColor: BearlyColors.brown950,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          color: BearlyColors.brown950,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      dividerTheme: const DividerThemeData(color: BearlyColors.lineSoft, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: GoogleFonts.poppins(color: BearlyColors.muted, fontSize: 14),
        labelStyle: GoogleFonts.poppins(color: BearlyColors.muted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BearlyColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BearlyColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BearlyColors.brown700, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BearlyColors.brown900,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BearlyColors.brown900,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: BearlyColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BearlyColors.brown950,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
