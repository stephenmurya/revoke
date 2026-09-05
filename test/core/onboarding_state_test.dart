import 'package:flutter_test/flutter_test.dart';

import 'package:revoke/core/models/onboarding_state.dart';
import 'package:revoke/core/models/commitment_draft.dart';

void main() {
  test('onboarding state round trips the exact step and draft', () {
    final original = OnboardingState(
      step: OnboardingStep.firstCommitment,
      nickname: 'Alex',
      intent: 'reduce',
      firstCommitmentId: 'schedule-1',
    );

    final restored = OnboardingState.fromJson(original.toJson());

    expect(restored.step, OnboardingStep.firstCommitment);
    expect(restored.nickname, 'Alex');
    expect(restored.intent, 'reduce');
    expect(restored.firstCommitmentId, 'schedule-1');
    expect(restored.isComplete, isFalse);
  });

  test('routing uses explicit completion and ignores permissions/profile', () {
    expect(
      OnboardingRoutePolicy.redirect(
        authenticated: true,
        complete: false,
        location: '/home',
      ),
      '/onboarding',
    );
    expect(
      OnboardingRoutePolicy.redirect(
        authenticated: true,
        complete: true,
        location: '/home',
      ),
      isNull,
    );
    expect(
      OnboardingRoutePolicy.redirect(
        authenticated: true,
        complete: true,
        location: '/onboarding',
      ),
      '/home',
    );
    expect(
      OnboardingRoutePolicy.redirect(
        authenticated: false,
        complete: true,
        location: '/home',
      ),
      '/onboarding',
    );
  });

  test('nested Commitment draft and commercial choices survive restart', () {
    final original = OnboardingState(
      step: OnboardingStep.premium,
      intent: 'reduce',
      commitmentDraft: const CommitmentDraft(
        type: 'reduce',
        name: 'Reduce Social',
        targetApps: ['com.example.social'],
        days: [1, 2, 3, 4, 5],
        scheduleId: 'taper_schedule_1',
        planId: 'plan-1',
        baselineDailyMinutes: 167,
        targetDailyMinutes: 45,
        durationDays: 42,
      ),
      overrideAuthority: 'ai',
      selectedCircleMemberIds: ['member-1'],
      creditBackingSelected: true,
      creditBackingAmount: 20,
      creditGracePolicy: 'ONE',
    );

    final restored = OnboardingState.fromJson(original.toJson());

    expect(restored.step, OnboardingStep.premium);
    expect(restored.commitmentDraft?.targetDailyMinutes, 45);
    expect(restored.commitmentDraft?.durationDays, 42);
    expect(restored.overrideAuthority, 'ai');
    expect(restored.selectedCircleMemberIds, ['member-1']);
    expect(restored.creditBackingSelected, isTrue);
    expect(restored.creditBackingAmount, 20);
    expect(restored.creditGracePolicy, 'ONE');
  });
}
