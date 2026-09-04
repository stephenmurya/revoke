# 009 - Credits Redeem for Premium at a Fixed v2 Ratio

Status: Accepted

## Decision

100 Credits equal 30 Premium days. Backend accounting uses SECONDS_PER_CREDIT = 25920. The initial UI permits redemption in multiples of 10 Credits.

## Consequences

- 10 Credits equal 3 Premium days; 50 equal 15 days; 100 equal 30 days.
- Existing purchased Credits retain this value if future Premium pricing changes.
- Future pricing changes affect future Google Play purchases rather than devaluing existing Credits.
- Discounted bulk Credit tiers are outside the initial v2 scope unless separately approved.
- See ../product/monetization.md.

