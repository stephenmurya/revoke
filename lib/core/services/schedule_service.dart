import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_model.dart';
import '../native_bridge.dart';
import 'regime_service.dart';

class ScheduleService {
  static const String _key = 'regime_schedules';

  static Future<List<ScheduleModel>> _readLocalSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
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
    await prefs.setString(_key, data);
  }

  static Future<void> _pushSingleToCloudInBackground(
    ScheduleModel schedule,
  ) async {
    try {
      await RegimeService.saveRegime(schedule);
    } catch (_) {
      // Background sync is best-effort by design.
    }
  }

  static Future<void> _deleteFromCloudInBackground(String id) async {
    try {
      await RegimeService.deleteRegime(id);
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
    await syncWithNative();
    unawaited(_pushSingleToCloudInBackground(schedule));
  }

  static Future<void> deleteSchedule(String id) async {
    final schedules = await _readLocalSchedules();
    schedules.removeWhere((s) => s.id == id);
    await _writeLocalSchedules(schedules);
    await syncWithNative();
    unawaited(_deleteFromCloudInBackground(id));
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
    await syncWithNative();
    unawaited(_pushSingleToCloudInBackground(updated));
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
