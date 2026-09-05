# Credit-backed Commitments — Phase 7 Boundary

Status: Phase 7 repository implementation is present. Google Play configuration, licensed-device evidence testing, Play Integrity configuration, policy review, and production operational proof remain release gates.

## Implemented boundary

Flutter exposes the Credit wallet projection and history under `CreditService`, the app-bar `RevokeCreditsPill` reads the server wallet, and `CreditDetailsScreen` provides localized product metadata, the mandatory `credit-purchase-v1` disclosure before every purchase, redemption choices, and history. `PremiumBillingService` remains the single owner of the Flutter purchase stream; Credit products are routed through its explicit consumable branch.

Cloud Functions in `functions/credit_ledger.js` own product verification, acknowledgement, server-side consumption, purchase-token binding, disclosure acceptance, append-only ledger events, materialized `creditWallet/current`, sanitized `creditHistory`, per-Commitment `creditHolds`, Credit-backed Commitment snapshots, evidence upload, redemption, reversal reconciliation, and the scheduled resolver. Client Firestore writes to all authoritative Credit collections are denied by `firestore.rules`.

The implementation uses the installed Google Publisher API's `purchases.productsv2.getproductpurchasev2` and `purchases.products.consume` boundaries. Pending Play purchases never issue Credits. `credits_50` and `credits_100` are fixed server quantities; Play-provided localized pricing is displayed by Flutter.

## Backing and settlement

`createCreditBacking` accepts only active Premium users, supported existing schedules, fixed initial lock amounts, healthy client preflight permissions, and an explicit backing-terms version. It snapshots the schedule rule and creates a hold and `CREDIT_LOCK` atomically with the wallet projection. It does not create a new native enforcement engine. `CreditBackingStore` synchronizes that snapshot to native Android so existing Accessibility enforcement can journal observations.

`CreditEvidenceStore` is a durable SQLite append-only local journal with sequence and hash-chain fields. `RevokeAccessibilityService` records targeted foreground observations and positive block observations. Flutter uploads pending journal batches through `submitCreditEvidence`; the server never accepts a client-selected final outcome.

Settlement is server-canonical. The default resolver waits until the authoritative end plus 24 hours, remains configurable per backing, and then releases on success or uncertainty. Verified failure can consume configured grace before `CREDIT_FORFEITURE`. Offline native failure observations create a local `FAILURE_VERIFIED_LOCAL` projection and a durable pending reconciliation record; the server re-evaluates evidence before final settlement. Wipe/reinstall before synchronization may lose that local event and is an explicitly accepted v2 risk.

The current evidence recorder has not been proven on physical OEM variants, does not yet provide Keystore signing or Play Integrity verdicts, and emits no complete positive checkpoint proof for every schedule type. Those limitations can produce `UNVERIFIABLE` and are intentionally visible rather than replaced with optimistic client calculations.

## Fixed redemption

`redeemCreditsForPremium` accepts 10, 50, or 100 available Credits and creates a server Premium grant using `SECONDS_PER_CREDIT = 25920` (100 Credits = 30 Premium days). Locked Credits cannot be redeemed. The existing Premium entitlement recomputation remains the entitlement projection authority.

## Deferred release work

The current repository does not yet provide full server-created Commitment leases, device signing, complete native checkpoint coverage, retry Commitment linking, automatic removal of resolved native backing caches, or a production Play RTDN topic configuration. These are hardening and operational tasks, not permission to weaken the ledger boundary or treat local state as the global wallet.
