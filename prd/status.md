# Revoke Project Status

Last updated: Apr 4, 2026

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
- [x] 🩺 Android watchdog + self-healing reliability path (WorkManager periodic watchdog, boot enqueue, app-start enqueue, Flutter revive bridge)
- [x] 🔒 Same-squad Firestore visibility rules + emulator verification (`/users`, `/regimes`, `/rapSheet`, `/pleas`)
- [x] 🧾 Rap Sheet snapshot denormalization (`/users/{uid}/rapSheet/latest` + last-5 safe infractions)
- [x] 🧪 Multi-block validator QA coverage (overlap, min-duration, cross-midnight, fragmented blocks, deterministic tests)
- [x] ⏱️ Session-scoped usage tracking (`UsageStatsManager.queryEvents`) + dashboard remaining-time UI
- [x] ⚡ Zero-latency regime enforcement on save/sync (immediate foreground evaluation + tight 2s reset)
- [x] 🧱 Time Block / Usage Limit native decoupling fix (strict branching + service-survival error boundaries)
- [x] 🔁 Approved-plea replay guard (prevents stale approved pleas from reapplying temp unlocks on app boot)
- [x] 🪪 Permissions/onboarding UX hardening (small-screen overflow fixes, pinned CTA, staged permission progress)
- [x] 🛑 Blocker overlay branding refresh (native “Cooked” HUD now uses Revoke logo + stacked wordmark)
- [x] 🧠 Hybrid enforcement architecture pass (`EnforcementEngine` shared between `AppMonitorService` and `RevokeAccessibilityService`)
- [x] ♿ Accessibility fast path + adaptive polling fallback (event-driven detection with lighter service backstop when Accessibility is enabled)
- [x] 📣 Google Play accessibility disclosure gate + settings bridge (dedicated onboarding step with resume-state auto-advance)
- [x] 🏠 Anti-flash blocker sequence (`GLOBAL_ACTION_HOME` before native blocker overlay renders)
- [x] 🎭 Native cooked-screen consolidation + redesign (single live blocker UI in `BlockerOverlayController`, state-aware presentation model, no-squad CTA path, full-screen overlay polish)

## In Progress
- [ ] 🛡️ Solo fallback abuse limits + telemetry (caps, cooldowns, and logs for safety/observability)
- [ ] ✅ Device-side enforcement QA (watchdog revive, exact on-device block timing, Crashlytics verification)
- [ ] ✅ Edge-case test coverage (uninstall/reinstall behavior, stale approvals, no-squad and no-voter plea handling)
- [ ] 🔒 Separate `:enforcement` process evaluation after native state moves off single-process `SharedPreferences`
- [ ] 🧪 Optional Shizuku hard mode / Device Admin spike only if product + policy review green-light it
- [ ] Website Blocker Flow Consolidation (skipped for now)
- [ ] Production Hardening Pass (skipped for now)

## Execution Notes (Condensed)
- `Website Blocker Flow Consolidation` remains pending because no website-blocker entry points currently exist in repo code.
- `Production Hardening Pass` is partially complete: debug prints removed in key Flutter paths, Firestore indexes expanded in `firestore.indexes.json`, rules emulator tests added in `functions/test/firestore.rules.test.js`, and Firebase emulator execution now works locally with a modern JDK.
- Multi-block rollout shipped: schema supports `blocks[]` + `emoji` with backward compatibility; create/edit supports multi-block schedules; home card actions include tribunal break/delete; approved break pleas pause monitoring; approved delete pleas remove regimes; native Android enforcement now handles multi-window schedules with legacy fallback and usage-limit custom windows.
- Create regime UX refresh shipped: step order is `Select blocking type` -> `Set conditions` -> `Regime details`; top chips removed; time-block editor moved to pill-based rows; usage limit uses inline `CupertinoTimerPicker` + optional `All day long`; details page order and condition summary were clarified; target-app selection display is icon-only; updated surfaces use Phosphor icons.
- Home UX refresh shipped: regime cards were redesigned for clearer scanability, hierarchy, and actions.
- Stability fixes shipped: usage-limit edit assertion fixed via timer interval normalization; tribunal delete flow made idempotent and safer around resolved pleas/admin overrides; verdict UX now uses explicit `Close` and includes accept/reject tally with voter names/photos; tribunal chat rebuild conflicts reduced; app root/auth lifecycle hardened to keep global dependencies stable; onboarding redirect guard fixed to prevent init-screen hang.
- Android background reliability shipped: foreground-service starts now fail safely (non-fatal) under Android 12+ start restrictions, and Amnesty background handling now has a native receiver path that does not depend on a live Flutter engine/method-channel attachment.
- Launch readiness sprint shipped: AppMonitor watchdog worker, same-squad Firestore rules, rap-sheet snapshot builder, and emulator-backed backend verification are in place; remaining validation is primarily device-side QA.
- Enforcement hardening shipped: native schedule sync now performs immediate foreground evaluation, usage-limit math is session-scoped from `activatedAt`, and Time Blocks are decoupled from usage-limit `queryEvents` logic with safe non-fatal error boundaries.
- Replay/permission polish shipped: stale approved pleas no longer reapply temp unlocks on startup, onboarding/permissions flows were rebuilt for small screens, and the blocker overlay HUD now uses branded Revoke visuals.
- Curbox-derived hardening shipped: Revoke is now hybrid rather than polling-only, with a shared `EnforcementEngine`, an Accessibility fast path, adaptive fallback polling, a Play-compliant Accessibility disclosure step, and an anti-flash HOME-before-overlay sequence.
- Blocker overlay redesign shipped: legacy cooked-screen leftovers were retired, the live blocker is now a single native full-screen UI driven by `BlockPresentation`, overlay dismissal/re-show behavior was stabilized, and the blocker now supports state-aware copy, compact stats, and a no-squad recovery CTA.
- Uninstalled-app UX hardening shipped: missing target packages now render as ghost apps with explicit “Restriction remains active” messaging instead of broken/missing UI.
- Solo tribunal handling shipped: pleas with zero eligible voters are now auto-resolved by `SYSTEM_WARDEN` with immediate verdict + system message, preventing stuck active pleas.
- Uninstall/reinstall anti-cheat hardening shipped: Android now listens for package removals and immediately clears stale temporary approvals from `SharedPreferences` and running monitor state; temp approvals returned to Flutter are now install-aware.
- Regime editor hardening shipped: ghost apps in regime details now show explicit replace/remove actions so users can repair stale target packages without deleting the entire regime.
- Tribunal no-squad guardrail shipped: `createPlea` now returns explicit reason-code details for no-squad failures, and client flows show a targeted “Open Squad” recovery action instead of generic errors.
- QA progress: schedule migration/validation unit tests are in place, `test/core/utils/schedule_block_validator_test.dart` now passes expanded edge-case coverage (13 tests), and backend emulator tests for rules + rap-sheet snapshot pass locally (8 tests).

## Implementation Plan (Remaining)
1. **✅ Device-side enforcement QA**
   - Verify watchdog revival on-device after force-stopping/killing the monitor service.
   - Verify immediate block timing for current-time Time Blocks and limit-reached Usage Limits.
   - Verify Crashlytics non-fatal payloads for native service/watchdog failures.

2. **🧪 Remaining edge-case QA**
   - Add widget/integration checks for block editor interactions, timeline overlays, and home regime card actions.
   - Validate timezone and DST transitions plus uninstall/reinstall/stale-approval edge cases.

3. **🔒 Deferred Curbox-inspired native hardening**
   - Revisit a separate `:enforcement` process only after native persistence is migrated away from single-process `SharedPreferences`.
   - Decide whether Shizuku hard mode or Device Admin is worth the policy/product cost.

4. **Website Blocker Flow Consolidation** (Skipped for now)
   - Pick single entry-point architecture for website restriction state changes.
   - Remove duplicate triggers/handlers and route all paths through one coordinator.

5. **Production Hardening Pass** (Skipped for now)
   - Expand emulator coverage and release verification pass.

## Suggested Execution Order
1. ✅ Device-side enforcement QA
2. 🧪 Remaining edge-case QA
3. 🔒 Deferred Curbox-inspired native hardening
4. Website Blocker Flow Consolidation (when unskipped)
5. Production Hardening Pass (when unskipped)

## Next Steps (Aligned to PRD)
- [ ] Challenges pillar implementation beyond placeholder
- [ ] Notifications + Analytics pages (currently placeholders) and real dashboards
- [ ] Focus Score: make stats fully source-backed and document data sources in detail UX
- [ ] OEM reliability hardening beyond current watchdog pass (manufacturer-specific guidance + stronger service-running UX)
- [ ] Evaluate separate-process enforcement only after native state storage is multi-process safe
- [ ] Decide whether Shizuku hard mode or Device Admin belongs in product scope at all
- [ ] iOS strategy decision (scaffold only vs enforcement parity plan)

## Backlog
- [ ] Vandalism Feature (Wallpaper penalties)
- [ ] Simp Protocol (Friction-based unlocking)
- [ ] Squad leaderboard and social ranking layer
- [ ] AI Vibe Rater
