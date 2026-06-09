import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../native_bridge.dart';
import 'auth_service.dart';
import 'persistence_service.dart';
import 'theme_service.dart';

class SettingsSyncService {
  static const String _settingsField = 'appPreferences';
  static const String _whitelistedAppsKey = 'whitelistedApps';
  static const String _softReminderEnabledKey = 'softReminderEnabled';
  static const String _softReminderFrequencyMinutesKey =
      'softReminderFrequencyMinutes';
  static const String _themeModeKey = 'themeMode';
  static const String _accentColorKey = 'accentColor';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> syncWhitelistedAppsToCloud(
    Set<String> packageNames,
  ) async {
    final normalized =
        packageNames
            .map((packageName) => packageName.trim())
            .where((packageName) => packageName.isNotEmpty)
            .toList()
          ..sort();
    await _writeAppPreferences({_whitelistedAppsKey: normalized});
  }

  static Future<void> syncSoftReminderEnabledToCloud(bool enabled) async {
    await _writeAppPreferences({_softReminderEnabledKey: enabled});
  }

  static Future<void> syncSoftReminderFrequencyMinutesToCloud(
    int minutes,
  ) async {
    await _writeAppPreferences({
      _softReminderFrequencyMinutesKey: minutes.clamp(0, 120).toInt(),
    });
  }

  static Future<void> syncThemeToCloud({
    ThemeMode? themeMode,
    Color? accentColor,
  }) async {
    final values = <String, Object?>{};
    if (themeMode != null) {
      values[_themeModeKey] = ThemeService.encodeThemeMode(themeMode);
    }
    if (accentColor != null) {
      values[_accentColorKey] = accentColor.toARGB32();
    }
    await _writeAppPreferences(values);
  }

  static Future<void> hydrateLocalPreferencesFromCloud() async {
    final preferences = await _readAppPreferences();
    if (preferences.isEmpty) return;

    final remoteWhitelist = _stringSet(preferences[_whitelistedAppsKey]);
    if (remoteWhitelist != null) {
      await PersistenceService.saveWhitelistedApps(remoteWhitelist);
      try {
        await NativeBridge.syncWhitelistApps(remoteWhitelist);
      } catch (_) {}
    }

    var reminderEnabled = await PersistenceService.getSoftReminderEnabled();
    var reminderFrequency =
        await PersistenceService.getSoftReminderFrequencyMinutes();
    var reminderChanged = false;

    final remoteReminderEnabled = preferences[_softReminderEnabledKey];
    if (remoteReminderEnabled is bool) {
      reminderEnabled = remoteReminderEnabled;
      reminderChanged = true;
      await PersistenceService.saveSoftReminderEnabled(remoteReminderEnabled);
    }

    final remoteReminderFrequency =
        (preferences[_softReminderFrequencyMinutesKey] as num?)?.toInt();
    if (remoteReminderFrequency != null) {
      reminderFrequency = remoteReminderFrequency.clamp(0, 120).toInt();
      reminderChanged = true;
      await PersistenceService.saveSoftReminderFrequencyMinutes(
        reminderFrequency,
      );
    }

    if (reminderChanged) {
      try {
        await NativeBridge.syncReminderConfig(
          softReminderEnabled: reminderEnabled,
          softReminderCooldownMs: reminderFrequency * 60000,
        );
      } catch (_) {}
    }

    final remoteThemeMode = ThemeService.parseThemeMode(
      preferences[_themeModeKey]?.toString(),
    );
    if (remoteThemeMode != null) {
      await ThemeService.instance.setThemeMode(remoteThemeMode);
    }

    final remoteAccent = _color(preferences[_accentColorKey]);
    if (remoteAccent != null) {
      await ThemeService.instance.setAccentColor(remoteAccent);
    }
  }

  static Future<Map<String, dynamic>> _readAppPreferences() async {
    final user = AuthService.currentUser;
    if (user == null) return const <String, dynamic>{};

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final raw = snapshot.data()?[_settingsField];
    if (raw is! Map) return const <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  static Future<void> _writeAppPreferences(Map<String, Object?> values) async {
    if (values.isEmpty) return;
    final user = AuthService.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);
    final updates = <String, Object?>{
      for (final entry in values.entries)
        '$_settingsField.${entry.key}': entry.value,
      '$_settingsField.updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.update(updates);
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
      await ref.set({
        _settingsField: {...values, 'updatedAt': FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    }
  }

  static Set<String>? _stringSet(Object? raw) {
    if (raw is! Iterable) return null;
    return raw
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static Color? _color(Object? raw) {
    if (raw is num) {
      return Color(raw.toInt());
    }
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final normalized = text.startsWith('0x') ? text.substring(2) : text;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
