# Policy and Compliance Assumptions

Review date: 2026-09-04

These are assumptions and design constraints requiring external validation. None is a claim of Google Play approval or compliance.

- Credit purchases use Google Play Billing for Play-distributed Android digital goods.
- The adopted Flutter in_app_purchase version and its supported Google Play Billing version must be selected at implementation time; no obsolete fixed library-version requirement is documented.
- Consumable purchase verification, acknowledgement/consumption, RTDN, and voided-purchase reconciliation require current Google Play Developer API validation.
- Product premium with prepaid-30d is the intended Premium catalog shape; actual availability, disclosure, base-plan configuration, renewal behavior, and market support require Play Console validation.
- Commitment Credits are closed-loop Revoke entitlements, not cash, transferable property, physical goods, or external services; legal and platform interpretation still requires review.
- Credit-backed Commitment eligibility, age limits, rooted/unsupported-device treatment, Play Integrity requirements, and evidence retention require policy decisions.
- Privacy review is required for Circle projections, usage summaries, override/slip history, purchase lineage, device identifiers, and AI context.
- Jurisdiction-specific legal review may be required for behavioral Credit forfeiture, consumer disclosures, refunds, chargebacks, and prepaid Premium.
- Formal accounting/revenue recognition is outside product architecture and needs separate accounting review.
- No alternate payment mechanism is assumed for Play-distributed Credit purchases.
- Google Play policy compatibility must be a pre-release gate. Canonical docs must not say “Google Play compliant” as an established fact.
