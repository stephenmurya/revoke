import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color black = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF121212);
  static const Color orange = Color(0xFFFF4500);
  static const Color deepRed = Color(0xFFCF6679);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFB0B0B0);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        primary: orange,
        surface: darkGrey,
        onPrimary: white,
        onSurface: white,
        error: deepRed,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        bodyLarge: GoogleFonts.jetBrainsMono(fontSize: 16, color: white),
        bodyMedium: GoogleFonts.jetBrainsMono(fontSize: 14, color: lightGrey),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: white,
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: orange, width: 2),
        ),
        labelStyle: GoogleFonts.jetBrainsMono(color: lightGrey),
        hintStyle: GoogleFonts.jetBrainsMono(color: lightGrey.withOpacity(0.5)),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: black,
        selectedItemColor: orange,
        unselectedItemColor: lightGrey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Chip decoration
  static BoxDecoration chipDecoration({Color? borderColor, Color? fillColor}) {
    return BoxDecoration(
      color: fillColor ?? Colors.transparent,
      border: Border.all(color: borderColor ?? white, width: 1.5),
      borderRadius: BorderRadius.circular(20),
    );
  }
}
