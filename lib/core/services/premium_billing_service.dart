import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/premium_models.dart';
import 'premium_entitlement_service.dart';

class PremiumBillingState {
  const PremiumBillingState({
    required this.isAvailable,
    required this.isLoading,
    required this.isPurchasing,
    this.message,
    this.error,
  });

  const PremiumBillingState.initial()
    : isAvailable = false,
      isLoading = true,
      isPurchasing = false,
      message = null,
      error = null;

  final bool isAvailable;
  final bool isLoading;
  final bool isPurchasing;
  final String? message;
  final String? error;

  PremiumBillingState copyWith({
    bool? isAvailable,
    bool? isLoading,
    bool? isPurchasing,
    String? message,
    String? error,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return PremiumBillingState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      message: clearMessage ? null : message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PremiumPlanOption {
  const PremiumPlanOption({
    required this.plan,
    required this.product,
    this.offerToken,
  });

  final PremiumPlan plan;
  final ProductDetails product;
  final String? offerToken;

  String get price => product.price;
}

typedef CreditPurchaseHandler = Future<void> Function(PurchaseDetails purchase);

/// App-scoped Google Play billing boundary.
///
/// Product metadata and offer tokens come from Play. This service never
/// grants Premium locally; every purchased/restored token is sent to the
/// server verifier before the purchase is completed in the store plugin.
class PremiumBillingService {
  PremiumBillingService._();

  static final PremiumBillingService instance = PremiumBillingService._();

  static const String productId = 'premium';
  static const Set<String> creditProductIds = {'credits_50', 'credits_100'};
  static const String disclosureVersion = 'premium-purchase-v1';
  static const String _pendingFlowPrefix = 'premium_purchase_flow_v2_';

  final ValueNotifier<PremiumBillingState> state = ValueNotifier(
    const PremiumBillingState.initial(),
  );
  final ValueNotifier<List<PremiumPlanOption>> plans = ValueNotifier(
    const <PremiumPlanOption>[],
  );
  final ValueNotifier<List<ProductDetails>> creditProducts = ValueNotifier(
    const <ProductDetails>[],
  );
  final InAppPurchase _store = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  String? _uid;
  String? _activePurchaseFlowId;
  bool _initialized = false;
  CreditPurchaseHandler? _creditPurchaseHandler;

  void registerCreditPurchaseHandler(CreditPurchaseHandler? handler) {
    _creditPurchaseHandler = handler;
  }

  Future<void> initializeForUser(String? uid) async {
    final nextUid = uid?.trim().isEmpty == true ? null : uid?.trim();
    final userChanged = _uid != nextUid;
    _uid = nextUid;
    if (userChanged) {
      _activePurchaseFlowId = nextUid == null
          ? null
          : await _readPendingFlow(nextUid);
    }
    if (_initialized) return;
    _initialized = true;
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error, StackTrace stack) {
        state.value = state.value.copyWith(
          isPurchasing: false,
          error: 'Google Play could not update the purchase state.',
        );
      },
    );
    await refreshProducts();
  }

  Future<void> refreshProducts() async {
    state.value = state.value.copyWith(
      isLoading: true,
      clearError: true,
      clearMessage: true,
    );
    try {
      final available = await _store.isAvailable();
      if (!available) {
        plans.value = const <PremiumPlanOption>[];
        creditProducts.value = const <ProductDetails>[];
        state.value = state.value.copyWith(
          isAvailable: false,
          isLoading: false,
          message: 'Premium purchases are not available on this device.',
        );
        return;
      }

      final response = await _store.queryProductDetails({
        productId,
        ...creditProductIds,
      });
      if (response.error != null) {
        throw StateError(response.error!.message);
      }
      final nextPlans = <PremiumPlanOption>[];
      final nextCreditProducts = <ProductDetails>[];
      for (final product in response.productDetails) {
        if (creditProductIds.contains(product.id)) {
          nextCreditProducts.add(product);
          continue;
        }
        if (product.id != productId) continue;
        if (product is! GooglePlayProductDetails) continue;
        final index = product.subscriptionIndex;
        final offers = product.productDetails.subscriptionOfferDetails;
        if (index == null || offers == null || index >= offers.length) continue;
        final basePlan = PremiumPlanDetails.fromBasePlanId(
          offers[index].basePlanId,
        );
        final offerToken = product.offerToken;
        if (basePlan == null || offerToken == null || offerToken.isEmpty) {
          continue;
        }
        nextPlans.add(
          PremiumPlanOption(
            plan: basePlan,
            product: product,
            offerToken: offerToken,
          ),
        );
      }
      nextPlans.sort((a, b) => a.plan.index.compareTo(b.plan.index));
      plans.value = List.unmodifiable(nextPlans);
      nextCreditProducts.sort((a, b) => a.id.compareTo(b.id));
      creditProducts.value = List.unmodifiable(nextCreditProducts);
      state.value = state.value.copyWith(
        isAvailable: true,
        isLoading: false,
        message: nextPlans.isEmpty
            ? 'Premium plans are not available yet.'
            : null,
        clearMessage: nextPlans.isNotEmpty,
      );
    } catch (error) {
      plans.value = const <PremiumPlanOption>[];
      creditProducts.value = const <ProductDetails>[];
      state.value = state.value.copyWith(
        isAvailable: false,
        isLoading: false,
        error: 'Premium plans could not be loaded. Try again later.',
      );
    }
  }

  Future<bool> purchaseCredits(String productId) async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    final normalized = productId.trim();
    final matching = creditProducts.value.where((item) => item.id == normalized);
    final product = matching.isEmpty ? null : matching.first;
    if (uid == null || uid.isEmpty) {
      state.value = state.value.copyWith(error: 'Sign in before buying Credits.');
      return false;
    }
    if (product == null) {
      state.value = state.value.copyWith(error: 'This Credit product is not available yet.');
      return false;
    }
    state.value = state.value.copyWith(
      isPurchasing: true,
      message: 'Opening Google Play…',
      clearError: true,
    );
    try {
      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: sha256
            .convert('revoke:account:$uid'.codeUnits)
            .toString(),
      );
      final launched = await _store.buyConsumable(purchaseParam: purchaseParam);
      if (!launched) {
        state.value = state.value.copyWith(
          isPurchasing: false,
          message: 'Google Play did not start the purchase.',
        );
      }
      return launched;
    } catch (_) {
      state.value = state.value.copyWith(
        isPurchasing: false,
        error: 'Credit purchase could not be started.',
      );
      return false;
    }
  }

  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _store.completePurchase(purchase);
    }
  }

  Future<bool> purchasePlan(PremiumPlan plan) async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    final matching = plans.value.where((item) => item.plan == plan);
    final option = matching.isEmpty ? null : matching.first;
    if (uid == null || uid.isEmpty) {
      state.value = state.value.copyWith(error: 'Sign in before purchasing Premium.');
      return false;
    }
    if (option == null) {
      state.value = state.value.copyWith(error: 'This Premium plan is not available yet.');
      return false;
    }

    final flowId = 'premium_${DateTime.now().microsecondsSinceEpoch}';
    try {
      await _writePendingFlow(uid, flowId);
      await _functions.httpsCallable('recordPremiumPurchaseDisclosure').call({
        'purchaseFlowId': flowId,
        'disclosureVersion': disclosureVersion,
      });
      _activePurchaseFlowId = flowId;
      state.value = state.value.copyWith(
        isPurchasing: true,
        message: 'Opening Google Play…',
        clearError: true,
      );
      final accountHash = sha256
          .convert('revoke:account:$uid'.codeUnits)
          .toString();
      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: option.product,
        offerToken: option.offerToken,
        applicationUserName: accountHash,
      );
      final launched = await _store.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!launched) {
        _activePurchaseFlowId = null;
        await _clearPendingFlow(uid);
        state.value = state.value.copyWith(
          isPurchasing: false,
          message: 'Google Play did not start the purchase.',
        );
      }
      return launched;
    } on FirebaseFunctionsException catch (error) {
      _activePurchaseFlowId = null;
      await _clearPendingFlow(uid);
      state.value = state.value.copyWith(
        isPurchasing: false,
        error: error.message ?? 'Purchase disclosure could not be recorded.',
      );
      return false;
    } catch (_) {
      _activePurchaseFlowId = null;
      await _clearPendingFlow(uid);
      state.value = state.value.copyWith(
        isPurchasing: false,
        error: 'Premium purchase could not be started.',
      );
      return false;
    }
  }

  Future<void> restorePurchases() async {
    state.value = state.value.copyWith(
      isPurchasing: true,
      message: 'Checking Google Play purchases…',
      clearError: true,
    );
    try {
      await _store.restorePurchases();
    } catch (_) {
      state.value = state.value.copyWith(
        isPurchasing: false,
        error: 'Google Play purchases could not be restored.',
      );
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (creditProductIds.contains(purchase.productID)) {
        final handler = _creditPurchaseHandler;
        if (handler == null) {
          state.value = state.value.copyWith(
            isPurchasing: false,
            error: 'Credit purchase handling is not ready.',
          );
        } else {
          await handler(purchase);
        }
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state.value = state.value.copyWith(
            isPurchasing: true,
            message: 'Purchase pending in Google Play…',
          );
        case PurchaseStatus.error:
          _activePurchaseFlowId = null;
          await _clearPendingFlowForCurrentUser();
          state.value = state.value.copyWith(
            isPurchasing: false,
            error: purchase.error?.message ?? 'Google Play could not complete the purchase.',
          );
        case PurchaseStatus.canceled:
          _activePurchaseFlowId = null;
          await _clearPendingFlowForCurrentUser();
          state.value = state.value.copyWith(
            isPurchasing: false,
            message: 'Purchase canceled.',
          );
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          await _verifyPurchase(purchase);
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    final token = purchase.verificationData.serverVerificationData.trim();
    if (uid == null || uid.isEmpty || token.isEmpty) {
      state.value = state.value.copyWith(
        isPurchasing: false,
        error: 'Purchase verification is unavailable for this account.',
      );
      return;
    }
    state.value = state.value.copyWith(
      isPurchasing: true,
      message: 'Verifying Premium…',
      clearError: true,
    );
    try {
      await _functions.httpsCallable('verifyPremiumPurchase').call({
        'purchaseToken': token,
        if (_activePurchaseFlowId != null && purchase.status == PurchaseStatus.purchased)
          'purchaseFlowId': _activePurchaseFlowId,
      });
      await PremiumEntitlementService.instance.refresh();
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      await _clearPendingFlowForCurrentUser();
      _activePurchaseFlowId = null;
      state.value = state.value.copyWith(
        isPurchasing: false,
        message: 'Premium is active on this account.',
      );
    } on FirebaseFunctionsException catch (error) {
      state.value = state.value.copyWith(
        isPurchasing: false,
        error: error.message ?? 'Premium could not be verified yet.',
      );
    } catch (_) {
      state.value = state.value.copyWith(
        isPurchasing: false,
        error: 'Premium could not be verified yet.',
      );
    }
  }

  Future<void> disposeForTests() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _initialized = false;
    _uid = null;
    _activePurchaseFlowId = null;
  }

  Future<String?> _readPendingFlow(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_pendingFlowPrefix$uid');
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePendingFlow(String uid, String flowId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_pendingFlowPrefix$uid', flowId);
    } catch (_) {
      // The server acceptance remains the primary audit record. A cache
      // failure only means a process restart may require a fresh purchase.
    }
  }

  Future<void> _clearPendingFlow(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_pendingFlowPrefix$uid');
    } catch (_) {}
  }

  Future<void> _clearPendingFlowForCurrentUser() async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    await _clearPendingFlow(uid);
  }
}
