import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_model.dart';
import '../native_bridge.dart';
import 'auth_service.dart';

class RegimeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _legacyKey = 'regime_schedules';
  static const String _keyPrefix = 'regime_schedules_';
  static final Set<String> _migratedUsers = <String>{};

  static Future<String> _requireUid() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw Exception('NO AUTHENTICATED USER FOR REGIMES');
    }
    return uid.trim();
  }

  static String? _currentUidOrNull() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    final normalized = uid.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static CollectionReference<Map<String, dynamic>> _regimesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('regimes');
  }

  // Cross-user access: used by Squad HUD. Returns only enabled regimes.
  // Note: This must be allowed by Firestore security rules (same-squad read).
  static Future<List<ScheduleModel>> getRegimesForUser(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return const <ScheduleModel>[];
    try {
      final snapshot = await _regimesRef(normalized)
          .where('isEnabled', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromFirestore).toList();
    } catch (_) {
      return const <ScheduleModel>[];
    }
  }

  static String _localKeyForUid(String uid) => '$_keyPrefix$uid';

  static String _timeToString(TimeOfDay? time) {
    if (time == null) return '';
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static TimeOfDay? _parseTime(dynamic value, dynamic hour, dynamic minute) {
    if (value is String && value.contains(':')) {
      final parts = value.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          return TimeOfDay(hour: h, minute: m);
        }
      }
    }
    if (hour is num) {
      return TimeOfDay(
        hour: hour.toInt(),
        minute: (minute as num?)?.toInt() ?? 0,
      );
    }
    return null;
  }

  static Map<String, dynamic> _toFirestore(ScheduleModel schedule) {
    return {
      // Required regime fields for cloud schema.
      'name': schedule.name,
      'apps': schedule.targetApps,
      'daysOfWeek': schedule.days,
      'startTime': _timeToString(schedule.startTime),
      'endTime': _timeToString(schedule.endTime),
      'isEnabled': schedule.isActive,
      // Legacy/compat fields used by native sync model.
      'type': schedule.type.index,
      'targetApps': schedule.targetApps,
      'days': schedule.days,
      'startHour': schedule.startTime?.hour,
      'startMinute': schedule.startTime?.minute,
      'endHour': schedule.endTime?.hour,
      'endMinute': schedule.endTime?.minute,
      'durationSeconds': schedule.durationLimit?.inSeconds,
      'isActive': schedule.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static ScheduleModel _fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final targetApps = List<String>.from(
      data['targetApps'] as List? ?? data['apps'] as List? ?? const <String>[],
    );
    final days = List<int>.from(
      data['days'] as List? ?? data['daysOfWeek'] as List? ?? const <int>[],
    );

    final startTime = _parseTime(
      data['startTime'],
      data['startHour'],
      data['startMinute'],
    );
    final endTime = _parseTime(
      data['endTime'],
      data['endHour'],
      data['endMinute'],
    );
    final durationSeconds = (data['durationSeconds'] as num?)?.toInt();
    final rawType = (data['type'] as num?)?.toInt() ?? 0;
    final safeType = rawType.clamp(0, ScheduleType.values.length - 1);

    return ScheduleModel(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'REGIME',
      type: ScheduleType.values[safeType],
      targetApps: targetApps,
      days: days,
      startTime: startTime,
      endTime: endTime,
      durationLimit: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds),
      isActive:
          (data['isActive'] as bool?) ?? (data['isEnabled'] as bool?) ?? true,
    );
  }

  static Future<void> migrateLegacyLocalDataIfNeeded() async {
    final uid = _currentUidOrNull();
    if (uid == null) return;
    if (_migratedUsers.contains(uid)) return;

    final prefs = await SharedPreferences.getInstance();
    final migrationFlagKey = 'regimes_migrated_$uid';
    final alreadyMigrated = prefs.getBool(migrationFlagKey) ?? false;
    if (alreadyMigrated) {
      _migratedUsers.add(uid);
      return;
    }

    // Prefer per-user cache; fall back to legacy global key.
    final perUserKey = _localKeyForUid(uid);
    String? localRaw = prefs.getString(perUserKey);
    if (localRaw == null || localRaw.trim().isEmpty) {
      localRaw = prefs.getString(_legacyKey);
      // If we found legacy data, re-home it under the user-scoped key to prevent
      // cross-account leakage on the same device.
      if (localRaw != null && localRaw.trim().isNotEmpty) {
        await prefs.setString(perUserKey, localRaw);
        await prefs.remove(_legacyKey);
      }
    }
    if (localRaw != null && localRaw.trim().isNotEmpty) {
      try {
        final existing = await _regimesRef(uid).limit(1).get();
        if (existing.docs.isEmpty) {
          final decoded = jsonDecode(localRaw) as List<dynamic>;
          final schedules = decoded
              .map(
                (item) =>
                    ScheduleModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
          final batch = _firestore.batch();
          for (final schedule in schedules) {
            final docRef = _regimesRef(uid).doc(schedule.id);
            batch.set(docRef, {
              ..._toFirestore(schedule),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
      } catch (_) {
        // Keep non-fatal; migration is best-effort.
      }
    }

    await prefs.setBool(migrationFlagKey, true);
    _migratedUsers.add(uid);
  }

  static Future<List<ScheduleModel>> getRegimes() async {
    try {
      await migrateLegacyLocalDataIfNeeded();
      final uid = _currentUidOrNull();
      if (uid == null) return const <ScheduleModel>[];
      final snapshot = await _regimesRef(
        uid,
      ).orderBy('createdAt', descending: false).get();
      return snapshot.docs.map(_fromFirestore).toList();
    } catch (_) {
      return const <ScheduleModel>[];
    }
  }

  static Stream<List<ScheduleModel>> watchRegimes() async* {
    try {
      await migrateLegacyLocalDataIfNeeded();
      final uid = _currentUidOrNull();
      if (uid == null) {
        yield const <ScheduleModel>[];
        return;
      }
      yield* _regimesRef(uid)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_fromFirestore).toList());
    } catch (_) {
      yield const <ScheduleModel>[];
    }
  }

  static Future<void> saveRegime(ScheduleModel schedule) async {
    await migrateLegacyLocalDataIfNeeded();
    final uid = await _requireUid();
    await _regimesRef(uid).doc(schedule.id).set({
      ..._toFirestore(schedule),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await syncEnabledRegimesWithNative();
  }

  static Future<void> deleteRegime(String id) async {
    await migrateLegacyLocalDataIfNeeded();
    final uid = await _requireUid();
    await _regimesRef(uid).doc(id).delete();
    await syncEnabledRegimesWithNative();
  }

  static Future<void> toggleRegime(String id) async {
    await migrateLegacyLocalDataIfNeeded();
    final uid = await _requireUid();
    final docRef = _regimesRef(uid).doc(id);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final current =
          (data['isActive'] as bool?) ?? (data['isEnabled'] as bool?) ?? true;
      transaction.update(docRef, {
        'isActive': !current,
        'isEnabled': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await syncEnabledRegimesWithNative();
  }

  static Future<void> syncEnabledRegimesWithNative() async {
    final regimes = await getRegimes();
    final activeRegimes = regimes.where((r) => r.isActive).toList();
    final jsonSchedules = jsonEncode(
      activeRegimes.map((r) => r.toJson()).toList(),
    );
    await NativeBridge.syncSchedules(jsonSchedules);
  }
}
