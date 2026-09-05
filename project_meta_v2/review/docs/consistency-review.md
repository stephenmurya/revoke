# Documentation Consistency Review

Review date: 2026-09-05

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

The current shell routes `/home` to `TodayScreen` and `/commitments` to `CommitmentsScreen`. Legacy `HomeScreen` and `RegimesScreen` remain compatibility implementations/routes where referenced, but they no longer define the primary v2 shell experience. Canonical v2 names the daily surface Today and the management surface Commitments.

### Squad versus Circle

The `/squad` compatibility route now renders the optional Circle surface. Sanitized member projections, server-owned permissions, explicit Commitment sharing, and the new Override Request path are v2 behavior. `SquadService`, `squads`, `pleas`, and Tribunal remain compatibility names and storage; the legacy `SquadScreen` is no longer the primary route.

### Override authority and Tribunal behavior

Commitments use explicit `SELF`, `AI`, or `CIRCLE` policy. Circle authority snapshots eligible voters at request creation and uses strict majority; attendance and chat participation do not establish authority. Circle timeout rejects and does not invoke AI. The existing Tribunal remains the discussion/voting presentation, while the backend owns verdicts and native-access side effects.

### Regimes/Schedules versus Commitments

The v2 `/commitments` list, detail, and creation flow now use Commitment-oriented summaries and behavioral intent. `ScheduleModel`, `ScheduleService`, `RegimeService`, and the `users/{uid}/regimes` collection remain beneath that surface as retained enforcement/persistence mechanisms.

### Focus Score and wallet prominence

Current Home and Appearance preview still show Focus Score. It is retired from v2. Today must use direct behavioral evidence and must not become a large Credit wallet surface. Credits remain a compact global utility and contextual Commitment information.

### Premium pricing and renewal

Premium is prepaid and non-auto-renewing. The canonical reference prices are USD $9.99 for 30 days and USD $59.99 for 365 days; weekly and lifetime products are excluded from initial v2. Localized Google Play pricing remains authoritative.

### Design terminology and theme assumptions

The v2 design vocabulary is semantic: Today, Commitments, Circle, Insights, Available Credits, Locked Credits, and enforcement/verification states. `AppTheme` and `AppColorsExtension` are foundations, not a complete contract. The dated design audit records the unrestricted accent palette, screen-local components, and native hardcoded palette as current implementation concerns.

### Phase 1 implementation boundary

The implemented shell now uses the accepted Today / Commitments / Circle / Insights labels, while `/home`, `RegimesScreen`, and `/squad` remain compatibility/content locations. This does not contradict the target IA: it is the documented migration boundary. The Credits control is now a compact server-derived available-Credits projection; the detailed Credit purchase, disclosure, redemption, history, and backing boundary is routed separately. The current native blocker remains unchanged and is intentionally deferred to the native visual-alignment phase.

### Phase 2 Today boundary

`/home` now renders the dedicated Today presentation and `/commitments` now renders the user-facing Commitment management destination. Today uses direct native/local evidence and omits unsupported v2 adherence, recovery, grace, and override metrics. Focus Score is removed from Today without deleting its compatibility route or legacy storage. Credits remain app-bar-only and no Credit-backed values are displayed.

### Phase 3 Commitments boundary

The Commitments screen and creation journey are now v2-facing, while the backend and native contract remain schedule-backed. This is consistent with the accepted migration strategy: do not rename `ScheduleModel` or rewrite enforcement before a safe domain migration exists. Reduce is only classified when an active taper plan matches the materialized schedule; ambiguous legacy data is shown as needing attention and no Launch Count creation path exists.

### Phase 5 Circle boundary

Circle member summaries are readable without peer access to full `users/{uid}` profiles. Commitment summary sharing is assigned through a separate `sharedMemberIds` policy field; Circle voter selection uses `selectedMemberIds`. FCM/native approval delivery complements, rather than replaces, the existing Flutter listener. Self access is local-first and bounded; AI and Circle decisions remain server-authoritative.

### Phase 6 Premium boundary

Premium is now a repository-level implementation, not an absent feature claim. Flutter reads one sanitized entitlement projection and may cache only an unexpired server-verified expiry. Google Play purchase tokens are verified and acknowledged by Cloud Functions before a purchase is completed; grants and purchase records are server-only and idempotent. RTDN triggers a Developer API requery. Phase 7 adds a separate Credit purchase, redemption, and Credit-backed Commitment compatibility boundary; it does not claim live Play configuration, complete evidence-integrity hardening, or a native/server-native Commitment object.

The accepted matrix is consistent: Free has basic use, one active Protect Commitment, and Circle participation/voting/help; Premium adds new Reduce activation, additional Protect Commitments, AI Architect authority, Circle creation, and owner permission management. Existing active v1-v5 behavior and legacy authority policies are grandfathered. New Premium purchase disclosure is required on every purchase initiation; restore is a re-verification path, not a new purchase.

The code lifecycle is intentionally separate from release readiness. Play Console product/base-plan configuration, licensed-device testing, Android Publisher credentials, refunds/revocations, and RTDN delivery remain manual gates in `engineering/google-play-setup.md`.

## Previous-document status

Previous canonical-facing terminology has been corrected. No accidental legacy terminology remains in current product, architecture, decisions, or review-packet text. Remaining scan matches are limited to intentionally preserved historical archive material or dated implementation evidence; they are not current product or backend terminology.

## Intentional distinctions

The dated revival audit may describe implementation names and historical product assumptions that v2 retires. That evidence remains unchanged so current code reality is not erased. Engineering status connects that evidence to the target v2 architecture.
## Phase 7 Credit consistency

- The app-bar Credits pill is now a server-derived available Credit projection; Today still has no general wallet card.
- Credit purchases are separate from Premium subscription verification but share the single `PremiumBillingService` purchase stream.
- The server ledger and `creditWallet/current` projection are authoritative; native/Flutter offline state is provisional only.
- The accepted 24-hour post-end reconciliation default is implemented in the resolver and is not an open product question.
- `UNVERIFIABLE` releases locked Credits without forfeiture or grace consumption.
- Credit-backed Commitments remain a compatibility layer over `users/{uid}/regimes`; this does not claim native/server Commitment persistence.
