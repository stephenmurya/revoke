# Revoke 2.0 Final Adversarial Review Handoff

Prepared: 2026-09-06

This handoff follows Phase 11 hardening. It is an honest review baseline, not a production-readiness certificate.

## Current baseline

- Mobile Flutter + native Android enforcement architecture remains intact.
- Release APK and AAB build successfully; effective target/compile SDK is 36.
- Flutter analysis, Android Kotlin compilation with JDK 17, and 11 pure backend tests pass.
- Firestore emulator-backed suite was not run because port 8080 was occupied.
- Credit-backed Commitment activation is fail-closed by default until evidence can be server-verified.
- Native and Flutter user-bound state now clears or scopes schedules, unlocks, whitelist, evidence, Credit backings, local outcome markers, and legacy score caches across account changes.

## Required adversarial review focus

1. Prove no client-controlled field can create a trusted evidence outcome or move the canonical Credit ledger.
2. Prove resolver retries and concurrent calls are idempotent across grace, release, forfeiture, and `UNVERIFIABLE`.
3. Prove account switch, sign-out, delete, reinstall, and stale native state cannot cross user boundaries.
4. Prove service death, reboot, OEM battery restrictions, permission loss, exact-alarm denial, and Flutter process death preserve safe enforcement behavior.
5. Prove native FCM approval delivery is UID/package/expiry/idempotent while Flutter is dead.
6. Complete Play billing, RTDN, refund/revocation, signing, Integrity, policy, privacy, and device-matrix gates.

## Known non-claims

The repository does not claim production signing, live Play setup, Play policy approval, physical-device enforcement proof, complete cross-device restoration, server-native Commitment leases, or production financial custody. Any final release recommendation must be based on new evidence for those external gates.

## Source records

- [Phase 11 hardening review](docs/phase-11-hardening.md)
- [Release readiness](../engineering/release-readiness.md)
- [Migration boundary](../engineering/migration.md)
- [Device matrix](../engineering/device-test-matrix.md)
