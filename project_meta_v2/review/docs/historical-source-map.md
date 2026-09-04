# Historical Source Map

Review date: 2026-09-04

No files in `old_project_meta/` were edited. It contains the previous project_meta set and remains reference-only.

## Mapping into project_meta_v2

| Historical source | Current v2 destination | Treatment |
|---|---|---|
| old_project_meta/prd.md | archive/prd-v1.3.md; product/vision.md; product/product-spec.md; product/commitments.md; product/monetization.md | Product intent was reclassified. Commitment/Credit decisions supersede the legacy financial and processor concepts in v1.3. |
| old_project_meta/status.md | archive/status-pre-v2.md; engineering/status.md | Historical phase/status retained; current implementation status is source-verified and separate from target v2. |
| old_project_meta/revival_audit.md | audits/2026-09-04-revival-audit.md | Current code evidence retained as a dated audit, not silently rewritten as v2 intent. |
| old_project_meta/audits/audit_report.md | archive/legacy-audits/audit-report-2026-06.md; engineering/status.md | Historical release findings inform current status but do not define v2 scope. |
| old_project_meta/audits/onboarding_audit.md | archive/legacy-audits/onboarding-audit-2026-06.md; product/onboarding.md; engineering/status.md | Broken routing/goal persistence remains an implementation blocker; target onboarding is now a persisted Commitment state machine. |
| old_project_meta/audits/schedule_audit.md | archive/legacy-audits/schedule-audit-2026-06.md; product/commitments.md; architecture/system-overview.md | Existing Time Block/Usage Limit are retained; Launch Count is explicitly out of v2. |
| old_project_meta/curbox_assessment.md | archive/curbox-assessment.md; architecture/system-overview.md | Historical comparative architecture only; current Revoke hybrid remains the source of truth. |
| old_project_meta/firestore_index_notes.md | archive/firestore-index-notes.md; current implementation audit | Historical index notes are preserved; no new v2 Credit schema is claimed as implemented. |

## Concepts originating from the revival audit

The September revival audit supplied the source-verified distinction separating current implementation from target architecture: Accessibility versus UsageStats authority, local-first schedule sync gaps, Flutter-dependent approved unlocks, current Focus Score/Squad/admin fossils, absent billing, and build/test health. Those findings remain in `audits/2026-09-04-revival-audit.md` and are reflected in `engineering/status.md` and `architecture/system-overview.md`.

## Historical handling rule

Archive and `old_project_meta/` material may be consulted for migration context, but current product decisions come from `product/`, technical contracts from `architecture/`, implementation reality from `engineering/status.md`, and accepted rationale from `decisions/`. Historical vocabulary must not be copied into new v2 product or backend contracts.
