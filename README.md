# Revoke
Revoke is a squad-governed discipline app that makes screen-time boundaries enforceable and socially visible.

It pairs a hard Android enforcement layer (foreground monitoring + overlay lock) with a server-authoritative social governance layer (Squads + Tribunals) so willpower is no longer the single point of failure.

Primary platform: Android. iOS scaffolding exists, but enforcement is Android-only.

## What You Can Do Today
- **Enforcement**
  - Android Kotlin **foreground service** monitors foreground apps and triggers a **hard-lock overlay** when restricted apps are launched during an active regime window.
  - Permission-gated reliability: Usage Stats, Overlay permission, and Battery Optimization exemption.
  - Boot persistence: restart-on-boot and best-effort restart strategies.
- **Regimes (Protocols)**
  - Create regimes as time blocks or usage limits, pick target apps, choose active days, and toggle on/off.
  - **Local-first save**: regimes persist instantly on-device, are activated immediately after creation, and sync to Firebase in the background.
  - **Account-tied storage**: regimes are scoped per-user locally and cloud-synced to `/users/{uid}/regimes`.
  - Native enforcement consumes active regimes via a MethodChannel schedule sync.
- **Focus Score**
  - Animated Focus Score card, rank titles, and a dedicated explainer/details screen.
  - Score is surfaced throughout the app (0-1000 scale).
- **Squads**
  - Create/join squads via code, share squad code, and monitor member state.
  - **Squad HUD 2.0 ("The Barracks")**
    - **The Pillory**: highlights the lowest-scoring member (with harsher treatment when critically low).
    - **Roster Strip**: status rings (`locked_in`, `vulnerable`, `idle`) + focus score pill per member.
    - **Squad Log**: dense timeline feed of audit events.
    - Member drilldown: tap a roster member to open their **Rap Sheet** (protocols, blacklist summary, plea stats).
- **Tribunals (Plea Sessions)**
  - Server-authoritative plea lifecycle via Cloud Functions callables.
  - Squad notification fanout via FCM.
  - Attendance-based voting model (`participants` excluding requester are eligible voters).
  - Verdict resolution, timeouts, cleanup, and guardrails are enforced server-side.
  - Approved pleas trigger temporary unlocks via the native bridge.
- **Admin ("God Mode")**
  - Admin dashboard (claim-gated) for tribunal simulation and privileged operations.
  - Mock tribunal creation/destruction tools for testing the full lifecycle.

## Backend + Security Model
- Firebase Auth (Google Sign-In).
- Firestore data model:
  - `/users/{uid}` profiles, focus score, squad fields, status fields.
  - `/users/{uid}/regimes/{regimeId}` regime definitions.
  - `/squads/{squadId}` squad membership.
  - `/squads/{squadId}/logs/{logId}` server-written squad audit trail.
  - `/pleas/{pleaId}` + `/pleas/{pleaId}/messages/{messageId}` tribunal sessions.
- Cloud Functions (Node.js 22):
  - Callables for plea creation/voting/joining/messaging, user status updates.
  - Triggers for verdict resolution and push notification fanout.
  - Scheduled tasks for stale session finalization and data cleanup.
- Rules: client writes to pleas are blocked; messaging is callable-authoritative; squad logs are server-written.

## UX Direction
Revoke is intentionally judgmental.
- Black/orange base palette with high-contrast “system” language.
- Dense, data-forward surfaces that make behavior visible.
- Tap-first interactions: drilldowns, copy actions, modal sheets, and fast navigation.

## Roadmap (Near-Term)
- Finish the **Challenges** pillar beyond the placeholder screen.
- Rap Sheet hardening:
  - secure access rules or server-derived member snapshots for cross-user regime visibility
  - implement reactions (“Salute”) as callable-backed writes
- Vote subcollection migration (optional PRD milestone) to simplify long-term integrity.
- Production hardening pass: remove debug prints, add index docs, emulator tests, and OEM reliability checks.
