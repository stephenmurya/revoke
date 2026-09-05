# Revoke 2.0 Documentation Review Packet

Review date: 2026-09-05

This directory is a cumulative review artifact for Revoke 2.0 documentation audits and implementation phases. It is not canonical product documentation. Canonical sources live under ../.. and are indexed by ../../README.md.

The Markdown files in this directory are the current review packet. The retained `docs.zip` is a prior generated export and was not regenerated during this pass; it is not an authority over the Markdown packet.

## Packet contents

- [Change Summary](change-summary.md): every canonical file created, modified, or intentionally left unchanged.
- [Decision Matrix](decision-matrix.md): decisions encoded in this pass, implementation reality, and migration impact.
- [Consistency Review](consistency-review.md): contradictions checked across the v2 corpus and their resolution.
- [Historical Source Map](historical-source-map.md): mapping from old_project_meta and the revival audit into current v2 documentation.
- [Policy and Compliance Assumptions](policy-compliance-assumptions.md): assumptions requiring external validation.
- [Open Questions](open-questions.md): unresolved questions only; accepted decisions are not reopened.
- [Documentation Quality Checklist](documentation-quality-checklist.md): final structural and scope checks.
- [Terminology Scan](terminology-scan.md): required case-insensitive search results and classification of every remaining match.
- [Design-System Audit Summary](design-system-audit-summary.md): review-facing summary of the current Flutter/native UI audit and implementation readiness.
- [Phase 1 Implementation](phase-1-implementation.md): source implementation review for the design-system foundation and global mobile shell.
- [Phase 2 Today Implementation](phase-2-today-implementation.md): source implementation review for the Today experience and its data provenance.
- [Phase 3 Commitments Implementation](phase-3-commitments-implementation.md): source implementation review for the user-facing Commitment layer, Reduce/Protect flows, persistence, and native compatibility mapping.
- [Phase 5 Circle and Override Authority](phase-5-circle-override-implementation.md): source implementation review for Circle permissions, privacy boundaries, explicit authority, quorum, and native approval delivery.

## Authority reminder

- old_project_meta/ = historical/reference only.
- project_meta_v2/ = current canonical Revoke 2.0 documentation.
- project_meta_v2/archive/ = retained historical material, not current authority.
- project_meta_v2/audits/ = point-in-time implementation evidence, not product intent.
