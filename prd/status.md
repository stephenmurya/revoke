# Revoke Project Status

Last updated: Feb 15, 2026

Source of truth: repository implementation + PRD (`prd/prd.md`).

## Completed
- [x] Project Foundation & Permissions (Usage Stats, Overlay, Battery Optimization gate)
- [x] Design System (Black/Orange base palette + centralized theme system)
- [x] Android Enforcement Layer
- [x] Kotlin Foreground Service (Usage monitoring + adaptive polling)
- [x] Overlay Triggering (Broadcast + MethodChannel bridge)
- [x] Boot Persistence (BOOT_COMPLETED receiver + restart strategy)
- [x] Native Persistence (SharedPreferences storage for service restarts)
- [x] App Discovery (Installed app fetch + icons + categorization)
- [x] Local Persistence (Restricted apps in SharedPreferences)
- [x] Regime (Schedule) Engine (Time blocks + usage limits)
- [x] Local-first Regime Save + Background Cloud Sync
- [x] Account-tied Regime Storage (per-user local key + cloud `/users/{uid}/regimes`)
- [x] Native Schedule Sync (active regimes synced to Kotlin service)
- [x] Home (Monitor) Dashboard (Focus Score + currently restricted + active regimes)
- [x] Focus Score System (card + detail page)
- [x] Core Navigation Shell (3 primary pillars: Home/Monitor, Squad, Challenges)
- [x] Personal HUD Header (brand cluster + notifications/analytics + avatar -> controls)
- [x] Challenges Pillar (placeholder screen + route + legacy alias)
- [x] Firebase Auth (Google Sign-In) + token refresh sync for FCM
- [x] Smart Onboarding Resume (squad/profile-based redirect flow)
- [x] Squad Data Layer (User & Squad models + create/join)
- [x] Plea/Tribunal System (server-authoritative callables + triggers + scheduled jobs)
- [x] Tribunal UX (chat, vote UI, live banner entry, verdict lifecycle)
- [x] Anti-spam + Abuse Controls (plea/message throttles in callable layer)
- [x] Firestore Rules Hardening (server-only plea mutation, callable-authoritative messaging)
- [x] Outcome Enforcement (approved pleas trigger native temporary unlock)
- [x] Admin Flow Consolidation (GodModeDashboard + mock tribunal tools)
- [x] Squad Logs Data Layer
- [x] Cloud Functions: automatic squad log writes on plea creation + verdict resolution
- [x] Cloud Functions: `updateUserStatus` callable writes `users/{uid}.currentStatus`
- [x] Firestore Rules: server-written `squads/{squadId}/logs` (read-only for squad members)
- [x] Squad HUD 2.0 ("The Barracks")
- [x] Pillory hero (lowest-scoring member highlight)
- [x] Roster strip with status rings + score pill
- [x] Squad log feed (timeline UI; reactions stubbed)
- [x] Member Rap Sheet sheet (protocols, blacklist summary, plea stats)

## In Progress
- [ ] Onboarding Final Polish (copy tuning + micro-interactions)
- [ ] Website Blocker Flow Consolidation (single-source behavior + eliminate duplicate entry points)
- [ ] Squad Log Reactions (implement callable-backed "salute" reactions, not stub)
- [ ] Member Rap Sheet correctness hardening (secure cross-user regime visibility; see Next Steps)
- [ ] Production Hardening Pass (remove debug prints, add index docs, emulator tests)
- [ ] Option A Vote Subcollection Migration (PRD milestone: votes as subcollection)

## Next Steps (Aligned to PRD)
- [ ] Firestore rules + data model for cross-user regime visibility
- [ ] Build a safe member snapshot for Rap Sheet
- [ ] Challenges pillar implementation beyond placeholder
- [ ] Notifications + Analytics pages (currently placeholders) and real dashboards
- [ ] OEM reliability hardening (WorkManager fallback + stronger "service running" UX)
- [ ] iOS strategy decision (scaffold only vs enforcement parity plan)

## Backlog
- [ ] Vandalism Feature (Wallpaper penalties)
- [ ] Simp Protocol (Friction-based unlocking)
- [ ] Squad leaderboard and social ranking layer
- [ ] AI Vibe Rater
