# 004 - Commitment Credits Are Evidence-First and Fail-Safe

Status: Accepted

## Decision

Revoke 2.0 adopts optional Commitment Credits as an accountability mechanism. Evidence resolution and Credit settlement are separate.

Evidence outcomes are:

- SUCCESS_VERIFIED;
- FAILURE_VERIFIED;
- UNVERIFIABLE;
- CANCELLED_PRE_START.

Settlement outcomes are separate, including CREDIT_RELEASE, CREDIT_RELEASE_GRACE, CREDIT_FORFEITURE, CREDIT_RELEASE_UNVERIFIABLE, and CREDIT_RELEASE_CANCELLED.

Only FAILURE_VERIFIED after applicable grace may produce CREDIT_FORFEITURE. UNVERIFIABLE never forfeits Credits and never consumes grace. Force-close, uninstall, service death, permission failure, OEM battery management, crashes, or evidence gaps cannot independently create financial failure. Positive violation evidence recorded before monitoring loss remains valid.

## Offline provisional settlement

If positive failure evidence is verified while offline, native/client state may provisionally apply the consequence immediately: update available and locked Credit projections, enter FAILURE_VERIFIED_LOCAL, and append a durable pending Credit-forfeiture reconciliation event. The local projection is not the global ledger. When connectivity returns, the server idempotently reconciles the pending event into the canonical ledger.

If app data is wiped or the app is uninstalled/reinstalled before synchronization, the pending local event may be lost. This is an explicitly accepted Revoke 2.0 risk. Revoke resists ordinary avoidance without becoming an adversarial anti-fraud or custody system.

## Consequences

- Credits are released when evidence is unverifiable.
- Short Commitments prefer recovery retry; long Reduce programs use checkpoint grace.
- Settlement is server-authoritative after synchronization and idempotent.
- The initial evidence reconciliation window is 24 hours after authoritative Commitment end, while the server remains able to configure the duration.
- Future Credit eligibility may be restricted after repeated unexplained unverifiable outcomes without punishing uncertainty.
- See ../architecture/commitment-verification.md.
