# 010 - Neutral Credit Terminology

Status: Accepted  
Date: 2026-09-04

## Decision

Revoke uses neutral Commitment and Credit language throughout product documentation, user-facing UI, backend architecture, data models, event names, analytics, state machines, diagrams, and implementation guidance.

The canonical model is:

- `available_credits` for Credits available in the Revoke wallet;
- `locked_credits` for Credits held against an active eligible Commitment;
- `credit_holds` for Commitment-specific holds; and
- `CREDIT_PURCHASE`, `CREDIT_LOCK`, `CREDIT_RELEASE`, `CREDIT_FORFEITURE`, `PREMIUM_REDEMPTION`, and `PURCHASE_REVERSAL` for ledger events.

Preferred user-facing language includes Buy Credits, Available Credits, Locked Credits, Lock Credits, Credits returned, Credits forfeited, Redeem Credits for Premium, and Commitment backed by Credits.

Legacy financial, prize-oriented, and external-withdrawal language is prohibited as canonical Revoke terminology. Existing legacy field names may be mentioned only when documenting migration evidence or an unavoidable compatibility boundary; they are never the v2 domain model or user-facing vocabulary.

## Rationale

Credits are an in-app Revoke entitlement used to back eligible Commitments and access Premium. Neutral terminology accurately communicates that Revoke is a self-accountability product rather than a financial custody or prize platform.

## Consequences

- New documentation and implementation guidance must use the canonical names above.
- Ledger and state diagrams must distinguish Credit lock, release, and forfeiture.
- Any migration from legacy code must translate old names at an explicit boundary rather than carrying them into the v2 contract.
- Documentation reviews must scan canonical and review-packet material for accidental legacy vocabulary.
