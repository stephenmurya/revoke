# Premium Entitlement and Google Play Billing

Status: Phase 6 code complete in the repository. Play Console catalog, licensed-device verification, RTDN delivery, production service credentials, and policy/legal review remain release gates.

This document owns the Revoke 2.0 Premium entitlement boundary. Commitment Credits, Credit-backed Commitments, Premium redemption, and a wallet are not implemented by Phase 6.

## Catalog

Revoke uses one Google Play subscription product, `premium`, with two prepaid base plans:

| Product | Base plan | Reference price | Entitlement period |
| --- | --- | ---: | ---: |
| `premium` | `prepaid-30d` | USD $9.99 | 30 days |
| `premium` | `prepaid-365d` | USD $59.99 | 365 days |

Only the base-plan IDs returned by Google Play are accepted. The client never selects a product by list position, displayed price, or hardcoded currency. Weekly and lifetime plans are outside the initial catalog. The product is prepaid and non-auto-renewing.

## Capability boundary

The server-enforced initial matrix is:

| Capability | Free | Premium |
| --- | --- | --- |
| Basic Revoke use | Yes | Yes |
| One active Protect Commitment | Yes | Yes |
| Additional active Protect Commitments | No | Yes |
| New Reduce activation | No | Yes |
| New AI Architect authority | No | Yes |
| New Circle creation and owner permission management | No | Yes |
| Circle participation, voting, and helping a Premium member | Yes | Yes |

Existing active v1-v5 Protect/Reduce behavior and existing configured AI/Circle policies are grandfathered. Expiry does not rewrite an active policy or abruptly disable an active Commitment. New paid-capability configuration and activation are checked again. When an AI entitlement has expired, pending AI work fails safely; the saved policy remains unchanged and the user can choose a different authority or renew.

## Authority and data flow

```mermaid
flowchart LR
  Paywall[Flutter Paywall] -->|disclosure accepted| Play[Google Play Billing]
  Play -->|purchase token| Verify[verifyPremiumPurchase]
  Verify --> API[purchases.subscriptionsv2.get]
  API --> Validate[validate package/product/base plan/state/expiry/account]
  Validate --> Ack[acknowledge if pending]
  Ack --> Grant[server-only Premium grant]
  Grant --> Entitlement[users/{uid}/premiumEntitlement/current]
  Entitlement --> Flutter[Flutter capability cache]
  RTDN[Google RTDN Pub/Sub] --> Reconcile[requery Developer API]
  Reconcile --> Grant
```

Flutter code lives in:

- `lib/core/services/premium_billing_service.dart`: app-scoped purchase listener, Play product/offer discovery, account obfuscation, disclosure callable, token verification, and purchase completion;
- `lib/core/services/premium_entitlement_service.dart`: one auth-scoped entitlement stream, offline cache, capability presentation, and server capability checks;
- `lib/features/premium/premium_paywall_screen.dart`: reusable paywall and Account entry surface;
- `functions/premium_billing.js`: Play resource normalization, account hash, token-to-account replay binding, idempotent grant calculation, entitlement projection, and RTDN helpers;
- `functions/index.js`: callable verification/disclosure/capability boundaries, Circle creation gate, and RTDN trigger.

## Purchase disclosure

Every initiated Premium purchase records `premium-purchase-v1` through `recordPremiumPurchaseDisclosure` before `buyNonConsumable` opens Google Play. The server stores the user ID, flow ID, disclosure version, and server timestamp under `users/{uid}/premiumDisclosureAcceptances/{purchaseFlowId}`. Existing acceptance never suppresses a later purchase disclosure. Restore/reverification is not a new purchase and may use the existing server purchase record without a new disclosure.

The paywall shows a fresh explicit acknowledgement dialog for every new Premium purchase attempt. It tells the user that Premium is prepaid, does not renew automatically, and provides digital Revoke access for the selected localized Play period. It has no fake purchase success path and no Credit wallet or Premium redemption UI. The in-flight disclosure flow ID is retained in the local purchase boundary across a process restart; this supports verification recovery but does not grant Premium locally.

## Server verification

`verifyPremiumPurchase` accepts only an authenticated user's purchase token and optional disclosure flow ID. For a new token it requires a matching disclosure acceptance. The backend calls `purchases.subscriptionsv2.get` with the fixed package `com.crescence.revoke`, then validates:

1. subscription product is `premium`;
2. line item base plan is exactly `prepaid-30d` or `prepaid-365d`;
3. a prepaid plan is present;
4. subscription state is active and expiry is in the future;
5. `externalAccountIdentifiers.obfuscatedExternalAccountId`, when present, equals the SHA-256 hash of `revoke:account:{uid}`;
6. the token has not been granted twice.

Pending purchases are acknowledged through the Google Play subscriptions acknowledgement endpoint after validation. Flutter completes its plugin purchase only after the callable returns successfully. Raw tokens and purchase lineage are server-only; the callable response contains only sanitized entitlement information.

## Grant and entitlement storage

The server writes:

- `users/{uid}/premiumPurchases/{sha256(purchaseToken)}`: private verified purchase record, token, product/base plan, observed expiry, account binding, acknowledgement, and grant ID;
- `users/{uid}/premiumGrants/{grantId}`: private append-only source grant with base plan, duration, start anchor, status, and observed Play data;
- `users/{uid}/premiumEntitlement/current`: sanitized owner-readable materialized projection containing `active`, `status`, `premiumUntil`, `verifiedAt`, `computedAt`, `plan`, and `sourceSummary`;
- `premiumAccountBindings/{sha256(revoke:account:{uid})}`: server-only account-to-token RTDN lookup binding;
- `premiumPurchaseBindings/{sha256(purchaseToken)}`: server-only token-to-account replay-prevention binding;
- `premiumRtdnEvents/{messageId}`: server-only RTDN idempotency record.

One deterministic grant ID is derived from each token. Repeated verification updates observed purchase data but does not append another grant. Active grants are sorted by source start time and document ID; each plan duration is added sequentially. This keeps a future `CREDIT_REDEMPTION` grant compatible with the same projection without replacing purchase history.

## RTDN, expiry, and reversals

`reconcilePremiumRtdn` watches the manually configured `revoke-premium-rtdn` Pub/Sub topic. RTDN is a signal only. The trigger deduplicates by Pub/Sub message ID, resolves a previously bound account, calls the Developer API again, then marks the matching grant revoked for terminal/revoked/expired state and recomputes the entitlement. History is retained. Expired materialized state is `expired`/inactive; it never silently becomes active from a stale client cache.

## Offline behavior

Flutter may use an unexpired last-server-verified `premiumUntil` value when offline. It cannot extend that value, write grants, or treat an expired cache as Premium. If the server document is absent or expired, the client behaves as Free. Server capability callables remain the final authority before paid-capability activation or new authority configuration.

## Firestore authorization

Rules allow the owner to read only `premiumEntitlement/current`. Client writes to entitlements, grants, purchases, and disclosure acceptances are denied. Server Admin SDK writes the private records and projection. `premiumAccountBindings` and `premiumRtdnEvents` are covered by the default server-only rule.

## Not implemented in Phase 6

- Commitment Credits, purchases, locks, forfeitures, or `PREMIUM_REDEMPTION`;
- Credit-backed Commitment activation;
- automatic commercial onboarding/paywall sequencing;
- Play Console configuration or production service-account secrets;
- live licensed-device, refund, RTDN, and restore testing.
