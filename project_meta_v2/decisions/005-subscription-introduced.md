# 005 - Premium Uses Prepaid Google Play Subscription

Status: Accepted

## Decision

Revoke 2.0 uses Google Play prepaid Premium products as the initial Premium model. The reference catalog is a 30-day prepaid Premium product at USD $9.99 and a 365-day prepaid Premium product at USD $59.99. They do not auto-renew.

The primary paywall sells Premium after the user understands the problem and configures/reviews a first Commitment. Google Play localized pricing determines actual market pricing. Weekly and lifetime Premium are outside initial v2 scope. Exact free-tier, trial, entitlement, and market decisions remain open; the accepted reference prices are not reopened as product questions.

## Consequences

- Do not describe Premium as automatically renewing.
- Users top up through Google Play or extend Premium using eligible Revoke Credits.
- Credit-backed Commitments are a Premium capability unless a later accepted decision changes that.
- Use the latest stable Google Play Billing version supported by the adopted Flutter in_app_purchase stack at implementation time.
- Google Play policy compatibility is not established and must be validated before release.
