# Monetization

Status: Phase 7 Credit wallet, purchase, backing, evidence-upload, settlement, and Premium-redemption repository boundaries are implemented behind server verification. Google Play Console configuration, licensed-device testing, RTDN delivery, evidence-device testing, production credentials, and policy review remain release work; see ../engineering/status.md.

## Product systems

Revoke has two distinct optional/paid systems:

1. **Premium**: paid access to Revoke digital capabilities.
2. **Commitment Credits**: optional in-app accountability credits that can be locked behind a Commitment.

They are separate entitlements and must not be presented as interchangeable options.

## Commitment Credits

Use only the user-facing terms Credits, Commitment Credits, Lock Credits, Credits returned, and Credits forfeited.

Credits are an accountability mechanism, not an investment, prize system, or method of making money. They are optional: ordinary non-financial Commitments work without them.

Credits can only be obtained by purchasing through Google Play Billing. They are not earned for free, cannot be transferred or sold, cannot be redeemed for cash, physical goods, or outside services, and remain usable only inside Revoke. A Commitment may lock Credits; successful completion releases the same Credits; verified failure after exhausted grace may permanently forfeit them. Successful behavior never awards more Credits than the amount originally locked. Credits may also be redeemed for Revoke Premium access time.

Evidence and financial settlement are separate. The evidence outcomes are SUCCESS_VERIFIED, FAILURE_VERIFIED, UNVERIFIABLE, and CANCELLED_PRE_START. UNVERIFIABLE returns Credits and never consumes grace. Only verified failure after applicable grace can produce Credit forfeiture. See ../architecture/commitment-verification.md.

## Google Play Credit catalog

The initial conceptual one-time products are:

- credits_50: 50 Credits;
- credits_100: 100 Credits.

Google Play localized pricing is authoritative for what the user pays. Keep catalog and reference pricing centralized and do not scatter prices across architecture documents. Do not add discounted bulk tiers to the v2 launch scope without separate approval.

## Premium

Premium uses a Google Play subscription product with prepaid base plans:

- subscription product: premium;
- base plan: prepaid-30d;
- base plan: prepaid-365d;
- 30-day prepaid Premium: USD $9.99 reference price;
- 365-day prepaid Premium: USD $59.99 reference price.

Prepaid Premium does not auto-renew. Weekly and lifetime plans are not in the initial v2 catalog. Google Play localized pricing determines actual market pricing; the reference prices are not literal currency-conversion rules.

The accepted initial entitlement matrix is:

| Capability | Free | Premium |
| --- | --- | --- |
| Basic Revoke use | Yes | Yes |
| One active Protect Commitment | Yes | Yes |
| Additional active Protect Commitments | No | Yes |
| Reduce Commitments | No for new activation | Yes |
| AI Architect authority | No for new configuration | Yes |
| Circle creation and owner permission management | No for new actions | Yes |
| Circle participation, voting, and helping another member | Yes | Yes |

Existing active v1-v5 behavior is grandfathered at the migration boundary. Existing active Protect and Reduce Commitments are not abruptly disabled when an account is free. A Premium check is required for new paid-capability activation or reconfiguration; the backend remains authoritative.

The primary paywall is reusable and appears after the user understands/configures a paid capability. Commercial onboarding is not fully wired in Phase 7. Credits belong in the Commitment/Wallet experience, not as a replacement for the Premium paywall. Credit purchases require active Premium; redemption is the exception and does not require active Premium.

Premium status is derived from server-verified Google Play grants and exposed to Flutter through a sanitized entitlement document. The client may cache the last verified expiry for offline presentation, but cannot extend it or issue Premium locally. On expiry, AI/Circle authority is unavailable for new configuration; an existing configured policy is not rewritten automatically.

Credit-backed Commitments should be a Premium capability unless a later canonical decision changes that boundary.

## Fixed Credit conversion

The v2 conversion is stable for already purchased Credits:

**100 Credits = 30 Premium days**

Therefore 10 Credits = 3 days, 50 Credits = 15 days, and 100 Credits = 30 days.

Backend accounting uses:

SECONDS_PER_CREDIT = 25920
extension_seconds = credits_redeemed * 25920
new_premium_until = max(existing_premium_until, server_now) + extension_seconds

The initial UI allows redemption in multiples of 10 Credits. Future Premium pricing changes must not devalue existing Credits; adjust future acquisition prices instead.

## Mandatory Credit purchase disclosure

Every time a user initiates a Credit purchase, Revoke must show a purchase disclosure before launching the Google Play purchase sheet. This is required every time: it is not first-purchase-only, onboarding-only, dismiss-once, or remember-my-choice behavior. The user must explicitly confirm understanding before Revoke invokes Google Play Billing.

The disclosure must communicate that:

- Revoke Credits are digital in-app Credits;
- Credits cannot be withdrawn, transferred to another user, exchanged for cash, or redeemed outside Revoke;
- Credits can back eligible Revoke Commitments;
- a successful eligible Commitment returns locked Credits to the user's Revoke wallet;
- a failed eligible Commitment can permanently forfeit those locked Credits;
- Credits can be redeemed for Revoke Premium access time; and
- Credits have no external cash value.

Record an auditable `credit_purchase_disclosure_accepted` event containing at least `disclosureVersion`, `userId`, a server/client timestamp, and `purchaseFlowId`. An earlier acknowledgement never waives the disclosure on a later purchase.

## Mandatory Premium purchase disclosure

Every Premium purchase initiation must record an explicit, versioned disclosure acceptance before Revoke invokes Google Play Billing. This is required on every purchase, including a later extension, even when an earlier acceptance exists. The current implementation records `premium-purchase-v1` with the user ID, server acceptance timestamp, and purchase flow ID under the server-only acceptance namespace. Restore/reverification of an existing purchase does not start a new purchase and does not require a second acceptance event.

The Premium disclosure states that the product is prepaid, does not renew automatically, uses localized Google Play pricing, and provides digital Revoke access for the displayed period.

## Billing architecture boundary

Flutter initiates Premium purchases through the official `in_app_purchase` API and selects the exact base-plan offer token returned by Google Play. The backend verifies the purchase token through `purchases.subscriptionsv2.get`, validates the package/product/base plan/account binding/state/expiry, acknowledges the purchase when required, and completes the purchase only after server verification. Flutter is never authoritative for Premium entitlement.

Verified prepaid purchases append one server-only Premium grant per purchase token. The materialized `users/{uid}/premiumEntitlement/current` document is sanitized and owner-readable; grant and purchase lineage remain server-only. Reverification is idempotent, and grants are recomputed in deterministic sequence so a future Credit redemption can append another grant without replacing purchase history. RTDN is only a signal: the backend re-queries the Google API before applying expiry, revocation, or refund consequences.

The backend retains purchase token, order identity, product ID, quantity, obfuscated account mapping where appropriate, verification/consumption state, issuance transaction, and remaining entitlement lineage. RTDN and voided-purchase information reconcile reversals through immutable PURCHASE_REVERSAL entries.

Forfeiture revokes an in-app entitlement; it is not a second payment transaction and must not be described as company revenue from failed Commitments. Formal accounting treatment requires separate review.

See ../architecture/credit-ledger-and-billing.md for the ledger and reconciliation contract.

## Policy position

These are design assumptions, not established compliance facts. Use the latest stable Google Play Billing version supported by the current Flutter in_app_purchase stack at implementation time. As dated discussion references only, Google Play Billing 9.1.0 and Flutter in_app_purchase 3.3.0 existed on 2026-09-04; they are not permanent requirements.

Do not claim Google Play policy approval or compliance. Final Google Play policy compatibility, market/payment availability, and legal review are pre-release gates.
