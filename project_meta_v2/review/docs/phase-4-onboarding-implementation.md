# Revoke 2.0 Phase 4 Onboarding Implementation Review

Review date: 2026-09-05

## Change Summary

### Source files created

- `lib/core/models/onboarding_state.dart`: versioned `OnboardingStep`, persisted draft state, and pure route policy.
- `lib/core/services/onboarding_state_service.dart`: user-scoped SharedPreferences persistence and conservative legacy schedule migration.
- `test/core/onboarding_state_test.dart`: exact-step serialization and route-policy coverage.

### Source files modified

- `lib/core/app_router.dart`: explicit onboarding completion gate; removed nickname/Circle/global-permission inference.
- `lib/main.dart`: retained native Circle setup callback now opens the optional `/squad` surface instead of an obsolete onboarding query step.
- `lib/features/auth/onboarding_screen.dart`: deterministic v2 journey, progressive permissions, Reality Check, first Commitment handoff, intervention explanation, and review.
- `lib/features/commitments/create_commitment_screen.dart`: onboarding-aware initial intent and return of the persisted schedule ID while retaining the shared creation engine.
- `lib/features/splash/splash_screen.dart`: presentation-only splash; routing owns auth/onboarding decisions.
- `test/widget_test.dart`: replaced the obsolete counter/Firebase-less smoke test with a real onboarding entry-point test.

## State and routing contract

The persisted `OnboardingState` contains version, exact `OnboardingStep`, nickname draft, intent, and first Commitment ID. A user-scoped local record survives normal restart. A locally or remotely observed persisted schedule is the only legacy migration signal that marks an authenticated user complete; nickname, Circle membership, and Android permissions do not mark completion. If state cannot be read, routing is conservative and resumes onboarding.

After `complete`, missing Android permissions do not send the user back to onboarding. `/permissions` remains an explicit repair surface. The state is currently device-local; cross-device hydration and server-authoritative activation are deferred.

## Journey and permission boundary

```text
Welcome -> Auth -> Identity -> Usage Access -> Reality Check
        -> Reduce/Protect intent -> CreateCommitmentScreen
        -> Accessibility/Overlay/Exact Alarm -> Intervention explanation
        -> Review -> Complete -> Today
```

Usage Access is requested before Reality Check. Accessibility, overlay, and exact-alarm requests are withheld until the first Commitment is saved. Circle creation/joining and nickname are not completion gates.

## First-Commitment integration

The onboarding route pushes the existing `CreateCommitmentScreen` through a normal Flutter route with `initialType` and `onboardingMode`. Reduce therefore still requires measured Usage Insights and uses `TaperPlanService`; Protect still writes the existing usage-limit or time-block `ScheduleModel`. Activation returns the materialized schedule ID, which is stored in onboarding state for the review step.

Persistence remains the Phase 3 compatibility boundary: local SharedPreferences first, best-effort Firestore under `users/{uid}/regimes` / `taperPlans`, and existing native synchronization. No new backend Commitment record or native engine was introduced.

## Regression review

- `flutter analyze`: PASS, no issues found.
- Targeted onboarding/state/widget and Commitment tests: PASS, 9 tests.
- Full `flutter test`: PASS, 34 tests.
- `flutter build apk --debug`: PASS under Flutter 3.47.0/Dart 3.13.0 with the existing Android toolchain. Existing Gradle/AGP/Kotlin support warnings remain; no dependency changes were made.
- The old smoke test was repaired rather than deleted. It now tests the real production onboarding entry widget without requiring Firebase initialization in a unit environment.
- Android enforcement code and Firebase Functions/rules were not changed.

## Deferred work

- nested Reduce/Protect draft persistence before activation;
- cross-device/server onboarding hydration;
- native/server Commitment activation lease;
- device/OEM proof of permission and first-Commitment enforcement;
- optional Circle, override, Credits, Premium, and paywall stages;
- full remote taper hydration and schedule conflict protocol.
