import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/credit_models.dart';
import '../native_bridge.dart';
import 'premium_billing_service.dart';

class CreditPurchaseState {
  const CreditPurchaseState({
    this.isPurchasing = false,
    this.message,
    this.error,
  });

  final bool isPurchasing;
  final String? message;
  final String? error;
}

/// Auth-scoped client projection for the server-authoritative Credit ledger.
/// The client may cache a projection and provisional offline consequence, but
/// never writes the wallet or ledger directly.
class CreditService {
  CreditService._();

  static final CreditService instance = CreditService._();
  static const String disclosureVersion = 'credit-purchase-v1';
  static const String _pendingLocalPrefix = 'pending_credit_forfeiture_v2_';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  final ValueNotifier<CreditWallet> wallet = ValueNotifier(
    const CreditWallet.empty(),
  );
  final ValueNotifier<CreditPurchaseState> purchaseState = ValueNotifier(
    const CreditPurchaseState(),
  );
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _walletSubscription;
  String? _uid;
  bool _initialized = false;
  CreditWallet _serverWallet = const CreditWallet.empty();
  List<Map<String, dynamic>> _nativePendingLocal = const [];

  Future<void> initializeForUser(String? uid) async {
    final nextUid = uid?.trim().isEmpty == true ? null : uid?.trim();
    if (_uid == nextUid && _initialized) return;
    await _walletSubscription?.cancel();
    _walletSubscription = null;
    _uid = nextUid;
    wallet.value = const CreditWallet.empty();
    _initialized = nextUid != null;
    if (nextUid == null) return;
    final ref = _firestore
        .collection('users')
        .doc(nextUid)
        .collection('creditWallet')
        .doc('current');
    _walletSubscription = ref.snapshots().listen((snapshot) {
      _serverWallet = CreditWallet.fromFirestore(snapshot.data());
      _applyLocalProjection();
    });
    unawaited(syncPendingLocalForfeitures());
    unawaited(syncNativeEvidence());
    unawaited(syncPendingNativeLocalForfeitures());
  }

  Stream<List<CreditLedgerEntry>> historyStream() {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.value(const <CreditLedgerEntry>[]);
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('creditHistory')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CreditLedgerEntry.fromFirestore(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<List<CreditBackingSummary>> backingsStream() {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.value(const <CreditBackingSummary>[]);
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('creditBackings')
        .where('status', whereIn: const ['LOCKED', 'GRACE'])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => CreditBackingSummary.fromFirestore(doc.id, doc.data()),
              )
              .toList(growable: false),
        );
  }

  Future<bool> purchase(CreditPurchaseProduct product) async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      purchaseState.value = const CreditPurchaseState(
        error: 'Sign in before buying Credits.',
      );
      return false;
    }
    final flowId = 'credit_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final response = await _functions
          .httpsCallable('recordCreditPurchaseDisclosure')
          .call({
            'purchaseFlowId': flowId,
            'productId': product.productId,
            'disclosureVersion': disclosureVersion,
          });
      if ((response.data as Map?)?['success'] != true) {
        throw StateError('Disclosure was not recorded.');
      }
      await _writePendingFlow(uid, flowId);
      final started = await PremiumBillingService.instance.purchaseCredits(
        product.productId,
      );
      if (!started) await _clearPendingFlow(uid);
      return started;
    } on FirebaseFunctionsException catch (error) {
      purchaseState.value = CreditPurchaseState(
        error: error.message ?? 'Credit purchase could not start.',
      );
      return false;
    } catch (_) {
      purchaseState.value = const CreditPurchaseState(
        error: 'Credit purchase could not start.',
      );
      return false;
    }
  }

  Future<void> handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      purchaseState.value = const CreditPurchaseState(
        isPurchasing: true,
        message: 'Purchase pending in Google Play…',
      );
      return;
    }
    if (purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.canceled) {
      await _clearPendingFlowForCurrentUser();
      purchaseState.value = CreditPurchaseState(
        error: purchase.error?.message ?? 'Credit purchase was canceled.',
      );
      return;
    }
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    final token = purchase.verificationData.serverVerificationData.trim();
    if (uid == null || uid.isEmpty || token.isEmpty) {
      purchaseState.value = const CreditPurchaseState(
        error: 'Credit verification is unavailable.',
      );
      return;
    }
    purchaseState.value = const CreditPurchaseState(
      isPurchasing: true,
      message: 'Verifying Credits…',
    );
    try {
      final flowId = await _readPendingFlow(uid);
      final payload = <String, dynamic>{
        'purchaseToken': token,
        'productId': purchase.productID,
      };
      if (flowId != null) payload['purchaseFlowId'] = flowId;
      await _functions.httpsCallable('verifyCreditPurchase').call(payload);
      await PremiumBillingService.instance.completePurchase(purchase);
      await _clearPendingFlow(uid);
      purchaseState.value = const CreditPurchaseState(
        message: 'Credits are available.',
      );
    } on FirebaseFunctionsException catch (error) {
      purchaseState.value = CreditPurchaseState(
        error: error.message ?? 'Credits could not be verified yet.',
      );
    } catch (_) {
      purchaseState.value = const CreditPurchaseState(
        error: 'Credits could not be verified yet.',
      );
    }
  }

  Future<Map<String, dynamic>> createBacking({
    required String commitmentId,
    required int amount,
    required String gracePolicy,
    String retryPolicy = 'SHORT_RETRY_WINDOW',
    String termsAcceptedVersion = 'credit-backing-v1',
  }) async {
    final health = await NativeBridge.checkPermissions();
    final response = await _functions.httpsCallable('createCreditBacking').call(
      {
        'commitmentId': commitmentId,
        'amount': amount,
        'gracePolicy': gracePolicy,
        'retryPolicy': retryPolicy,
        'termsAcceptedVersion': termsAcceptedVersion,
        'monitoringHealth': {
          'accessibility': health['accessibility'] == true,
          'usageStats': health['usage_stats'] == true,
          'overlay': health['overlay'] == true,
        },
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
    final backing = data['backing'];
    if (backing is Map) {
      await NativeBridge.syncCreditBacking(Map<String, dynamic>.from(backing));
    }
    return data;
  }

  Future<Map<String, dynamic>> redeem(int amount) async {
    final response = await _functions
        .httpsCallable('redeemCreditsForPremium')
        .call({'amount': amount});
    return Map<String, dynamic>.from(response.data as Map? ?? const {});
  }

  Future<void> recordOfflineVerifiedFailure({
    required String backingId,
    required int amount,
  }) async {
    if (amount <= 0) return;
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_pendingLocalPrefix$uid';
    final values = prefs.getStringList(key) ?? <String>[];
    final event = jsonEncode({
      'eventId': 'local_${DateTime.now().microsecondsSinceEpoch}',
      'backingId': backingId,
      'amount': amount,
    });
    values.add(event);
    await prefs.setStringList(key, values);
    wallet.value = wallet.value.copyWith(
      lockedCredits: wallet.value.lockedCredits - amount,
    );
  }

  Future<void> syncPendingLocalForfeitures() async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_pendingLocalPrefix$uid';
    final values = prefs.getStringList(key) ?? const <String>[];
    final remaining = <String>[];
    for (final raw in values) {
      try {
        final event = jsonDecode(raw);
        if (event is! Map) continue;
        await _functions
            .httpsCallable('submitPendingLocalForfeiture')
            .call(Map<String, dynamic>.from(event));
      } catch (_) {
        remaining.add(raw);
      }
    }
    await prefs.setStringList(key, remaining);
  }

  Future<void> syncNativeEvidence() async {
    try {
      final pending = await NativeBridge.getPendingCreditEvidence();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final entry in pending) {
        final backingId = (entry['backingId'] as String?)?.trim() ?? '';
        if (backingId.isEmpty) continue;
        grouped
            .putIfAbsent(backingId, () => <Map<String, dynamic>>[])
            .add(entry);
      }
      final uploaded = <String>[];
      for (final group in grouped.entries) {
        await _functions.httpsCallable('submitCreditEvidence').call({
          'backingId': group.key,
          'entries': group.value,
        });
        uploaded.addAll(
          group.value.map((entry) => entry['eventId'].toString()),
        );
      }
      if (uploaded.isNotEmpty) {
        await NativeBridge.markCreditEvidenceUploaded(uploaded);
      }
    } catch (_) {
      // Native evidence stays durable and is retried on the next auth/app pass.
    }
  }

  Future<void> syncPendingNativeLocalForfeitures() async {
    try {
      final pending = await NativeBridge.getPendingLocalCreditForfeitures();
      final unresolved = <Map<String, dynamic>>[];
      final settled = <String>[];
      for (final event in pending) {
        final backingId = (event['backingId'] as String?)?.trim() ?? '';
        final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
        if (uid == null || backingId.isEmpty) continue;
        final backing = await _firestore
            .collection('users')
            .doc(uid)
            .collection('creditBackings')
            .doc(backingId)
            .get();
        final status = (backing.data()?['status'] as String?)?.trim() ?? '';
        if (status.isNotEmpty && status != 'LOCKED' && status != 'GRACE') {
          settled.add(event['eventId'].toString());
          continue;
        }
        await _functions
            .httpsCallable('submitPendingLocalForfeiture')
            .call(event);
        unresolved.add(event);
      }
      if (settled.isNotEmpty) {
        await NativeBridge.clearPendingLocalCreditForfeitures(settled);
      }
      _nativePendingLocal = unresolved;
      _applyLocalProjection();
    } catch (_) {
      // The native event remains durable until the server accepts it.
    }
  }

  Future<String?> _readPendingFlow(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('credit_purchase_flow_v2_$uid');
  }

  Future<void> _writePendingFlow(String uid, String flowId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('credit_purchase_flow_v2_$uid', flowId);
  }

  Future<void> _clearPendingFlow(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('credit_purchase_flow_v2_$uid');
  }

  Future<void> _clearPendingFlowForCurrentUser() async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) await _clearPendingFlow(uid);
  }

  Future<void> reset() async {
    await _walletSubscription?.cancel();
    _walletSubscription = null;
    _uid = null;
    _initialized = false;
    _serverWallet = const CreditWallet.empty();
    _nativePendingLocal = const [];
    wallet.value = const CreditWallet.empty();
  }

  void _applyLocalProjection() {
    final localAmount = _nativePendingLocal.fold<int>(
      0,
      (total, event) => total + ((event['amount'] as num?)?.toInt() ?? 0),
    );
    wallet.value = _serverWallet.copyWith(
      lockedCredits: _serverWallet.lockedCredits - localAmount,
    );
  }

  Future<void> disposeForTests() async => reset();
}
