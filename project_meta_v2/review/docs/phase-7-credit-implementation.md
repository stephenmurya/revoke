# Phase 7 Commitment Credits Implementation Review

Review date: 2026-09-05

## Change summary

Flutter added `lib/core/models/credit_models.dart`, `lib/core/services/credit_service.dart`, `lib/features/credits/credit_details_screen.dart`, and `lib/features/credits/credit_backing_screen.dart`. The existing `PremiumBillingService` remains the single purchase-stream owner and now routes `credits_50` and `credits_100` through an explicit consumable branch. The shell now reads the server-derived available Credit projection and `/credits` is a real detail route.

Cloud Functions added `functions/credit_ledger.js`, Credit purchase/disclosure/verification/redemption/backing/evidence/reversal callables, a 15-minute resolution worker, and pure Credit tests. Firestore rules expose only owner-readable wallet/history/backing summaries and deny client writes to authoritative Credit state. Android added `CreditEvidenceStore.kt`, `CreditBackingStore`, and `CreditLocalSettlement`; the existing Accessibility service records targeted observations and positive block evidence without changing enforcement decisions.

Canonical updates include `architecture/credit-backed-commitments.md`, the Credit ledger/monetization/status documents, ADRs 004/008/009/011/015, and this review packet.

## Product and disclosure

Credit products are fixed server quantities: `credits_50` = 50 Credits and `credits_100` = 100 Credits. Google Play supplies the localized price; no bulk discount is introduced. Credit purchase requires active Premium. Every purchase attempt shows the explicit disclosure in `CreditDetailsScreen` before the Play sheet, records `credit-purchase-v1` through `recordCreditPurchaseDisclosure`, and requires a matching server acceptance for a new purchase token.

## Ledger and wallet

The server creates append-only `CREDIT_PURCHASE`, `CREDIT_LOCK`, `CREDIT_RELEASE`, `CREDIT_FORFEITURE`, `PREMIUM_REDEMPTION`, and `PURCHASE_REVERSAL` events. The owner-readable `users/{uid}/creditWallet/current` projection separates `availableCredits` and `lockedCredits`; `creditHistory` is sanitized. Per-Commitment `creditHolds` and `creditBackings` retain attribution. The client never writes the wallet, ledger, hold, backing, purchase, evidence, or disclosure records.

## Verification and settlement

`credit_ledger.js` uses the installed `purchases.productsv2.getproductpurchasev2`, acknowledgement, and `purchases.products.consume` boundaries. Pending purchases do not issue Credits. Account binding and token hashes prevent replay across Revoke users. The default resolution policy is 24 hours after authoritative end and remains server-configurable. `UNVERIFIABLE` releases locked Credits and consumes no grace. A native positive failure creates a durable local `FAILURE_VERIFIED_LOCAL` projection/pending reconciliation event; the server re-evaluates evidence before canonical settlement. Wipe/reinstall before synchronization may lose that event and is an explicitly accepted v2 risk.

## Evidence and native boundary

`CreditEvidenceStore` is a local SQLite append-only journal with sequence, boot-session, monotonic elapsed time, wall-clock observation, monitoring state, and hash-chain fields. `RevokeAccessibilityService` records targeted foreground observations and block violations; Flutter uploads batches opportunistically. The implementation is not claimed to have Keystore signing, Play Integrity enforcement, complete positive checkpoint coverage, or OEM/device proof yet.

## Redemption

`redeemCreditsForPremium` accepts 10/50/100 available Credits and creates a server Premium grant using 25,920 seconds per Credit. Redemption does not require active Premium; locked Credits cannot be redeemed.

## Readiness matrix

| Gate | Current state |
|---|---|
| Repository code | CODE COMPLETE for the documented compatibility boundary |
| Play Console products | NOT VERIFIED |
| Licensed Play device | NOT VERIFIED |
| One-time purchase and server consumption | CODE COMPLETE; live test NOT VERIFIED |
| Pending/voided/reversal lifecycle | CODE COMPLETE boundary; live test NOT VERIFIED |
| RTDN topic and delivery | NOT CONFIGURED/VERIFIED |
| Native evidence device coverage | NOT VERIFIED |
| Keystore signing / Play Integrity | SEAM NOT IMPLEMENTED/CONFIGURED |
| Legal and policy review | NOT VERIFIED |
| Production readiness | NOT READY |

## Tests and build

- `flutter analyze`: PASS.
- `flutter test`: PASS; 42 tests after Credit model coverage was added.
- `node --check credit_ledger.js` and `node --check index.js`: PASS.
- `node --test test/credit_ledger.test.js`: PASS; 4 tests.
- `npm test`: PASS; 22 tests (including the four Credit tests) under Firebase CLI 15.26.0, Node 24.11.1, Java 26.
- `flutter build apk --debug`: PASS with the repository's existing Gradle/AGP/Kotlin deprecation warnings.

## Deferred work

Full server-created Commitment leases, complete native checkpoint success evidence, retry Commitment linking, device signing, Play Integrity policy, physical-device validation, automatic resolved-cache cleanup, and production Play/RTDN configuration remain deferred. No native enforcement engine or alternative billing architecture was introduced.
