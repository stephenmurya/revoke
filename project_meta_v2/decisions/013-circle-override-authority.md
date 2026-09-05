# 013 — Override Authority Is Explicit and Server-Authoritative

Status: **Accepted**

## Decision

Every v2 Override Request is governed by an explicit per-Commitment authority:

- `SELF` — local deliberate access request;
- `AI` — the configured server AI evaluator;
- `CIRCLE` — selected Circle members using a fixed voter snapshot.

These authorities do not silently fall back into one another. The old random `SYSTEM_WARDEN` decision path is not a v2 resolver.

Circle voters are validated at request creation, exclude the requester, and are stored on the request. Quorum is strict majority, `floor(n / 2) + 1`, of that immutable voter set. A Circle request that reaches its bounded timeout is rejected; it does not become an AI request.

## Delivery and authority boundary

The existing `pleas` collection and Tribunal infrastructure remain the storage compatibility layer for Override Requests. Client code may request access, discuss, or cast a vote through callable boundaries, but it cannot write approval, rejection, resolved status, AI output, or native unlock authority directly.

Approved access is delivered through both the existing Flutter listener and a targeted, validated FCM/native path. Native delivery binds the payload to the last authenticated app user, validates the package, expiry, and idempotency key, and persists temporary access in the existing native configuration. Repeated delivery must not extend access beyond the authoritative expiry.

## Circle privacy boundary

Circle membership does not grant broad profile, Commitment, usage, or Override History access. The owner controls supported member permissions through server callables. Commitment summary sharing is explicit and separate from Circle voter assignment. Peer clients read sanitized member/projection data rather than full `users/{uid}` documents.

## Compatibility implementation

The Phase 5 implementation uses `users/{uid}/commitmentPolicies/{commitmentId}`, sanitized `squads/{circleId}/members/{uid}` documents, and v2 fields added to legacy `pleas` documents (`authority`, `eligibleVoterIds`, `requiredApprovalCount`, `visibleToUids`, `outcomeSource`, `approvedUntil`, and an idempotency key). A native/server Commitment domain object is not introduced in this phase.
