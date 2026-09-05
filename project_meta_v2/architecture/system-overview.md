# System Overview

## Status

This document distinguishes the audited current repository from the target Revoke 2.0 architecture. Current implementation evidence is ../audits/2026-09-04-revival-audit.md; current status is ../engineering/status.md.

## Current implementation

Revoke is an Android-first Flutter app. Flutter owns Auth, onboarding, schedule/regime UI, taper setup, settings, Insights, Squads/Pleas/Tribunals, notifications, and the approved-Plea listener. Kotlin owns Accessibility foreground events, UsageStats fallback/backstop, schedule evaluation, native overlays, temporary unlock persistence, local native cache, alarms, boot/restart/watchdog recovery, and UsageStats-derived usage. Firebase owns Auth, Firestore data, FCM, callable/triggered Functions, Tribunal resolution, AI fallback, rap sheets, and blocked-attempt events.

This current foundation is salvageable. Phase 3 provides a user-facing Commitment adapter, Phase 5 provides Circle/Override Authority semantics over compatibility storage, and Phase 6 provides a server-verified Premium entitlement/paywall boundary. A native/server Commitment object, Credit ledger, Credit purchase flow, or durable financial evidence journal is not implemented.

## Target v2 layering

### Product layer: Commitment

Commitment is the primary product object. Reduce progressively moves a measured baseline to a target. Protect establishes a hard boundary. Schedules are generated enforcement mechanisms, not the primary user contract.

### Enforcement layer

Reuse RevokeAccessibilityService, AppMonitorService fallback/backstop, EnforcementEngine, native overlays, RevokeConfig, UsageStats calculators, and boot/alarm/watchdog infrastructure. Initial primitives are Time Block and Usage Limit. Launch Count is outside v2.

### Evidence layer

A server-created immutable Commitment lease defines UTC boundaries and the rule snapshot. Native records behavior and health in an append-only durable journal for Credit-backed Commitments. Android monotonic time supports elapsed evidence; device wall clock cannot decide financial results. See commitment-verification.md.

### Accountability layer

The v2 user-facing layer is an optional Accountability Circle. `squads`/`pleas`/Tribunal remain compatibility storage and routes. Circle member summaries are sanitized; member permissions and per-Commitment sharing are server-authorized; Override Authority is explicit as SELF, AI, or CIRCLE; Circle voters are snapshotted; and resolution side effects are idempotent. Approved access can reach native Android through the existing protected FCM receiver even when Flutter is inactive.

### Credit and Premium layers

Commitment Credits are optional, purchased only through Google Play Billing, stored in an append-only server ledger, and held per Commitment. Evidence resolution is separate from settlement; only FAILURE_VERIFIED after exhausted grace can produce Credit forfeiture. Premium is a prepaid Google Play subscription capability. The native engine never settles Credits or billing.

Phase 6 implements Premium through `in_app_purchase`, `verifyPremiumPurchase`, server-only grants, the sanitized `premiumEntitlement/current` projection, and RTDN-triggered API requery. The initial catalog is `premium` with `prepaid-30d` and `prepaid-365d`; the accepted reference prices are centralized in `product/monetization.md`. Credits and Premium redemption remain later work.

## Offline and policy boundaries

Activated enforcement continues locally where Android permits. Native evidence continues offline and uploads opportunistically. The backend evaluates after authoritative end plus a configurable resolution window. If evidence cannot establish success/failure by the deadline, it resolves UNVERIFIABLE and returns Credits. Google Play compatibility and legal assumptions are pre-release validation gates, not established facts.

Self Override access is a separate local-first path: after deliberate friction, native temporary-unlock persistence can grant a bounded 5/10/15-minute window offline, while a local Override History event queues best-effort synchronization. This local event is not the global server ledger.

## Required prerequisites before Credit-backed Commitments

1. deterministic onboarding and persisted Commitment draft;
2. immutable server lease and rule snapshot;
3. durable native journal and evidence upload;
4. revisioned native synchronization and health acknowledgment;
5. explicit timezone/day-boundary and proof policy;
6. server-authoritative grace and outcome resolution;
7. append-only Credit ledger and purchase lineage;
8. idempotent Google Play verification/reversal handling;
9. policy/legal review and device eligibility rules;
10. auditable reason for every UNVERIFIABLE result.
