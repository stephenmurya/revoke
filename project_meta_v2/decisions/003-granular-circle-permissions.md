# 003 — Accountability Circles Use Granular Permissions

Status: **Accepted**

## Decision

Squads evolve into optional Accountability Circles with explicit member permissions and explicit per-Commitment sharing/authority assignments.

Membership alone must not expose all user/usage data or grant override authority.

The currently operational permissions are `viewCommitmentSummary`, `viewOverrideHistory`, `receiveOverrideRequests`, `participateInOverrideDiscussion`, `voteOnOverrideRequests`, and `receiveAccountabilityNotifications`. Member-facing data is served through sanitized Circle member summaries and server-authorized projections. Future visibility and Credit-related permissions remain reserved, not production UI.

## Consequences

- Firestore data exposure must be narrowed;
- override voter eligibility must be explicit;
- product UI should offer permission presets plus advanced toggles;
- Circle participation never gates basic Revoke enforcement.
- owners manage another member's permissions server-side;
- members may leave, while an owner with remaining members must transfer ownership;
- Commitment sharing is stored separately from the Circle voter set;
- peer clients must not read full user profiles or FCM tokens.
