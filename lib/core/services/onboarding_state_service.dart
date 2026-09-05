import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_state.dart';
import 'auth_service.dart';
import 'regime_service.dart';
import 'schedule_service.dart';

/// Local-first persistence for the explicit v2 onboarding state machine.
///
/// The local record is the resume authority on this device. It is deliberately
/// not inferred from profile or permission fields. Existing users with a
/// persisted schedule are conservatively treated as already active so they
/// are not forced through a new-user journey.
class OnboardingStateService {
  static const String _keyPrefix = 'onboarding_state_v2_';

  static String? _uid() {
    final uid = AuthService.currentUser?.uid.trim();
    return uid == null || uid.isEmpty ? null : uid;
  }

  static String? _key() {
    final uid = _uid();
    return uid == null ? null : '$_keyPrefix$uid';
  }

  static Future<OnboardingState?> read() async {
    final key = _key();
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return OnboardingState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<OnboardingState> loadOrCreate() async {
    final existing = await read();
    if (existing != null && existing.version >= 2) return existing;

    // A schedule is concrete evidence of an already configured product. It
    // is the only legacy migration signal used here; nickname, Circle, and
    // permissions are not completion signals.
    var schedules = await ScheduleService.getSchedules();
    // ScheduleService refreshes cloud state in the background. During the
    // one-time migration, perform a direct best-effort read as well so an
    // existing active user is not mistaken for a new user on a cold install.
    if (schedules.isEmpty) {
      schedules = await RegimeService.getRegimes();
    }
    final now = DateTime.now();
    final migrated = schedules.isNotEmpty
        ? OnboardingState(
            step: OnboardingStep.complete,
            createdAt: now,
            updatedAt: now,
          )
        : OnboardingState(createdAt: now, updatedAt: now);
    await save(migrated);
    return migrated;
  }

  static Future<void> save(OnboardingState state) async {
    final key = _key();
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final persisted = state.copyWith(
      version: 2,
      createdAt: state.createdAt ?? now,
      updatedAt: now,
    );
    await prefs.setString(key, jsonEncode(persisted.toJson()));
  }

  static Future<void> clearForCurrentUser() async {
    final key = _key();
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
