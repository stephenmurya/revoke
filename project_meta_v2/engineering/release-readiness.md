# Revoke 2.0 Release Readiness

Last verified: 2026-09-06

This is an evidence-based release gate, not a declaration of production readiness. A gate marked `NOT VERIFIED` requires an external or device-level check before release.

## Repository evidence

| Gate | Evidence | Result |
| --- | --- | --- |
| Flutter static analysis | `flutter analyze` | PASS |
| Android Kotlin compilation | `:app:compileDebugKotlin` with JDK 17 | PASS |
| Release APK | `flutter build apk --release` | PASS; local upload keystore only |
| Release App Bundle | `flutter build appbundle --release` | PASS; local upload keystore only |
| Effective SDK | `aapt2 dump badging` and merged release manifest | compile/target SDK 36 |
| Resolved Billing Library | Gradle `releaseRuntimeClasspath` | `com.android.billingclient:billing:8.0.0` |
| Pure Functions tests | Node test runner, 11 tests | PASS |
| Firestore emulator suite | `npm test` | NOT RUN: local port 8080 occupied |
| Physical-device enforcement | device matrix | NOT VERIFIED |
| Licensed Play purchase lifecycle | Play license tester | NOT VERIFIED |
| RTDN delivery | Play Console/Pub/Sub | NOT VERIFIED |
| Production signing | release keystore and Play upload | NOT VERIFIED |
| Play Integrity | Play Console and server verdict policy | NOT VERIFIED |

## Configuration gates

- `android/key.properties` and the local upload keystore are ignored local files. They prove only that a local artifact can be signed; they are not production signing authority.
- `google-services.json` and `lib/firebase_options.dart` are local Firebase configuration artifacts. Server credentials must remain outside the client and repository.
- Credit-backed Commitment creation is fail-closed unless the reviewed server setting `REVOKE_CREDIT_BACKING_ENABLED=true` is explicitly configured after server-verifiable evidence exists. The default is disabled.
- Missing `OPENROUTER_API_KEY` fails AI fallback safely. Google Play Publisher access is lazy and requires deployment credentials; no production credentials are present in the repository.

## Toolchain note

The repository currently uses Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20, and Firebase BoM 34.9.0. Flutter 3.47.0 reports that support for these versions will be dropped in a future Flutter release. No dependency upgrade was performed during Phase 11. JDK 17 is the verified Android build environment; the configured Android Studio JBR reports Java 26 and is not the verified release environment.

## Release decision

The repository is buildable and materially hardened, but it is not production-ready. External device, Play Console, signing, policy, privacy, RTDN, Integrity, and emulator-suite gates remain open. No release claim should be made until those gates have evidence.
