# Documentation Quality Checklist

Review date: 2026-09-04

- [x] Canonical source for each major topic is identifiable in `project_meta_v2/README.md`.
- [x] `old_project_meta/` is explicitly historical/reference-only and was not edited.
- [x] No application code, Firebase configuration, Firestore rules, Cloud Functions, dependencies, tests, or build configuration was edited.
- [x] Accepted decisions are consistent across product, architecture, engineering, and decisions.
- [x] Unresolved decisions remain visibly marked in `product/open-questions.md`.
- [x] Implementation reality is separate from intended v2 design through `engineering/status.md` and the dated revival audit.
- [x] Focus Score is not reintroduced as a replacement composite metric.
- [x] Squad terminology is labeled as current/internal migration reality, not the final Circle product model.
- [x] Commitment Credit terminology uses available/locked Credits, Credit holds, and the canonical ledger event names.
- [x] Local provisional settlement and server canonical settlement are distinct.
- [x] Offline positive failure evidence changes local projections and creates a durable pending reconciliation event.
- [x] Reinstall/wipe loss before synchronization is explicitly recorded as an accepted v2 risk.
- [x] The initial evidence reconciliation window is 24 hours and remains server-configurable.
- [x] `UNVERIFIABLE` releases locked Credits, forfeits none, and consumes no grace.
- [x] Purchase disclosure is required before every Credit purchase and must be confirmed every time.
- [x] The disclosure acceptance event includes version, user, timestamp, and purchase flow ID.
- [x] The required case-insensitive terminology scan was run; results and classifications are in `terminology-scan.md`.
- [x] Current UI implementation is clearly separated from target v2 design intent.
- [x] Flutter theme, hardcoded-value inventory, component duplication, screen hierarchy, and native overlay divergence are source-backed in the dated design audit.
- [x] Target design principles and semantic token contract are canonical under `design/`.
- [x] Target mobile IA is Today / Commitments / Circle / Insights; Settings remains under Profile/account.
- [x] Credits pill placement and subordinate Today treatment are documented.
- [x] Premium reference prices are USD $9.99 for 30 days and USD $59.99 for 365 days; weekly and lifetime are excluded.
- [x] The generic evidence-resolution-window question was removed; only exceptional handling inside/after the accepted 24-hour window remains open.
- [x] Phase 1 implementation status is separated from target design intent; legacy feature content is explicitly documented as retained beneath the new shell.
- [x] The review packet records the implemented token foundation, shared primitives, constrained accent mapping, shell labels, and zero-valued Credits placeholder.
- [x] Phase 2 records Today as a dedicated surface while keeping Commitments management and other feature migrations scoped for later phases.
- [x] Every Today metric/state has an implementation data source or is explicitly omitted as unsupported.
- [x] Focus Score is absent from Today while legacy compatibility remains documented.
- [x] Browser, desktop, cross-device, browser Firebase/licensing, and iOS work are explicitly out of scope.
