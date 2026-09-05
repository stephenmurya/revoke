import 'package:flutter_test/flutter_test.dart';

import 'package:revoke/core/models/onboarding_state.dart';

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
}
