import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_model.dart';
import '../native_bridge.dart';

class ScheduleService {
  static const String _key = 'regime_schedules';

  static Future<List<ScheduleModel>> getSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];

    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((item) => ScheduleModel.fromJson(item)).toList();
  }

  static Future<void> saveSchedule(ScheduleModel schedule) async {
    final schedules = await getSchedules();
    final index = schedules.indexWhere((s) => s.id == schedule.id);

    if (index != -1) {
      schedules[index] = schedule;
    } else {
      schedules.add(schedule);
    }

    await _saveAll(schedules);
  }

  static Future<void> deleteSchedule(String id) async {
    final schedules = await getSchedules();
    schedules.removeWhere((s) => s.id == id);
    await _saveAll(schedules);
  }

  static Future<void> toggleSchedule(String id) async {
    final schedules = await getSchedules();
    final index = schedules.indexWhere((s) => s.id == id);
    if (index != -1) {
      final updated = schedules[index].copyWith(
        isActive: !schedules[index].isActive,
      );
      schedules[index] = updated;
      await _saveAll(schedules);
    }
  }

  static Future<void> _saveAll(List<ScheduleModel> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(schedules.map((s) => s.toJson()).toList());
    await prefs.setString(_key, data);
    // CRITICAL: Always sync after save
    await syncWithNative();
  }

  static Future<void> syncWithNative() async {
    final schedules = await getSchedules();
    final activeSchedules = schedules.where((s) => s.isActive).toList();
    final String jsonSchedules = jsonEncode(
      activeSchedules.map((s) => s.toJson()).toList(),
    );

    print(
      '[ScheduleService] Syncing ${activeSchedules.length} active schedules',
    );

    // Using MethodChannel via NativeBridge
    await NativeBridge.syncSchedules(jsonSchedules);
  }
}
