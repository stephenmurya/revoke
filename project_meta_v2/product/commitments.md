# Commitments

Status: Canonical Revoke 2.0 product model. The user-facing Reduce/Protect management layer is implemented over legacy schedules; current implementation limits are documented separately in ../engineering/status.md.

## Purpose

A Commitment is the primary user-facing contract in Revoke 2.0. Schedules, time blocks, usage limits, taper stages, reminders, and native restrictions are implementation mechanisms generated from or controlled by a Commitment.

## Modes

### Reduce

Progressively reduce usage from a measured baseline to a target over explicit stages/checkpoints.

### Protect

Establish a hard behavioral boundary, such as a protected time window or daily usage maximum. Existing native primitives are Time Block and Usage Limit. Launch Count is outside v2.

## Lifecycle

Recommended lifecycle:

DRAFT -> READY -> ACTIVE -> COMPLETED

Terminal/evaluation outcomes are separate:

- SUCCESS_VERIFIED;
- FAILURE_VERIFIED;
- UNVERIFIABLE;
- CANCELLED_PRE_START.

A non-financial Commitment may record a verified failure without any financial consequence. A financial consequence is governed by the separate settlement state in architecture/commitment-verification.md.

The initial evidence reconciliation window is 24 hours after the authoritative Commitment end and remains server-configurable. Positive offline failure evidence may enter the local provisional state `FAILURE_VERIFIED_LOCAL`, immediately update local Credit projections, and wait for idempotent server reconciliation. The server ledger remains canonical.

## Activation contract

Before activation, the user reviews and confirms:

- target apps and behavior;
- baseline and target where relevant;
- dates, timezone, and checkpoints;
- enforcement and override policy;
- optional Accountability Circle permissions;
- optional Credit backing;
- grace policy and verification requirements.

The server creates an authoritative activation lease/snapshot. After activation, target apps, criteria, dates, Credit amount, grace, and financial terms are immutable. Cosmetic edits may be allowed; changing the contract requires closing/replacing it.

## Checkpoints

Long Commitments use immutable checkpoints. Each checkpoint records planned target, evaluation window, measured result, evidence outcome, whether grace was consumed, outcome, and the evidence/revision used.

A missing signal is not zero usage and is not a failure. If the evidence cannot establish success or failure, the checkpoint is UNVERIFIABLE.

## Grace and recovery

Grace is a settlement policy selected before activation, not an evidence state.

For short one-off Commitments, the preferred initial model is a recovery retry: a verified failure with retry remaining keeps Credits locked while the user receives a short server-defined opportunity to restart a fresh full Commitment. Success releases the Credits. Decline, expiry, or failure after grace exhaustion permits forfeiture.

Long Reduce programs use checkpoint grace rather than restarting the entire program. Exact defaults remain product-configurable. UNVERIFIABLE never consumes grace.

## Monitoring loss and sabotage

Force-close, uninstall, service death, permission failure, OEM battery management, crashes, and unexplained evidence gaps cannot by themselves create FAILURE_VERIFIED. They may make a period UNVERIFIABLE. Positive violation evidence captured before monitoring loss remains valid.

An unverifiable Credit-backed Commitment returns locked Credits. Repeated unexplained unverifiable results may temporarily restrict new Credit-backed Commitments or require stronger integrity checks. Ordinary non-financial Revoke functionality remains available where possible.

## Overrides

An override is an explicit, bounded request to temporarily break or pause an active Commitment. The request follows the Commitment's immutable override policy: self, AI Warden, Circle, fallback, or no override. Approval changes access for the permitted window; it does not change the Commitment's financial criteria unless the contract explicitly says so.

See accountability.md for Circle permissions and architecture/commitment-verification.md for evidence/settlement authority.

## Current implementation boundary

The mobile Commitment experience is an adapter over the existing `ScheduleModel`, `ScheduleService`, `RegimeService`, and `TaperPlanService` contracts. Protect daily limits map to Usage Limit schedules, Protect periods map to Time Block schedules, and Reduce maps to a taper plan plus its materialized Usage Limit schedule. Local schedule persistence, native synchronization, and the `users/{uid}/regimes` Firestore collection remain the implementation authority. A native-persisted or server-authoritative Commitment document/activation lease is not yet implemented.
