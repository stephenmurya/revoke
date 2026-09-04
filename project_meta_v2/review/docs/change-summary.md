# Documentation Change Summary

Review date: 2026-09-04

This packet records the terminology correction, mobile design-system audit, and Phase 1 implementation review over the existing `project_meta_v2/` documents. Phase 1 changes Flutter theme, shared-widget, shell, router, and targeted test files only. Native Android enforcement, Firebase configuration, Firestore rules, Cloud Functions, dependencies, and `old_project_meta/` were not edited.

## Phase 1 implementation

The implementation-specific review is [Phase 1 Implementation](phase-1-implementation.md). It records the source changes, retained foundations, shell migration, test evidence, and intentionally deferred UI debt.

The Today implementation review is [Phase 2 Today Implementation](phase-2-today-implementation.md). It records the new Today surface, data provenance, lifecycle behavior, truthful metric boundary, and regression evidence.

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
- `README.md`
- `design/overview.md`
- `design/design-system.md`
- `design/information-architecture.md`
- `audits/2026-09-04-design-system-audit.md`
- review packet files in this directory
