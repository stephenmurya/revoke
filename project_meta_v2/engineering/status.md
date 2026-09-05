# Engineering Status

Last canonical update: 2026-09-05

Source baseline: ../audits/2026-09-04-revival-audit.md.

This file answers what exists now, not what Revoke 2.0 intends to build. The current repository is pre-Credit but has a Phase 6 Premium-v2 code boundary; live Google Play configuration and production verification remain incomplete.

## Phase 1 mobile foundation implemented

The Flutter design-system foundation and global mobile shell are now implemented without changing native enforcement or backend behavior. `AppTheme`, `ColorScheme`, and `AppColorsExtension` expose semantic surfaces, state colors, typography roles, and restrained component styling. `ThemeService` preserves persisted theme/accent preferences while mapping users to a curated safe accent palette. Shared primitives live under `lib/core/widgets/`. The shell exposes Today, Commitments, Circle, and Insights, with global Credits placeholder, Notifications, and Profile actions. Credits remain a zero-valued UI placeholder because no Credit ledger or billing path exists.

The Commitments management screen was migrated in Phase 3; Insights, Settings, and native overlay visuals retain their legacy implementations until their dedicated phases.

## Phase 2 Today experience implemented

The `/home` shell destination now renders `TodayScreen` rather than the legacy Home/Regimes presentation. Today uses existing schedule state, native daily usage-limit calculations, schedule-block timing, local taper plans, native permission state, temporary approval package state, and the existing native week usage snapshot. Focus Score is removed from the primary Today experience but its legacy route/storage remain for compatibility. Unsupported v2 adherence, recovery, grace, and override metrics are intentionally omitted.

The dedicated Today implementation preserves stable stream identity and stateful scroll behavior. Periodic usage refreshes update only changed status data and do not force a page remount. Commitments management remains under the existing schedule-backed implementation until the Commitment domain phase.

## Phase 3 Commitments implementation

The `/commitments` destination now renders `CommitmentsScreen`. `CommitmentPresentationAdapter` maps existing `ScheduleModel` values into user-facing Reduce and Protect `CommitmentViewModel` values. `CreateCommitmentScreen` provides behavioral intent selection, searchable installed-app selection, measured Reduce baseline, explicit target and bounded duration, actual taper-plan preview, Protect daily-limit and protected-period configuration, review, activation, and same-ID editing. `CommitmentDetailScreen` provides current state, plan, target apps, edit, supported Protect pause/resume, and end behavior.

Persistence and enforcement remain unchanged at the compatibility boundary: Protect daily limit writes `ScheduleType.usageLimit` (native type 1), Protect protected period writes `ScheduleType.timeBlock` (native type 0), and Reduce writes a `TaperPlanModel` that materializes a type 1 schedule. `ScheduleService` remains local-first, queues Firestore sync through `RegimeService`, and synchronizes the same schedule payload to native. No Launch Count schedule is produced by the v2 creation flow. The backend still stores schedules under `users/{uid}/regimes`; a native/server Commitment domain object is not implemented.

## Phase 4 onboarding foundation implemented

`OnboardingState` and `OnboardingStateService` provide a versioned, user-scoped local state machine with exact-step resume and conservative migration. `AppRouter` now uses explicit onboarding completion rather than nickname, Circle membership, or global Android permission checks. Completed users can reach the app after permission loss and use the existing permission repair surface; incomplete users resume `/onboarding`.

The new onboarding journey preserves Firebase/Google authentication, collects identity, requests Usage Access before the Reality Check, presents measured usage where available, collects Reduce/Protect intent, reuses `CreateCommitmentScreen` for a real first Commitment, then requests enforcement permissions and explains intervention before review/completion. The first Commitment persists through the existing `ScheduleService`/`TaperPlanService` local-first boundary and native synchronization. No new Commitment backend, Credits, Premium, Circle permissions, or native engine was added.

## Phase 5 Accountability Circle and Override Authority implementation

The `/squad` compatibility route now renders the optional v2 Circle surface. Circle member access uses server-generated sanitized summaries under `squads/{circleId}/members/{uid}` rather than peer reads of `users/{uid}`. Owners can manage the six currently supported permissions through `setCircleMemberPermissions`; members can leave through `leaveCircle`. Commitment sharing and Override Authority are configured separately in `users/{uid}/commitmentPolicies/{commitmentId}`.

The v2 authority set is explicit: `SELF`, `AI`, or `CIRCLE`. Self requests require a reason, a 30-second reflection period, and 5/10/15-minute bounded access; native temporary-unlock state is used offline and a local history event retries server recording. AI uses the existing sanitized OpenRouter task path and rejects safely. Circle requests snapshot selected eligible voter IDs, exclude the requester, use strict majority `floor(n / 2) + 1`, and reject after the existing five-minute timeout without AI fallback. The old random `SYSTEM_WARDEN` path is no longer used by the v2 callable flow.

Approved AI/Circle access is now delivered through the existing Flutter listener and a targeted FCM data path. `AmnestyPushReceiver` validates the bound app user, package, bounded expiry, and idempotency key before persisting native temporary access, so Flutter does not have to be alive for the native grant. The receiver remains protected by the FCM `SEND` permission. The old `pleas`/Tribunal names and compatibility paths remain internally.

## Phase 6 Premium entitlement and billing foundation implemented

`PremiumBillingService` listens once to the official Flutter purchase stream, discovers the `premium` subscription's `prepaid-30d` and `prepaid-365d` offers by Play-provided base-plan metadata, records the mandatory disclosure before every new purchase, sends purchase tokens to `verifyPremiumPurchase`, and completes purchases only after server verification. `PremiumEntitlementService` exposes one auth-scoped sanitized entitlement stream and caches only the last server-verified expiry for offline presentation; it never extends Premium locally. `PremiumPaywallScreen` is reusable and shows only actual localized Play products, prepaid/non-renewing language, restore, and controlled unavailable states.

The backend uses `purchases.subscriptionsv2.get`, account obfuscation, product/base-plan/state/expiry validation, acknowledgement, idempotent server-only `premiumPurchases`/`premiumGrants`, `premiumEntitlement/current`, and RTDN requery helpers. `assertPremiumCapability` gates new Reduce/additional-Protect activation; Circle creation and owner permission changes, and new AI/Circle authority configuration, are server-gated. Existing active v1-v5 behavior and legacy authority policies are grandfathered. Firestore rules deny client writes to Premium records.

Code is complete for the repository boundary, but Play Console products/base plans, licensed-device tests, production Android Publisher credentials, refund/revocation tests, and RTDN delivery are not verified here. See `google-play-setup.md`.

## Confirmed working or salvageable foundations

- Flutter shell and Firebase initialization in normal app launch;
- Google/Firebase authentication and user bootstrap;
- installed-app discovery and whitelist;
- Time Block and Usage Limit schedules;
- local-first schedule cache and native synchronization path;
- Accessibility foreground-event path and UsageStats fallback/backstop;
- native hard blocker overlay;
- usage-limit soft/interstitial reminders;
- native temporary-unlock persistence;
- boot/alarm/watchdog scaffolding;
- local UsageStats day/week/trend Insights;
- Squad creation/join;
- Plea creation, Tribunal chat, voting, and server-only Plea/vote/message writes;
- AI fallback plus sanitization/parser tests;
- rap sheet and server blocked-attempt ingestion;
- Firestore rules/rap-sheet emulator tests;
- Android Kotlin debug compilation and Flutter static analysis.

## Broken or release-blocking behavior

- remote/cross-device onboarding hydration is not implemented;
- nested onboarding Commitment drafts are not persisted until activation;
- Launch Count is not enforced;
- FCM/native delivery still depends on a valid current token and cannot be device-tested from this repository alone; Flutter listener fallback remains for compatibility;
- taper plans are integrated into the first-Commitment flow but remain incompletely remotely hydrated;
- schedule synchronization has no revision/conflict protocol;
- usage budget source and foreground event source differ without verification-confidence semantics;
- time/day/timezone boundaries are not formally reconciled;
- device/OEM Accessibility recovery lacks integration/device proof.

## V2 product concepts not implemented

- native/server Commitment domain object and immutable activation lease;
- server-authoritative Commitment onboarding state and cross-device hydration;
- complete Circle migration, including broader Commitment progress sharing and removal of all legacy Squad/Plea internals;
- Commitment Credits, Credit holds, append-only Credit ledger, Credit purchase lineage, or Premium redemption;
- production-ready Premium entitlement/paywall lifecycle (repository code exists; Play setup and live verification remain);
- financial evidence outcomes/settlement state machine;
- native append-only evidence journal, signing, and Play Integrity signals;
- v2 adherence, slip/recovery, grace, Credit wallet, and verification-health cards;
- category analytics and Danger Zone analysis;
- Social Regimes/community marketplace;
- complete Launch Count enforcement.

## Present but not v2-ready

- Focus Score is implemented/visible in legacy UI/storage but is retired from v2 product UX;
- Circle is implemented as an optional least-privilege user-facing layer over `squads`;
- Pleas/Tribunals remain compatibility infrastructure with v2 authority fields, fixed voter policy, and idempotent native delivery;
- legacy Home taper entry remains, while the new Commitments flow presents taper as Reduce behavior;
- admin/God Mode, mock Tribunals, score adjustment, and amnesty exist and need an explicit production boundary.

## Revival order

1. prove onboarding and first-Commitment enforcement/recovery on physical/emulated devices;
2. keep the repaired smoke test and existing suites green;
3. prove enforcement/recovery on physical/emulated devices;
4. extend and harden the Commitment presentation/domain adapter over existing schedules;
5. add schedule revisions, native acknowledgments, and conflict policy;
6. formalize usage evidence, timezone rules, monitoring health, and UNVERIFIABLE behavior;
7. complete device/FCM proof of durable override delivery and permission migration/backfill;
8. configure and prove Premium on licensed Play devices, including RTDN/refunds;
9. implement Credit ledger/purchase lineage only after evidence and policy gates;
10. replace Focus Score UI with direct cards;
11. expand advanced insights later.

## Rule

Do not mark a v2 feature implemented because a model, screen, or placeholder exists. Premium is marked as a repository code foundation only; its Play Console and production lifecycle are still unverified. Current documentation decisions are not claims that any Credit path exists in code.
