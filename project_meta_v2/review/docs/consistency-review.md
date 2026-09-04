# Documentation Consistency Review

Review date: 2026-09-04

The non-archive canonical corpus and review packet were re-read after the correction pass. The required case-insensitive terminology scan is recorded in `terminology-scan.md`. Historical archive material and the dated source audit are classified separately and were not rewritten.

## Corrections verified

### Credit vocabulary

Canonical docs now use Commitment Credits, Available Credits, Locked Credits, Credit lock, Credit release, Credit forfeiture, and Commitment backing. Backend examples use `available_credits`, `locked_credits`, `credit_holds`, `CREDIT_PURCHASE`, `CREDIT_LOCK`, `CREDIT_RELEASE`, `CREDIT_FORFEITURE`, `PREMIUM_REDEMPTION`, and `PURCHASE_REVERSAL`. The prohibited legacy vocabulary is absent from current product, architecture, decision, and review language.

### Local versus server settlement

`FAILURE_VERIFIED_LOCAL` is a local provisional state. Positive offline failure evidence immediately changes local Credit projections and writes a durable pending reconciliation event. The server ledger remains the canonical authority and must reconcile the event idempotently after reconnect.

### Accepted reinstall risk

If a user wipes or reinstalls before synchronization, the pending local forfeiture may be lost. This is explicitly accepted for v2. The design does not require continuous connectivity or an adversarial anti-avoidance system.

### Resolution policy

The initial default reconciliation window is 24 hours and remains server-configurable. At the end, sufficient evidence produces `SUCCESS_VERIFIED` or `FAILURE_VERIFIED`; insufficient trustworthy evidence produces `UNVERIFIABLE`, releases locked Credits, forfeits none, and consumes no grace.

### Purchase disclosure

Every Credit purchase requires a fresh disclosure and explicit confirmation before Google Play Billing. The acceptance event records disclosure version, user, timestamp, and purchase flow ID. Existing acceptance records do not suppress future disclosures.

## Design consistency

### Home versus Today

The current shell routes `/home` to `RegimesScreen` and renders `HomeScreen`. That is implementation reality, not the v2 information architecture. Canonical v2 names the daily surface Today and the management surface Commitments; `design/information-architecture.md` records the migration relationship.

### Squad versus Circle

Current Squad, Plea, and Tribunal screens remain implementation evidence. The target product surface is Circle with the previously accepted granular permissions. The design audit identifies the current Squad-specific visual language as a gradual replacement target, not a reason to remove native enforcement or functioning social code prematurely.

### Regimes/Schedules versus Commitments

Current schedule creation and schedule cards are dense, local implementations. The canonical design treats schedules as mechanisms beneath Commitments and requires Commitment-oriented summaries in new v2 surfaces.

### Focus Score and wallet prominence

Current Home and Appearance preview still show Focus Score. It is retired from v2. Today must use direct behavioral evidence and must not become a large Credit wallet surface. Credits remain a compact global utility and contextual Commitment information.

### Premium pricing and renewal

Premium is prepaid and non-auto-renewing. The canonical reference prices are USD $9.99 for 30 days and USD $59.99 for 365 days; weekly and lifetime products are excluded from initial v2. Localized Google Play pricing remains authoritative.

### Design terminology and theme assumptions

The v2 design vocabulary is semantic: Today, Commitments, Circle, Insights, Available Credits, Locked Credits, and enforcement/verification states. `AppTheme` and `AppColorsExtension` are foundations, not a complete contract. The dated design audit records the unrestricted accent palette, screen-local components, and native hardcoded palette as current implementation concerns.

## Previous-document status

Previous canonical-facing terminology has been corrected. No accidental legacy terminology remains in current product, architecture, decisions, or review-packet text. Remaining scan matches are limited to intentionally preserved historical archive material or dated implementation evidence; they are not current product or backend terminology.

## Intentional distinctions

The dated revival audit may describe implementation names and historical product assumptions that v2 retires. That evidence remains unchanged so current code reality is not erased. Engineering status connects that evidence to the target v2 architecture.
