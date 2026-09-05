# Revoke 2.0 Phase 5 Circle and Override Authority Implementation Review

Review date: 2026-09-05

Phase 5 replaces the primary Squad presentation with an optional Accountability Circle and adds explicit per-Commitment Override Authority over the retained schedule/Plea/Tribunal infrastructure. It includes narrowly scoped backend, rules, FCM, and native changes because permissions and access decisions cannot be Flutter-only concerns.

## Change Summary

### Flutter source created

- `lib/core/models/circle_models.dart`: supported Circle permissions/presets, explicit `SELF`/`AI`/`CIRCLE` authority, Commitment policy, sanitized member model, and quorum helper.
- `lib/core/services/circle_service.dart`: sanitized member streams, policy reads, server callable boundaries, shared Commitment summaries, Override Requests, history, and Circle leave.
- `lib/core/services/local_override_history_service.dart`: small user-scoped SharedPreferences retry queue for offline Self Override History.
- `lib/features/circle/circle_screen.dart`: optional Circle empty state, member list, permission management, explicit shared Commitment summaries, active Override Requests, and leave flow.
- `lib/features/circle/override_history_screen.dart`: neutral Override History presentation.
- `lib/features/circle/override_policy_screen.dart`: per-Commitment authority, Circle voter selection, and separate Commitment summary sharing.
- `lib/features/circle/override_request_screen.dart`: Request Access friction, bounded duration, Self/AI/Circle branching, and offline Self handling.
- `test/core/circle_models_test.dart`: permission sanitization, preset, policy, authority, and quorum coverage.
- `functions/test/override_authority.test.js`: backend authority normalization, permission sanitization, and quorum coverage.

### Flutter source modified

- `lib/core/app_router.dart`: `/squad` now opens Circle; `/plea-compose` opens the neutral Request Access flow; Override History and policy routes were added; the missing-Tribunal fallback no longer returns to the legacy Squad screen.
- `lib/core/models/plea_model.dart`: v2 authority, voter snapshot, resolution, and expiry fields were added while legacy fields remain parseable.
- `lib/core/native_bridge.dart`, `lib/main.dart`: native user binding and pending local-history synchronization were added; existing Phase 4 routing changes were preserved.
- `lib/core/services/auth_service.dart`: Commitment policy subcollections are included in account cleanup.
- `lib/core/services/notification_service.dart`: visible notification copy/types use Override terminology while legacy routing remains compatible.
- `lib/core/services/squad_service.dart`: sanitized Circle/Override streams and callable leave boundary were added; the old random approval side effect was removed from the legacy creation helper.
- `lib/core/utils/theme_extensions.dart`: shared semantic typography access used by Circle surfaces.
- `lib/features/commitments/commitment_detail_screen.dart`: Override Authority entry point.
- `lib/features/squad/tribunal_screen.dart`: neutral request/verdict copy and fixed-snapshot voter eligibility presentation.

### Backend, rules, and native source modified

- `functions/index.js`: Circle permission constants/projections, policy/share callables, v2 Override Request creation, fixed voter snapshots, quorum/timeout handling, sanitized shared summaries, server-authoritative side effects, and targeted approval FCM data messages.
- `functions/package.json`: focused authority tests are included in backend test scripts.
- `firestore.rules`: full peer user documents, direct policy writes, direct member-summary writes, direct Plea/message/vote writes, and unscoped Plea reads are denied; sanitized Circle member and request visibility rules were added.
- `firestore.indexes.json`: request visibility, member summary ordering, and Override History query indexes were added.
- `functions/test/firestore.rules.test.js`: private regime/rap-sheet boundaries, sanitized member access, and visible request data were covered.
- `android/app/src/main/kotlin/com/crescence/revoke/NativeOverrideAccess.kt`: validated, idempotent FCM approval application into existing native temporary-unlock storage.
- `android/app/src/main/kotlin/com/crescence/revoke/AmnestyPushReceiver.kt`: existing FCM receiver dispatches approval data to the native validator.
- `android/app/src/main/kotlin/com/crescence/revoke/MainActivity.kt`: Flutter binds the current Firebase UID for native approval validation.
- `android/app/src/main/kotlin/com/crescence/revoke/BlockerOverlayController.kt` and `EnforcementEngine.kt`: Request Access/Commitment wording and routing compatibility were updated; blocking architecture was retained.

No `old_project_meta/` file was modified. No Credits, Premium, Billing, browser, new Commitment backend, or new enforcement engine was added.

## Circle Compatibility Map

| v2 concept | Retained implementation |
|---|---|
| Accountability Circle | `squads/{circleId}` membership and existing create/join callable infrastructure |
| Circle member | Server-generated `squads/{circleId}/members/{uid}` sanitized summary |
| Override Request | `pleas/{pleaId}` with v2 fields; legacy collection name retained |
| Tribunal | Existing Tribunal screen, message stream, vote subcollection, and resolution triggers |
| Override History | Own `pleas` history plus sanitized owner-authorized member-history callable |
| Override Authority | `users/{uid}/commitmentPolicies/{commitmentId}` companion document keyed by the existing schedule-backed Commitment ID |
| Shared Commitment | Policy `sharedMemberIds` plus `getSharedCommitmentSummaries`, returning reduced active summaries only |

The compatibility boundary is deliberate. User-facing Flutter code reasons about Circle and authority; `ScheduleModel`, `ScheduleService`, `RegimeService`, `users/{uid}/regimes`, native enforcement, and legacy Function names remain underneath.

## Permission Matrix

Only these six permissions are operationally supported in the v2 UI and server sanitizer:

| Permission | Current grant |
|---|---|
| `viewCommitmentSummary` | Permits a sanitized shared Commitment summary when the owner explicitly assigns that Commitment. |
| `viewOverrideHistory` | Permits the server-authorized sanitized member-history callable. |
| `receiveOverrideRequests` | Controls request notification delivery in addition to user notification preferences. |
| `participateInOverrideDiscussion` | Permits discussion access for an authorized request. |
| `voteOnOverrideRequests` | Permits inclusion when the request is created and the member is snapshotted as an eligible voter. |
| `receiveAccountabilityNotifications` | Controls accountability notification delivery. |

Presets expand to supported permissions and remain editable. Observer defaults to summary/history visibility and no request receipt, discussion, or voting. Accountability Partner and Guardian default to the current supported set. Custom uses explicit toggles. Credit visibility and future progress/slip permissions are not exposed.

## Privacy Review

Before Phase 5, same-Squad code paths and rules could expose broad peer `users/{uid}` or schedule-derived data. The current peer path is:

```text
peer client
  -> squads/{circleId}/members/{uid}
  -> explicit visibleToUids / sharedMemberIds
  -> server-sanitized response
```

Peer clients cannot read another user's full profile, email, FCM token, private regimes, private taper plans, rap sheet, or unshared Commitment. Member-summary documents contain only UID, display name, avatar URL, role/preset, supported permissions, and update timestamp. FCM tokens are read only by trusted server code for delivery.

The owner can change another member's supported permissions only through `setCircleMemberPermissions`. Members cannot write their own permission summary. Direct client writes to summaries, policies, requests, messages, votes, and resolution fields remain denied. Members can leave through `leaveCircle`; an owner with remaining members must transfer ownership first.

## Override Authority Matrix

| Authority | Resolver | Offline? | Timeout/failure |
|---|---|---|---|
| SELF | Local deliberate flow, native temporary unlock, best-effort server history | Yes while native enforcement is healthy | No server decision required; bounded to 5/10/15 minutes |
| AI | Existing sanitized OpenRouter task path | No; queued server request | Existing AI deadman rejects safely |
| CIRCLE | Selected fixed voter snapshot and server vote resolution | No; server connectivity required | Existing five-minute Tribunal timeout rejects; no AI fallback |

The authority is persisted per Commitment and must match the request payload. If no v2 policy exists, the v2 request path defaults to Self. No random system decision is used by the v2 path.

## Self Authority

`OverrideRequestScreen` requires a reason, runs a 30-second reflection period, limits duration to 5, 10, or 15 minutes, invokes the existing native temporary-unlock bridge, and records a local event. `LocalOverrideHistoryService` stores up to 50 pending events in user-scoped SharedPreferences and retries `recordSelfOverride` on authenticated resume/startup. The local event is a history retry queue, not a server ledger.

## AI Authority

The new callable requires explicit `authority = ai`, verifies the saved Commitment policy, sanitizes the reason/context through the retained AI helpers, queues the configured OpenRouter task, and persists the server result. Malformed or failed AI evaluation rejects safely. The Circle path is not converted to AI when its voters do not respond.

## Circle Authority and Quorum

At creation, `createOverrideRequest` resolves the selected members from the saved Commitment policy, requires `voteOnOverrideRequests`, excludes the requester, and stores `eligibleVoterIds` and `requiredApprovalCount` on the request. Quorum is centralized as:

```text
floor(eligible voters / 2) + 1
```

The mapping is 1→1, 2→2, 3→2, and 4→3. Vote trigger and scheduled timeout paths use the fixed snapshot rather than mutable participants/attendance. Repeated vote/resolution paths use server transactions and a claimed native-delivery marker before side effects. A Circle timeout rejects and does not invoke AI.

## Native Unlock Delivery

There are now two compatible approval paths:

1. The existing Flutter Firestore listener can apply the approved request when the Flutter engine is active.
2. The server side-effect helper sends a targeted FCM data payload containing the request ID/idempotency key, bound UID, package, outcome, and authoritative expiry. `AmnestyPushReceiver` receives the protected FCM action, and `NativeOverrideAccess` validates UID binding, package shape, expiry bound, and idempotency before persisting `temp_unlocks` in `RevokeConfig`. It then asks `AppMonitorCoordinator` to revive enforcement immediately.

The receiver is technically exported because it is the existing Firebase/Android FCM entry point, but its manifest requires `com.google.android.c2dm.permission.SEND`; no unrestricted app-generated approval receiver was added. Actual FCM delivery, reboot behavior, and OEM behavior still require device testing.

## Legacy Migration

- `SquadService`, `squads`, `pleas`, and the Tribunal route remain compatibility names and are not mass-renamed.
- `/squad` renders Circle; missing Tribunal routing also falls back to Circle rather than the old Squad screen.
- `SquadScreen` and old `Beg for Time` copy remain unreferenced legacy code after the route migration; they are retained for reference and should be removed only after a wider compatibility/reference review.
- Legacy Pleas remain readable under the existing compatibility paths. Historical events are not retroactively assigned granular permission intent.
- The old `createPlea` callable remains for legacy/admin callers, but the v2 callable does not use random system approval and Circle/AI authority is explicit.
- Admin/mock Tribunal and amnesty operations remain operational tools, protected by existing admin checks, and are not folded into user Override History.

## Deferred Work

- device-level proof of FCM approval while Flutter is stopped, service restart, reboot, and OEM battery restrictions;
- complete migration/backfill of all existing Circle member summaries and historical permission intent;
- shared Commitment progress, usage, recovery, slip, and future Credit visibility permissions;
- native/server Commitment persistence and immutable activation lease;
- Credit visibility, Premium, purchase, and billing infrastructure;
- richer Circle onboarding and granular override policies beyond current supported permissions;
- schedule revision/conflict protocol and complete remote taper hydration.

## Regression Review

- `flutter analyze --no-pub`: PASS — no issues found.
- `flutter test --no-pub`: PASS — 37 tests passed, including the new Circle model tests and all prior Phase 1–4 tests.
- `npm test` in `functions/`: PASS — 13 tests passed under Firebase CLI 15.26.0, Node v24.11.1, and the Firestore emulator. The emulator logged expected undefined-admin/property-denied diagnostics for negative rule cases. Firebase also reported the existing unrelated `flutter` property warning in `firebase.json`.
- `node --check functions/index.js`: PASS.
- `firestore.indexes.json` JSON parse: PASS.
- `git diff --check`: PASS; Git only reported the repository's existing LF/CRLF conversion warnings.
- `flutter build apk --debug`: PASS under Flutter 3.47.0/Dart 3.13.0 and JDK 26. Existing Gradle 8.14, AGP 8.11.1, and Kotlin 2.2.20 support warnings remain. No dependency changes were made.
- No separate physical-device FCM, OEM, or native integration test was available in this repository run.

## Implementation conclusion

Phase 5 establishes a real optional Circle surface, server-enforced least-privilege projections, per-Commitment authority, fixed Circle quorum, deliberate offline Self access, and a protected native FCM delivery path. It does not claim a complete native Commitment domain or production-proven cross-process/device delivery. The next commercial phase may build on this boundary only after the deferred device and authority checks are proven.
