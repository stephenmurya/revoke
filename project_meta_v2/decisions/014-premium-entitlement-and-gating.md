# 014 - Premium Entitlement Is Server-Verified and Capability-Gated

Status: Accepted

Date: 2026-09-05

## Decision

Revoke 2.0 uses a prepaid Google Play subscription product named `premium` with `prepaid-30d` and `prepaid-365d` base plans. The accepted reference prices are USD $9.99 for 30 days and USD $59.99 for 365 days. There is no weekly, lifetime, or auto-renewing initial Premium offer.

Premium is an entitlement, not a local billing flag. Google Play tokens are verified by the backend, acknowledged after validation, and represented by idempotent server-only grants plus the sanitized materialized document `users/{uid}/premiumEntitlement/current`. Flutter can cache an unexpired verified expiry for offline presentation but cannot extend or issue Premium. RTDN causes a fresh Developer API query; it is not itself proof of entitlement.

The initial capability matrix is fixed in `product/monetization.md`: Free supports basic Revoke use, one active Protect Commitment, and Circle participation/voting/help; Premium adds additional Protect Commitments, Reduce activation, AI Architect authority, Circle creation, and owner permission management. Existing active v1-v5 behavior and already configured authority policies are grandfathered without destructive policy rewrites.

Every Premium purchase requires a new explicit disclosure acceptance before the Google Play purchase sheet opens. The acceptance is versioned and auditable; an earlier acceptance does not suppress a later purchase disclosure.

## Consequences

- The client must not invent success, prices, duration, or entitlement state.
- New paid-capability activation may fail closed when the server cannot confirm Premium.
- Expiry preserves history and existing configuration while preventing new Premium-only configuration.
- Play Console, licensed-device, RTDN, refund, and production credential setup remain release gates after code completion.

See [the Premium architecture](../architecture/premium-entitlement-and-billing.md) and [the manual Play setup runbook](../engineering/google-play-setup.md).
