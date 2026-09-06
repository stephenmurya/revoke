# Google Play Premium Setup Runbook

Status: manual release setup required. The repository contains the code boundary but no Play Console state or production credentials.

## Catalog to configure

Create one subscription product:

- product ID: `premium`;
- base plan: `prepaid-30d`;
- base plan: `prepaid-365d`;
- initial reference prices: USD $9.99 and USD $59.99 respectively.

Do not configure weekly, lifetime, or auto-renewing base plans for the initial Revoke 2.0 catalog. Localized prices shown by Play are authoritative at runtime.

## Backend prerequisites

1. Enable the Google Play Developer API for the release project.
2. Grant the production service identity the minimum Android Publisher permission required to read Premium subscriptions and one-time Credit purchases, and to acknowledge/consume them.
3. Configure the `revoke-premium-rtdn` and `revoke-credit-rtdn` Pub/Sub topics as the Google Play Real-time Developer Notifications destinations.
4. Deploy `verifyPremiumPurchase`, `recordPremiumPurchaseDisclosure`, `verifyCreditPurchase`, `recordCreditPurchaseDisclosure`, `redeemCreditsForPremium`, `createCreditBacking`, and both RTDN handlers only after reviewing project/package identity.
5. Keep service credentials in Secret Manager or the deployment environment; never add them to Flutter, Firestore, or this repository.

## Required test matrix

Use a Play license tester and a real configured application package to verify:

- 30-day and 365-day offer discovery by base plan ID;
- localized price rendering;
- disclosure required before every new purchase;
- pending, purchased, canceled, restored, and verification-error states;
- server acknowledgement only after validation;
- duplicate token verification is idempotent;
- account mismatch is rejected;
- expiry, refund/revocation, and RTDN requery recompute entitlement;
- reinstall/restore does not create a second grant;
- Free users cannot activate Reduce, create a second active Protect, create a Circle, or configure new AI/Circle authority;
- Free users can continue basic use and participate in another member's Circle activity.

## Lifecycle status

| Stage | Current state |
| --- | --- |
| Flutter billing code | CODE COMPLETE; static analysis/tests pass |
| Server verification/grants | CODE COMPLETE; emulator/pure tests pass, live API not tested |
| Firestore rules | CODE COMPLETE; emulator test coverage added |
| Play product/base plans | NOT CONFIGURED/NOT VERIFIED IN THIS REPOSITORY |
| Licensed-device purchase test | NOT RUN |
| RTDN Pub/Sub delivery | NOT CONFIGURED/NOT VERIFIED |
| Credit one-time products (`credits_50`, `credits_100`) | NOT CONFIGURED/NOT VERIFIED |
| Credit consume/reversal lifecycle | NOT RUN |
| Credit evidence device coverage | NOT RUN |
| Production release readiness | NOT READY until manual gates pass |

## Phase 11 release-hardening additions

- Verify the final signed artifact, package identity, target SDK 36, version code/name, mapping files, and Play App Signing/upload-key arrangement in the release environment.
- Keep production service credentials in deployment configuration/Secret Manager. The repository’s local `key.properties`, upload keystore, and Firebase client configuration are not production proof.
- Execute the Android/OEM lifecycle matrix in `device-test-matrix.md`, including service death, force-stop, reboot, permission loss, exact-alarm denial, Flutter process death, and native FCM approval while Flutter is dead.
- Do not enable Credit-backed Commitment creation until a server-verifiable evidence path and reviewed Integrity/signing policy exist. The code default is fail-closed.
- Re-run the Firestore emulator suite in an uncontested environment; the Phase 11 local run was blocked by port 8080 occupancy.
- Complete Play policy, Data Safety, Accessibility API declaration, privacy/retention, subscription/prepaid catalog, RTDN, refund/revocation, and support/incident runbooks before release.
