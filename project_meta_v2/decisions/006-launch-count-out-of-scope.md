# 006 — Launch Count Is Out of Initial Revoke 2.0 Scope

Status: **Accepted**

## Decision

Do not expose Launch Count commitments in the initial v2 product.

The existing model enum is not enough: the audited native engine does not enforce launch count and the create flow lacks a complete threshold model.

Keep compatibility code only where needed for existing data. Remove dead labels/paths later after migration/reference proof.
