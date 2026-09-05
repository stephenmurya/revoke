# Insights

Status: Phase 9 implementation is complete for direct native usage evidence, the Free/Premium range boundary, active Reduce analysis, and recorded override analysis. Verified Commitment outcome history, universal adherence, recovery, grace, and adaptive pattern analysis remain deferred until their authoritative data exists.

## Product purpose

Insights explains how usage is changing, which apps consume time, whether active Reduce plans are changing behavior, and where recorded override requests occur. It does not present Focus Score or another composite score.

## Supported ranges

- Free: the latest 7 complete local-calendar days.
- Premium: the latest 7 or 30 complete local-calendar days.
- 90 days: not currently supported by the native retention/aggregation contract and not exposed.

The range is calculated from Android UsageStats/UsageEvents through `UsageInsightsCalculator`. A period is labeled complete because it ends on the previous local day; no current partial day is presented as a complete historical day.

## Metric definitions

### Average daily usage

`total tracked usage in the selected period / selected period length`.

Usage is the sum of clipped foreground sessions returned by native UsageEvents. The current native source treats each calendar day in a permitted historical range as an observed day; `observedDays` reports the non-future buckets returned by that source.

### Period comparison

The comparison is the selected period's average daily usage minus the immediately preceding equal-length period. The UI shows it only when the native source has usage sessions in the preceding period. It is descriptive, not a financial gain/loss signal and not a behavioral score.

### Where your time went

Top applications are ranked by summed foreground-session duration in the selected period. Revoke/system/launcher packages and whitelisted packages are excluded by the native calculator. App names come from the existing installed-app cache; an unavailable package falls back to a readable package label and icon.

### Reduce analysis

For each of up to five active local taper plans, native usage is aggregated across the plan's target packages. Baseline and final goal come from `TaperPlanModel`; current allowance comes from `limitFor(now)`; current use is the selected-period average for those packages. Planned chart points come from the actual taper plan for each returned bucket date. This does not claim adherence or prove that a user kept each allowance.

### Recorded override analysis

Premium override analysis counts the current user's recorded `pleas` documents whose `createdAt` falls inside the selected complete period. It reports request count, approved/not-approved counts, approved temporary-access minutes, and the recorded authority breakdown. It excludes local pending history that has not synchronized and does not judge an override as good or bad.

## Sections and entitlement

The primary Insights story is:

`period -> usage overview -> daily usage trend -> where your time went -> Premium Reduce analysis -> recorded override behavior`.

Free users see the usage overview, comparison when reliable, daily trend, and top apps for 7 days. They then see one restrained Premium preview. Premium users can select 30 days and receive active Reduce and recorded override sections when those sources contain data.

## Intentionally deferred

The current repository does not provide reliable general checkpoint history for universal adherence, verified outcome history for all Commitments, ordered failure/success pairs for recovery, grace usage history, per-Commitment Protect violations, or trustworthy hourly/daypart patterns. These are omitted rather than inferred. A future danger-period experience must not be inferred from this implementation.

## Focus Score retirement

Focus Score is absent from `/insights` and the Appearance preview. Legacy score storage, admin surfaces, legacy Home compatibility code, and `/focus-score` remain only where existing compatibility paths still reference them. Historical score data is not deleted by the Insights migration.

## Data ownership

Native UsageStats/UsageEvents owns usage duration and buckets. `TaperPlanModel` owns Reduce allowance. `CircleService` owns the server-backed recorded override history. `PremiumEntitlementService` owns entitlement state. No shared analytics backend or new server schema is introduced in Phase 9.
