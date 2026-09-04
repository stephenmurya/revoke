# 003 — Accountability Circles Use Granular Permissions

Status: **Accepted**

## Decision

Squads evolve into optional Accountability Circles with explicit member permissions that can be overridden per Commitment.

Membership alone must not expose all user/usage data or grant override authority.

## Consequences

- Firestore data exposure must be narrowed;
- override voter eligibility must be explicit;
- product UI should offer permission presets plus advanced toggles;
- Circle participation never gates basic Revoke enforcement.
