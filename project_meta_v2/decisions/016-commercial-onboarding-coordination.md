# 016 - Commercial Onboarding Uses Draft-First Coordinated Activation

Status: Accepted implementation boundary

## Decision

New-user onboarding keeps the first Revoke 2.0 Commitment as a persisted semantic `CommitmentDraft` until the user has configured enforcement permissions, Override Authority, and any required Premium or optional Credit backing. Reduce and Protect remain the user-facing intents; the draft materializes the retained schedule/taper compatibility objects only at activation.

The onboarding order is Reality Check -> Commitment draft -> enforcement permissions -> intervention explanation -> Override Authority -> optional Circle setup -> Commitment review -> Premium when required -> optional Credit backing -> coordinated activation -> Today. A Free user may complete one Protect Commitment with Self authority. Circle setup is shown only for Circle authority, and Credit backing is optional.

`OnboardingActivationCoordinator` sequences behavioral persistence, native synchronization, authority persistence, and optional server Credit backing. This is coordinated activation with explicit recovery states, not globally atomic activation, because schedule persistence remains local-first while Premium and Credit state remain server-authoritative. A failed Credit hold does not delete a valid behavioral Commitment or falsely mark it as backed.

## Migration and resume

Phase 4 records with an existing `firstCommitmentId` are treated as already behaviorally activated and are never recreated. Completed users are not returned to onboarding. Drafts, authority, Circle voter selection, and backing choice survive normal process death in the user-scoped local onboarding record; Android permissions, Premium entitlement, Circle membership, and Credit balance are revalidated at their decision points.

Declining a required Premium capability is never a dead end. After explicit confirmation, Reduce or Premium-only authority can be converted to the valid Free Protect/Self path. The original draft is not silently rewritten.

## Consequences

- Onboarding no longer creates an active first Commitment before the user finishes the commercial and authority decisions.
- Existing Phase 3 schedule/taper services, native enforcement, Circle services, Premium paywall, and Credit backing screen remain the implementation boundaries.
- New Credit-backed onboarding activation requires connectivity for server validation and hold creation.
- Local-first behavioral activation can survive an unavailable backend where Self authority and no Credit backing are selected, but production operations must continue to harden synchronization and recovery.
- A native/server Commitment lease and cross-device onboarding authority remain deferred.

See `../product/onboarding.md`, `../architecture/credit-backed-commitments.md`, and `../engineering/status.md`.
