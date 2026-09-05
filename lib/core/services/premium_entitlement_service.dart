import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/premium_models.dart';

/// The single Flutter read boundary for Premium state and capabilities.
///
/// The server owns the entitlement document. Local storage is only an
/// offline cache of the last server verification; it can never extend the
/// entitlement or create a new grant.
class PremiumEntitlementService {
  PremiumEntitlementService._();

  static final PremiumEntitlementService instance = PremiumEntitlementService._();

  static const String entitlementDocument = 'premiumEntitlement/current';
  static const String _cachePrefix = 'premium_entitlement_v2_';

  final ValueNotifier<PremiumEntitlementState> state = ValueNotifier(
    const PremiumEntitlementState.initial(),
  );
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String? _uid;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  String? get currentUid => _uid;
  PremiumEntitlement get entitlement => state.value.entitlement;
  bool get hasPremium => state.value.isPremium;

  Future<void> initializeForUser(String? uid) async {
    final normalizedUid = uid?.trim();
    if (normalizedUid == null || normalizedUid.isEmpty) {
      await reset();
      return;
    }
    if (_uid == normalizedUid && _subscription != null) return;

    await _subscription?.cancel();
    _subscription = null;
    _uid = normalizedUid;
    state.value = const PremiumEntitlementState.initial();

    final cached = await _readCache(normalizedUid);
    if (cached != null) {
      state.value = PremiumEntitlementState(
        loadState: PremiumEntitlementLoadState.offline,
        entitlement: cached,
        message: 'Using the last verified Premium status.',
      );
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(normalizedUid)
        .collection('premiumEntitlement')
        .doc('current');
    _subscription = ref.snapshots().listen(
      (snapshot) async {
        if (_uid != normalizedUid) return;
        if (!snapshot.exists) {
          await _writeCache(normalizedUid, const PremiumEntitlement.free());
          state.value = const PremiumEntitlementState(
            loadState: PremiumEntitlementLoadState.available,
            entitlement: PremiumEntitlement.free(),
          );
          return;
        }
        final entitlement = PremiumEntitlement.fromFirestore(snapshot.data()!);
        await _writeCache(normalizedUid, entitlement);
        state.value = PremiumEntitlementState(
          loadState: PremiumEntitlementLoadState.available,
          entitlement: entitlement,
        );
      },
      onError: (Object error, StackTrace stack) {
        if (_uid != normalizedUid) return;
        final cachedEntitlement = state.value.entitlement;
        state.value = PremiumEntitlementState(
          loadState: PremiumEntitlementLoadState.offline,
          entitlement: cachedEntitlement,
          message: 'Premium status will recheck when you are online.',
        );
      },
    );
  }

  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('premiumEntitlement')
          .doc('current')
          .get(const GetOptions(source: Source.server));
      if (!snapshot.exists) {
        state.value = const PremiumEntitlementState(
          loadState: PremiumEntitlementLoadState.available,
          entitlement: PremiumEntitlement.free(),
        );
        return;
      }
      final entitlement = PremiumEntitlement.fromFirestore(snapshot.data()!);
      await _writeCache(uid, entitlement);
      state.value = PremiumEntitlementState(
        loadState: PremiumEntitlementLoadState.available,
        entitlement: entitlement,
      );
    } catch (_) {
      state.value = PremiumEntitlementState(
        loadState: PremiumEntitlementLoadState.offline,
        entitlement: state.value.entitlement,
        message: 'Premium status will recheck when you are online.',
      );
    }
  }

  bool can(PremiumCapability capability) {
    if (hasPremium) return true;
    return false;
  }

  bool canCreateProtect({required int activeProtectCount}) {
    return hasPremium || activeProtectCount < 1;
  }

  /// Rechecks a paid capability on the server before a legacy schedule is
  /// persisted. The client cache controls presentation only; it is not the
  /// authority for Premium access.
  Future<bool> assertServerCapability(String capability) async {
    final result = await _functions.httpsCallable('assertPremiumCapability').call({
      'capability': capability,
    });
    final data = Map<String, dynamic>.from(result.data as Map? ?? const {});
    return data['allowed'] == true;
  }

  Future<void> reset() async {
    await _subscription?.cancel();
    _subscription = null;
    _uid = null;
    state.value = const PremiumEntitlementState.initial();
  }

  Future<PremiumEntitlement?> _readCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$uid');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return PremiumEntitlement.fromCacheJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String uid, PremiumEntitlement entitlement) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$uid', jsonEncode(entitlement.toCacheJson()));
    } catch (_) {
      // Cache failures never prevent the server-authoritative path from
      // continuing.
    }
  }
}
