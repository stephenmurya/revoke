# Revoke 2.0 Decision Matrix

Review date: 2026-09-04

| Decision | Status | Canonical source | Implemented now? | Migration required? |
|---|---|---|---|---|
| Commitment is the primary product object | ACCEPTED | decisions/001; product/vision.md | User-facing adapter and management flows implemented; schedules remain current persistence primitive | Yes |
| Reduce and Protect are the Commitment forms | ACCEPTED | product/commitments.md; product-spec.md | Partial: user-facing flows map to taper and Time Block/Usage Limit; backend domain remains absent | Yes |
| Focus Score is retired | ACCEPTED | decisions/002; product/metrics.md | Legacy UI/storage exists | Yes |
| Accountability Circles are optional and granular | ACCEPTED | decisions/003; product/accountability.md | Circle surface, sanitized member summaries, owner permissions, and self-leave are implemented over `squads` | Migration remains for legacy names and broader progress sharing |
| Commitment sharing is explicit and separate from voter authority | ACCEPTED | decisions/003; product/accountability.md; decisions/013 | `sharedMemberIds` policy plus sanitized `getSharedCommitmentSummaries` callable | Yes, for wider shared progress |
| Override authority is explicit as SELF / AI / CIRCLE | ACCEPTED | decisions/013; product/accountability.md | Per-Commitment policy callable and v2 request path implemented | Legacy callers remain |
| Circle voters are snapshotted and use strict majority; timeout rejects | ACCEPTED | decisions/013; product/accountability.md | `eligibleVoterIds`, `requiredApprovalCount`, vote trigger, and timeout path implemented | Device/production proving remains |
| Approved access does not depend solely on Flutter being alive | ACCEPTED | decisions/013; product/accountability.md | Protected FCM receiver validates and persists native temporary unlock; Flutter listener remains fallback | Device/FCM proving remains |
| Commitment Credits use `available_credits`, `locked_credits`, and `credit_holds` | ACCEPTED | decisions/008; architecture/credit-ledger-and-billing.md | No v2 ledger | Yes |
| Canonical ledger events are `CREDIT_PURCHASE`, `CREDIT_LOCK`, `CREDIT_RELEASE`, `CREDIT_FORFEITURE`, `PREMIUM_REDEMPTION`, and `PURCHASE_REVERSAL` | ACCEPTED | decisions/008; decisions/010 | No | Yes |
| Positive offline failure may provisionally forfeit locked Credits locally | ACCEPTED | decisions/004; commitment-verification.md | No | Yes |
| Server ledger remains canonical after local synchronization | ACCEPTED | decisions/004; decisions/008 | No | Yes |
| Reinstall/wipe loss before synchronization is accepted v2 risk | ACCEPTED | decisions/004; commitment-verification.md | No | No additional anti-fraud architecture |
| Evidence reconciliation defaults to 24 hours and remains server-configurable | ACCEPTED | decisions/004; commitment-verification.md | No | Yes |
| `UNVERIFIABLE` releases locked Credits, forfeits none, and consumes no grace | ACCEPTED | decisions/004; product/commitments.md | No | Yes |
| Force-close, uninstall, or monitoring loss alone cannot mean failure | ACCEPTED | decisions/004; commitment-verification.md | No | Yes |
| Purchase disclosure is mandatory before every Credit purchase | ACCEPTED | decisions/011; product/monetization.md | No billing implementation | Yes |
| Premium is prepaid and non-auto-renewing | ACCEPTED | decisions/005; product/monetization.md | No Premium/billing code | Yes |
| 30-day prepaid Premium reference price is USD $9.99 | ACCEPTED | decisions/005; product/monetization.md | No Premium/billing code | Yes |
| 365-day prepaid Premium reference price is USD $59.99 | ACCEPTED | decisions/005; product/monetization.md | No Premium/billing code | Yes |
| Weekly Premium is outside initial v2 scope | ACCEPTED | decisions/005; product/monetization.md | No | No |
| Lifetime Premium is outside initial v2 scope | ACCEPTED | decisions/005; product/monetization.md | No | No |
| 100 Credits = 30 Premium days; 25,920 seconds/Credit | ACCEPTED | decisions/009; monetization.md | No | Yes |
| Target bottom navigation is Today / Commitments / Circle / Insights | ACCEPTED | decisions/012; design/information-architecture.md | Implemented; Today is dedicated, other destinations retain their scoped legacy content | Yes |
| Settings lives under Profile/account, not primary navigation | ACCEPTED | decisions/012; design/information-architecture.md | Current controls/profile routes are separate | Yes |
| Global app bar includes Credits pill, Notifications, and Profile where appropriate | ACCEPTED | decisions/012; design/information-architecture.md | Phase 1 compact zero-valued Credits placeholder, Notifications, and Profile are implemented; no Credit source exists | Yes |
| Credits are visually subordinate and Today has no large wallet balance card | ACCEPTED | decisions/012; design/information-architecture.md | Compact zero-valued app-bar placeholder; no wallet card or Credit backend | Yes |
| Revoke 2.0 uses a calm, precise, authoritative, refined, premium visual direction | ACCEPTED | decisions/012; design/overview.md | Phase 2 Today follows the direction; remaining feature screens remain mixed | Yes |
| A governed design system is required before broad v2 UI implementation | ACCEPTED | decisions/012; design/design-system.md | Phase 1 tokens/primitives/shell are implemented and used by Phase 3 Commitment surfaces; broad migration remains | Yes |
| Google Play policy compatibility is not assumed | ACCEPTED | monetization.md; credit-ledger-and-billing.md | External validation only | Release gate |
| Default grace, eligibility, caps, device policy, and free tier | OPEN | product/open-questions.md | No | Product decision required |
| Social Regimes/community marketplace | DEFERRED | product-spec.md; engineering/status.md | No integrated path | No unless later revived |
