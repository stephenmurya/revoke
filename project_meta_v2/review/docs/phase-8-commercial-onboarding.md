# Phase 8 Commercial Onboarding Implementation Review

Review date: 2026-09-05

This review records the implemented first-run orchestration across the Phase 4 onboarding, Phase 3 Commitment presentation, Phase 5 Circle/Override Authority, Phase 6 Premium, and Phase 7 Commitment Credit boundaries. It does not claim a native/server-native Commitment domain object or production billing readiness.

## Journey Map

The current route is `/onboarding`, backed by `OnboardingScreen` and `OnboardingStateService`.

```text
Welcome/Auth/Identity
        |
   Reality Check
        |
   Commitment intent
        |
  Reduce or Protect draft
        |
 Enforcement permissions -> intervention explanation
        |
  Override Authority: Self / AI Architect / Circle
        |
  Circle setup only when Circle is selected
        |
  Commitment review
        |
 Premium when required -- decline -> explicit Free Protect/Self fallback
        |
 optional Credit backing -> existing Credit backing/purchase return flow
        |
 coordinated activation -> Today
```

Reduce uses `CreateCommitmentScreen` in onboarding mode to collect apps, measured baseline, target, duration, and the generated taper preview. Protect collects either a daily usage limit or a recurring protected period. The onboarding screen keeps the returned `CommitmentDraft` in its user-scoped local state until activation.

## State Machine

`OnboardingStep` now includes the following commercial states in addition to the existing welcome, authentication, identity, usage-access, and reality-check states:

| State | Implemented responsibility |
|---|---|
| `commitmentDraft` | Collect or resume the semantic Reduce/Protect draft |
| `enforcementPermissions` | Verify the device can enforce the draft |
| `intervention` | Explain enforcement and continue |
| `overrideAuthority` | Select Self, AI Architect, or Circle |
| `circleSetup` | Optionally create/join/select Circle voters when Circle authority was selected |
| `commitmentReview` | Review the draft before commercial decisions |
| `premium` | Resolve required Premium through the existing paywall or explicit Free fallback |
| `creditBacking` | Offer optional backing through the existing Credit boundary |
| `readyToActivate` | Confirm final activation |
| `complete` | Persist completion and enter Today |

The legacy `firstCommitment` and `review` states remain readable for migration and compatibility. They are not the new first-run path.

## Draft Model and Persistence

`lib/core/models/commitment_draft.dart` defines `CommitmentDraft`, the explicit adapter boundary between onboarding intent and retained enforcement primitives. It persists:

- intent (`reduce` or `protect`);
- display name and selected package names;
- selected days;
- stable source schedule ID;
- optional taper plan ID;
- Protect mode (`dailyLimit` or `protectedPeriod`);
- limit, start/end minutes, baseline, target, and duration.

`OnboardingState` persists the nested draft, authority, Circle ID/member selection, Credit backing choice/amount, and credit grace policy through `OnboardingStateService`. This survives normal process death in the user-scoped local record. It is not remote Commitment persistence and it is not the canonical Credit ledger.

## Capability Resolution

`OnboardingCapabilityResolver` is a pure, testable policy helper. It requires Premium for:

- Reduce;
- AI Architect authority;
- Circle authority;
- a second active Protect Commitment;
- optional Credit backing.

The Free path supports one Protect Commitment with Self authority. If a user declines a required Premium capability, onboarding presents an explicit fallback. Reduce can be converted to a truthful daily-limit Protect draft using the chosen target; Premium-only authority can continue as Protect/Self. No silent downgrade is performed.

The existing entitlement projection is re-read by `_hasPremium()` at the Premium decision point. This is a capability check, not a new entitlement source.

## Override Authority and Circle

`OnboardingScreen._overrideAuthorityStep` presents Self, AI Architect, and Circle using product language. Self is the local/default policy and does not require a new server write. AI and Circle persist through `CircleService.setPolicy` during activation.

Circle setup is not a mandatory onboarding gate. It is entered only after the user deliberately selects Circle authority. `CircleService.watchMembers` supplies selectable member projections, and only members with `voteOnOverrideRequests` are eligible for selection. Existing `SquadService.createSquad` and `joinSquad` remain the compatibility creation/join boundaries. Membership and Premium are revalidated when the branch is used.

## Premium Integration

`PremiumPaywallScreen` accepts `onboardingMode: true`. It reuses the existing purchase, restore, entitlement, and disclosure behavior rather than introducing an onboarding billing path. When the entitlement becomes active, the onboarding-specific success surface returns to the draft.

Premium is required only where `OnboardingCapabilityResolver` says the selected capability requires it. A declined purchase does not dead-end the user: the explicit Free fallback remains available. Play Console configuration, licensed-device verification, refund/revocation proving, and production credentials remain release gates documented by Phase 6.

## Credit Integration

Credit backing is offered only after Premium resolution and remains optional. `OnboardingScreen` routes to the existing `/commitment/back` screen with the activated compatibility Commitment when the user chooses to back it. `CreditBackingScreen` retains the draft/Commitment context and offers `Buy Credits` through the existing `/credits` flow when the available balance is insufficient.

Onboarding does not invent a purchase, wallet, or ledger implementation. Credit-backed activation requires connectivity and server validation. If the hold/backing step is canceled or fails, the behavioral Commitment is retained and onboarding returns to an explicit recovery state rather than reporting a backed Commitment.

## Activation Coordinator

`lib/core/services/onboarding_activation_coordinator.dart` owns the cross-boundary sequence:

1. validate the draft and materialize the retained `TaperPlanModel` or `ScheduleModel`;
2. persist the behavior through `TaperPlanService` or `ScheduleService`;
3. persist the compatibility regime through `RegimeService` when cloud persistence is available/required;
4. synchronize the schedule payload to native through `ScheduleService.syncWithNative`;
5. persist AI/Circle authority through the existing server policy callable;
6. route optional Credit backing to the existing Credit hold flow.

The sequence is coordinated, not globally atomic. Behavioral persistence and native synchronization remain separate from server entitlement/ledger operations. A Credit hold failure must not erase a valid behavioral Commitment.

## Compatibility Mapping

| User-facing onboarding intent | Materialized compatibility object |
|---|---|
| Protect / daily limit | `ScheduleModel` type `usageLimit` (native type 1) |
| Protect / protected period | `ScheduleModel` type `timeBlock` (native type 0) |
| Reduce | `TaperPlanModel` plus materialized usage-limit schedule (native type 1) |

The adapter preserves stable IDs and existing `createdAt`/`updatedAt` behavior. Launch Count is not produced by the onboarding flow.

## Phase 4 Migration

`OnboardingStateService` recognizes older states with an existing `firstCommitmentId` and migrates them to the current state version without recreating the Commitment. `OnboardingScreen` marks such users as already behaviorally activated and continues through the compatibility review path. Users with `complete` state remain out of onboarding. An old no-ID `firstCommitment` state can be converted into the new persisted draft when its original configuration is available.

## Resume and External Revalidation

Normal process death resumes the persisted semantic state, draft, authority choice, Circle voter selection, and backing choice. External state is not trusted indefinitely:

- device enforcement permissions are checked at the permission/intervention boundary;
- Premium entitlement is re-read before paid capability continuation;
- Circle membership and eligible voters are re-read in Circle setup;
- Credit balance/hold validity remains owned by the existing server-backed Credit flow.

Cross-device draft hydration, a server-native Commitment lease, and stronger synchronization conflict handling remain deferred.

## Testing and Verification

Phase 8 targeted tests cover nested onboarding state round-tripping, Protect draft materialization, and capability resolution/fallback behavior. The existing Commitment creation tests continue to cover normal non-onboarding save behavior.

At the time of this review:

- `flutter analyze` passes with no issues;
- targeted onboarding/Commitment tests pass;
- full `flutter test` passes;
- full backend/Firestore verification passes: 22 Node/Firestore tests;
- Android debug build passes: `build/app/outputs/flutter-apk/app-debug.apk`.

The observed backend run used Node 24.11.1, Firebase CLI 15.26.0, and the local Firestore emulator. The Android build completed in 42.7 seconds with the repository's existing Flutter/Gradle configuration. Flutter reports upgrade-availability warnings for the existing Gradle, Android Gradle Plugin, and Kotlin versions; no upgrades were made in this phase.

The Phase 4 stale Firebase smoke-test concern is not changed by this phase; any remaining failure must be reported separately from Phase 8 behavior rather than hidden by changing unrelated test architecture.

## Deferred Domain Work

- native/server-native Commitment persistence and lease authority;
- cross-device draft hydration;
- complete positive evidence and device-integrity production proof;
- remote taper-plan hydration and schedule conflict resolution;
- Circle migration away from compatibility `squads` naming;
- production Google Play catalog, policy, RTDN, refund, and licensed-device gates;
- a separate commercial recovery surface for abandoned or partially completed activation.

## Scope Confirmation

This phase modified Flutter onboarding, Commitment drafting, Premium paywall integration, Credit backing entry, state persistence, tests, and canonical/review documentation. It did not modify `old_project_meta/`, native enforcement code, Firebase Functions, Firestore rules, browser/iOS work, or the retained enforcement engine.
