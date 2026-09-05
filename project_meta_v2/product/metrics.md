# Metrics and Today Cards

## Phase 9 Insights implementation

The `/insights` destination now uses direct UsageStats/UsageEvents evidence rather than Focus Score. Free users receive the latest 7 complete days; Premium users may select 7 or 30 complete days. The exact metric definitions and provenance are canonical in [insights.md](insights.md). Reduce analysis and recorded override analysis are Premium-only and are omitted when their source data is unavailable. Universal adherence, verified outcomes, recovery, grace, and time-of-day pattern metrics are not currently claimed.

## Focus Score retirement

Focus Score is retired from Revoke 2.0. Legacy storage/UI may remain temporarily for migration, but no opaque composite score should replace it or drive the v2 information architecture.

## Phase 2 Today implementation

The current Today surface uses only existing truthful proxies: native daily usage-limit status, current schedule-block timing, local taper-plan state, native monitoring permissions, temporary-approval package state, and the existing native week usage snapshot. It does not present adherence, recovery, grace, override counts, or any replacement score because the current implementation cannot establish those v2 metrics reliably.

## Today goal

Today answers: “Am I keeping the Commitments I made, and where am I struggling?” Cards should be direct and understandable. Insights separately explains historical usage evidence and trends.

### Active Commitment

Show target, allowance/window, current usage, taper stage, next checkpoint, and time remaining.

### Adherence

Use verifiable checkpoints only:

adherence = verified_successes / verified_checkpoints

Exclude UNVERIFIABLE from the denominator. Do not turn missing telemetry into failure.

### Override behavior

Show requests, approvals, denials, self overrides, requested duration, and relevant change over time. Keep this separate from adherence.

### Reduction progress

Show baseline -> current -> target, current stage, actual recent average, and change since baseline.

### Slips and recovery

A slip is a verified miss. Recovery measures return to plan after a slip, for example recovered slips divided by slips with a follow-up checkpoint. Do not collapse this into a universal score.

### Grace

Show remaining retry/checkpoint grace, consumption history, and whether the Commitment remains eligible for Credit backing.

### Verification health

For Credit-backed Commitments show Verified, Degraded, or Unverifiable with a plain-language reason. Verification health is not a behavioral score.

### Credit wallet

Show available, locked, and total Credits, with Commitment association for locked Credits. Ledger state is server-authoritative.

### Danger Zones

Future analysis may show periods correlated with overruns or overrides, but must not imply causal certainty.
