# System Overview

## Status

This document distinguishes the audited current repository from the target Revoke 2.0 architecture. Current implementation evidence is ../audits/2026-09-04-revival-audit.md; current status is ../engineering/status.md.

## Current implementation

Revoke is an Android-first Flutter app. Flutter owns Auth, onboarding, schedule/regime UI, taper setup, settings, Insights, Squads/Pleas/Tribunals, notifications, and the approved-Plea listener. Kotlin owns Accessibility foreground events, UsageStats fallback/backstop, schedule evaluation, native overlays, temporary unlock persistence, local native cache, alarms, boot/restart/watchdog recovery, and UsageStats-derived usage. Firebase owns Auth, Firestore data, FCM, callable/triggered Functions, Tribunal resolution, AI fallback, rap sheets, and blocked-attempt events.

This current foundation is salvageable but does not implement the v2 Commitment, Circle permissions, Credit ledger, Premium billing, durable evidence journal, or direct Home cards in full.

## Target v2 layering

### Product layer: Commitment

Commitment is the primary product object. Reduce progressively moves a measured baseline to a target. Protect establishes a hard boundary. Schedules are generated enforcement mechanisms, not the primary user contract.

### Enforcement layer

Reuse RevokeAccessibilityService, AppMonitorService fallback/backstop, EnforcementEngine, native overlays, RevokeConfig, UsageStats calculators, and boot/alarm/watchdog infrastructure. Initial primitives are Time Block and Usage Limit. Launch Count is outside v2.

### Evidence layer

A server-created immutable Commitment lease defines UTC boundaries and the rule snapshot. Native records behavior and health in an append-only durable journal for Credit-backed Commitments. Android monotonic time supports elapsed evidence; device wall clock cannot decide financial results. See commitment-verification.md.

### Accountability layer

Squads/Pleas/Tribunals can remain internal compatibility names while evolving to optional Accountability Circles with granular permissions, least-privilege projections, fixed voter snapshots, durable override delivery, and idempotent side effects.

### Credit and Premium layers

Commitment Credits are optional, purchased only through Google Play Billing, stored in an append-only server ledger, and held per Commitment. Evidence resolution is separate from settlement; only FAILURE_VERIFIED after exhausted grace can produce Credit forfeiture. Premium is a prepaid Google Play subscription capability. The native engine never settles Credits or billing.

## Offline and policy boundaries

Activated enforcement continues locally where Android permits. Native evidence continues offline and uploads opportunistically. The backend evaluates after authoritative end plus a configurable resolution window. If evidence cannot establish success/failure by the deadline, it resolves UNVERIFIABLE and returns Credits. Google Play compatibility and legal assumptions are pre-release validation gates, not established facts.

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

