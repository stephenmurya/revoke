import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'circle_service.dart';

/// Durable local queue for self-authorized access requests. It is deliberately
/// small and best-effort: the native unlock is immediate, while each event is
/// retried against the canonical server history when connectivity returns.
class LocalOverrideHistoryService {
  static String _key(String uid) => 'pending_override_history_${uid.trim()}';

  static Future<void> record({
    required String uid,
    required String idempotencyKey,
    required String commitmentId,
    required String appName,
    required String packageName,
    required int durationMinutes,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key(uid)) ?? <String>[];
    values.insert(
      0,
      jsonEncode({
        'idempotencyKey': idempotencyKey,
        'commitmentId': commitmentId,
        'appName': appName,
        'packageName': packageName,
        'durationMinutes': durationMinutes,
        'reason': reason,
      }),
    );
    await prefs.setStringList(_key(uid), values.take(50).toList());
  }

  static Future<void> syncPending(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key(normalizedUid)) ?? <String>[];
    if (values.isEmpty) return;
    final remaining = <String>[];
    for (final value in values) {
      try {
        final item = jsonDecode(value);
        if (item is! Map) {
          continue;
        }
        final data = Map<String, dynamic>.from(item);
        await CircleService.recordSelfOverride(
          commitmentId: data['commitmentId']?.toString() ?? '',
          appName: data['appName']?.toString() ?? '',
          packageName: data['packageName']?.toString() ?? '',
          durationMinutes:
              int.tryParse(data['durationMinutes'].toString()) ?? 5,
          reason: data['reason']?.toString() ?? '',
          localRequestId: data['idempotencyKey']?.toString(),
        );
      } catch (_) {
        remaining.add(value);
      }
    }
    await prefs.setStringList(_key(normalizedUid), remaining);
  }
}
