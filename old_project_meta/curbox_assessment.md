I audited `C:\Users\USER\Documents\dev\curbox` against Revoke’s Android enforcement layer only.

**Baseline**
Curbox is a pure native Android app: Kotlin + XML + DataStore/Room/Material, not Flutter or React Native, per [app/build.gradle.kts](/c:/Users/USER/Documents/dev/curbox/app/build.gradle.kts#L1). Its README explicitly says it “relies exclusively on accessibility services” and the manifest backs that up with two `AccessibilityService`s: `AppBlockerService` and `UsageTrackingService` in [Readme.md](/c:/Users/USER/Documents/dev/curbox/Readme.md#L101) and [AndroidManifest.xml](/c:/Users/USER/Documents/dev/curbox/app/src/main/AndroidManifest.xml#L43).

High-level, Curbox blocks by listening to accessibility window events in real time, immediately deciding on the visible package, sending the user home, optionally force-stopping the app through Shizuku, and then launching a warning Activity from the service in [AppBlockerService.kt](/c:/Users/USER/Documents/dev/curbox/app/src/main/java/neth/iecal/curbox/services/AppBlockerService.kt#L49) and [AppBlocker.kt](/c:/Users/USER/Documents/dev/curbox/app/src/main/java/neth/iecal/curbox/blockers/AppBlocker.kt#L310). Revoke, by contrast, is still centered on a Kotlin foreground service with polling plus a watchdog/boot recovery path in [AppMonitorCoordinator.kt](/c:/Users/USER/Documents/dev/revoke/android/app/src/main/kotlin/com/crescence/revoke/AppMonitorCoordinator.kt#L46), [BootReceiver.kt](/c:/Users/USER/Documents/dev/revoke/android/app/src/main/kotlin/com/crescence/revoke/BootReceiver.kt#L8), and [AppMonitorService.kt](/c:/Users/USER/Documents/dev/revoke/android/app/src/main/kotlin/com/crescence/revoke/AppMonitorService.kt#L613).

**Subsystem Audit**
1. Background survival  
Curbox does not use `WorkManager`, `JobScheduler`, or a foreground service for enforcement. It leans on Android keeping enabled accessibility services bound, and even isolates `AppBlockerService` into its own process in [AndroidManifest.xml](/c:/Users/USER/Documents/dev/curbox/app/src/main/AndroidManifest.xml#L43). Revoke uses a conventional foreground service plus boot receiver, restart alarms, and a 15-minute watchdog in [AndroidManifest.xml](/c:/Users/USER/Documents/dev/revoke/android/app/src/main/AndroidManifest.xml#L43) and [AppMonitorCoordinator.kt](/c:/Users/USER/Documents/dev/revoke/android/app/src/main/kotlin/com/crescence/revoke/AppMonitorCoordinator.kt#L63).

2. Usage tracking  
Curbox uses Accessibility events for instant app/view detection, but its app-usage limit math is still day-relative: `AppBlocker` calls `getForegroundStatsByRelativeDay(0)`, which is built on `queryEvents` plus foreground-process fallback in [AppBlocker.kt](/c:/Users/USER/Documents/dev/curbox/app/src/main/java/neth/iecal/curbox/blockers/AppBlocker.kt#L113) and [UsageStatsHelper.kt](/c:/Users/USER/Documents/dev/curbox/app/src/main/java/neth/iecal/curbox/utils/UsageStatsHelper.kt#L22). Revoke is better on semantic correctness for limits because it has a dedicated session-scoped `queryEvents` calculator keyed off `activatedAt` in [UsageEventsSessionCalculator.kt](/c:/Users/USER/Documents/dev/revoke/android/app/src/main/kotlin/com/crescence/revoke/UsageEventsSessionCalculator.kt#L10).

3. Block UI  
Curbox’s primary blocker is a transparent Activity launched from the accessibility service after `GLOBAL_ACTION_HOME`, with optional `am force-stop` via Shizuku in [AppBlocker.kt](/c:/Users/USER/Documents/dev/curbox/app/src/main/java/neth/iecal/curbox/blockers/AppBlocker.kt#L310) and [WarningActivity.kt](/c:/Users/USER/Documents/dev/curbox/app/src/main/java/neth/iecal/curbox/ui/activity/WarningActivity.kt#L112). Its `TYPE_ACCESSIBILITY_OVERLAY` usage is for counters/aux overlays, not the main blocker, in [ReelsOverlayManager.kt](/c:/Users/USER/Documents/dev/curbox/app/src/main/java/neth/iecal/curbox/ui/overlay/ReelsOverlayManager.kt#L18). Revoke’s blocker is a full-screen `TYPE_APPLICATION_OVERLAY` rendered directly from the service in [AppMonitorService.kt](/c:/Users/USER/Documents/dev/revoke/android/app/src/main/kotlin/com/crescence/revoke/AppMonitorService.kt#L917).

4. Boot persistence  
I did not find a real `BOOT_COMPLETED` receiver in Curbox. It requests the permission, but there is no implemented boot receiver; it appears to rely on Android re-binding accessibility services after reboot. Revoke is materially stronger here with an actual boot receiver, exact-alarm restart path, and periodic watchdog in [BootReceiver.kt](/c:/Users/USER/Documents/dev/revoke/android/app/src/main/kotlin/com/crescence/revoke/BootReceiver.kt#L8).

5. Uninstall prevention  
Curbox declares a `DeviceAdminReceiver` in [AndroidManifest.xml](/c:/Users/USER/Documents/dev/curbox/app/src/main/AndroidManifest.xml#L67) and [AdminReceiver.kt](/c:/Users/USER/Documents/dev/curbox/app/src/main/java/neth/iecal/curbox/receivers/AdminReceiver.kt#L1), but I did not find active `DevicePolicyManager` calls or a full admin-enrollment flow in code. So the anti-uninstall story exists on paper more than in a complete enforcement flow. Revoke currently has no comparable device-admin path.

**Verdict Matrix**

| Subsystem | Revoke | Reference | Resilience | Battery | Latency | Overall |
|---|---|---|---|---|---|---|
| Background survival | Foreground service + boot + watchdog | AccessibilityService in its own process, no watchdog | Reference | Reference | Reference | Reference for live survival; Revoke for explicit recovery |
| Usage tracking | Polling for foreground, session-scoped `queryEvents` for limits | Accessibility events for live detection, day-scoped `queryEvents` totals | Reference | Reference | Reference | Reference for firing speed; Revoke for session-limit correctness |
| Block UI | Full-screen application overlay | HOME + warning Activity + optional Shizuku force-stop | Revoke | Revoke | Revoke | Revoke |
| Boot persistence | Boot receiver + restart alarm + watchdog | No real boot receiver found | Revoke | Reference | Revoke | Revoke |
| Uninstall prevention | None | `DeviceAdminReceiver` declared, but incomplete | Reference | n/a | n/a | Reference, but only partially implemented |

**Hardening Plan**
- Add an optional `RevokeAccessibilityService` as a fast-path companion, not a replacement. Let it listen to `TYPE_WINDOW_STATE_CHANGED` and `TYPE_WINDOW_CONTENT_CHANGED`, extract the visible package, and call the same shared evaluator that Revoke already uses for `shouldBlockPackage`.
- Keep Revoke’s existing foreground service, boot receiver, restart alarm, and watchdog exactly as the recovery/backstop layer. This is stronger than Curbox’s boot story and should not be discarded.
- Extract Revoke’s blocking decision logic into a shared Kotlin `EnforcementEngine` so both the Accessibility fast-path and `AppMonitorService` call the same code path.
- When accessibility is granted, use it to eliminate most foreground polling. Revoke can then reserve `queryEvents` polling for fallback and session-usage math instead of primary app detection.
- Do not copy Curbox’s usage-limit implementation. Keep Revoke’s `activatedAt`-scoped `UsageEventsSessionCalculator`; it is more precise than Curbox’s day-relative usage totals.
- Do not replace Revoke’s overlay with Curbox’s `WarningActivity` approach. Revoke’s overlay is more compatible with modern background-launch restrictions.
- Consider an optional “hard mode” behind flavor/flag using Shizuku for `am force-stop` or `pm suspend`, but only outside Play-distributed builds or behind a clear risk gate. It is powerful, but policy-sensitive.
- If you add the Accessibility fast-path, consider running it in a separate `:enforcement` process the way Curbox isolates `AppBlockerService`. That would reduce Flutter/UI crashes taking down enforcement.
- Treat Device Admin as optional and separate. Curbox’s current implementation is not strong enough to copy directly, and Play/policy risk is real.

Bottom line: Curbox’s strongest idea is not its warning UI or its usage math. It’s the event-driven Accessibility architecture. The best hardening move for Revoke is a hybrid: keep Revoke’s watchdog/boot recovery, but add an Accessibility fast-path for instant foreground detection and enforcement.