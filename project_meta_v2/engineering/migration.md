# Revoke 2.0 Migration and Account Isolation

Last verified: 2026-09-06

## Current migration boundary

The current app still persists and enforces schedules under legacy-compatible keys and Firestore paths such as `users/{uid}/regimes`. The v2 user-facing Commitment layer and later commercial services adapt that infrastructure; they do not yet replace it with a server-native Commitment lease.

## Account-switch policy

Authenticated Flutter local keys for schedules, app selections, whitelist state, reminder preferences, onboarding, taper plans, Premium state, Credit state, and override history are UID-scoped where the service owns the data. Legacy global keys are imported once for the first authenticated account where safe and then removed. Unauthenticated schedule reads and writes are empty/no-op and native schedules are cleared.

On account binding, native Android clears schedules, temporary unlocks, whitelist packages, overlay account context, alarms, and active Credit backing snapshots before the new UID is bound. Flutter binds the native UID before account-scoped services publish state. Native evidence rows without a UID are retained locally but are not uploaded.

## Sign-out, delete, and reinstall

Sign-out clears the Flutter session and rebinds native state to no user. Account deletion removes the currently implemented user-owned Firebase subcollections and Auth record; Premium/Credit ledger records remain server-governed according to retention and financial reconciliation policy rather than being client-deleted. This boundary requires product/legal confirmation before launch.

Offline `FAILURE_VERIFIED_LOCAL` projections and pending reconciliation events are intentionally device-local until upload. A wipe or reinstall before synchronization may lose them. This is an accepted Revoke 2.0 risk. The product principle is to resist ordinary avoidance without creating an adversarial anti-fraud system or requiring continuous connectivity.

## Remaining migration work

- server-authoritative Commitment leases and revision identifiers;
- cross-device onboarding/draft hydration;
- schedule/native synchronization conflict policy;
- native evidence signing and Play Integrity signals;
- explicit backup/restore and device migration policy;
- removal or migration of remaining legacy Focus Score, Squad, Tribunal, and schedule-only UI.

Until these are implemented and tested, migration is defensive compatibility work, not proof of cross-device restoration or financial custody.
