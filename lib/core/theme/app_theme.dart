import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color black = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF121212);
  static const Color orange = Color(0xFFFF4500);
  static const Color deepRed = Color(0xFFFF3131); // Pure Red for Revoke
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF757575);
  static const Color lightGrey = Color(0xFFB0B0B0);

  // Trend Colors
  static const Color trendUp = Color(0xFF00FF41); // Matrix Green
  static const Color trendDown = Color(0xFFFF3131);

  static InputDecoration defaultInputDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: darkGrey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: orange, width: 2),
      ),
      labelStyle: bodyMedium.copyWith(
        color: grey,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
      floatingLabelStyle: bodyMedium.copyWith(
        color: orange,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: bodyMedium.copyWith(
        color: lightGrey.withOpacity(0.6),
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }

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
        displayLarge: h1,
        displayMedium: h2,
        headlineMedium: h3,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelSmall: labelSmall,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkGrey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: orange, width: 2),
        ),
        labelStyle: bodyMedium.copyWith(
          color: grey,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: bodyMedium.copyWith(
          color: orange,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: bodyMedium.copyWith(
          color: lightGrey.withOpacity(0.6),
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: black,
        selectedItemColor: orange,
        unselectedItemColor: grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Text Styles
  static final TextStyle h1 = GoogleFonts.spaceGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: white,
  );

  static final TextStyle h2 = GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: white,
  );

  static final TextStyle h3 = GoogleFonts.spaceGrotesk(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: white,
  );

  static final TextStyle bodyLarge = GoogleFonts.jetBrainsMono(
    fontSize: 16,
    color: white,
  );

  static final TextStyle bodyMedium = GoogleFonts.jetBrainsMono(
    fontSize: 14,
    color: white,
  );

  static final TextStyle bodySmall = GoogleFonts.jetBrainsMono(
    fontSize: 12,
    color: grey,
  );

  static final TextStyle squadCodeInput = GoogleFonts.jetBrainsMono(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: orange,
    letterSpacing: 4,
  );

  static final TextStyle labelSmall = GoogleFonts.jetBrainsMono(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: orange,
    letterSpacing: 2,
  );

  static final SliderThemeData vowSliderTheme = SliderThemeData(
    activeTrackColor: orange,
    inactiveTrackColor: darkGrey,
    thumbColor: orange,
    overlayColor: orange.withOpacity(0.16),
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
  );

  // Button Styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: orange,
    foregroundColor: white,
    textStyle: GoogleFonts.spaceGrotesk(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      letterSpacing: 1.1,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
    elevation: 0,
  );

  static final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: darkGrey,
    foregroundColor: white,
    textStyle: GoogleFonts.spaceGrotesk(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      letterSpacing: 1.1,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: white.withOpacity(0.1), width: 1),
    ),
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
    elevation: 0,
  );

  static final ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: black,
    foregroundColor: deepRed,
    textStyle: GoogleFonts.spaceGrotesk(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      letterSpacing: 1.1,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: deepRed, width: 2),
    ),
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
    elevation: 0,
  );

  static final BoxDecoration avatarBorderStyle = BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: orange, width: 2),
  );

  // Chip decoration
  static BoxDecoration chipDecoration({Color? borderColor, Color? fillColor}) {
    return BoxDecoration(
      color: fillColor ?? Colors.transparent,
      border: Border.all(color: borderColor ?? white, width: 1.5),
      borderRadius: BorderRadius.circular(20),
    );
  }
}

class RevokeTheme {
  static Color get accentTimeColor => AppTheme.orange;

  static TextStyle get codeStyle => AppTheme.squadCodeInput;

  static TextStyle get monoLabel => AppTheme.labelSmall;

  static InputDecoration get nicknameInputDecoration =>
      AppTheme.defaultInputDecoration(hintText: "E.G. TERMINATOR");
}
