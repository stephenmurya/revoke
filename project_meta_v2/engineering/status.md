# Engineering Status

Last canonical update: 2026-09-04

Source baseline: ../audits/2026-09-04-revival-audit.md.

This file answers what exists now, not what Revoke 2.0 intends to build. The current repository is pre-Credit/pre-Premium-v2 implementation.

## Confirmed working or salvageable foundations

- Flutter shell and Firebase initialization in normal app launch;
- Google/Firebase authentication and user bootstrap;
- installed-app discovery and whitelist;
- Time Block and Usage Limit schedules;
- local-first schedule cache and native synchronization path;
- Accessibility foreground-event path and UsageStats fallback/backstop;
- native hard blocker overlay;
- usage-limit soft/interstitial reminders;
- native temporary-unlock persistence;
- boot/alarm/watchdog scaffolding;
- local UsageStats day/week/trend Insights;
- Squad creation/join;
- Plea creation, Tribunal chat, voting, and server-only Plea/vote/message writes;
- AI fallback plus sanitization/parser tests;
- rap sheet and server blocked-attempt ingestion;
- Firestore rules/rap-sheet emulator tests;
- Android Kotlin debug compilation and Flutter static analysis.

## Broken or release-blocking behavior

- onboarding can skip/resume incorrectly;
- the onboarding vow/goal is not persisted;
- the legacy Flutter widget smoke test fails because Firebase is not initialized for direct RevokeApp mounting and it expects an obsolete counter;
- Launch Count is not enforced;
- approved Plea to native unlock depends on a Flutter listener;
- taper plans are not integrated into onboarding or fully remotely hydrated;
- schedule synchronization has no revision/conflict protocol;
- usage budget source and foreground event source differ without verification-confidence semantics;
- time/day/timezone boundaries are not formally reconciled;
- device/OEM Accessibility recovery lacks integration/device proof.

## V2 product concepts not implemented

- Commitment domain object and immutable activation lease;
- deterministic persisted Commitment onboarding state;
- optional Accountability Circle granular permissions;
- Commitment Credits, Credit holds, append-only Credit ledger, purchase lineage, Google Play verification, or Premium redemption;
- prepaid Premium entitlement/paywall;
- financial evidence outcomes/settlement state machine;
- native append-only evidence journal, signing, and Play Integrity signals;
- v2 adherence, override, slip/recovery, grace, Credit wallet, and verification-health cards;
- category analytics and Danger Zone analysis;
- Social Regimes/community marketplace;
- complete Launch Count enforcement.

## Present but not v2-ready

- Focus Score is implemented/visible in legacy UI/storage but is retired from v2 product UX;
- Squads are functional but evolve into optional Accountability Circles;
- Pleas/Tribunals are functional but need durable approval delivery, fixed voter policy, and idempotency hardening;
- taper is a Home opt-in but should become Commitment Reduce behavior;
- admin/God Mode, mock Tribunals, score adjustment, and amnesty exist and need an explicit production boundary.

## Revival order

1. repair deterministic onboarding and goal persistence;
2. replace stale test bootstrap and keep existing suites green;
3. prove enforcement/recovery on physical/emulated devices;
4. introduce the Commitment domain layer over existing schedules;
5. add schedule revisions, native acknowledgments, and conflict policy;
6. formalize usage evidence, timezone rules, monitoring health, and UNVERIFIABLE behavior;
7. make override approval delivery durable without Flutter dependency;
8. migrate Squad product semantics toward Circle permissions;
9. implement prepaid Premium entitlement and Google Play validation;
10. implement Credit ledger/purchase lineage only after evidence and policy gates;
11. replace Focus Score UI with direct cards;
12. expand advanced insights later.

## Rule

Do not mark a v2 feature implemented because a model, screen, or placeholder exists. Update this status only after an end-to-end executable path is verified. Current documentation decisions are not claims that any Credit, billing, evidence journal, or Premium path exists in code.

