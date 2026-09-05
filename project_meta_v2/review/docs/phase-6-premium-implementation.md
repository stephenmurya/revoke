# Phase 6 Premium Implementation Review

Review date: 2026-09-05

Phase 6 implements the Revoke 2.0 Premium entitlement and Google Play Billing foundation. It does not implement Commitment Credits, Credit purchases, Credit locks, Premium redemption, Credit-backed Commitments, commercial onboarding, or native enforcement changes.

## Change summary

### Flutter

- Added `lib/core/models/premium_models.dart` for the fixed plan IDs, entitlement projection, and capability vocabulary.
- Added `lib/core/services/premium_entitlement_service.dart` for the auth-scoped server stream, offline expiry cache, and server capability-callable boundary.
- Added `lib/core/services/premium_billing_service.dart` for the app-scoped official `in_app_purchase` listener, Play offer discovery, obfuscated account binding, disclosure acceptance, verification, restore, and completion.
- Added `lib/features/premium/premium_paywall_screen.dart` and `/premium` routing.
- Added the Premium status entry under Profile/account.
- Added Reduce/additional-Protect activation checks in the existing Commitment creation flow.
- Added client presentation gates for new Circle creation and AI/Circle Override Authority configuration. Existing Circle participation and voting remain available.
- Added `test/premium_entitlement_test.dart`.
- Added `in_app_purchase`, `in_app_purchase_android`, and `crypto` dependencies. The generated macOS plugin registration changed as a consequence of dependency resolution; no macOS purchase UI or product path was implemented.

### Backend and authorization

- Added `functions/premium_billing.js`, isolated from the existing Tribunal/override code, for Play resource normalization, account hashes, idempotent grant IDs, sequential grant calculation, sanitized entitlement projection, and RTDN parsing.
- Added `recordPremiumPurchaseDisclosure`, `verifyPremiumPurchase`, `assertPremiumCapability`, and `createCircle` callables to `functions/index.js`.
- Added `reconcilePremiumRtdn` on the `revoke-premium-rtdn` Pub/Sub topic. It deduplicates message IDs and re-queries Google Play before changing grant state.
- Added `googleapis` to the Functions dependencies.
- Added server-only Firestore rule coverage for entitlement, grants, purchases, disclosure acceptances, and Premium Circle creation requirements.
- Added `functions/test/premium_billing.test.js` and extended the rules test fixture for Premium-authorized Circle creation.

## Accepted catalog and capability matrix

| Capability | Free | Premium |
|---|---|---|
| Basic Revoke use | Yes | Yes |
| One active Protect Commitment | Yes | Yes |
| Additional active Protect Commitments | No | Yes |
| New Reduce activation | No | Yes |
| New AI Architect authority | No | Yes |
| New Circle creation and owner permission management | No | Yes |
| Circle participation, voting, and helping another member | Yes | Yes |

Catalog: product `premium`; prepaid base plans `prepaid-30d` and `prepaid-365d`; reference prices USD $9.99 and $59.99. The app does not define weekly, lifetime, auto-renewing, or hardcoded localized prices.

Existing active v1-v5 behavior and existing legacy authority policies are grandfathered. This means new paid-capability configuration is checked without abruptly disabling active behavior. Expiry does not rewrite an authority policy; pending Premium-required AI work is rejected safely and the policy can be revisited after renewal.

## Purchase and disclosure flow

```text
Paywall → recordPremiumPurchaseDisclosure → Google Play sheet
       → purchaseStream → verifyPremiumPurchase → Play API requery
       → validate/account-bind/acknowledge → append one grant
       → recompute premiumEntitlement/current → completePurchase
```

The paywall shows actual localized prices from Play's product metadata and the selected offer token. Every new Premium purchase gets a fresh confirmation dialog, a new `purchaseFlowId`, and explicit `premium-purchase-v1` acceptance before the Play sheet. The in-flight flow ID is cached locally so a process restart can complete server verification; the cache cannot grant Premium. Restore/reverification of an existing server purchase is not a new purchase, so it does not create another disclosure acceptance requirement.

No successful UI state grants Premium. A canceled purchase is shown as canceled; pending and verification errors remain controlled states. Raw tokens never leave server-only purchase storage or the verification request boundary.

## Server records and authority

- `users/{uid}/premiumPurchases/{tokenHash}` stores raw token and verification lineage server-side.
- `users/{uid}/premiumGrants/{grantId}` stores one idempotent source grant per token.
- `users/{uid}/premiumEntitlement/current` is the sanitized owner-readable projection.
- `premiumAccountBindings/{accountHash}` resolves RTDN to a previously verified account.
- `premiumPurchaseBindings/{tokenHash}` prevents the same Play token being verified against another Revoke account.
- `premiumRtdnEvents/{messageId}` provides RTDN idempotency.

The entitlement projection is derived from active grants in deterministic order. It is not a client ledger and the client cannot write any of these records. The implementation is intentionally compatible with a future Credit redemption grant without implementing Credits now.

## Offline and expiry behavior

Flutter may present an unexpired last verified `premiumUntil` from its user-scoped cache. It never extends the value. An expired cache or absent entitlement is Free. Paid activation and paid authority changes call the server capability boundary where the legacy schedule model still owns persistence.

Google RTDN is a signal only. The function re-queries the Google Play Developer API and then preserves purchase/grant history while recomputing the current projection for expiry, revocation, or refund consequences.

## Scope boundary

The existing schedule/regime system remains the enforcement/persistence authority. Phase 6 gates the existing Reduce/taper and Protect creation path before activation; it does not create a new Commitment backend. `CircleService` still uses `squads` and `commitmentPolicies`, but new Circle creation, owner permission changes, and new AI/Circle authority configuration are server-gated. Circle members may join, participate, vote, and help without Premium.

The Credits pill remains the existing zero-valued placeholder. There is no Credit purchase, wallet balance, lock, release, forfeiture, redemption, or Credit-backed Commitment in this phase.

## Test and build evidence

| Check | Result |
|---|---|
| `flutter analyze` | PASS — no issues found |
| `flutter test` | PASS — all tests passed, including Premium entitlement tests |
| `node --check index.js` / `premium_billing.js` | PASS |
| AI backend tests | PASS |
| Premium pure backend tests | PASS |
| Firestore rules emulator tests | PASS — 17 tests under Firebase CLI 15.26.0 / Java 26 |
| Android debug build | PASS — `flutter build apk --debug` using the installed Android Studio JBR |
| Licensed Google Play purchase/restore/refund test | NOT RUN — requires Play Console configuration and licensed device |
| RTDN delivery test | NOT RUN — requires Pub/Sub and Play Console configuration |

## Manual release work remaining

See `project_meta_v2/engineering/google-play-setup.md`. Code completion does not mean the Play product, base plans, Android Publisher credentials, licensed device, RTDN topic, refunds/revocations, or Google Play policy/legal review have been verified.
