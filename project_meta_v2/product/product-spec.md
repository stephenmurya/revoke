# Revoke 2.0 Product Specification

Status: Canonical product direction; not all items are implemented. See ../engineering/status.md before treating any item as current behavior.

## 1. Product model

Revoke 2.0 is a behavioral commitment and rehabilitation system. The primary object is the Commitment, not a schedule or regime.

The product loop is:

Observe -> Commit -> Plan -> Enforce -> Override -> Learn -> Adapt

Commitments are either:

- Reduce: lower usage from a measured baseline to a target through explicit stages;
- Protect: maintain a hard period or usage boundary.

Schedules and native restrictions are generated mechanisms. Initial enforcement primitives are Time Block and Usage Limit. Launch Count is outside v2.

## 2. Intervention model

The conceptual intervention stages are:

1. Notice: awareness without blocking;
2. Resist: friction before continued use;
3. Revoke: access blocked when the Commitment boundary is crossed.

Existing soft reminder, interstitial, and hard-block behavior should map to these stages without a terminology-only rewrite.

## 3. Commitment creation and activation

Users select apps/behavior and define the outcome, baseline, target, dates, enforcement, override policy, optional Circle permissions, optional Credit backing, grace, and verification requirements. The user reviews the complete contract before activation.

Activation creates an immutable server-authoritative lease/snapshot with server UTC boundaries, rule revision, Credit hold if present, proof policy, grace policy, and unique identity. Native schedules are materialized only after required permissions, Premium entitlement, and any Credit purchase/lock requirements are valid and synchronization is acknowledged.

## 4. Evidence and outcomes

Evidence resolution supports:

- SUCCESS_VERIFIED;
- FAILURE_VERIFIED;
- UNVERIFIABLE;
- CANCELLED_PRE_START.

Credit settlement is separate from evidence. Only verified failure after applicable grace may cause Credit forfeiture. Unverifiable behavior never forfeits Credits and never consumes grace. Force-close/uninstall/monitoring loss cannot automatically mean failure; positive violation evidence recorded before monitoring loss remains failure evidence.

See ../architecture/commitment-verification.md.

## 5. Overrides and Circles

Overrides are bounded and policy-controlled by an explicit per-Commitment `SELF`, `AI`, or `CIRCLE` authority. AI evaluates sanitized request context but cannot change an active contract. Accountability Circles are optional, least-privilege, and granular. Membership never grants broad user-profile access or billing authority. Circle voters are snapshotted at request creation and use deterministic majority; Circle timeout rejects without changing authority.

## 6. Today and learning

Today exposes direct interpretable state: active Commitment progress, adherence, override behavior, slips/recovery, grace, verification health, and Credit wallet state where relevant. Focus Score is retired and must not be reintroduced as a replacement composite score.

## 7. Premium and Credits

Premium is a prepaid, non-auto-renewing Google Play subscription capability. The initial product is `premium` with `prepaid-30d` and `prepaid-365d` base plans. The accepted reference prices are USD $9.99 for 30 days and USD $59.99 for 365 days; localized Play pricing is authoritative. Free users can use Revoke with one active Protect Commitment and can participate in another member's Circle. Premium adds new Reduce activation, additional Protect Commitments, AI Architect authority, Circle creation, and owner permission management. Existing active v1-v5 behavior is grandfathered.

Commitment Credits are optional, purchased only through Google Play Billing, and usable only inside Revoke. Credits may be locked behind a Commitment, released on verified success, released on unverifiable/cancelled outcomes, forfeited only after verified failure and exhausted grace, or redeemed for Premium access time. Credits and Credit-backed Commitments are not part of Phase 6 implementation.

The v2 conversion is fixed at 100 Credits = 30 Premium days. This is a design decision, not a policy approval. Final Google Play and legal validation is a pre-release gate.

See monetization.md and ../architecture/credit-ledger-and-billing.md.

## 8. Explicit initial revival boundary

Keep non-financial Time Block and Usage Limit enforcement, local-first operation, basic Insights, optional Circle permissions, the bounded override flow, and the new Premium entitlement boundary. Phase 5 implements Circle/authority semantics over compatibility storage, and Phase 6 implements Premium over server-verified Google Play grants; neither introduces a native/server Commitment domain. Defer Credit implementation, Credit-backed activation, advanced analytics, community regimes, and other financial infrastructure until verification, policy, and ledger prerequisites are complete.
