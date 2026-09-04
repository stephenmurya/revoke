import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _kThemeMode = 'theme_mode'; // system|light|dark
  static const String _kAccentColor = 'accent_color'; // int color value

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  // Default to a contrast-tested Revoke orange.
  final ValueNotifier<Color> accentColor = ValueNotifier<Color>(
    const Color(0xFFC2410C),
  );

  /// Curated accents only. Semantic success, warning, destructive, and
  /// enforcement colors are supplied by AppTheme and are never user accents.
  static const List<Color> accentPalette = <Color>[
    Color(0xFFC2410C), // Blaze
    Color(0xFFA61B1B), // Crimson
    Color(0xFF175CD3), // Cobalt
    Color(0xFF067647), // Mint
    Color(0xFF6941C6), // Violet
  ];

  static const Map<int, Color> _legacyAccentFallbacks = <int, Color>{
    0xFFFF4500: Color(0xFFC2410C), // Blaze
    0xFFD50000: Color(0xFFA61B1B), // Crimson
    0xFF76FF03: Color(0xFF067647), // Biohazard -> Mint
    0xFF00E5FF: Color(0xFF175CD3), // Protocol -> Cobalt
    0xFFFFD600: Color(0xFFC2410C), // Voltage -> Blaze
    0xFFD500F9: Color(0xFF6941C6), // Sovereign -> Violet
    0xFFFF1744: Color(0xFFA61B1B), // Plasma -> Crimson
    0xFF2979FF: Color(0xFF175CD3), // Cobalt
    0xFF90A4AE: Color(0xFF175CD3), // Stealth -> Cobalt
    0xFF1DE9B6: Color(0xFF067647), // Mint
  };

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final modeRaw = prefs.getString(_kThemeMode);
    themeMode.value = parseThemeMode(modeRaw) ?? ThemeMode.system;

    final accentRaw = prefs.getInt(_kAccentColor);
    if (accentRaw != null) {
      accentColor.value = normalizeAccent(Color(accentRaw));
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, encodeThemeMode(mode));
  }

  Future<void> setAccentColor(Color color) async {
    final safeColor = normalizeAccent(color);
    accentColor.value = safeColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentColor, safeColor.toARGB32());
  }

  /// Migrates old persisted palette values and rejects arbitrary colors.
  static Color normalizeAccent(Color color) {
    final argb = color.toARGB32();
    final legacy = _legacyAccentFallbacks[argb];
    if (legacy != null) return legacy;
    for (final safe in accentPalette) {
      if (safe.toARGB32() == argb) return safe;
    }
    return accentPalette.first;
  }

  static String encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static ThemeMode? parseThemeMode(String? raw) {
    switch (raw) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }
}
