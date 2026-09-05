# 011 - Credit Purchase Disclosure on Every Purchase

Status: Accepted  
Date: 2026-09-04

## Decision

Revoke must show a Credit purchase disclosure every single time a user initiates a Credit purchase, before launching the Google Play purchase sheet. The user must explicitly confirm understanding before Revoke invokes Google Play Billing.

The disclosure is not first-purchase-only, onboarding-only, dismiss-once, or remember-my-choice behavior. A prior acknowledgement does not waive the disclosure for a later purchase.

The disclosure must explain that:

- Revoke Credits are digital in-app Credits;
- Credits cannot be withdrawn, transferred to another user, exchanged for cash, or redeemed outside Revoke;
- Credits can back eligible Revoke Commitments;
- successful eligible Commitments return locked Credits to the Revoke wallet;
- failed eligible Commitments can permanently forfeit locked Credits;
- Credits can be redeemed for Revoke Premium access time; and
- Credits have no external cash value.

Record an auditable `credit_purchase_disclosure_accepted` event for each confirmed purchase flow, including at least `disclosureVersion`, `userId`, a server/client timestamp, and `purchaseFlowId`.

## Rationale

The user should understand the in-app nature of Credits and the possible Credit consequence of a failed eligible Commitment before initiating a purchase. Repeating the disclosure keeps the decision informed at the point of every purchase.

## Consequences

- The disclosure is a prerequisite in the purchase flow, not a post-purchase notice.
- Billing cannot be invoked until the current disclosure has been explicitly confirmed.
- Acceptance records support auditability but do not suppress future disclosures.

## Phase 7 implementation note

`CreditDetailsScreen` displays the disclosure on every purchase attempt. `CreditService` records `credit-purchase-v1` with the product and flow ID before `PremiumBillingService` invokes the shared consumable Play purchase branch; the server verifier requires a matching acceptance for a new token.
