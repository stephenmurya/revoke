# Revoke 2.0 Domain Model

Status: Target model for product/engineering alignment. This is not a claim about current Firestore schema; current implementation is in ../engineering/status.md.

## Commitment

Suggested fields:

- id and ownerUserId;
- type: reduce or protect;
- status: draft, ready, active, completed;
- target packages;
- start/end and timezone;
- baseline, goal, plan/checkpoints;
- enforcement and override policies;
- Circle assignments/permissions;
- optional creditBacking;
- activationLeaseId and revision.

## CommitmentActivationLease

Server-created immutable record containing Commitment ID, user ID, server UTC start/end, rule snapshot, locked Credit amount, proof-policy version, grace-policy snapshot, unique nonce, required entitlement, terms version, and native materialization revision.

## CommitmentCheckpoint

Contains Commitment ID, index, window start/end, target, actual, evidence outcome, measured/verification source, grace consumed, evaluation revision, reason codes, and finalization time.

Evidence outcome is one of SUCCESS_VERIFIED, FAILURE_VERIFIED, UNVERIFIABLE, or CANCELLED_PRE_START. Financial settlement is separate and must not be represented by a success/failure boolean.

## EnforcementRule

Internal/materialized representation mapping a Commitment to existing native primitives. Initial v2 types are timeBlock and usageLimit. Do not expose launchCount.

## VerificationWindow

Tracks required signals, health/coverage, clock integrity, schedule/native revision, journal batch, upload state, and whether evidence is sufficient. Device wall clock is diagnostic; server UTC lease boundaries are authoritative and Android monotonic elapsed time supports elapsed evidence.

## NativeEvidenceEvent

Append-only native record with Commitment ID, monotonic sequence, event type, boot-session identity, SystemClock.elapsedRealtime value, observed wall clock, package/app observation, monitoring/service health, permission health, clock/timezone changes, reboot markers, and previous-event hash/chain information.

Credit-backed evidence should use a durable Room/SQLite-equivalent journal, Android Keystore-backed batch signing, and Play Integrity as an additional signal for activation, suspicious recovery, or finalization when policy requires it.

## AccountabilityCircle and permissions

AccountabilityCircle, CircleMembership, and CommitmentMemberPermission contain owner, members, defaults, Commitment-specific grants, and status. Permissions are granular; membership does not expose a full user profile. The current compatibility implementation uses sanitized `squads/{circleId}/members/{uid}` projections and `users/{uid}/commitmentPolicies/{commitmentId}` with separate `selectedMemberIds` (voter authority) and `sharedMemberIds` (summary visibility).

## OverrideRequest

Successor/product abstraction over Plea/Tribunal: Commitment ID, requester, bounded duration, sanitized reason, explicit SELF/AI/CIRCLE authority, policy snapshot, eligible voter snapshot, status, verdict source, approved-until, and idempotency key. The current implementation stores this in `pleas` with compatibility fields and protects decision writes behind callable/triggered backend paths.

## CreditLedgerEntry and CreditHold

CreditLedgerEntry is append-only and server-authoritative. Types are CREDIT_PURCHASE, CREDIT_LOCK, CREDIT_RELEASE, CREDIT_FORFEITURE, PREMIUM_REDEMPTION, and PURCHASE_REVERSAL. `credit_holds` associates each locked amount with one Commitment and purchase lineage. Materialized wallet fields are `available_credits` and `locked_credits`.

## CommitmentEvidenceResolution and CreditSettlement

Evidence resolution stores one of the four evidence outcomes and its proof policy/reason. Credit settlement separately stores CREDIT_RELEASE, CREDIT_RELEASE_GRACE, CREDIT_FORFEITURE, or CREDIT_RELEASE_UNVERIFIABLE plus idempotency and ledger references. Offline positive failure may first be represented locally as FAILURE_VERIFIED_LOCAL with a pending forfeiture event; the server ledger remains canonical after reconciliation.

## PremiumEntitlement

Contains user, provider, product/base plan, status, period end, grant lineage, and server verification time. The current materialized document is `users/{uid}/premiumEntitlement/current`; it is sanitized and owner-readable. Private purchase/token records live under `premiumPurchases`, and source grants live under `premiumGrants`. Premium is prepaid and non-auto-renewing; it is never extended by the client.

The Phase 6 compatibility implementation uses Google Play `purchases.subscriptionsv2.get`, validates `premium` plus `prepaid-30d`/`prepaid-365d`, acknowledges only after validation, and recomputes the projection from idempotent grants. RTDN is a requery signal, not entitlement proof. Existing configured behavior is grandfathered while new paid capabilities are server-gated.
