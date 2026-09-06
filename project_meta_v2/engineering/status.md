# Engineering Status

Last canonical update: 2026-09-06

Source baseline: ../audits/2026-09-04-revival-audit.md.

This file answers what exists now, not what Revoke 2.0 intends to build. The current repository has a Phase 8 commercial onboarding boundary layered over the Phase 3 Commitment, Phase 5 Circle/Override Authority, Phase 6 Premium, and Phase 7 Credit foundations; live Google Play configuration, evidence-device proof, and production verification remain incomplete.

## Phase 1 mobile foundation implemented

The Flutter design-system foundation and global mobile shell are now implemented without changing native enforcement or backend behavior. `AppTheme`, `ColorScheme`, and `AppColorsExtension` expose semantic surfaces, state colors, typography roles, and restrained component styling. `ThemeService` preserves persisted theme/accent preferences while mapping users to a curated safe accent palette. Shared primitives live under `lib/core/widgets/`. The shell exposes Today, Commitments, Circle, and Insights, with global server-derived Credits, Notifications, and Profile actions.

The Commitments management screen was migrated in Phase 3; Settings and native overlay visuals retain their legacy implementations until their dedicated phases.

## Phase 9 Insights implementation

`InsightsScreen` now presents a repository-backed direct-evidence surface. `InsightsRepository` coordinates one bounded native usage overview, installed-app metadata, active local Reduce plans, and a single bounded current-user override-history read. The native `UsageInsightsCalculator` supports 7-day and 30-day complete-period aggregation and accepts a package set for grouped Reduce analysis. Flutter renders a tokenized accessible trend chart, usage overview, top apps, and Premium-only Reduce/recorded-override sections.

Free users receive a useful 7-day view. Premium users can access 30 days and the advanced sections when data exists. Focus Score is removed from `/insights` and the Appearance preview; legacy storage, admin paths, legacy Home compatibility, and `/focus-score` remain for migration. No universal adherence, verified outcomes, recovery, grace, or time-of-day analysis is fabricated.

## Phase 10 native visual alignment and app-wide polish

The active Flutter theme now uses the documented tinted semantic light/dark neutrals and fixed state colors, with governed defaults for dialogs, sheets, snackbars, chips, dividers, progress indicators, and inputs. `RevokeSettingRow` and `RevokeStatusBanner` extend the shared primitive vocabulary. Profile, Appearance, permission repair, notifications, and the global shell received focused token/copy/accessibility refinements; permission polling no longer rebuilds when state is unchanged.

The Kotlin blocker/reminder palette now resolves through `values/revoke_colors.xml`, `values-night/revoke_colors.xml`, and `revoke_dimens.xml`, with native content descriptions for app/logo imagery. Native remains Kotlin-owned and uses controlled Android sans typography; no enforcement logic changed. Physical-device, large-text, TalkBack, OEM, and screenshot verification remain Phase 11/release-hardening work.

## Phase 2 Today experience implemented

The `/home` shell destination now renders `TodayScreen` rather than the legacy Home/Regimes presentation. Today uses existing schedule state, native daily usage-limit calculations, schedule-block timing, local taper plans, native permission state, temporary approval package state, and the existing native week usage snapshot. Focus Score is removed from the primary Today experience but its legacy route/storage remain for compatibility. Unsupported v2 adherence, recovery, grace, and override metrics are intentionally omitted.

The dedicated Today implementation preserves stable stream identity and stateful scroll behavior. Periodic usage refreshes update only changed status data and do not force a page remount. Commitments management remains under the existing schedule-backed implementation until the Commitment domain phase.

## Phase 3 Commitments implementation

The `/commitments` destination now renders `CommitmentsScreen`. `CommitmentPresentationAdapter` maps existing `ScheduleModel` values into user-facing Reduce and Protect `CommitmentViewModel` values. `CreateCommitmentScreen` provides behavioral intent selection, searchable installed-app selection, measured Reduce baseline, explicit target and bounded duration, actual taper-plan preview, Protect daily-limit and protected-period configuration, review, activation, and same-ID editing. `CommitmentDetailScreen` provides current state, plan, target apps, edit, supported Protect pause/resume, and end behavior.

Persistence and enforcement remain unchanged at the compatibility boundary: Protect daily limit writes `ScheduleType.usageLimit` (native type 1), Protect protected period writes `ScheduleType.timeBlock` (native type 0), and Reduce writes a `TaperPlanModel` that materializes a type 1 schedule. `ScheduleService` remains local-first, queues Firestore sync through `RegimeService`, and synchronizes the same schedule payload to native. No Launch Count schedule is produced by the v2 creation flow. The backend still stores schedules under `users/{uid}/regimes`; a native/server Commitment domain object is not implemented.

## Phase 4 onboarding foundation implemented

`OnboardingState` and `OnboardingStateService` provide a versioned, user-scoped local state machine with exact-step resume and conservative migration. `AppRouter` now uses explicit onboarding completion rather than nickname, Circle membership, or global Android permission checks. Completed users can reach the app after permission loss and use the existing permission repair surface; incomplete users resume `/onboarding`.

The Phase 4 journey remains the compatibility path for older in-progress records. Phase 8 adds a nested persisted `CommitmentDraft`, commercial/authority branches, and coordinated activation. New users keep configuration out of `ScheduleService`/`TaperPlanService` until final activation; `CreateCommitmentScreen(onboardingMode: true)` returns the draft, then `OnboardingActivationCoordinator` materializes the existing schedule/taper rule, synchronizes native enforcement, persists non-Self authority through the existing server boundary, and optionally enters the Phase 7 backing flow. No new Commitment backend or native engine was added.

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

- remote/cross-device onboarding hydration remains unavailable; the nested draft is device-local;
- Launch Count is not enforced;
- FCM/native delivery still depends on a valid current token and cannot be device-tested from this repository alone; Flutter listener fallback remains for compatibility;
- taper plans are integrated into the first-Commitment flow but remain incompletely remotely hydrated;
- schedule synchronization has no revision/conflict protocol;
- usage budget source and foreground event source differ without verification-confidence semantics;
- time/day/timezone boundaries are not formally reconciled;
- device/OEM Accessibility recovery lacks integration/device proof.

## Phase 7 Commitment Credits implementation

`CreditService` exposes the server wallet projection, sanitized history, purchase lifecycle, every-purchase disclosure flow, Premium redemption, native evidence upload, and offline local projection. `PremiumBillingService` remains the single app-scoped Google Play purchase listener and routes `credits_50`/`credits_100` through its consumable branch. The app-bar pill now reads server-derived available Credits and `/credits` provides the restrained detail surface.

`credit_ledger.js` verifies ProductPurchaseV2, never credits pending purchases, acknowledges and consumes on the server, binds tokens to accounts, appends immutable events, atomically creates per-Commitment holds, creates schedule-backed backing snapshots, accepts evidence batches, reconciles reversals, resolves after the 24-hour default window, and creates Credit-derived Premium grants. `firestore.rules` denies client writes to authoritative Credit state.

Android `CreditEvidenceStore` provides the append-only SQLite journal with sequences and hash-chain fields. `RevokeAccessibilityService` records targeted observations and positive block evidence; local verified-failure projections are durably retained until upload. This remains a compatibility implementation over existing schedule enforcement, not a new enforcement engine.

Repository code is present, but Google Play product configuration, licensed-device purchase/consumption/reversal testing, RTDN delivery, physical-device evidence coverage, signing/Integrity configuration, legal/policy review, and production operational readiness are not verified.

## Phase 8 Commercial Onboarding integration

`OnboardingState` now persists semantic states for Commitment draft, enforcement permissions, intervention, Override Authority, optional Circle setup, Commitment review, Premium, optional Credit backing, ready-to-activate, and completion. `CommitmentDraft` stores the Reduce/Protect configuration required to resume after process death without creating an active schedule early.

The final sequence is Reality Check -> Commitment draft -> enforcement permissions -> intervention -> Override Authority -> optional Circle setup -> Commitment review -> Premium when required -> optional Credit backing -> coordinated activation -> Today. Reduce, AI Architect, Circle authority, additional Protect capacity, and Credit backing use the existing Premium capability boundary. A Free user can complete one Protect Commitment with Self authority; declining Premium offers an explicit valid Free fallback.

`OnboardingActivationCoordinator` preserves the compatibility architecture. Behavioral persistence remains local-first and best-effort remote/native synchronization; non-Self authority requires the existing server policy boundary; Credit backing is opened only after the behavioral Commitment exists and is validated by the Phase 7 server callable. If backing is declined or fails, the behavioral Commitment is retained and the user is returned to an explicit recovery choice. This is coordinated activation, not global atomicity.

Phase 4 users with an existing `firstCommitmentId` are migrated without creating a duplicate. Completed users are not returned to onboarding. Premium, Circle membership, Android permissions, and Credit availability remain external authorities and are re-read at their decision points.

## V2 product concepts not implemented

- native/server Commitment domain object and immutable activation lease;
- server-authoritative Commitment onboarding state and cross-device hydration;
- complete Circle migration, including broader Commitment progress sharing and removal of all legacy Squad/Plea internals;
- full native/server Commitment lease model, complete proof coverage, retry-linked settlement, and cross-device Credit restoration hardening;
- production-ready Premium entitlement/paywall lifecycle (repository code exists; Play setup and live verification remain);
- complete device signing and Play Integrity signals;
- complete v2 adherence, slip/recovery, and verification-health cards;
- verified Commitment outcome history, universal adherence, recovery/grace history, Protect violation history, and time-of-day Insights aggregation;
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
10. replace remaining Focus Score UI outside Insights and Appearance compatibility surfaces;
11. expand advanced Insights only when authoritative history exists.

## Rule

Do not mark a v2 feature implemented because a model, screen, or placeholder exists. Credit and Premium are repository code foundations with live Play, device, policy, and production gates still open. The server ledger remains canonical; the local wallet projection and `FAILURE_VERIFIED_LOCAL` state are provisional only.

## Phase 11 reliability, security, migration, device, and release hardening

Phase 11 hardened repository-verifiable boundaries without changing product scope or replacing the native enforcement architecture. Native and Flutter user-bound state now clears or scopes schedules, temporary unlocks, whitelist data, Credit backing snapshots, evidence, Tribunal outcome markers, and legacy Focus Score caches across account changes. Auth binds the native UID before account-scoped services publish state. Native evidence records carry a UID and client uploads are filtered to the current account.

Credit evidence submission now uses an allowlisted client schema, rejects conflicting event-ID reuse, is idempotent for retries, and never accepts client-controlled trusted fields. Only server-trusted evidence may produce a final evidence outcome. Credit-backed Commitment creation is fail-closed by default through `REVOKE_CREDIT_BACKING_ENABLED` until a server-verifiable evidence path exists. Concurrent grace consumption and final settlement use one transaction over the latest backing, hold, and wallet state.

The release APK and AAB build successfully and report compile/target SDK 36; resolved Billing Library is 8.0.0. `flutter analyze`, Android Kotlin compilation under JDK 17, and 11 pure backend tests pass. The Firestore emulator suite could not run because local port 8080 was occupied. Physical devices, OEM recovery, licensed Play lifecycle, RTDN, production signing, Play Integrity, policy/privacy, and operational gates remain unverified. Revoke is buildable and materially hardened, not production-ready. See `engineering/release-readiness.md`, `engineering/migration.md`, `engineering/device-test-matrix.md`, and `review/docs/phase-11-hardening.md`.
