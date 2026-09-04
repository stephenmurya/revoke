# Schedule and Categorization Audit

## SCHEDULE DATA MODEL
- **Fields:** `id`, `name`, `type`, `targetApps` (List of package strings), `days` (List of ints 1-7 for Mon-Sun), `blocks` (List of `ScheduleBlock`), `durationLimit` (Duration), `isActive`, `emoji`, `activatedAt`.
- **Types:** Defined in `ScheduleType` enum: `timeBlock`, `usageLimit`, `launchCount`.
- **ScheduleBlock:** Represents a time window using `startTime` and `endTime` (both `TimeOfDay`), and includes logic for midnight-crossing duration.

## SCHEDULE CREATION FLOW
- **UI Flow:** User interacts with `CreateScheduleScreen` (Regimes). They select target apps (using `AppDiscoveryService` and `app_selection_screen.dart`), set days, and define time blocks.
- **Saving:** The schedule is converted to JSON and stored locally via `SharedPreferences` in `ScheduleService.saveSchedule`.
- **Cloud Sync:** Background sync is initiated via `RegimeService.saveRegime`, which pushes the data to Firebase Firestore. A pending queue handles offline scenarios (`_pendingUpsertsPrefix`).
- **Native Sync:** The JSON is forwarded to Android via `NativeBridge.syncSchedules`.

## SCHEDULE ENFORCEMENT
- **Engine:** Evaluated natively in Kotlin via `EnforcementEngine.kt`.
- **Evaluation Loop:** Native layer loops through cached schedules.
  - For `timeBlock` (type 0): Blocks access if the current time in minutes falls within any of the defined `TimeWindow`s.
  - For `usageLimit` (type 1): Reads usage data via `UsageEventsSessionCalculator`. Blocks if usage exceeds `limitMinutes`. If windows are defined, the app is blocked *outside* those windows (`WINDOW_CLOSED` state).
- **Breaks/Windows:** Time blocks are strictly enforced. Bounded unlocks (pleas/temp unlocks) are handled as exceptions that bypass the schedule loop (`isPackageTemporarilyUnlocked`).

## APP CATEGORIZATION
- **Location:** `lib/core/utils/app_categorizer.dart`.
- **Categories:** 16 defined in `AppCategory` (Social, Games, Entertainment, Education, Health, Productivity, News, Shopping, Travel, Utilities, Finance, Communication, Business, Books, Food, Others).
- **Assignment Logic:**
  1. **Exact Package Overrides:** Hardcoded map of popular apps (e.g., `com.instagram.android` -> Social).
  2. **Native Category Mapping:** Maps Android's native `ApplicationInfo.category` (e.g., `CATEGORY_GAME` -> Games).
  3. **Keyword Heuristic Fallback:** Checks if the package name string `.contains()` specific keywords (e.g., "chat", "pay").
- **Reliability:** Moderately reliable for popular apps, but fragile for long-tail apps. The keyword heuristic is naive and prone to false positives (e.g., an app named `com.tax.payment` would hit the keyword "pay" and become Finance, which is fine, but `com.game.companion` might become Games even if it's a utility).

## GAPS AND LIMITATIONS
1. **Ignored Launch Count Schedules:** The `ScheduleModel` allows creating `launchCount` schedules (Type 2), but `EnforcementEngine.kt` explicitly ignores them (`else -> null`). They are completely unenforced.
2. **Missing Conflict Resolution:** `ScheduleService` blindly overwrites Firestore schedules with local state. If schedules are generated programmatically (e.g., by an AI), local clients might overwrite them if they sync from a stale cache.
3. **Time Zone Assumptions:** The data model relies on `TimeOfDay` (hours/minutes in local time) without timezone data, which could break or enforce at the wrong times if the user crosses time zones.
