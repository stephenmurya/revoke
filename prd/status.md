# Revoke Project Status

Last updated: Feb 21, 2026

Source of truth: repository implementation + PRD (`prd/prd.md`).

## Completed
- [x] Project Foundation & Permissions (Usage Stats, Overlay, Battery Optimization gate)
- [x] Design System (Black/Orange base palette + centralized theme system)
- [x] Android Enforcement Layer + Kotlin Foreground Service
- [x] Overlay Triggering (Broadcast + MethodChannel bridge)
- [x] Boot Persistence + Native Persistence (SharedPreferences)
- [x] App Discovery (installed apps + icons + categorization)
- [x] Local-first Regime Save + Background Cloud Sync
- [x] Account-tied Regime Storage (`/users/{uid}/regimes`)
- [x] Native Schedule Sync (active regimes -> Kotlin service)
- [x] Home Dashboard (Focus Score + restricted apps + active regimes)
- [x] Focus Score System + detail/explainer UX
- [x] Core Navigation Shell (Home/Monitor, Squad, Challenges)
- [x] Controls Hub + Appearance + ThemeService wiring
- [x] Firebase Auth (Google Sign-In) + token refresh sync for FCM
- [x] Squad Data Layer + Smart Onboarding Resume
- [x] Plea/Tribunal System (server-authoritative callables + lifecycle)
- [x] Anti-spam + Abuse Controls + Firestore Rules Hardening
- [x] Outcome Enforcement (approved pleas trigger native unlock)
- [x] Squad HUD 2.0 + logs + reactions + rap sheet snapshot hardening
- [x] Focus Score stats integrity (native blocked-attempt telemetry + callable ingestion)
- [x] Option A Vote Subcollection Migration (dual-write/read + backfill callable)
- [x] 🧱 Multi-Block Regime data model + migration (single window -> multi-window `blocks[]`)
- [x] 😀 Regime emoji system (curated picker + default emoji for legacy regimes)
- [x] 🛡️ Regime block validation engine (no overlap, gap-allowed, min-duration, cross-midnight)
- [x] 🧭 Create Focus Schedule flow redesign (3-step: apps/emoji -> blocks -> timeline review)
- [x] ↔️ Block editor interactions (add/remove blocks, time pickers, drag-to-create, drag-to-adjust)
- [x] 📊 Usage-aware timeline chart (24h usage baseline + blocked/free overlays + empty state)
- [x] 💡 Smart scheduling assists (peak-hour snap, break suggestion, copy-to-weekdays)
- [x] 🪪 Home regime card redesign (centered emoji content + type icon + overlapped app icons)
- [x] 📋 Regime card action sheet + tribunal flows (`Block now`, `Beg for a break`, `Duplicate`, `Delete`)
- [x] 🚫 Remove regime on/off switch UX from primary home card path
- [x] 🤖 Native sync/enforcement parity for multi-block schedules (Flutter payload + Kotlin runtime parsing)
- [x] 🎨 Iconography consistency pass (migrated app UI from Material `Icons.*` to Phosphor icons)
- [x] 🧯 Android 12+ foreground-service start hardening (safe try/catch around background FGS starts with non-fatal logging)
- [x] 📨 Native Amnesty handling path (broadcast receiver + native FCM fallback + Flutter background bridge to native intent)
- [x] 👻 Ghost App protocol baseline (uninstalled blocked apps render gracefully in regime UI without dropping package restrictions)
- [x] 🤖 The Warden solo-tribunal flow (zero eligible voters auto-resolve immediately with system vote/message)
- [x] 📦 App uninstall reconciliation (native package-removal receiver now prunes stale temporary unlock state)
- [x] 🧹 Native amnesty/unlock cleanup hardening (uninstalled packages removed from `temp_unlocks` + stale approval UI filtered)
- [x] 📲 Regime target-app integrity UX (ghost apps in details/editor now support replace/remove actions)
- [x] 👥 Tribunal eligibility guardrails (explicit no-squad reason-code contract + client fallback UX path)

## In Progress
- [ ] 🧪 Multi-block QA + edge-case hardening (timezone/DST, fragmented schedules, regression coverage)
- [ ] 🛡️ Solo fallback abuse limits + telemetry (caps, cooldowns, and logs for safety/observability)
- [ ] ✅ Edge-case test coverage (uninstall/reinstall behavior, stale approvals, no-squad and no-voter plea handling)
- [ ] Website Blocker Flow Consolidation (skipped for now)
- [ ] Production Hardening Pass (skipped for now)

## Execution Notes (Condensed)
- `Website Blocker Flow Consolidation` remains pending because no website-blocker entry points currently exist in repo code.
- `Production Hardening Pass` is partially complete: debug prints removed in key Flutter paths, Firestore indexes expanded in `firestore.indexes.json`, and rules emulator tests added in `functions/test/firestore.rules.test.js`; local emulator execution is currently blocked by Java 21 requirement.
- Multi-block rollout shipped: schema supports `blocks[]` + `emoji` with backward compatibility; create/edit supports multi-block schedules; home card actions include tribunal break/delete; approved break pleas pause monitoring; approved delete pleas remove regimes; native Android enforcement now handles multi-window schedules with legacy fallback and usage-limit custom windows.
- Create regime UX refresh shipped: step order is `Select blocking type` -> `Set conditions` -> `Regime details`; top chips removed; time-block editor moved to pill-based rows; usage limit uses inline `CupertinoTimerPicker` + optional `All day long`; details page order and condition summary were clarified; target-app selection display is icon-only; updated surfaces use Phosphor icons.
- Home UX refresh shipped: regime cards were redesigned for clearer scanability, hierarchy, and actions.
- Stability fixes shipped: usage-limit edit assertion fixed via timer interval normalization; tribunal delete flow made idempotent and safer around resolved pleas/admin overrides; verdict UX now uses explicit `Close` and includes accept/reject tally with voter names/photos; tribunal chat rebuild conflicts reduced; app root/auth lifecycle hardened to keep global dependencies stable; onboarding redirect guard fixed to prevent init-screen hang.
- Android background reliability shipped: foreground-service starts now fail safely (non-fatal) under Android 12+ start restrictions, and Amnesty background handling now has a native receiver path that does not depend on a live Flutter engine/method-channel attachment.
- Uninstalled-app UX hardening shipped: missing target packages now render as ghost apps with explicit “Restriction remains active” messaging instead of broken/missing UI.
- Solo tribunal handling shipped: pleas with zero eligible voters are now auto-resolved by `SYSTEM_WARDEN` with immediate verdict + system message, preventing stuck active pleas.
- Uninstall/reinstall anti-cheat hardening shipped: Android now listens for package removals and immediately clears stale temporary approvals from `SharedPreferences` and running monitor state; temp approvals returned to Flutter are now install-aware.
- Regime editor hardening shipped: ghost apps in regime details now show explicit replace/remove actions so users can repair stale target packages without deleting the entire regime.
- Tribunal no-squad guardrail shipped: `createPlea` now returns explicit reason-code details for no-squad failures, and client flows show a targeted “Open Squad” recovery action instead of generic errors.
- QA progress: added schedule migration/validation unit tests in `test/core/models/schedule_model_test.dart` and `test/core/utils/schedule_block_validator_test.dart`; targeted run passed (10 tests).

## Implementation Plan (Remaining)
1. **🧪 Multi-block QA + edge-case hardening**
   - Add unit tests for interval overlap, min-duration, and cross-midnight behavior.
   - Add widget tests for block editor interactions, timeline overlays, and home regime card actions.
   - Add integration checks for migration, save/edit flows, break/delete tribunal requests, and native sync behavior.
   - Validate timezone and DST transitions plus highly fragmented schedules.

2. **Website Blocker Flow Consolidation** (Skipped for now)
   - Pick single entry-point architecture for website restriction state changes.
   - Remove duplicate triggers/handlers and route all paths through one coordinator.

3. **Production Hardening Pass** (Skipped for now)
   - Expand emulator coverage and release verification pass.

## Suggested Execution Order
1. 🧪 Multi-block QA + edge-case hardening
2. Website Blocker Flow Consolidation (when unskipped)
3. Production Hardening Pass (when unskipped)

## Next Steps (Aligned to PRD)
- [ ] Firestore rules + data model for cross-user regime visibility
- [ ] Build a safe member snapshot for Rap Sheet
- [ ] Challenges pillar implementation beyond placeholder
- [ ] Notifications + Analytics pages (currently placeholders) and real dashboards
- [ ] Focus Score: make stats fully source-backed and document data sources in detail UX
- [ ] OEM reliability hardening (WorkManager fallback + stronger service-running UX)
- [ ] iOS strategy decision (scaffold only vs enforcement parity plan)

## Backlog
- [ ] Vandalism Feature (Wallpaper penalties)
- [ ] Simp Protocol (Friction-based unlocking)
- [ ] Squad leaderboard and social ranking layer
- [ ] AI Vibe Rater
