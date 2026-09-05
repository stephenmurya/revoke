import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usage_insights_model.dart';
import '../native_bridge.dart';
import 'auth_service.dart';

class UsageInsightsService {
  static const String _cachePrefix = 'usage_insights_v1';

  static String _cacheKey({
    required String mode,
    required DateTime anchorDate,
    String? packageName,
    List<String>? packageNames,
    int? periodDays,
  }) {
    final uid = AuthService.currentUser?.uid.trim();
    final userKey = uid == null || uid.isEmpty ? 'anonymous' : uid;
    final day = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final packageKey = <String>[
      if (packageNames != null && packageNames.isNotEmpty)
        ...packageNames
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      if (packageNames == null || packageNames.isEmpty)
        if (packageName == null || packageName.trim().isEmpty)
          'all'
        else
          packageName.trim(),
    ]..sort();
    final periodKey = periodDays ?? 0;
    return '$_cachePrefix:$userKey:$mode:${day.millisecondsSinceEpoch}:$periodKey:${packageKey.join(',')}';
  }

  static Future<UsageInsightsSnapshot?> readCache({
    required String mode,
    required DateTime anchorDate,
    String? packageName,
    List<String>? packageNames,
    int? periodDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _cacheKey(
        mode: mode,
        anchorDate: anchorDate,
        packageName: packageName,
        packageNames: packageNames,
        periodDays: periodDays,
      ),
    );
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return UsageInsightsSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<UsageInsightsSnapshot> refresh({
    required String mode,
    required DateTime anchorDate,
    String? packageName,
    List<String>? packageNames,
    int? periodDays,
  }) async {
    final raw = await NativeBridge.getUsageInsights(
      mode: mode,
      anchorDateMs: DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day,
      ).millisecondsSinceEpoch,
      packageName: packageName,
      packageNames: packageNames,
      periodDays: periodDays,
    );
    final snapshot = UsageInsightsSnapshot.fromJson(raw);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(
        mode: mode,
        anchorDate: anchorDate,
        packageName: packageName,
        packageNames: packageNames,
        periodDays: periodDays,
      ),
      jsonEncode(snapshot.toJson()),
    );
    return snapshot;
  }
}
