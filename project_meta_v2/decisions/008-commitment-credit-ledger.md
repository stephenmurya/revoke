# 008 - Commitment Credits Use an Append-only Server Ledger

Status: Accepted

## Decision

Credits are purchased only through Google Play Billing and remain inside Revoke. The canonical source of truth is an append-only server-authoritative Credit ledger plus Commitment-specific holds. Clients cannot issue, destroy, release, forfeit, or redeem Credits directly.

Ledger transaction types include CREDIT_PURCHASE, CREDIT_LOCK, CREDIT_RELEASE, CREDIT_FORFEITURE, PREMIUM_REDEMPTION, and PURCHASE_REVERSAL. Purchase lineage is retained for every Credit. Materialized wallet fields use available_credits, locked_credits, and credit_holds.

## Consequences

- available_credits and locked_credits may be materialized read caches only.
- Simultaneous Commitments use separate holds.
- Purchase verification, consumption/acknowledgement, reversals, and settlement use atomic/idempotent backend transactions.
- A purchase is the external payment transaction; Credit forfeiture revokes an in-app entitlement and is not a second payment transaction.
- See ../architecture/credit-ledger-and-billing.md.

## Phase 7 implementation note

The repository implementation is in `functions/credit_ledger.js` and `lib/core/services/credit_service.dart`. Server callables create immutable events, sanitized wallet/history projections, and per-Commitment holds; Firestore rules deny client writes. Google Play, production credentials, and reversal/consumption device tests remain open.
