# Monetization

Status: Canonical Revoke 2.0 product direction. No billing or Credit implementation currently exists; see ../engineering/status.md.

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

Premium should use a Google Play subscription product with a prepaid base plan:

- subscription product: premium;
- base plan: prepaid-30d;
- 30-day prepaid Premium: USD $9.99 reference price;
- 365-day prepaid Premium: USD $59.99 reference price.

Prepaid Premium does not auto-renew. The user tops up through Google Play or extends Premium using eligible Credits. It must not be described as an automatically renewing subscription.

Google Play localized pricing determines actual market pricing. These are reference/base product decisions, not literal currency-conversion rules. Weekly Premium and lifetime Premium are outside initial v2 scope. The exact free tier, trial, entitlement split, and market availability remain open. The primary onboarding/paywall flow sells Premium after the user understands the problem and has configured/reviewed a first Commitment. Credits belong in the Commitment/Wallet experience, not as a replacement for the primary Premium paywall.

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

## Mandatory purchase disclosure

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

## Billing architecture boundary

Flutter initiates Google Play purchases. The backend verifies the purchase token through Google Play Developer APIs, confirms PURCHASED state, idempotently writes one CREDIT_PURCHASE ledger transaction, and completes the adopted package's current consume/acknowledgement flow. Flutter is never authoritative for Credit issuance.

The backend retains purchase token, order identity, product ID, quantity, obfuscated account mapping where appropriate, verification/consumption state, issuance transaction, and remaining entitlement lineage. RTDN and voided-purchase information reconcile reversals through immutable PURCHASE_REVERSAL entries.

Forfeiture revokes an in-app entitlement; it is not a second payment transaction and must not be described as company revenue from failed Commitments. Formal accounting treatment requires separate review.

See ../architecture/credit-ledger-and-billing.md for the ledger and reconciliation contract.

## Policy position

These are design assumptions, not established compliance facts. Use the latest stable Google Play Billing version supported by the current Flutter in_app_purchase stack at implementation time. As dated discussion references only, Google Play Billing 9.1.0 and Flutter in_app_purchase 3.3.0 existed on 2026-09-04; they are not permanent requirements.

Do not claim Google Play policy approval or compliance. Final Google Play policy compatibility, market/payment availability, and legal review are pre-release gates.
