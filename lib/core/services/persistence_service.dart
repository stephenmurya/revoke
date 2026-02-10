import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersistenceService {
  static const String _appsKey = 'restricted_apps';

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
}
