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

  // Default to "Blaze" (Revoke orange).
  final ValueNotifier<Color> accentColor = ValueNotifier<Color>(
    const Color(0xFFFF4500),
  );

  static const List<Color> accentPalette = <Color>[
    Color(0xFFFF4500), // Blaze
    Color(0xFFD50000), // Crimson
    Color(0xFF76FF03), // Biohazard
    Color(0xFF00E5FF), // Protocol
    Color(0xFFFFD600), // Voltage
    Color(0xFFD500F9), // Sovereign
    Color(0xFFFF1744), // Plasma
    Color(0xFF2979FF), // Cobalt
    Color(0xFF90A4AE), // Stealth
    Color(0xFF1DE9B6), // Mint
  ];

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final modeRaw = prefs.getString(_kThemeMode);
    themeMode.value = _parseThemeMode(modeRaw) ?? ThemeMode.system;

    final accentRaw = prefs.getInt(_kAccentColor);
    if (accentRaw != null) {
      accentColor.value = Color(accentRaw);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _encodeThemeMode(mode));
  }

  Future<void> setAccentColor(Color color) async {
    accentColor.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentColor, color.toARGB32());
  }

  static String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static ThemeMode? _parseThemeMode(String? raw) {
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
