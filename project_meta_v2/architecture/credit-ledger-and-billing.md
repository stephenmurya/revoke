# Commitment Credits, Ledger, and Google Play Billing

Status: Canonical Revoke 2.0 target architecture. This is product/technical design, not a claim that the feature is implemented or that Google Play has approved it.

## Product terminology and boundaries

The only user-facing financial vocabulary is **Credits**, **Commitment Credits**, **Lock Credits**, **Credits returned**, and **Credits forfeited**. Product copy uses neutral Revoke terminology.

Commitment Credits are an optional accountability mechanism, not an investment, prize system, or method of making money. Credits:

- are obtained only by purchasing through Google Play Billing;
- are never awarded free for behavior;
- cannot be transferred, sold, withdrawn as cash, or redeemed for physical goods/external services;
- remain usable only inside Revoke;
- may be locked behind a behavioral Commitment;
- return as the same Credits after successful completion;
- may be permanently forfeited only after verified failure and exhausted grace;
- may be redeemed for Revoke Premium access time;
- never produce more Credits through successful behavior than were originally locked.

Non-financial Commitments remain fully available. Credit backing is never required to use Revoke.

## Canonical ledger

`available_credits` and `locked_credits`, if retained, are materialized/cache fields only. The source of truth is an append-only server-authoritative Credit ledger plus `credit_holds`. Clients cannot create, destroy, return, forfeit, or redeem Credits directly.

Conceptual ledger transaction types:

- `CREDIT_PURCHASE`;
- `CREDIT_LOCK`;
- `CREDIT_RELEASE`;
- `CREDIT_FORFEITURE`;
- `PREMIUM_REDEMPTION`;
- `PURCHASE_REVERSAL`.

Each locked amount belongs to one specific Commitment. Simultaneous Commitments use separate `credit_holds` rather than one global balance. Purchase lineage links every Credit to the Google Play purchase that issued it.

Wallet projections may expose available, locked, and total Credits, but atomic backend transactions and immutable ledger entries remain authoritative.

## Mandatory purchase disclosure

Every Credit purchase flow must display a disclosure before Revoke launches the Google Play purchase sheet. The user must explicitly confirm understanding every time. The disclosure is never first-purchase-only, onboarding-only, dismiss-once, or suppressed because of an earlier acknowledgement.

The disclosure must state that Credits are digital in-app Credits; cannot be withdrawn, transferred, exchanged for cash, or redeemed outside Revoke; can back eligible Commitments; return to the Revoke wallet after a successful eligible Commitment; can be permanently forfeited after a failed eligible Commitment; can be redeemed for Revoke Premium access time; and have no external cash value.

Append an auditable `credit_purchase_disclosure_accepted` event for each confirmed flow with `disclosureVersion`, `userId`, a server/client timestamp, and `purchaseFlowId`. The event supports auditability but does not remove the requirement on future purchases.

## Purchase verification and lineage

For consumable Credit products, Flutter initiates the purchase but does not issue Credits. The backend must receive the purchase token, verify it through Google Play Developer APIs, confirm `PURCHASED`, idempotently create exactly one `CREDIT_PURCHASE` entry, and perform the canonical consume/acknowledgement flow using the APIs exposed by the current adopted Flutter `in_app_purchase` version.

Retain:

- Google purchase token;
- order/purchase identity;
- product ID and quantity/Credit amount;
- non-PII obfuscated account identifier where appropriate;
- purchase verification state;
- consumption/acknowledgement state;
- Credit issuance transaction;
- remaining entitlement lineage.

Prefer server-side verification and consumption because Credits have behavioral/financial significance. Document only the purchase APIs exposed by the adopted package version.

## Product catalog

Keep product catalog and pricing centralized rather than scattering prices through architecture documents.

Initial conceptual Credit products:

- `credits_50`: 50 Credits;
- `credits_100`: 100 Credits.

Product catalog and reference pricing are owned by `product/monetization.md`. Google Play localized pricing is authoritative for the amount actually paid. Do not introduce discounted bulk tiers in the canonical v2 launch scope unless separately approved.

Premium is a Google Play subscription product with a prepaid base plan:

- subscription product: `premium`;
- base plan: `prepaid-30d`;
- reference Premium prices: see `product/monetization.md`;
- weekly and lifetime Premium are outside initial v2 scope.

Prepaid Premium does not auto-renew. The user tops up through Google Play or extends Premium using eligible Credits. The exact free entitlement, Premium capabilities, and pricing remain open in `product/open-questions.md`.

## Credit-to-Premium conversion

The v2 conversion is stable for Credits already purchased:

**100 Credits = 30 Premium days**

Therefore 10 Credits = 3 days, 50 Credits = 15 days, and 100 Credits = 30 days.

Backend constants:

```text
SECONDS_PER_CREDIT = 25920
extension_seconds = credits_redeemed * 25920
new_premium_until = max(existing_premium_until, server_now) + extension_seconds
```

The initial UI should allow redemption only in multiples of 10 Credits, while backend accounting remains integer-Credit based. Future Premium pricing must not devalue already purchased Credits; change future acquisition prices instead. Credit-backed Commitments are a Premium capability unless a later canonical decision changes that boundary.

## Refunds, chargebacks, and RTDN

Use Google Play Real-time Developer Notifications and voided-purchase information as reconciliation inputs. A reversed purchase produces an immutable `PURCHASE_REVERSAL` entry.

On reversal:

- revoke unspent Credits issued from that purchase;
- explicitly handle Credits locked in active Commitments;
- preserve the original purchase/issuance/hold history;
- do not silently mutate balances or create an unrelated negative balance;
- reconcile Premium through traceable `premium_grant` records when purchase-derived Credits produced entitlement.

If Credits were forfeited before a later reversal, preserve both historical facts rather than rewriting the forfeiture against another purchase. Repeated refund/chargeback abuse may affect future Credit-backed eligibility under a later approved policy.

## Separation from settlement and accounting

The evidence architecture decides `SUCCESS_VERIFIED`, `FAILURE_VERIFIED`, `UNVERIFIABLE`, or `CANCELLED_PRE_START`. The verification document defines the separate settlement values. This ledger executes only server-authorized `CREDIT_RELEASE` or `CREDIT_FORFEITURE` transactions.

A purchase is the external payment transaction. Credit forfeiture revokes an existing in-app entitlement; it does not initiate a second payment transaction. Formal accounting treatment requires separate review.

## Policy gate

These are design assumptions, not established compliance facts. Final Google Play policy compatibility, billing API requirements, market availability, and any legal review must be validated before production release. No v2 document should say Revoke is Google Play compliant as an established fact.
