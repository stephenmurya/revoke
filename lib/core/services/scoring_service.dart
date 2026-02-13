import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../native_bridge.dart';
import 'auth_service.dart';
import 'persistence_service.dart';
import 'schedule_service.dart';

class ScoringService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _syncTimer;
  static bool _initialized = false;

  static const int _baselineScore = 500;
  static const int _minScore = 0;
  static const int _maxScore = 1000;
  static const String _scoringMetaKey = 'scoringMeta';
  static const String _dateKey = 'date';
  static const String _dailyDecayAppliedKey = 'dailyDecayApplied';
  static const String _dailyRewardAppliedKey = 'dailyRewardApplied';

  static void initializePeriodicSync() {
    if (_initialized) return;
    _initialized = true;

    AuthService.authStateChanges.listen((user) {
      _syncTimer?.cancel();
      if (user == null) return;

      syncFocusScore(user.uid);
      _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        syncFocusScore(user.uid);
      });
    });

    final current = AuthService.currentUser;
    if (current != null) {
      syncFocusScore(current.uid);
      _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        syncFocusScore(current.uid);
      });
    }
  }

  static Future<void> syncFocusScore(String uid) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final snapshot = await userRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final double vowHours = _extractVowHours(data);
      final Map<String, dynamic> reality = await NativeBridge.getRealityCheck();
      final Map<String, bool> restricted =
          await PersistenceService.getRestrictedApps();
      final Set<String> restrictedPackages = restricted.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();

      final double restrictedHoursToday = _estimateRestrictedHoursToday(
        topApps: reality['topApps'] as List? ?? const [],
        restrictedPackages: restrictedPackages,
      );

      final int decayTarget = _calculateDecay(
        restrictedHoursToday: restrictedHoursToday,
        vowHours: vowHours,
      );

      final int regimeSessionsCompleted =
          await _estimateCompletedRegimeSessions(
            restrictedHoursToday,
            vowHours,
          );
      final int rewardTarget = regimeSessionsCompleted * 15;

      await _firestore.runTransaction((tx) async {
        final fresh = await tx.get(userRef);
        if (!fresh.exists) return;

        final user = fresh.data() ?? <String, dynamic>{};
        final int current =
            (user['focusScore'] as num?)?.toInt() ?? _baselineScore;
        final List<int> history = List<int>.from(
          (user['scoreHistory'] as List?)?.map((e) => (e as num).toInt()) ??
              const <int>[],
        );

        final Map<String, dynamic> meta = Map<String, dynamic>.from(
          (user[_scoringMetaKey] as Map?) ?? const {},
        );

        final String today = _dateOnly(DateTime.now());
        final bool isSameDay = meta[_dateKey] == today;
        final int appliedDecay = isSameDay
            ? (meta[_dailyDecayAppliedKey] as num?)?.toInt() ?? 0
            : 0;
        final int appliedReward = isSameDay
            ? (meta[_dailyRewardAppliedKey] as num?)?.toInt() ?? 0
            : 0;

        final int decayDelta = (decayTarget - appliedDecay).clamp(0, 100000);
        final int rewardDelta = (rewardTarget - appliedReward).clamp(0, 100000);

        final int next = _clampScore(current - decayDelta + rewardDelta);
        final List<int> nextHistory = _pushHistory(history, next);

        tx.update(userRef, {
          'focusScore': next,
          'scoreHistory': nextHistory,
          _scoringMetaKey: {
            _dateKey: today,
            _dailyDecayAppliedKey: appliedDecay + decayDelta,
            _dailyRewardAppliedKey: appliedReward + rewardDelta,
            'restrictedHoursToday': restrictedHoursToday,
            'vowHours': vowHours,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      });

      await _syncFocusScoreLocal(uid);
    } catch (_) {}
  }

  static Future<void> applyBeggarsTax(String uid) async {
    await _applyDelta(uid, -25);
  }

  static Future<void> applyRejectedPleaPenalty(String uid) async {
    await _applyDelta(uid, -100);
  }

  static Future<void> _applyDelta(String uid, int delta) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      await _firestore.runTransaction((tx) async {
        final fresh = await tx.get(userRef);
        if (!fresh.exists) return;

        final data = fresh.data() ?? <String, dynamic>{};
        final int current =
            (data['focusScore'] as num?)?.toInt() ?? _baselineScore;
        final List<int> history = List<int>.from(
          (data['scoreHistory'] as List?)?.map((e) => (e as num).toInt()) ??
              const <int>[],
        );

        final int next = _clampScore(current + delta);
        final List<int> nextHistory = _pushHistory(history, next);

        tx.update(userRef, {
          'focusScore': next,
          'scoreHistory': nextHistory,
          'lastScoreEventAt': FieldValue.serverTimestamp(),
        });
      });

      await _syncFocusScoreLocal(uid);
    } catch (_) {}
  }

  static Future<void> _syncFocusScoreLocal(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) return;
      final int focusScore =
          (snap.data()?['focusScore'] as num?)?.toInt() ?? _baselineScore;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('focus_score', focusScore);
    } catch (_) {}
  }

  static int _clampScore(int value) => value.clamp(_minScore, _maxScore);

  static List<int> _pushHistory(List<int> history, int next) {
    final List<int> out = List<int>.from(history);
    if (out.isNotEmpty && out.last == next) return out;
    out.add(next);
    if (out.length > 7) {
      return out.sublist(out.length - 7);
    }
    return out;
  }

  static double _extractVowHours(Map<String, dynamic> userData) {
    final dynamic vow = userData['vowHours'] ?? userData['goalHours'];
    if (vow is num) return vow.toDouble().clamp(0.5, 24.0);
    return 1.0;
  }

  static int _calculateDecay({
    required double restrictedHoursToday,
    required double vowHours,
  }) {
    final double excess = restrictedHoursToday - vowHours;
    if (excess <= 0) return 0;
    return excess.floor() * 50;
  }

  static double _estimateRestrictedHoursToday({
    required List topApps,
    required Set<String> restrictedPackages,
  }) {
    if (restrictedPackages.isEmpty || topApps.isEmpty) return 0;
    double restrictedMsOver7Days = 0;
    for (final dynamic raw in topApps) {
      if (raw is! Map) continue;
      final String pkg = (raw['packageName'] ?? '').toString();
      if (!restrictedPackages.contains(pkg)) continue;
      final num usageMs = (raw['usageMs'] as num?) ?? 0;
      restrictedMsOver7Days += usageMs.toDouble();
    }
    final double dailyMs = restrictedMsOver7Days / 7.0;
    return dailyMs / (1000 * 60 * 60);
  }

  static Future<int> _estimateCompletedRegimeSessions(
    double restrictedHoursToday,
    double vowHours,
  ) async {
    final schedules = await ScheduleService.getSchedules();
    final bool hasActiveRegimes = schedules.any((s) => s.isActive);
    if (!hasActiveRegimes) return 0;
    if (restrictedHoursToday > vowHours) return 0;
    return 1;
  }

  static String _dateOnly(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
