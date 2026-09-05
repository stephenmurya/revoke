import '../models/commitment_draft.dart';

/// Pure commercial branching rules for onboarding.
///
/// Entitlement truth still comes from PremiumEntitlementService and the
/// backend. This helper only answers which path the saved configuration needs.
class OnboardingCapabilityResolver {
  const OnboardingCapabilityResolver._();

  static bool requiresPremium({
    required CommitmentDraft draft,
    required String authority,
    required int activeProtectCount,
    bool creditBackingSelected = false,
  }) {
    return draft.isReduce ||
        authority == 'ai' ||
        authority == 'circle' ||
        activeProtectCount >= 1 ||
        creditBackingSelected;
  }

  static CommitmentDraft freeFallback(CommitmentDraft draft) {
    if (!draft.isReduce) return draft;
    return CommitmentDraft(
      type: 'protect',
      name: draft.name,
      targetApps: draft.targetApps,
      days: draft.days,
      scheduleId: draft.scheduleId,
      protectMode: 'limit',
      durationLimitMinutes:
          (draft.targetDailyMinutes ?? 30).clamp(5, 1440).toInt(),
    );
  }
}
