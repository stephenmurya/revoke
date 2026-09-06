import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class PersistenceService {
  static const String _appsKey = 'restricted_apps';
  static const String _whitelistedAppsKey = 'whitelisted_apps';
  static const String _softReminderEnabledKey = 'soft_reminder_enabled';
  static const String _softReminderFrequencyMinutesKey =
      'soft_reminder_frequency_minutes';

  static String _key(String baseKey) {
    final uid = AuthService.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) return baseKey;
    return '${baseKey}_$uid';
  }

  static Future<String?> _readString(String baseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _key(baseKey);
    final scoped = prefs.getString(scopedKey);
    if (scoped != null || scopedKey == baseKey) return scoped;

    // The legacy keys predate account-scoped persistence. Import them once
    // for the first authenticated account, then remove the global copy so a
    // later account can never inherit it.
    final legacy = prefs.getString(baseKey);
    if (legacy != null) {
      await prefs.setString(scopedKey, legacy);
      await prefs.remove(baseKey);
    }
    return legacy;
  }

  static Future<List<String>?> _readStringList(String baseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _key(baseKey);
    final scoped = prefs.getStringList(scopedKey);
    if (scoped != null || scopedKey == baseKey) return scoped;

    final legacy = prefs.getStringList(baseKey);
    if (legacy != null) {
      await prefs.setStringList(scopedKey, legacy);
      await prefs.remove(baseKey);
    }
    return legacy;
  }

  static Future<bool?> _readBool(String baseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _key(baseKey);
    final scoped = prefs.getBool(scopedKey);
    if (scoped != null || scopedKey == baseKey) return scoped;

    final legacy = prefs.getBool(baseKey);
    if (legacy != null) {
      await prefs.setBool(scopedKey, legacy);
      await prefs.remove(baseKey);
    }
    return legacy;
  }

  static Future<int?> _readInt(String baseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _key(baseKey);
    final scoped = prefs.getInt(scopedKey);
    if (scoped != null || scopedKey == baseKey) return scoped;

    final legacy = prefs.getInt(baseKey);
    if (legacy != null) {
      await prefs.setInt(scopedKey, legacy);
      await prefs.remove(baseKey);
    }
    return legacy;
  }

  static Future<void> saveRestrictedApps(Map<String, bool> appStates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_appsKey), jsonEncode(appStates));
  }

  static Future<Map<String, bool>> getRestrictedApps() async {
    final String? data = await _readString(_appsKey);
    if (data == null) return {};
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return {};
      return decoded.map<String, bool>(
        (key, value) => MapEntry(key.toString(), value == true),
      );
    } catch (_) {
      return {};
    }
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
    await prefs.setStringList(_key(_whitelistedAppsKey), normalized);
  }

  static Future<Set<String>> getWhitelistedApps() async {
    final values =
        await _readStringList(_whitelistedAppsKey) ?? const <String>[];
    return values
        .map((packageName) => packageName.trim())
        .where((packageName) => packageName.isNotEmpty)
        .toSet();
  }

  static Future<void> saveSoftReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_softReminderEnabledKey), enabled);
  }

  static Future<bool> getSoftReminderEnabled() async {
    return await _readBool(_softReminderEnabledKey) ?? true;
  }

  static Future<void> saveSoftReminderFrequencyMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(_softReminderFrequencyMinutesKey),
      minutes.clamp(0, 120).toInt(),
    );
  }

  static Future<int> getSoftReminderFrequencyMinutes() async {
    return await _readInt(_softReminderFrequencyMinutesKey) ?? 5;
  }
}
