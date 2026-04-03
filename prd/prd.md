# Project Revoke: Technical PRD (Re-baselined)

Version: 1.2 (Apr 2026)

Status: Active (Aligned to repository implementation)

Primary Platform: Android (iOS scaffolding exists; enforcement is Android-only)

Core Philosophy: Social accountability through friction and peer-governed access.

## 1. Executive Summary

Revoke is a discipline app with:

1. A hard enforcement layer on Android (Accessibility fast path + Usage Stats fallback + Overlay + Foreground Service + watchdog recovery).
2. A social governance layer (Squads + Tribunals) for temporary clearance.

When a blocked app is opened during an active regime, Revoke prefers an event-driven Accessibility path to detect the launch instantly, snap the user back Home, and paint the native blocker overlay. The foreground service remains as the resilient fallback and session-usage evaluator. Users can request temporary clearance via a Tribunal where squad members attend, chat, and vote. Verdict resolution is server-authoritative.

## 2. Current Technical Stack

- Flutter app (routing via `go_router`).
- Firebase: Auth, Firestore, Cloud Functions (Node.js 22), FCM.
- Native Android: Kotlin `AccessibilityService` fast path (`RevokeAccessibilityService`) + shared `EnforcementEngine` + foreground-service fallback (`AppMonitorService`) + `TYPE_APPLICATION_OVERLAY` blocker + WorkManager watchdog + MethodChannel bridge.
- State management: service-layer patterns (no Riverpod dependency in current implementation).

## 3. System Requirements (Current Baseline)

### 3.1 Android Enforcement

- Hybrid event-driven enforcement is the current baseline:
  - `RevokeAccessibilityService` listens for `TYPE_WINDOW_STATE_CHANGED` events and evaluates the visible package with near-zero latency.
  - `EnforcementEngine` is the shared Kotlin decision layer used by both the Accessibility service and `AppMonitorService`.
  - `AppMonitorService` remains the resilient backstop for OEM-kill scenarios, periodic reevaluation, usage-limit maintenance, and boot/app-start recovery.
- Anti-flash blocker path:
  - If the Accessibility fast path detects a blocked app, it immediately fires `GLOBAL_ACTION_HOME`.
  - Revoke then paints the full-screen native blocker overlay over Home so the target app does not visibly render first.
- Adaptive polling:
  - If Accessibility is enabled and healthy, aggressive foreground polling is suspended.
  - In fast-path mode, the fallback service drops to:
    - 15s right after a restricted detection
    - 5s when an active usage-limit regime or blocker overlay still needs maintenance
    - 12s otherwise
  - If Accessibility is unavailable, the service falls back to primary `UsageStatsManager` polling:
    - 2s during recent high-risk periods
    - 5s otherwise
- Boot persistence:
  - Service restarts on device boot (`BOOT_COMPLETED` receiver).
  - WorkManager watchdog (`AppMonitorWatchdogWorker`) re-enqueues on boot/app start and revives the monitor service if needed.
  - Best-effort restart strategy on service/task removal.
- Battery optimization:
  - App requires exemption from battery optimizations for reliability.
- Compliance/onboarding:
  - Accessibility permission is gated behind a dedicated prominent disclosure screen before users are sent to Android Accessibility Settings.
  - Flutter re-checks the Accessibility permission on resume and advances onboarding automatically once granted.

### 3.1.1 Regime Evaluation Rules

- Time Blocks and Usage Limits are strictly decoupled in native evaluation.
- Time Blocks:
  - only check whether the current local time falls inside one of the configured enforcement windows
  - never read `activatedAt`
  - never query `UsageStatsManager.queryEvents`
- Usage Limits:
  - require an `activatedAt` timestamp
  - calculate usage strictly from that activation point using `UsageStatsManager.queryEvents`
  - include the still-open-app edge case when no background event has fired yet
- Native evaluation is wrapped in non-fatal error boundaries so malformed regime payloads do not crash the enforcement service.

### 3.2 Regimes (Schedules)

- Users define regimes (time blocks and usage limits) and the apps affected.
- Multi-window schedules are supported via `blocks[]` with cross-midnight validation and native parity.
- Usage-limit regimes persist an `activatedAt` timestamp only while the limit session is active.
- Regimes are cloud-synced and survive reinstall/new devices:
  - `/users/{uid}/regimes/{regimeId}`
- Native enforcement consumes regimes via MethodChannel schedule sync.

### 3.3 Squads

- Users create/join a squad via a code.
- Squad HUD shows member list and active Tribunal entry points.

### 3.4 Tribunals (Plea Sessions)

Terminology:
- A "plea" document is a Tribunal session.
- Attendance = `participants` list (users who enter or act in the room).
- Eligible voters = `participants` excluding `userId` (the requester).

Flow:
1. Requester composes plea (app icon, time chips, reason).
2. Server creates `/pleas/{pleaId}` and notifies squad members via FCM.
3. Members enter Tribunal, chat, and cast votes.
4. Server finalizes verdict and updates plea status.
5. If approved, requester receives a temporary unlock for the requested package and duration (enforced by native service).

Quorum:
- Attendance-based quorum is the global model.
- Completion condition: all eligible voters in `participants` have cast a vote.
- Tie-breaker: tie resolves to `rejected`.
- Timeout: stale active pleas auto-finalize on the server (tie/incomplete defaults to reject).

## 4. Backend Architecture (Current)

### 4.1 Firestore Collections

`/users/{uid}`
- `uid`, `email`, `fullName`, `nickname`
- `squadId`, `squadCode`
- `focusScore`
- `fcmToken`

`/users/{uid}/regimes/{regimeId}`
- `name`, `apps`, `daysOfWeek`, `startTime`, `endTime`, `isEnabled`
- Compatibility fields used by native sync (e.g., `targetApps`, `days`, `startHour`, etc.)

`/squads/{squadId}`
- `squadCode`, `creatorId`, `memberIds`

`/pleas/{pleaId}`
- `userId` (requester), `userName`
- `squadId`
- `appName`, `packageName`
- `durationMinutes`, `reason`
- `status`: `active | approved | rejected`
- `participants`: array of uids
- `votes`: map `{ uid: accept|reject }`
- `voteCounts`: map `{ accept: number, reject: number }`
- `createdAt`, `resolvedAt`
- lifecycle metadata: `markedForDeletion`, `deletionMarkedAt`, `outcomeSource`, etc.

`/pleas/{pleaId}/messages/{messageId}`
- `senderId`, `senderName`, `text`, `timestamp`
- optional `isSystem`

`/limits/{uid}` (anti-spam)
- rolling timestamp arrays and cooldown state for plea creation and messages

### 4.2 Cloud Functions (Server Authority)

Callables:
- `createPlea`
- `castVote`
- `joinPleaSession`
- `sendPleaMessage`
- `markPleaForDeletion`

Firestore triggers:
- `broadcastPleaCreated` (FCM fanout)
- `resolvePleaVerdict` (verdict finalizer)

Schedulers:
- `autoFinalizeStalePleas`
- `cleanupPleaData`

### 4.3 Security Model (Rules + Authority)

- Plea documents are server-only mutable (clients cannot create/update/delete `/pleas/{pleaId}`).
- Chat messages are sent via callable; direct client writes are blocked.
- User doc reads are restricted to self or same-squad.
- Regimes are read/write for self (and admin).

## 5. Admin ("God Mode") Baseline

- Admin is controlled by Firebase custom claim `admin: true`.
- Admin dashboard exists as a dedicated screen.
- Admin can view global stats and perform privileged operations via callables/privileged writes.

## 6. Planned Migration Milestones

### 6.1 Reference-Driven Hardening Status (Curbox Audit)

- Implemented:
  - shared `EnforcementEngine` now owns blocking decisions for both the Accessibility fast path and the foreground-service fallback
  - `RevokeAccessibilityService` is live as the zero-latency fast path for app detection
  - adaptive polling is in place, so `AppMonitorService` backs off when Accessibility is healthy and resumes primary polling when it is not
  - the Google Play accessibility disclosure gate and settings bridge are live in onboarding
  - the anti-flash `GLOBAL_ACTION_HOME` blocker sequence is live before the native overlay appears
  - Revoke retained its stronger boot/watchdog architecture rather than regressing to an accessibility-only model
  - Revoke retained its session-scoped `queryEvents` usage-limit math instead of adopting Curbox's day-relative totals
  - Revoke retained the existing overlay-based blocker instead of switching to a background-launched blocker Activity
- Deferred:
  - a separate `:enforcement` process remains intentionally deferred because the current native persistence layer still depends on single-process `SharedPreferences`
  - any Shizuku-backed hard mode remains deferred behind flavor/flag and policy review
  - Device Admin / uninstall-prevention work remains deferred and is not part of the Play-baseline architecture

Legacy roadmap items retained below for backlog continuity:

P0:
- Optional migration to a vote subcollection model (Option A) for simpler integrity boundaries:
  - `/pleas/{pleaId}/votes/{uid}`
  - Aggregate counts and verdicts computed from vote docs.

P1:
- Stronger Android reliability on OEM-kill devices:
  - WorkManager fallback + stricter “service running” UX gate.

P2:
- Reintroduce / prioritize previously drafted features if desired:
  - Vandalism (wallpaper), Simp Protocol, MAD heartbeat, leaderboards.
