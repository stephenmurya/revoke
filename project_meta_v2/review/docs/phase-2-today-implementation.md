# Revoke 2.0 Phase 2 Today Implementation Review

Review date: 2026-09-04

Phase 2 replaces the legacy Home presentation at `/home` with a dedicated Today surface. It does not redesign or remove the Commitments management flow, Circle, Insights, Premium, Credits, or native enforcement UI.

## Phase 2 Change Summary

### Source files created

- `lib/features/today/today_screen.dart`: stateful Today loader, schedule-backed state selection, monitoring treatment, primary Commitment panel, protection list, weekly usage summary, empty state, and taper presentation.
- `test/features/today/today_screen_test.dart`: coverage for empty, usage-limit, protected-period, monitoring-degradation, taper, and Focus Score-absence states.

### Source files modified

- `lib/core/app_router.dart`: `/home` now builds `TodayScreen`; `/commitments` remains the existing `RegimesScreen` management destination.

### Documentation files modified

- `product/metrics.md`: Today metric boundary and truthful proxy policy.
- `design/information-architecture.md`: Phase 2 Today implementation status.
- `engineering/status.md`: current Today implementation and known boundary.
- review packet index, change summary, decision matrix, consistency review, quality checklist, and Phase 1 review status.

No `old_project_meta/`, Kotlin, Firebase, Firestore rules, Cloud Functions, dependency, asset, or native blocker file was modified.

## Today Information Hierarchy

The implemented vertical order is:

1. daily state (`Today`, concise state title, restrained explanation);
2. monitoring-health warning only when required setup is missing;
3. primary schedule-backed Commitment-equivalent behavior;
4. active Protect/time-block rows;
5. direct week usage evidence;
6. other active Commitment-equivalent rows.

The empty state has one clear action, `Create a Commitment`, routed to the existing `/regime/new` flow. Today rows route to `/commitments` for management rather than exposing edit/delete controls inline.

## Data Provenance

| UI element | Actual source | Boundary |
|---|---|---|
| Daily state | `TodayViewData` derived from current local schedules, permission flags, and usage status | No inferred behavioral intelligence |
| Primary behavior | `ScheduleModel` from `ScheduleService.watchSchedules()` | Legacy schedule is the current Commitment-equivalent primitive |
| Usage used/remaining | `NativeBridge.getSessionUsage()` backed by `UsageEventsSessionCalculator.effectiveDailyStartMs()` | Existing native daily usage-limit path; not a new ledger or backend metric |
| Usage progress | `TodayUsageStatus` calculated from native used milliseconds and `ScheduleModel.durationLimit` | Missing Usage Access and pending activation are shown as non-measured states |
| Protection active/next | `ScheduleModel.blocks` plus `ScheduleBlockValidator.isMinuteWithinBlocks()` | Time-block schedule timing only |
| Taper day/allowance/progress | `TaperPlanService.getActivePlan()` and `TaperPlanModel` | Existing local plan; remote hydration limitations remain |
| Week summary | `UsageInsightsService.refresh(mode: 'week')`, native `UsageInsightsCalculator`, and `UsageInsightsSnapshot` | Shows average daily use and recorded days, not adherence |
| Monitoring health | `NativeBridge.checkPermissions()` | Accessibility, Usage Access, Overlay, and Exact Alarm flags |
| Temporary access | `NativeBridge.getTemporaryApprovedPackages()` | Shows active indication only; no unsupported remaining-time claim |
| Available Credits | Phase 1 app-bar `RevokeCreditsPill` | Remains zero placeholder; Today adds no wallet data |

## Primary-item selection

`TodayViewData.primarySchedule()` ranks active schedule-backed items as follows:

1. scheduled-today usage limits already reached;
2. scheduled-today usage limits near their boundary (15 minutes or less remaining, or at least 75% consumed);
3. currently active time protection;
4. other scheduled-today active items, including taper-backed schedules;
5. active items scheduled for another day.

Ties are stable alphabetical ordering by schedule name. A time block is a protected state, not a failure state; only a reached usage limit receives destructive emphasis.

## Focus Score Migration

`FocusScoreCard` is no longer imported or rendered by Today. No replacement composite score was introduced. The legacy `/focus-score` route, `FocusScoreDetailScreen`, local score storage, and related historical services remain for compatibility and are recorded as deferred cleanup. The existing Insights and Appearance legacy surfaces were not broadly redesigned in this phase.

## Taper presentation

An active taper-backed schedule is presented in the primary Commitment panel with day-of-plan, current daily allowance, target allowance, and a restrained progress bar. If native usage data is available for its materialized schedule, the panel also shows used/remaining usage. The taper calculation and materialization engine were not changed.

## Monitoring and temporary approvals

Missing required native permissions produce a contextual warning surface with the missing permission names and a `Fix setup` action. Healthy setup produces no persistent warning. An approved temporary package is shown as `Temporary access active`; because the current bridge exposes package membership but not remaining duration, Today does not invent a countdown.

## Performance / Lifecycle Review

- The schedule stream is created once in `initState`, not in `build`.
- The `TodayScreen` State owns the scrollable body, so normal schedule/usage updates do not replace the page or reset scroll position.
- A generation guard prevents stale concurrent native usage responses from overwriting newer state.
- The one-minute timer refreshes usage status only; it does not toggle loading or remount Today.
- Permission and temporary-access polling update only when their visible values change.
- The weekly summary uses the existing native usage-insights bridge and does not add Firestore listeners.
- Taper loading uses the existing local-first service, whose background cloud sync behavior is unchanged.

## Deferred Today Data

The following are intentionally omitted because current code cannot establish them as v2 metrics without a domain/backend change:

- weekly Commitment adherence and eligible checkpoint counts;
- verified success/failure/unverifiable outcome counts;
- override counts and approval/denial history;
- recovery and slip measures;
- grace remaining and consumption;
- Credit lock or Credit-backed Commitment state;
- category-level or danger-period intelligence.

## Regression Review

- `flutter analyze`: PASS - no issues found.
- `flutter test test/features/today/today_screen_test.dart`: PASS - 5 tests passed.
- Existing core schedule/model/validator tests: pass during the full suite run.
- Full `flutter test`: the known pre-existing `test/widget_test.dart` fails because it mounts `RevokeApp` without Firebase initialization and asserts obsolete counter UI. No test was deleted or changed.
- `flutter build apk --debug`: PASS - `build/app/outputs/flutter-apk/app-debug.apk` built after the Phase 2 source changes under Flutter 3.47.0/Dart 3.13.0 with the existing Android toolchain. Existing Gradle/AGP/Kotlin deprecation warnings remain.

## Deferred Feature Work

Commitments management remains the legacy Regimes/schedule UI. Circle, Insights, native blocker visuals, real Credits, Premium, and the v2 Commitment backend remain outside this phase. The remaining legacy Home widgets are retained where they still support schedule management or compatibility routes; `FocusScoreCard` is now unused by Today and should be removed only after reference cleanup confirms no compatibility need.
