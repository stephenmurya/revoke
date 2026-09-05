# 015 - Credit-backed Commitment Activation Uses a Compatibility Lease Boundary

Status: Accepted implementation boundary

## Decision

Phase 7 introduces Credit-backed Commitments without replacing the existing schedule-based enforcement engine. A server callable creates a per-Commitment immutable backing snapshot, Credit hold, and `CREDIT_LOCK` event atomically after Premium, supported-rule, available-Credit, and monitoring preflight checks. Native Android receives the snapshot through a narrow bridge and records observations in its durable SQLite journal.

The server remains authoritative for evidence outcomes, the 24-hour default reconciliation window, grace, Credit release, and Credit forfeiture. Flutter and native Android may maintain provisional local state while offline, but they cannot settle the global ledger. A wipe/reinstall before a pending local event synchronizes may lose that event; this is an explicitly accepted v2 product risk.

## Consequences

- Existing Accessibility, UsageStats, blocker, alarm, watchdog, and temporary-access infrastructure is retained.
- Backing terms and rule snapshots are auditable and tied to one Commitment.
- Incomplete native checkpoint coverage can produce `UNVERIFIABLE`, which releases locked Credits without consuming grace.
- Full server-created Commitment leases, device signing, Play Integrity policy, retry linking, and physical-device validation remain follow-up hardening.

See `../architecture/credit-backed-commitments.md` and `../architecture/commitment-verification.md`.
