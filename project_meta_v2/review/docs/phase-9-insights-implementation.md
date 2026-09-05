# Phase 9 Insights Implementation Review

Review date: 2026-09-05

## Information Hierarchy

`/insights` now renders one direct-evidence experience:

```text
Insights
  -> period selector
  -> Usage overview
  -> Daily usage trend
  -> Where your time went
  -> Reduce Commitments (Premium, when active plans exist)
  -> Override behavior (Premium, when recorded history is available)
  -> Premium preview (Free only)
```

The page uses one primary vertical story rather than the former Today/This Week/Trend dashboard. The app-detail route remains available and uses the same usage evidence boundary for a selected package.

## Free/Premium Matrix

| Capability | Free | Premium |
|---|---|---|
| Usage overview | Latest 7 complete days | Latest 7 or 30 complete days |
| Daily trend | Yes | Yes |
| Top applications | Yes | Yes |
| Previous-period comparison | When native source has reliable comparison data | When native source has reliable comparison data |
| Active Reduce analysis | No | Yes, when active local taper plans exist |
| Recorded override analysis | No | Yes, from current-user recorded history |
| Verified outcomes, universal adherence, recovery, grace, time-of-day patterns | Not shown | Not shown until authoritative history exists |

Premium is read through `PremiumEntitlementService`; no second entitlement system was added. A Free user sees the useful 7-day content first and one restrained Premium preview. The existing `/premium` paywall handles exploration.

## Data Provenance

| UI element | Source | Authority boundary |
|---|---|---|
| Total/average usage | `UsageInsightsCalculator` through `NativeBridge.getUsageInsights` | Android UsageStats/UsageEvents |
| Daily trend buckets | `UsageInsightsCalculator` | Android local usage evidence |
| Period comparison | Native current and preceding equal-length session aggregation | Native calculation; displayed only when preceding sessions exist |
| Recorded day count | Native non-future bucket count | Usage Access-backed local projection |
| Top applications | Native grouped foreground sessions, then `AppDiscoveryService.getApps` for names/icons | Native usage plus installed-app metadata |
| Reduce baseline/goal | `TaperPlanModel` | Existing local taper plan |
| Reduce current allowance | `TaperPlanModel.limitFor(date)` | Existing taper plan |
| Reduce actual use | One native package-set aggregation per bounded active plan | Android UsageStats/UsageEvents |
| Override behavior | `CircleService.watchOverrideHistory` and `pleas` documents | Server-backed recorded request history |
| Premium capability | `PremiumEntitlementService` | Server-verified entitlement projection |

The screen does not infer adherence from an active schedule, infer success from missing records, or treat missing outcome history as a zero.

## Metric Definitions

- Average daily usage is total clipped foreground session duration divided by the selected 7- or 30-day period.
- Period change is selected-period average minus the immediately preceding equal-length period. The UI suppresses the comparison when no preceding sessions are returned.
- Top apps are ranked by selected-period foreground duration after native exclusion of Revoke, system, launcher, and whitelisted packages.
- Reduce current use is the selected-period average over the plan's target package set. Baseline, allowance, target, and planned chart values come from the actual `TaperPlanModel`.
- Recorded override count is the number of current-user `pleas` records whose `createdAt` is in the selected complete period. Approved duration is summed only for approved records. These are recorded request patterns, not a moral score.
- Universal adherence is not implemented. The repository lacks a reliable general checkpoint denominator, so no adherence percentage is shown.

## Chart Architecture

No chart dependency was added. `UsageTrendChart` uses a small `CustomPainter` with semantic Revoke colors, restrained gridlines, a solid actual-use line, and an optional dashed planned-allowance line. It supplies a textual `Semantics` equivalent containing the period, recorded-day count, and average.

The native calculator now supports `periodDays` values of 7 and 30 for trend aggregation and accepts a package set for a grouped Reduce query. It does not alter enforcement decisions. The Flutter cache key includes the package set so grouped plan results cannot collide with the all-app overview.

## Reduce Analysis

Premium Reduce sections show each bounded active local taper plan, target apps, baseline, current selected-period use, current allowance, final goal, plan week, and actual-versus-planned trend. Planned values are calculated for each displayed bucket date from the plan, not hardcoded example numbers. Remote taper hydration remains incomplete, so only active local plans are included.

## Protect Analysis

No Protect adherence or violation section was added. Current schedule configuration can describe a rule, but it cannot by itself prove historical behavior. Protect app usage remains visible through the general top-app and app-detail evidence.

## Override Analysis

Premium users receive a bounded recorded-history summary when the existing `pleas` query is available: total requests, approved/not-approved counts, approved temporary-access minutes, and authority breakdown. No pie chart, judgment score, or unsynchronized local-history claim is shown. If the optional query fails, the usage overview remains available.

## Outcome Analysis

Verified Commitment outcomes are not shown in Phase 9. `CreditService.backingsStream` exposes only active `LOCKED`/`GRACE` backings and does not provide a complete historical outcome query. The implementation therefore does not fabricate succeeded, failed, or unverifiable counts and does not calculate adherence, recovery, or grace history.

## Pattern Analysis

Hourly/daypart, weekday, Danger Zone, and adaptive pattern analysis remain deferred. Existing native hourly support is not used as a behavioral prediction surface in this phase. No AI advice or automatic Commitment change was added.

## Focus Score Cleanup

The legacy Insights screen, its score-oriented presentation, and the Focus Score sections were removed from `/insights`. The Appearance preview now describes a 7-day Usage Insights view rather than Focus Score. `FocusScoreCard`, `FocusScoreDetailScreen`, `/focus-score`, score storage, admin tools, and legacy Home/Squad score references remain only where compatibility or internal/admin paths still reference them. Historical score data is not deleted.

## Query and Performance Review

- The primary page makes one native trend aggregation call and one installed-app metadata load.
- It does not create one listener or query per chart point or top-app row.
- Premium Reduce analysis is bounded to five active local taper plans, with one grouped native query per plan.
- Premium override history is one bounded Firestore stream read, consumed once; no per-row query is created.
- Insights refreshes on entry, period change, pull-to-refresh, and entitlement change. It does not poll every minute.
- Period changes preserve the stateful screen and show an inline refresh indicator rather than an empty-page remount.

The native query scans the selected period plus the existing one-day session lookback padding. Large-range 90-day analysis is not exposed.

## Test Review

Phase 9 added `test/core/usage_insights_model_test.dart` for comparison and recorded-day metadata. Existing Today, design-system, Commitment, onboarding, Premium, Circle, and Credit tests remain in the suite.

Validation after implementation:

- `flutter analyze` passes with no issues;
- targeted usage/Today tests pass;
- full `flutter test` passes: 50 tests;
- no backend query, Firestore rule, or Firebase Function source changed in Phase 9;
- Android debug compilation passes: `build/app/outputs/flutter-apk/app-debug.apk`;
- `git diff --check` passes with only repository line-ending warnings.

The Android build completed in 53.8 seconds using the existing Flutter/Gradle/Kotlin configuration. Flutter emitted its existing upgrade-availability warnings for Gradle, Android Gradle Plugin, and Kotlin; no dependency changes were made.

## Deferred Insights

- universal adherence and its checkpoint denominator;
- verified outcome history across Credit-backed Commitments;
- Protect violation history;
- ordered recovery sequences;
- grace usage history;
- 90-day range support;
- reliable hourly/daypart and weekday pattern confidence;
- adaptive Danger Zones, AI advice, and automatic Commitment changes;
- cross-device analytics synchronization.

## Scope Confirmation

Phase 9 is mobile-only. No browser, iOS, desktop, billing, Credit mechanics, Circle permission model, Commitment persistence model, enforcement decision, AI behavior, or native blocker redesign was added.
