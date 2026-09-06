# Phase 11 Reliability, Security, Migration, Device, and Release Hardening

Review date: 2026-09-06

## Executive readiness

Phase 11 addresses repository-verifiable reliability and security boundaries. It does not certify production readiness. The repository produces release APK/AAB artifacts and passes static analysis, Android Kotlin compilation under JDK 17, and 11 pure backend tests. Device, Play Console, production signing, RTDN, Play Integrity, policy/privacy, and the emulator-backed Firestore suite remain unverified or blocked by the local environment.

## Critical findings fixed

- Credit evidence upload no longer copies arbitrary client fields or accepts a client-selected `trusted` value. Allowed event types and fields are normalized; duplicate event IDs are idempotent; conflicting reuse fails.
- Untrusted client evidence cannot independently settle a Credit-backed Commitment. Final financial outcomes require server-trusted evidence. Credit-backed activation is fail-closed by default through `REVOKE_CREDIT_BACKING_ENABLED`.
- Concurrent resolver calls now consume grace and settle the wallet in one transaction using the latest backing state, preventing duplicate grace consumption or ledger movement.
- Native Credit evidence and local forfeiture records are UID-bound. Cross-account evidence upload is skipped, active native Credit backings are cleared on account switch, and pending rows without a UID are not treated as belonging to the current account.
- Flutter local schedules and important preferences are UID-scoped; unauthenticated schedule state is empty/no-op; native state is cleared during sign-out/account switching.
- Tribunal outcome markers and legacy Focus Score caches are UID-scoped to prevent cross-account local leakage. Focus Score remains compatibility code only.

## Phase 11 source change summary

| Area | Source files |
| --- | --- |
| Native account binding and cleanup | `MainActivity.kt`, `AppMonitorService.kt`, `CreditEvidenceStore.kt`, `NativeBridge` |
| Flutter local/account isolation | `persistence_service.dart`, `schedule_service.dart`, `credit_service.dart`, `main.dart`, `tribunal_screen.dart`, legacy Focus Score readers/writer |
| Credit evidence and settlement trust | `functions/credit_ledger.js`, `functions/index.js`, `functions/test/credit_ledger.test.js` |
| Canonical/review documentation | `project_meta_v2/engineering/*`, `architecture/*`, ADR 015, this review, final handoff |

No P0/P1 source defect was left unaddressed in the repository checks performed; the final adversarial review must re-evaluate this conclusion. The P1 items listed below are external release gates or deliberately disabled capability boundaries, not claims that the corresponding scenarios have passed.

## Android release configuration

The effective release artifact reports compile SDK 36 and target SDK 36. The resolved Billing Library is 8.0.0. Release APK and AAB builds pass with the available local signing material. Production signing, Play upload identity, versioning policy, mapping/symbol upload, and Play Console configuration are external gates.

## Lifecycle and enforcement review

The retained `RevokeAccessibilityService`, `AppMonitorService`, `EnforcementEngine`, `UsageEventsSessionCalculator`, `BootReceiver`, alarms, watchdog worker, and native overlay remain the enforcement architecture. Existing service restart and boot scaffolding was not rewritten. Account switching now clears native schedules, unlocks, whitelist, Credit backing cache, alarms, and monitor restart state before rebinding.

Physical verification is still required for Accessibility failure, OEM process killing, force-stop, Flutter process death, service death, reboot, permission loss, exact-alarm denial, and offline recovery. No claim is made that OEM behavior is solved by code inspection.

## FCM and override reliability

`AmnestyPushReceiver` validates the expected native UID, package, bounded expiry, and persisted delivery identity before granting native temporary access. The Flutter listener remains a compatibility path. Native delivery while Flutter is dead, duplicate delivery, stale delivery, token rotation, and uninstall/reinstall behavior require device testing.

## Auth, account isolation, and deletion

`AuthService.signOut` clears the Flutter session and global services; native UID binding now clears user-bound state. `deleteAccount` deletes the currently enumerated user-owned app data and Auth record. Premium/Credit ledger records are not client-deleted, which preserves server reconciliation but requires retention/legal policy confirmation. Cross-device native restoration is not implemented.

## Firebase security

Firestore rules deny client writes to authoritative Premium/Credit ledger, purchase, hold, evidence, and entitlement records. Callable functions derive the authenticated UID and validate ownership. The evidence callable now whitelists fields and writes `trusted: false`. The remaining production requirement is server-verifiable evidence promotion, not a more permissive client path.

## Premium and Credit reliability

Premium verification/grant code remains idempotent and RTDN is a requery signal. Google Play product configuration, licensed-device purchase/restore/refund/revocation testing, and RTDN delivery are not verified. Credit purchase and redemption code exists, but Credit-backed Commitment creation is disabled by default because client evidence is not proof. Offline native positive failure creates a local `FAILURE_VERIFIED_LOCAL` projection and pending reconciliation; the server remains canonical. Reinstall-before-sync loss is explicitly accepted v2 risk.

## Evidence and resolution policy

The accepted default is 24 hours after authoritative Commitment end, remaining server-configurable. Untrusted or insufficient evidence resolves `UNVERIFIABLE` after the window; locked Credits are released, no Credit is forfeited, and no grace is consumed. The local projection is provisional and must reconcile idempotently after connectivity returns.

## Migration review

See [engineering/migration.md](../../engineering/migration.md). Legacy schedules, regime paths, Focus Score compatibility, Squad/Tribunal names, and device-local caches remain. A server-native Commitment lease, revision conflict policy, device signing, Play Integrity, and cross-device restoration are not implemented.

## Build and test results

| Check | Result |
| --- | --- |
| `flutter analyze` | PASS; no issues |
| Pure Node tests | PASS; 11/11 |
| `npm test` Firestore emulator suite | NOT RUN; port 8080 occupied by another local process |
| `:app:compileDebugKotlin` | PASS with JDK 17 |
| `flutter build apk --release` | PASS; 61.4 MB artifact |
| `flutter build appbundle --release` | PASS; 61.9 MB artifact |
| release artifact target SDK | PASS; 36 |

## Device, Play, policy, and release blockers

P1 external gates: physical enforcement/FCM/OEM matrix, licensed Play lifecycle, RTDN delivery, production signing, Play Integrity configuration, Firebase emulator-suite rerun, policy/privacy review, and release operational monitoring. These are not fixed by claiming code completeness. The Credit-backed Commitment feature remains unavailable by default until its evidence trust boundary is implemented and reviewed.

## Deferred work

Dependency warnings, Java-8 target migration, full native visual alignment follow-ups, server-native Commitment leases, schedule revision conflicts, clock/timezone policy, backup/restore, and legacy UI cleanup remain deferred. No dependency or product-scope expansion was made in Phase 11.
