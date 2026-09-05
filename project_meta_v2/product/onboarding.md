# Revoke 2.0 Onboarding

Status: Phase 4 foundation remains implemented over the retained Firebase/auth, Android permission, schedule, and taper services. Phase 6 adds Premium insertion points and server capability checks; commercial onboarding/paywall sequencing is intentionally not fully wired.

## Phase 4 implementation boundary

`OnboardingStateService` persists an explicit version-2 state record in user-scoped local storage. `OnboardingRoutePolicy` routes only from authentication and that explicit completion state. The journey resumes the persisted step and draft fields; it does not infer completion from nickname, Circle membership, or permission state. Existing users with persisted schedules are conservatively migrated as already active, while ambiguous authenticated users remain in onboarding.

The implemented journey is Welcome -> Authentication -> Identity -> Usage Access -> Reality Check -> Reduce/Protect intent -> first Commitment -> enforcement permissions -> intervention explanation -> review -> complete. The first Commitment reuses `CreateCommitmentScreen`, so it writes the existing schedule/taper records and native-compatible payloads. Usage Access is requested before Reality Check; Accessibility, overlay, and exact-alarm permissions are requested only after the Commitment is saved. Completion is independent of Circle setup.

This is a local-first resume record. It survives normal process death and restart on the device; it is not yet a cross-device onboarding authority. Existing permission repair remains a separate route and permission loss after completion does not redirect to onboarding.

## Goal

Onboarding must explain the problem, establish behavioral reality where possible, create a first Commitment, and resume deterministically after Android settings detours. It must not force a Circle or Credit-backed Commitment.

## Target flow

1. Welcome and thesis.
2. Authentication.
3. Minimum Usage Access request for Reality Check where possible.
4. Reality Check: usage baseline, top distracting apps, and reliable high-usage periods; insufficient history is stated plainly.
5. Select apps/behavior to change.
6. Choose Reduce or Protect.
7. Configure the first Commitment: baseline/target/duration for Reduce, or protected window/cap for Protect.
8. Configure required enforcement permissions: Accessibility, overlay, exact alarms where needed, and battery/OEM guidance.
9. Explain Notice, Resist, and Revoke intervention levels.
10. Choose override authority: self, AI Warden if entitled, Circle, or no override.
11. Optionally create/join an Accountability Circle and set granular permissions.
12. Optionally preview Credit-backed Commitment capability; do not ask for Credits before the user understands the Commitment.
13. Review the full Commitment contract.
14. Show the reusable Premium paywall before activation of paid functionality. Phase 6 exposes this insertion point; the full commercial onboarding sequence remains deferred.
15. If Credit backing was selected, complete the required Credit purchase/lock flow before financially backed activation.
16. Activate only after server validation, immutable lease creation, native materialization, and synchronization acknowledgment.

## Persistence requirements

Persist semantic progress rather than only a page index, including at minimum:

- onboarding progress/state;
- baseline where applicable;
- target goal;
- Commitment draft;
- permission state and return-from-settings state;
- override policy;
- Circle choice and permissions;
- financial backing choice;
- accepted terms/product versions.

The future state machine may add server-backed states such as ACCOUNT_COMPLETE, BASELINE_COMPLETE, OVERRIDE_POLICY_COMPLETE, CREDIT_SETUP_COMPLETE, PAYWALL_REQUIRED, and READY_TO_ACTIVATE. The current mobile state names are the explicit `OnboardingStep` values in `lib/core/models/onboarding_state.dart`; optional Circle/Credit/Premium steps are not silently represented as complete.

## Trust and payment rules

No Circle creation, Credit backing, or Premium purchase is mandatory for ordinary Revoke use. The user must see amount, exact criteria, grace, verification health, and the rule that unverifiable evidence returns Credits before confirming a Credit-backed Commitment. Google Play policy compatibility is not assumed and must be validated before release.
