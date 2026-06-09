import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/schedule_model.dart';
import '../models/taper_plan_model.dart';
import '../native_bridge.dart';
import 'auth_service.dart';
import 'schedule_service.dart';

class TaperPlanService {
  static const String _keyPrefix = 'taper_plans_';
  static const String _pendingUpsertsPrefix = 'taper_plans_pending_upserts_';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String? _uidOrNull() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    final normalized = uid.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static String? _plansKey() {
    final uid = _uidOrNull();
    return uid == null ? null : '$_keyPrefix$uid';
  }

  static String? _pendingUpsertsKey() {
    final uid = _uidOrNull();
    return uid == null ? null : '$_pendingUpsertsPrefix$uid';
  }

  static Future<List<TaperPlanModel>> _readLocalPlans() async {
    final key = _plansKey();
    if (key == null) return const <TaperPlanModel>[];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return const <TaperPlanModel>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <TaperPlanModel>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => TaperPlanModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((plan) => plan.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <TaperPlanModel>[];
    }
  }

  static Future<void> _writeLocalPlans(List<TaperPlanModel> plans) async {
    final key = _plansKey();
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(plans.map((plan) => plan.toJson()).toList()),
    );
  }

  static Future<Set<String>> _readPendingUpserts() async {
    final key = _pendingUpsertsKey();
    if (key == null) return <String>{};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .map((id) => id?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> _writePendingUpserts(Set<String> ids) async {
    final key = _pendingUpsertsKey();
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (ids.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(ids.toList()));
  }

  static Future<void> _markPendingUpsert(String planId) async {
    final pending = await _readPendingUpserts();
    pending.add(planId);
    await _writePendingUpserts(pending);
  }

  static TaperPlanModel buildLinearPlan({
    required List<String> targetApps,
    required int baselineDailyMinutes,
    required int targetDailyMinutes,
    required int durationDays,
  }) {
    final now = DateTime.now();
    final safeBaseline = baselineDailyMinutes.clamp(5, 1440).toInt();
    final safeTarget = targetDailyMinutes.clamp(5, safeBaseline).toInt();
    final safeDuration = durationDays.clamp(7, 60).toInt();
    final planId = const Uuid().v4();

    return TaperPlanModel(
      id: planId,
      scheduleId: 'taper_schedule_$planId',
      status: 'active',
      targetApps: targetApps
          .map((pkg) => pkg.trim())
          .where((pkg) => pkg.isNotEmpty)
          .toSet()
          .toList(),
      baselineDailyMinutes: safeBaseline,
      targetDailyMinutes: safeTarget,
      durationDays: safeDuration,
      startDate: DateTime(now.year, now.month, now.day),
      createdAt: now,
      updatedAt: now,
    );
  }

  static Future<TaperPlanModel?> getActivePlan() async {
    final plans = await _readLocalPlans();
    unawaited(syncPendingToCloud());
    final active = plans
        .where((plan) => plan.status.trim().toLowerCase() == 'active')
        .toList(growable: false);
    if (active.isEmpty) return null;
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final plan = active.first;
    unawaited(materializeTodaySchedule(plan));
    return plan;
  }

  static Future<void> savePlanLocalFirst(TaperPlanModel plan) async {
    final existing = await _readLocalPlans();
    TaperPlanModel? previousActive;
    final archivedPlans = <TaperPlanModel>[];
    final nextPlans = <TaperPlanModel>[];
    for (final current in existing) {
      if (current.id == plan.id) continue;
      if (current.status.trim().toLowerCase() == 'active') {
        previousActive ??= current;
        final archived = current.copyWith(
          status: 'archived',
          updatedAt: DateTime.now(),
        );
        archivedPlans.add(archived);
        nextPlans.add(archived);
      } else {
        nextPlans.add(current);
      }
    }

    final normalized = plan.copyWith(
      status: 'active',
      updatedAt: DateTime.now(),
    );
    nextPlans.add(normalized);
    await _writeLocalPlans(nextPlans);
    await _markPendingUpsert(normalized.id);
    for (final archived in archivedPlans) {
      await _markPendingUpsert(archived.id);
    }
    if (previousActive != null &&
        previousActive.scheduleId.isNotEmpty &&
        previousActive.scheduleId != normalized.scheduleId) {
      await ScheduleService.deleteSchedule(previousActive.scheduleId);
    }
    await materializeTodaySchedule(normalized);
    unawaited(NativeBridge.syncReminderConfig());
    unawaited(_pushPlanToCloud(normalized));
    for (final archived in archivedPlans) {
      unawaited(_pushPlanToCloud(archived));
    }
    unawaited(syncPendingToCloud());
  }

  static Future<void> materializeTodaySchedule(TaperPlanModel plan) async {
    if (plan.status.trim().toLowerCase() != 'active') return;
    final todayLimit = plan.limitFor(DateTime.now());
    final schedule = ScheduleModel(
      id: plan.scheduleId,
      name: 'Daily Goal Plan',
      type: ScheduleType.usageLimit,
      targetApps: List<String>.from(plan.targetApps),
      days: const <int>[1, 2, 3, 4, 5, 6, 7],
      blocks: const <ScheduleBlock>[],
      durationLimit: Duration(minutes: todayLimit),
      isActive: true,
      emoji: ScheduleModel.defaultEmoji,
    );
    await ScheduleService.saveSchedule(schedule);
  }

  static Future<bool> _pushPlanToCloud(TaperPlanModel plan) async {
    final uid = _uidOrNull();
    if (uid == null) return false;
    try {
      final data = plan.toJson();
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('taperPlans')
          .doc(plan.id)
          .set({
            ...data,
            'uid': uid,
            'updatedAt': FieldValue.serverTimestamp(),
            'syncedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      final pending = await _readPendingUpserts();
      if (pending.remove(plan.id)) {
        await _writePendingUpserts(pending);
      }
      return true;
    } catch (_) {
      await _markPendingUpsert(plan.id);
      return false;
    }
  }

  static Future<void> syncPendingToCloud() async {
    final pending = await _readPendingUpserts();
    if (pending.isEmpty) return;

    final localPlans = await _readLocalPlans();
    final byId = {for (final plan in localPlans) plan.id: plan};
    for (final planId in pending.toList()) {
      final plan = byId[planId];
      if (plan == null) {
        pending.remove(planId);
        continue;
      }
      if (await _pushPlanToCloud(plan)) {
        pending.remove(planId);
      }
    }
    await _writePendingUpserts(pending);
  }
}
