import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_model.dart';
import '../native_bridge.dart';
import 'auth_service.dart';
import 'regime_service.dart';

class ScheduleService {
  static const String _legacyKey = 'regime_schedules';
  static const String _keyPrefix = 'regime_schedules_';
  static const String _pendingUpsertsPrefix = 'regime_schedules_pending_upserts_';
  static const String _pendingDeletesPrefix = 'regime_schedules_pending_deletes_';

  static Future<void> _syncWithNativeInBackground() async {
    try {
      await syncWithNative();
    } catch (_) {
      // Native sync is best-effort; local-first UX must not be blocked by it.
    }
  }

  static String? _uidOrNull() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    final normalized = uid.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static String _localSchedulesKey() {
    final uid = _uidOrNull();
    if (uid == null) return _legacyKey;
    return '$_keyPrefix$uid';
  }

  static Future<Set<String>> _readPendingIds(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(key) ?? '').trim();
    if (raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .map((e) => (e?.toString() ?? '').trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> _writePendingIds(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(ids.toList()));
  }

  static Future<void> _markPendingUpsert(String scheduleId) async {
    final uid = _uidOrNull();
    if (uid == null) return;
    final upsertsKey = '$_pendingUpsertsPrefix$uid';
    final deletesKey = '$_pendingDeletesPrefix$uid';

    final upserts = await _readPendingIds(upsertsKey);
    upserts.add(scheduleId);
    await _writePendingIds(upsertsKey, upserts);

    // If something was previously queued for deletion, un-queue it.
    final deletes = await _readPendingIds(deletesKey);
    if (deletes.remove(scheduleId)) {
      await _writePendingIds(deletesKey, deletes);
    }
  }

  static Future<void> _markPendingDelete(String scheduleId) async {
    final uid = _uidOrNull();
    if (uid == null) return;
    final upsertsKey = '$_pendingUpsertsPrefix$uid';
    final deletesKey = '$_pendingDeletesPrefix$uid';

    final deletes = await _readPendingIds(deletesKey);
    deletes.add(scheduleId);
    await _writePendingIds(deletesKey, deletes);

    // If it was queued to upsert, remove it.
    final upserts = await _readPendingIds(upsertsKey);
    if (upserts.remove(scheduleId)) {
      await _writePendingIds(upsertsKey, upserts);
    }
  }

  static Future<void> _flushPendingCloudSyncInBackground() async {
    final uid = _uidOrNull();
    if (uid == null) return;

    final upsertsKey = '$_pendingUpsertsPrefix$uid';
    final deletesKey = '$_pendingDeletesPrefix$uid';

    final pendingDeletes = await _readPendingIds(deletesKey);
    final pendingUpserts = await _readPendingIds(upsertsKey);
    if (pendingDeletes.isEmpty && pendingUpserts.isEmpty) return;

    // Local is the source of truth for what should exist. We re-attempt best-effort.
    final local = await _readLocalSchedules();
    final byId = {for (final s in local) s.id: s};

    // Deletes first.
    if (pendingDeletes.isNotEmpty) {
      final remaining = <String>{...pendingDeletes};
      for (final id in pendingDeletes) {
        try {
          await RegimeService.deleteRegime(id);
          remaining.remove(id);
        } catch (_) {
          // Keep queued
        }
      }
      await _writePendingIds(deletesKey, remaining);
    }

    // Upserts second.
    if (pendingUpserts.isNotEmpty) {
      final remaining = <String>{...pendingUpserts};
      for (final id in pendingUpserts) {
        final schedule = byId[id];
        if (schedule == null) {
          // If it no longer exists locally, don't keep trying to upsert it.
          remaining.remove(id);
          continue;
        }
        try {
          await RegimeService.saveRegime(schedule);
          remaining.remove(id);
        } catch (_) {
          // Keep queued
        }
      }
      await _writePendingIds(upsertsKey, remaining);
    }
  }

  static Future<List<ScheduleModel>> _readLocalSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localSchedulesKey();
    String? data = prefs.getString(key);

    // One-time migration from the legacy global key to per-user key.
    if ((data == null || data.trim().isEmpty) && key != _legacyKey) {
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyKey);
        data = legacy;
      }
    }

    if (data == null || data.trim().isEmpty) return <ScheduleModel>[];
    try {
      final decoded = jsonDecode(data) as List<dynamic>;
      return decoded
          .map(
            (item) => ScheduleModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return <ScheduleModel>[];
    }
  }

  static Future<void> _writeLocalSchedules(
    List<ScheduleModel> schedules,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(schedules.map((s) => s.toJson()).toList());
    await prefs.setString(_localSchedulesKey(), data);
  }

  static Future<void> _pushSingleToCloudInBackground(
    ScheduleModel schedule,
  ) async {
    try {
      await RegimeService.saveRegime(schedule);
      final uid = _uidOrNull();
      if (uid != null) {
        final upsertsKey = '$_pendingUpsertsPrefix$uid';
        final pending = await _readPendingIds(upsertsKey);
        if (pending.remove(schedule.id)) {
          await _writePendingIds(upsertsKey, pending);
        }
      }
    } catch (_) {
      // Background sync is best-effort by design.
    }
  }

  static Future<void> _deleteFromCloudInBackground(String id) async {
    try {
      await RegimeService.deleteRegime(id);
      final uid = _uidOrNull();
      if (uid != null) {
        final deletesKey = '$_pendingDeletesPrefix$uid';
        final pending = await _readPendingIds(deletesKey);
        if (pending.remove(id)) {
          await _writePendingIds(deletesKey, pending);
        }
      }
    } catch (_) {
      // Background sync is best-effort by design.
    }
  }

  static Future<void> _refreshLocalFromCloudInBackground() async {
    try {
      final remote = await RegimeService.getRegimes();
      final local = await _readLocalSchedules();
      // Do not replace non-empty local with empty remote.
      if (remote.isEmpty && local.isNotEmpty) return;
      await _writeLocalSchedules(remote);
    } catch (_) {
      // Ignore; local-first behavior should remain resilient offline.
    }
  }

  static Future<List<ScheduleModel>> getSchedules() async {
    final local = await _readLocalSchedules();
    // Retry any missed cloud sync attempts.
    unawaited(_flushPendingCloudSyncInBackground());
    unawaited(_refreshLocalFromCloudInBackground());
    return local;
  }

  static Stream<List<ScheduleModel>> watchSchedules() async* {
    final local = await _readLocalSchedules();
    yield local;

    yield* RegimeService.watchRegimes().asyncMap((remote) async {
      final currentLocal = await _readLocalSchedules();
      if (remote.isEmpty && currentLocal.isNotEmpty) {
        return currentLocal;
      }
      await _writeLocalSchedules(remote);
      return remote;
    });
  }

  static Future<void> saveSchedule(ScheduleModel schedule) async {
    final schedules = await _readLocalSchedules();
    final index = schedules.indexWhere((s) => s.id == schedule.id);
    if (index == -1) {
      schedules.add(schedule);
    } else {
      schedules[index] = schedule;
    }
    await _writeLocalSchedules(schedules);
    await _markPendingUpsert(schedule.id);
    unawaited(_syncWithNativeInBackground());
    unawaited(_pushSingleToCloudInBackground(schedule));
    unawaited(_flushPendingCloudSyncInBackground());
  }

  static Future<void> deleteSchedule(String id) async {
    final schedules = await _readLocalSchedules();
    schedules.removeWhere((s) => s.id == id);
    await _writeLocalSchedules(schedules);
    await _markPendingDelete(id);
    unawaited(_syncWithNativeInBackground());
    unawaited(_deleteFromCloudInBackground(id));
    unawaited(_flushPendingCloudSyncInBackground());
  }

  static Future<void> toggleSchedule(String id) async {
    final schedules = await _readLocalSchedules();
    final index = schedules.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final updated = schedules[index].copyWith(
      isActive: !schedules[index].isActive,
    );
    schedules[index] = updated;
    await _writeLocalSchedules(schedules);
    await _markPendingUpsert(updated.id);
    unawaited(_syncWithNativeInBackground());
    unawaited(_pushSingleToCloudInBackground(updated));
    unawaited(_flushPendingCloudSyncInBackground());
  }

  static Future<void> syncWithNative() async {
    final schedules = await _readLocalSchedules();
    final activeSchedules = schedules.where((s) => s.isActive).toList();
    final jsonSchedules = jsonEncode(
      activeSchedules.map((s) => s.toJson()).toList(),
    );
    await NativeBridge.syncSchedules(jsonSchedules);
  }
}
