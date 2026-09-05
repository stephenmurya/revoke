# Revoke 2.0 Onboarding

Status: Phase 8 commercial onboarding orchestration is implemented over the retained Phase 4 state machine, Phase 3 Commitment adapter, Phase 5 Circle/Override Authority, Phase 6 Premium, and Phase 7 Credit boundaries. The flow remains local-first for behavioral activation and is coordinated rather than globally atomic; Play configuration and production device validation remain release gates.

## Phase 8 implementation boundary

New users now persist a semantic onboarding record with a nested `CommitmentDraft`. The implemented path is Welcome -> Authentication -> Identity -> Usage Access -> Reality Check -> Reduce/Protect draft -> enforcement permissions -> intervention explanation -> Override Authority -> optional Circle setup -> Commitment review -> Premium when required -> optional Credit backing -> coordinated activation -> Today.

`OnboardingStep` is semantic rather than page-index based and now includes override, Circle, Premium, Credit backing, and ready-to-activate states. `CommitmentDraft` persists selected apps, intent, name, Reduce baseline/target/duration, or Protect limit/period/days. `CreateCommitmentScreen(onboardingMode: true)` returns this draft without persisting or synchronizing an active rule.

Premium requirements are resolved from the existing capability model: Reduce, AI/Circle authority, an additional active Protect, or Credit backing requires Premium. A Free user can complete one Protect Commitment with Self authority. Declining Premium offers an explicit conversion to a valid Protect/Self configuration; no silent rewrite occurs. Circle setup is only shown for Circle authority and is revalidated after Premium.

Activation uses `OnboardingActivationCoordinator`: materialize the existing schedule/taper rule, ensure native synchronization, persist non-Self authority through the existing server callable, then optionally open the existing Credit backing flow. If backing fails, the behavioral Commitment remains and onboarding resumes in an explicit recovery state; it is not falsely labeled Credit-backed. This is coordinated activation, not a globally atomic Commitment transaction.

Phase 4 records with an already-created `firstCommitmentId` are migrated without recreating the Commitment. Completed users are not returned to onboarding. External permissions, Premium, Circle membership, and Credit availability are re-read at the relevant stages.

## Phase 4 implementation boundary

`OnboardingStateService` persists an explicit version-3 state record in user-scoped local storage. `OnboardingRoutePolicy` routes only from authentication and that explicit completion state. The journey resumes the persisted step and draft fields; it does not infer completion from nickname, Circle membership, or permission state. Existing users with persisted schedules are conservatively migrated as already active, while ambiguous authenticated users remain in onboarding.

The legacy Phase 4 journey was Welcome -> Authentication -> Identity -> Usage Access -> Reality Check -> Reduce/Protect intent -> first Commitment -> enforcement permissions -> intervention explanation -> review -> complete. It remains the migration reference for in-progress users. New Phase 8 users keep the first Commitment as a draft until final activation. Usage Access is requested before Reality Check; Accessibility, overlay, and exact-alarm permissions are requested only after configuration. Completion is independent of Circle setup unless Circle authority was explicitly chosen.

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
10. Choose override authority: Self, AI Architect if entitled, Circle, or no override.
11. Create/join an Accountability Circle only when Circle authority was deliberately selected, then set granular permissions.
12. Optionally preview Credit-backed Commitment capability; do not ask for Credits before the user understands the Commitment.
13. Review the full Commitment contract.
14. Show the reusable Premium paywall before activation of paid functionality. Phase 8 integrates this insertion point and preserves the draft while the entitlement is resolved.
15. If Credit backing was selected, complete the required Credit purchase/lock flow before financially backed activation.
16. Activate through the coordinated compatibility boundary: persist the retained behavior, synchronize native enforcement, persist non-Self authority, and complete any optional server-authoritative Credit backing. Immutable server Commitment leases and synchronization acknowledgments remain deferred.

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

The current mobile state names are the explicit `OnboardingStep` values in `lib/core/models/onboarding_state.dart`, including semantic `commitmentDraft`, `overrideAuthority`, `circleSetup`, `commitmentReview`, `premium`, `creditBacking`, and `readyToActivate`. Optional Circle/Credit/Premium steps are not silently represented as complete. The state is still device-local rather than a cross-device server authority.

## Trust and payment rules

No Circle creation, Credit backing, or Premium purchase is mandatory for ordinary Revoke use. The user must see amount, exact criteria, grace, verification health, and the rule that unverifiable evidence returns Credits before confirming a Credit-backed Commitment. Google Play policy compatibility is not assumed and must be validated before release.
