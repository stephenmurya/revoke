# 007 - Credit-backed Verification Uses a Native Journal and Server UTC

Status: Accepted

## Decision

Credit-backed Commitments require an immutable server-created lease with server UTC start/end and rule snapshots. Native Android records observation and monitoring health in an append-only durable journal, preferably Room/SQLite or equivalent.

Evidence uses Android monotonic elapsed time such as SystemClock.elapsedRealtime for elapsed durations. Device wall-clock time is diagnostic only and cannot independently decide financial success/failure. Evidence batches should use Android Keystore-backed signing; Play Integrity is an additional signal for high-value actions and does not replace behavioral observation.

## Consequences

- Existing RevokeAccessibilityService, UsageStats calculators, service-health, and boot/recovery infrastructure remain the observation foundation.
- Existing SharedPreferences remains suitable for ordinary cache/configuration but not as the financial evidence journal.
- Evidence may continue offline, upload opportunistically, and resolve after a configurable server resolution window.
- See ../architecture/commitment-verification.md.

