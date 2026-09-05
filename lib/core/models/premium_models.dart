import 'package:cloud_firestore/cloud_firestore.dart';

enum PremiumPlan { prepaid30d, prepaid365d }

extension PremiumPlanDetails on PremiumPlan {
  String get basePlanId => switch (this) {
    PremiumPlan.prepaid30d => 'prepaid-30d',
    PremiumPlan.prepaid365d => 'prepaid-365d',
  };

  String get durationLabel => switch (this) {
    PremiumPlan.prepaid30d => '30 days',
    PremiumPlan.prepaid365d => '365 days',
  };

  String get displayLabel => switch (this) {
    PremiumPlan.prepaid30d => '30-day Premium',
    PremiumPlan.prepaid365d => '365-day Premium',
  };

  static PremiumPlan? fromBasePlanId(String? value) {
    return switch (value?.trim()) {
      'prepaid-30d' => PremiumPlan.prepaid30d,
      'prepaid-365d' => PremiumPlan.prepaid365d,
      _ => null,
    };
  }
}

enum PremiumCapability {
  additionalProtectCommitment,
  reduceCommitment,
  aiAuthority,
  circleAuthority,
  circleCreation,
  circleMemberManagement,
}

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.active,
    required this.premiumUntil,
    required this.verifiedAt,
    required this.status,
    this.plan,
    this.sourceSummary,
  });

  const PremiumEntitlement.free()
    : active = false,
      premiumUntil = null,
      verifiedAt = null,
      status = 'free',
      plan = null,
      sourceSummary = null;

  final bool active;
  final DateTime? premiumUntil;
  final DateTime? verifiedAt;
  final String status;
  final PremiumPlan? plan;
  final String? sourceSummary;

  bool get isExpired => premiumUntil == null || !premiumUntil!.isAfter(DateTime.now());

  factory PremiumEntitlement.fromFirestore(Map<String, dynamic> data) {
    DateTime? readDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final until = readDate(data['premiumUntil']);
    final serverActive = data['active'] == true;
    final active = serverActive && until != null && until.isAfter(DateTime.now());
    return PremiumEntitlement(
      active: active,
      premiumUntil: until,
      verifiedAt: readDate(data['verifiedAt']),
      status: (data['status'] as String?)?.trim().isNotEmpty == true
          ? (data['status'] as String).trim()
          : active
          ? 'active'
          : 'expired',
      plan: PremiumPlanDetails.fromBasePlanId(data['plan'] as String?),
      sourceSummary: data['sourceSummary'] as String?,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'active': active,
    'premiumUntil': premiumUntil?.toIso8601String(),
    'verifiedAt': verifiedAt?.toIso8601String(),
    'status': status,
    'plan': plan?.basePlanId,
    'sourceSummary': sourceSummary,
  };

  factory PremiumEntitlement.fromCacheJson(Map<String, dynamic> data) {
    final until = DateTime.tryParse(data['premiumUntil'] as String? ?? '');
    final active = data['active'] == true && until != null && until.isAfter(DateTime.now());
    return PremiumEntitlement(
      active: active,
      premiumUntil: until,
      verifiedAt: DateTime.tryParse(data['verifiedAt'] as String? ?? ''),
      status: active ? 'active' : 'free',
      plan: PremiumPlanDetails.fromBasePlanId(data['plan'] as String?),
      sourceSummary: data['sourceSummary'] as String?,
    );
  }
}

enum PremiumEntitlementLoadState { loading, available, offline, unavailable }

class PremiumEntitlementState {
  const PremiumEntitlementState({
    required this.loadState,
    required this.entitlement,
    this.message,
  });

  const PremiumEntitlementState.initial()
    : loadState = PremiumEntitlementLoadState.loading,
      entitlement = const PremiumEntitlement.free(),
      message = null;

  final PremiumEntitlementLoadState loadState;
  final PremiumEntitlement entitlement;
  final String? message;

  bool get isPremium => entitlement.active;
  bool get isLoading => loadState == PremiumEntitlementLoadState.loading;
}
