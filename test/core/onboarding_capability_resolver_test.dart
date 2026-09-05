import 'package:flutter_test/flutter_test.dart';
import 'package:revoke/core/models/commitment_draft.dart';
import 'package:revoke/core/services/onboarding_capability_resolver.dart';

void main() {
  const protect = CommitmentDraft(
    type: 'protect',
    name: 'No social during work',
    targetApps: ['com.example.social'],
    days: [1, 2, 3, 4, 5],
    scheduleId: 'protect-1',
    durationLimitMinutes: 30,
  );
  const reduce = CommitmentDraft(
    type: 'reduce',
    name: 'Reduce social',
    targetApps: ['com.example.social'],
    days: [1, 2, 3, 4, 5, 6, 7],
    scheduleId: 'taper_schedule-1',
    planId: 'plan-1',
    baselineDailyMinutes: 180,
    targetDailyMinutes: 45,
    durationDays: 42,
  );

  test('Free Protect with Self is eligible when it is the only Protect', () {
    expect(
      OnboardingCapabilityResolver.requiresPremium(
        draft: protect,
        authority: 'self',
        activeProtectCount: 0,
      ),
      isFalse,
    );
  });

  test('Reduce, AI, Circle, and additional Protect require Premium', () {
    expect(
      OnboardingCapabilityResolver.requiresPremium(
        draft: reduce,
        authority: 'self',
        activeProtectCount: 0,
      ),
      isTrue,
    );
    expect(
      OnboardingCapabilityResolver.requiresPremium(
        draft: protect,
        authority: 'ai',
        activeProtectCount: 0,
      ),
      isTrue,
    );
    expect(
      OnboardingCapabilityResolver.requiresPremium(
        draft: protect,
        authority: 'circle',
        activeProtectCount: 0,
      ),
      isTrue,
    );
    expect(
      OnboardingCapabilityResolver.requiresPremium(
        draft: protect,
        authority: 'self',
        activeProtectCount: 1,
      ),
      isTrue,
    );
  });

  test('Free fallback preserves the selected apps and target as a limit', () {
    final fallback = OnboardingCapabilityResolver.freeFallback(reduce);
    expect(fallback.type, 'protect');
    expect(fallback.protectMode, 'limit');
    expect(fallback.durationLimitMinutes, 45);
    expect(fallback.targetApps, reduce.targetApps);
    expect(fallback.scheduleId, reduce.scheduleId);
  });
}
