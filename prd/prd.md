# Project Revoke: Technical PRD (Re-baselined)

Version: 1.1 (Feb 2026)

Status: Active (Aligned to repository implementation)

Primary Platform: Android (iOS scaffolding exists; enforcement is Android-only)

Core Philosophy: Social accountability through friction and peer-governed access.

## 1. Executive Summary

Revoke is a discipline app with:

1. A hard enforcement layer on Android (Usage Stats + Overlay + Foreground Service).
2. A social governance layer (Squads + Tribunals) for temporary clearance.

When a blocked app is opened during an active regime, a native overlay blocks access. Users can request temporary clearance via a Tribunal where squad members attend, chat, and vote. Verdict resolution is server-authoritative.

## 2. Current Technical Stack

- Flutter app (routing via `go_router`).
- Firebase: Auth, Firestore, Cloud Functions (Node.js 22), FCM.
- Native Android: Kotlin foreground service (`AppMonitorService`) + overlay + MethodChannel bridge.
- State management: service-layer patterns (no Riverpod dependency in current implementation).

## 3. System Requirements (Current Baseline)

### 3.1 Android Enforcement

- Foreground service monitors foreground apps using `UsageStatsManager` and blocks restricted apps using an overlay.
- Adaptive polling:
  - 2s in high-risk situations (restricted app detected / immediately after a block).
  - 5s during an active schedule window.
  - 9s otherwise.
  - 10s and skip enforcement when screen is off.
- Boot persistence:
  - Service restarts on device boot (`BOOT_COMPLETED` receiver).
  - Best-effort restart strategy on service/task removal.
- Battery optimization:
  - App requires exemption from battery optimizations for reliability.

### 3.2 Regimes (Schedules)

- Users define regimes (time blocks and usage limits) and the apps affected.
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

