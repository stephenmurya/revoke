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
| Commitment Credits use `available_credits`, `locked_credits`, and `credit_holds` | ACCEPTED | decisions/008; architecture/credit-ledger-and-billing.md | Server wallet/holds implemented; live production verification remains | Yes |
| Canonical ledger events are `CREDIT_PURCHASE`, `CREDIT_LOCK`, `CREDIT_RELEASE`, `CREDIT_FORFEITURE`, `PREMIUM_REDEMPTION`, and `PURCHASE_REVERSAL` | ACCEPTED | decisions/008; decisions/010 | Server event writer implemented | Yes |
| Positive offline failure may provisionally forfeit locked Credits locally | ACCEPTED | decisions/004; commitment-verification.md | Native SQLite/local projection and pending reconciliation implemented | Yes |
| Server ledger remains canonical after local synchronization | ACCEPTED | decisions/004; decisions/008 | No | Yes |
| Reinstall/wipe loss before synchronization is accepted v2 risk | ACCEPTED | decisions/004; commitment-verification.md | No | No additional anti-fraud architecture |
| Evidence reconciliation defaults to 24 hours and remains server-configurable | ACCEPTED | decisions/004; commitment-verification.md | Resolver implemented; device/production proof remains | Yes |
| `UNVERIFIABLE` releases locked Credits, forfeits none, and consumes no grace | ACCEPTED | decisions/004; product/commitments.md | No | Yes |
| Force-close, uninstall, or monitoring loss alone cannot mean failure | ACCEPTED | decisions/004; commitment-verification.md | No | Yes |
| Purchase disclosure is mandatory before every Credit purchase | ACCEPTED | decisions/011; product/monetization.md | CreditDetailsScreen and server acceptance implemented | Play/device verification remains |
| Premium is prepaid and non-auto-renewing | ACCEPTED | decisions/005; product/monetization.md | Repository billing foundation implemented; Play lifecycle unverified | Yes |
| 30-day prepaid Premium reference price is USD $9.99 | ACCEPTED | decisions/005; product/monetization.md | Product metadata/base-plan mapping implemented; Play price unverified | Yes |
| 365-day prepaid Premium reference price is USD $59.99 | ACCEPTED | decisions/005; product/monetization.md | Product metadata/base-plan mapping implemented; Play price unverified | Yes |
| Weekly Premium is outside initial v2 scope | ACCEPTED | decisions/005; product/monetization.md | No | No |
| Lifetime Premium is outside initial v2 scope | ACCEPTED | decisions/005; product/monetization.md | No | No |
| Premium purchase disclosure is required before every new Premium purchase | ACCEPTED | decisions/014; architecture/premium-entitlement-and-billing.md | Disclosure callable precedes every new Play flow | Play/device verification remains |
| Premium entitlement is server-verified, grant-backed, and cached only for offline expiry presentation | ACCEPTED | decisions/014; architecture/premium-entitlement-and-billing.md | Repository code implemented; live Play lifecycle unverified | Yes |
| Free/Premium capability matrix is fixed for initial v2 | ACCEPTED | decisions/014; product/monetization.md | UI and server gates implemented at new paid-capability boundaries | Existing-data migration/backfill remains |
| 100 Credits = 30 Premium days; 25,920 seconds/Credit | ACCEPTED | decisions/009; monetization.md | No | Yes |
| Credit-backed Commitment activation is an atomic server hold over an existing schedule compatibility boundary | ACCEPTED | decisions/015; architecture/credit-backed-commitments.md | Repository callable, native cache, and journal bridge implemented | Device/evidence hardening remains |
| First-run onboarding keeps a persisted semantic Commitment draft until coordinated activation | ACCEPTED | decisions/016; product/onboarding.md | Implemented in `OnboardingState` and `CommitmentDraft`; retained schedules materialize at activation | Native/server Commitment object remains deferred |
| Commercial onboarding order is draft -> enforcement -> authority -> optional Circle -> review -> required Premium -> optional Credit backing -> activation | ACCEPTED | decisions/016; product/onboarding.md | Implemented with external-state revalidation at decision points | Play/device production proving remains |
| Free onboarding fallback is one Protect Commitment with Self authority | ACCEPTED | decisions/016; product/monetization.md | Implemented as explicit Premium-decline fallback; no silent downgrade | Exact free/Premium entitlement matrix remains product-owned where open |
| Circle setup is optional and only shown when Circle authority is selected | ACCEPTED | decisions/016; product/accountability.md | Implemented; membership and voter selection are revalidated | Broader Circle migration remains |
| Credit backing is optional after Premium and activation is coordinated, not globally atomic | ACCEPTED | decisions/016; architecture/credit-backed-commitments.md | Implemented with explicit recovery when hold/backing is incomplete | Server/native Commitment lease remains deferred |
| Target bottom navigation is Today / Commitments / Circle / Insights | ACCEPTED | decisions/012; design/information-architecture.md | Implemented; Today is dedicated, other destinations retain their scoped legacy content | Yes |
| Settings lives under Profile/account, not primary navigation | ACCEPTED | decisions/012; design/information-architecture.md | Current controls/profile routes are separate | Yes |
| Global app bar includes Credits pill, Notifications, and Profile where appropriate | ACCEPTED | decisions/012; design/information-architecture.md | Compact server-derived available-Credits pill, Notifications, and Profile are implemented; Credit detail/purchase/backing remains behind the Phase 7 production gates | Yes |
| Credits are visually subordinate and Today has no large wallet balance card | ACCEPTED | decisions/012; design/information-architecture.md | Compact server-derived app-bar projection; no general wallet card on Today | Yes |
| Revoke 2.0 uses a calm, precise, authoritative, refined, premium visual direction | ACCEPTED | decisions/012; design/overview.md | Phase 2 Today follows the direction; remaining feature screens remain mixed | Yes |
| A governed design system is required before broad v2 UI implementation | ACCEPTED | decisions/012; design/design-system.md | Phase 1 tokens/primitives/shell are implemented and used by Phase 3 Commitment surfaces; broad migration remains | Yes |
| Insights uses direct evidence and never a replacement composite score | ACCEPTED | decisions/002; product/metrics.md; product/insights.md | Implemented on `/insights`; legacy Focus Score compatibility remains outside the v2 surface | Legacy cleanup remains |
| Free Insights provides a useful 7-day view; Premium unlocks supported longer analysis | ACCEPTED | product/insights.md; product/monetization.md | Implemented as 7 days for Free and 7/30 days for Premium; 90 days is not exposed | Longer retention/analysis remains deferred |
| Google Play policy compatibility is not assumed | ACCEPTED | monetization.md; credit-ledger-and-billing.md | External validation only | Release gate |
| Default grace, eligibility, caps, device policy, and Credit-backed Commitment policy | OPEN | product/open-questions.md | No | Product decision required |
| Social Regimes/community marketplace | DEFERRED | product-spec.md; engineering/status.md | No integrated path | No unless later revived |
