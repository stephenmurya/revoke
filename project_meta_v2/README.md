# Revoke Project Documentation

This directory is the canonical project knowledge base for Revoke 2.0.

`old_project_meta/` is historical/reference material only. Do not edit, reorganize, rename, delete, or add files there as part of v2 work.

`project_meta_v2/` is the current canonical Revoke 2.0 documentation root.

## Authority order

When documents disagree, use this order:

1. `product/` for current product intent, scope, and user behavior.
2. `architecture/` for current and target technical contracts.
3. `engineering/status.md` for what is implemented right now.
4. `decisions/` for durable accepted/proposed decisions.
5. `audits/` for point-in-time source-verified observations.
6. `archive/` for superseded documentation and historical context.

Audits are evidence, not living specifications. Archive documents are never authoritative for current implementation or v2 product decisions.

## Current product thesis

Revoke is a behavioral commitment and rehabilitation system. The primary product object is the Commitment, not the schedule. The product loop is:

`Observe -> Commit -> Plan -> Enforce -> Override -> Learn -> Adapt`

Commitments currently have two product forms:

- `Reduce`: progressively reduce usage from a measured baseline to a target.
- `Protect`: establish a hard boundary such as a protected period or daily usage maximum.

Schedules and native restrictions are enforcement mechanisms generated from or controlled by Commitments. Launch Count is outside Revoke 2.0. Focus Score is retired.

Accountability Circles are optional and use granular permissions. Commitment Credits are optional, purchased only through Google Play Billing, usable only inside Revoke, and settled through an evidence-first fail-safe model. Revoke does not claim Google Play policy approval; final policy validation is a pre-release gate.

## Documentation map

### Product

- `product/vision.md`: thesis, principles, and product boundaries.
- `product/product-spec.md`: canonical v2 behavior and scope.
- `product/commitments.md`: Reduce/Protect model, lifecycle, evidence outcomes, and grace.
- `product/accountability.md`: optional Accountability Circles and granular permissions.
- `product/onboarding.md`: deterministic onboarding, Commitment creation, paywall, and activation.
- `product/monetization.md`: Premium and Commitment Credits product model.
- `product/metrics.md`: direct Today evidence and metric semantics; Focus Score retirement.
- `product/insights.md`: Phase 9 Insights hierarchy, metric definitions, range support, provenance, and deferred analysis.
- `product/open-questions.md`: genuinely unresolved product and policy decisions.

### Architecture

- `architecture/system-overview.md`: current implementation boundary and v2 layering.
- `architecture/v2-domain-model.md`: target entities and state machines.
- `architecture/commitment-verification.md`: authoritative leases, native evidence journal, monitoring health, offline resolution, grace, and settlement.
- `architecture/credit-ledger-and-billing.md`: append-only Credit ledger, Google Play purchase verification, Premium redemption, and reconciliation.
- `architecture/credit-backed-commitments.md`: Phase 7 implementation boundary for wallet, backing holds, native evidence, settlement, and redemption.
- `architecture/premium-entitlement-and-billing.md`: Phase 6 Premium catalog, Play verification, grants, entitlement projection, disclosure, RTDN, and capability boundary.

### Engineering

- `engineering/status.md`: current implementation reality versus v2 target.
- `engineering/implementation-principles.md`: revival and authority constraints.
- `engineering/google-play-setup.md`: manual Play Console, licensed-device, RTDN, and production readiness runbook.

### Design

- `design/overview.md`: accepted Revoke 2.0 mobile visual direction and design governance.
- `design/design-system.md`: semantic token, component, native-mapping, accent, motion, and accessibility contract; the Phase 1 Flutter foundation is now implemented.
- `design/information-architecture.md`: accepted Today/Commitments/Circle/Insights mobile IA and global app-bar rules.

### Decisions

`decisions/` contains durable ADR/PDR records. `decisions/README.md` lists the numbering/status convention.

### Audits

- `audits/2026-09-04-revival-audit.md`: source-verified reconstruction of the repository as of 2026-09-04.
- `audits/2026-09-04-design-system-audit.md`: source-verified current Flutter/native UI and design-system audit.
- `audits/2026-09-05-visual-polish-audit.md`: point-in-time Phase 10 visual consistency and native alignment audit.

The Phase 1 implementation review is [review/docs/phase-1-implementation.md](review/docs/phase-1-implementation.md). It records the implemented shell/foundation boundary and the UI intentionally deferred to later phases.

The Phase 2 Today review is [review/docs/phase-2-today-implementation.md](review/docs/phase-2-today-implementation.md). The Phase 3 Commitments review is [review/docs/phase-3-commitments-implementation.md](review/docs/phase-3-commitments-implementation.md). These reviews record implementation boundaries and must not be read as claims that the complete v2 backend domain exists.

The Phase 4 onboarding review is [review/docs/phase-4-onboarding-implementation.md](review/docs/phase-4-onboarding-implementation.md). It records the explicit onboarding state machine, progressive permission boundary, first-Commitment integration, and known limitations.

The Phase 5 Circle and Override Authority review is [review/docs/phase-5-circle-override-implementation.md](review/docs/phase-5-circle-override-implementation.md). It records the least-privilege Circle projection, explicit authority policy, fixed quorum, server resolution boundary, and durable native approval delivery.

The Phase 6 Premium implementation review is [review/docs/phase-6-premium-implementation.md](review/docs/phase-6-premium-implementation.md). It records the prepaid Play entitlement boundary, disclosure requirement, server verification/grant projection, capability gates, and remaining Play Console lifecycle work.

The Phase 8 commercial onboarding review is [review/docs/phase-8-commercial-onboarding.md](review/docs/phase-8-commercial-onboarding.md). It records the draft-first first-run journey, capability resolution, authority/Circle/Premium/Credit branches, coordinated activation, migration, and resume boundaries.

The Phase 9 Insights review is [review/docs/phase-9-insights-implementation.md](review/docs/phase-9-insights-implementation.md). It records the direct usage-evidence hierarchy, Free/Premium range boundary, Reduce and override analysis, chart architecture, Focus Score cleanup, and deferred metrics.

The Phase 10 visual polish review is [review/docs/phase-10-implementation.md](review/docs/phase-10-implementation.md). It records semantic theme refinement, shared component states, native resource alignment, accessibility/code review, and intentionally deferred device-level visual verification.

### Archive

`archive/` contains superseded PRDs, status notes, comparative assessments, and older audits. It is retained for historical context and is not a current source of truth.

## Documentation maintenance rule

Any implementation task that changes product behavior, persistence authority, enforcement semantics, billing semantics, or backend authority must update the relevant canonical document in the same change. Do not create a random root-level Markdown note when an existing canonical document owns the subject.
