# Documentation Change Summary

Review date: 2026-09-05

This packet records the terminology correction, mobile design-system audit, Phases 1-5 implementation reviews, the Phase 6 Premium implementation review, and the Phase 7 Commitment Credits implementation review over the existing `project_meta_v2/` documents. Each phase remains scoped to its documented boundary; `old_project_meta/` remains untouched.

Phase 7 adds the Commitment Credits repository boundary over existing Premium, schedule, and native enforcement infrastructure. It does not claim live Play configuration, physical-device evidence proof, policy approval, or production readiness.

The Phase 7 implementation review is [Phase 7 Commitment Credits](phase-7-credit-implementation.md). It records the shared Play purchase listener, server ledger and wallet, per-Commitment holds, native journal, offline provisional state, 24-hour resolver, redemption, reversal boundary, and release gates.

## Phase 1 implementation

The implementation-specific review is [Phase 1 Implementation](phase-1-implementation.md). It records the source changes, retained foundations, shell migration, test evidence, and intentionally deferred UI debt.

The Today implementation review is [Phase 2 Today Implementation](phase-2-today-implementation.md). It records the new Today surface, data provenance, lifecycle behavior, truthful metric boundary, and regression evidence.

The Commitments implementation review is [Phase 3 Commitments Implementation](phase-3-commitments-implementation.md). It records the adapter boundary, creation/edit/detail flows, legacy schedule mapping, and verification evidence.

The Accountability Circle and Override Authority implementation review is [Phase 5 Circle and Override Authority](phase-5-circle-override-implementation.md). It records the server-enforced permission model, sanitized member data, explicit Commitment sharing, authority policy, fixed quorum, native FCM delivery, and compatibility boundary.

The Premium implementation review is [Phase 6 Premium](phase-6-premium-implementation.md). It records the prepaid Google Play product boundary, mandatory disclosure, server verification, acknowledgement, idempotent grants, sanitized entitlement projection, RTDN requery, capability gates, and manual Play setup still required.

## Correction-pass decisions

| Area | Correction | Canonical sources |
|---|---|---|
| Terminology | Replaced legacy risk/prize vocabulary with Commitment Credits, available/locked Credits, Credit holds, and the canonical ledger event names | decisions/010; architecture/v2-domain-model.md; architecture/credit-ledger-and-billing.md |
| Offline failure | Positive offline failure evidence immediately updates local projections, enters `FAILURE_VERIFIED_LOCAL`, and creates a durable pending forfeiture reconciliation event | decisions/004; architecture/commitment-verification.md |
| Settlement authority | Local settlement is provisional; the synchronized server ledger is canonical and reconciles pending events idempotently | decisions/004; decisions/008; architecture/commitment-verification.md |
| Reinstall risk | Loss of an unsynchronized local pending event after wipe/uninstall/reinstall is explicitly accepted for v2 | decisions/004; architecture/commitment-verification.md |
| Resolution window | Initial server-configurable evidence reconciliation default is 24 hours; insufficient trustworthy evidence becomes `UNVERIFIABLE` with Credit release and no forfeiture or grace consumption | decisions/004; architecture/commitment-verification.md; product/commitments.md |
| Purchase disclosure | A confirmed disclosure is required before every Google Play Credit purchase, with an auditable acceptance event; prior acceptance never suppresses a future disclosure | decisions/011; product/monetization.md; architecture/credit-ledger-and-billing.md |
| Mobile design direction | Added accepted calm/precise/refined/premium direction, restrained hierarchy, native-first enforcement presentation, and premium quality bar | design/overview.md; decisions/012 |
| Mobile information architecture | Established Today / Commitments / Circle / Insights, Profile-owned Settings, global Credits/Notifications/Profile app-bar utilities, and subordinate Credit visibility on Today | design/information-architecture.md; decisions/012 |
| Design-system contract | Added semantic color, typography, spacing, radius, elevation, border, icon, motion, accessibility, accent, component, and native-mapping guidance | design/design-system.md |
| Current UI audit | Recorded source-backed partial design-system status, hardcoded-value inventory, screen hierarchy, component duplication, and Flutter/native divergence | audits/2026-09-04-design-system-audit.md |
| Premium reference pricing | Accepted USD $9.99 for 30-day prepaid Premium and USD $59.99 for 365-day prepaid Premium; weekly/lifetime excluded; localized Play pricing remains authoritative | decisions/005; product/monetization.md |
| Evidence question correction | Removed the generic unresolved evidence-resolution-window question; only exceptional escalation remains open inside/after the accepted 24-hour window | product/open-questions.md; review/docs/open-questions.md |

## Phase 6 implementation

| Area | Implementation | Canonical sources |
|---|---|---|
| Premium catalog | `premium` with `prepaid-30d` and `prepaid-365d`; localized Play metadata; no weekly/lifetime/auto-renewing offer | product/monetization.md; architecture/premium-entitlement-and-billing.md; decisions/014 |
| Entitlement authority | Google Play Developer API verification, acknowledgement, server-only grants, sanitized `premiumEntitlement/current`, and offline expiry cache | architecture/premium-entitlement-and-billing.md; decisions/014 |
| Purchase disclosure | Fresh explicit `premium-purchase-v1` acceptance before every new Premium purchase, with user/flow/version/server timestamp | product/monetization.md; architecture/premium-entitlement-and-billing.md |
| Capability gates | Free/Premium matrix enforced at new Reduce/additional-Protect activation, Circle creation/owner permissions, and new AI/Circle authority configuration; Circle participation remains free | product/monetization.md; engineering/status.md; phase-6-premium-implementation.md |
| Reconciliation | RTDN deduplicates and re-queries Google; expiry/revocation preserves history and recomputes entitlement | architecture/premium-entitlement-and-billing.md; engineering/google-play-setup.md |
| Lifecycle | Repository code complete; Play Console, licensed-device, RTDN, refund/revocation, credentials, and production checks remain open | engineering/google-play-setup.md; phase-6-premium-implementation.md |

## Earlier v2 work retained

The correction pass preserves the prior v2 decisions: Commitments are primary; Focus Score is retired; Circles are optional; Premium is prepaid; Launch Count is outside initial scope; and the current implementation remains distinct from the target architecture.

## Files changed across the documented v2 passes

- `architecture/credit-ledger-and-billing.md`
- `product/monetization.md`
- `product/commitments.md`
- `product/open-questions.md`
- `decisions/004-credit-forfeiture-fail-safe.md` (renamed from the legacy filename)
- `decisions/005-subscription-introduced.md`
- `decisions/008-commitment-credit-ledger.md`
- `decisions/010-neutral-credit-terminology.md`
- `decisions/011-credit-purchase-disclosure.md`
- `decisions/012-mobile-design-direction-and-ia.md`
- `decisions/014-premium-entitlement-and-gating.md`
- `architecture/premium-entitlement-and-billing.md`
- `engineering/google-play-setup.md`
- `review/docs/phase-6-premium-implementation.md`
- `README.md`
- `design/overview.md`
- `design/design-system.md`
- `design/information-architecture.md`
- `audits/2026-09-04-design-system-audit.md`
- review packet files in this directory
