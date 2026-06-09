import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersistenceService {
  static const String _appsKey = 'restricted_apps';
  static const String _whitelistedAppsKey = 'whitelisted_apps';
  static const String _softReminderEnabledKey = 'soft_reminder_enabled';
  static const String _softReminderFrequencyMinutesKey =
      'soft_reminder_frequency_minutes';

  static Future<void> saveRestrictedApps(Map<String, bool> appStates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appsKey, jsonEncode(appStates));
  }

  static Future<Map<String, bool>> getRestrictedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_appsKey);
    if (data == null) return {};
    return Map<String, bool>.from(jsonDecode(data));
  }

  static Future<void> saveWhitelistedApps(Set<String> packageNames) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized =
        packageNames
            .map((packageName) => packageName.trim())
            .where((packageName) => packageName.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    await prefs.setStringList(_whitelistedAppsKey, normalized);
  }

  static Future<Set<String>> getWhitelistedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_whitelistedAppsKey) ?? const <String>[];
    return values
        .map((packageName) => packageName.trim())
        .where((packageName) => packageName.isNotEmpty)
        .toSet();
  }

  static Future<void> saveSoftReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_softReminderEnabledKey, enabled);
  }

  static Future<bool> getSoftReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_softReminderEnabledKey) ?? true;
  }

  static Future<void> saveSoftReminderFrequencyMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _softReminderFrequencyMinutesKey,
      minutes.clamp(0, 120).toInt(),
    );
  }

  static Future<int> getSoftReminderFrequencyMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_softReminderFrequencyMinutesKey) ?? 5;
  }
}
