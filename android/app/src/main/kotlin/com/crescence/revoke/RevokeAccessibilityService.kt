package com.crescence.revoke

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class RevokeAccessibilityService : AccessibilityService() {
    companion object {
        private const val HOME_OVERLAY_DELAY_MS = 140L
        private const val RECENTS_OVERLAY_DELAY_MS = 220L
        private const val SESSION_END_GRACE_MS = 4_000L
        private const val PREFS_NAME = "RevokeConfig"
        private const val KEY_SOFT_REMINDER_ENABLED = "soft_reminder_enabled"
        private const val KEY_INTERSTITIAL_THRESHOLD_MS = "interstitial_threshold_ms"
        private const val DEFAULT_INTERSTITIAL_THRESHOLD_MS = 900_000L

        @Volatile
        private var running: Boolean = false

        fun isRunning(): Boolean = running
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastEvaluatedPackage: String = ""
    private var lastEvaluationAtMs: Long = 0L
    private var pendingOverlayToken: Long = 0L
    private var activeSessionPackage: String = ""
    private var activeSessionStartedAtMs: Long = 0L
    private var activeSessionToken: Long = 0L
    private var pendingSessionClearToken: Long = 0L
    private var currentForegroundPackage: String = ""
    private var interstitialShownForSession: Boolean = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        running = true
        EnforcementEngine.ensureLoaded(applicationContext)
        CreditEvidenceRecorder.recordHealth(applicationContext)
        Log.d("RevokeAccessibility", "Accessibility fast path connected.")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val observedPackage = event.packageName?.toString()?.trim().orEmpty()
        if (observedPackage.isEmpty()) return
        if (isTransientIgnoredPackage(observedPackage)) return
        if (BlockerOverlayController.isShowing()) {
            Log.d(
                "RevokeAccessibility",
                "Ignoring accessibility event while blocker overlay is already showing. package=$observedPackage",
            )
            return
        }

        val now = System.currentTimeMillis()
        currentForegroundPackage = observedPackage
        CreditEvidenceRecorder.recordForeground(applicationContext, observedPackage)
        if (observedPackage == lastEvaluatedPackage && now - lastEvaluationAtMs < 250L) {
            return
        }

        lastEvaluatedPackage = observedPackage
        lastEvaluationAtMs = now

        try {
            val ignoredForEnforcement =
                EnforcementEngine.shouldIgnorePackage(applicationContext, observedPackage)
            if (ignoredForEnforcement) {
                if (isLauncherPackage(observedPackage)) {
                    clearActiveRestrictedSession("accessibility_launcher_foreground")
                } else {
                    scheduleActiveRestrictedSessionClear("accessibility_ignored_foreground")
                }
                return
            }

            EnforcementEngine.recordForegroundPackage(observedPackage)
            val blockPresentation =
                EnforcementEngine.findBlockPresentation(
                    context = applicationContext,
                    packageName = observedPackage,
                    shouldLog = false,
                )

            if (blockPresentation != null) {
                CreditEvidenceRecorder.recordForeground(
                    applicationContext,
                    observedPackage,
                    violation = true,
                )
                if (EnforcementEngine.isAccessibilityEscapePending(observedPackage)) {
                    Log.d(
                        "RevokeAccessibility",
                        "Ignoring duplicate blocked event during accessibility escape window. package=$observedPackage",
                    )
                    return
                }
                triggerEscapeAndOverlay(
                    presentation = blockPresentation,
                )
                return
            }

            if (EnforcementEngine.isAccessibilityEscapePending()) {
                Log.d(
                    "RevokeAccessibility",
                    "Ignoring non-blocked event during accessibility escape window. package=$observedPackage",
                )
                return
            }

            val reminderPresentation =
                EnforcementEngine.findReminderPresentation(
                    context = applicationContext,
                    packageName = observedPackage,
                    nowMs = now,
                    shouldLog = false,
                )

            if (reminderPresentation == null) {
                scheduleActiveRestrictedSessionClear("accessibility_unrestricted_foreground")
                BlockerOverlayController.hide(
                    context = applicationContext,
                    source = "accessibility_window_state_changed:not_blocked",
                )
                return
            }

            handleRestrictedForeground(
                packageName = observedPackage,
                nowMs = now,
                presentation = reminderPresentation,
            )
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = applicationContext,
                source = "RevokeAccessibilityService",
                message = "Accessibility evaluation failed.",
                error = error,
                extraKeys = mapOf("packageName" to observedPackage),
            )
            Log.e("RevokeAccessibility", "Accessibility evaluation failed.", error)
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        running = false
        return super.onUnbind(intent)
    }

    private fun handleRestrictedForeground(
        packageName: String,
        nowMs: Long,
        presentation: ReminderPresentation,
    ) {
        cancelPendingSessionClear()
        if (packageName == activeSessionPackage && activeSessionStartedAtMs > 0L) {
            return
        }

        BlockerOverlayController.hideReminder(
            context = applicationContext,
            source = "accessibility_restricted_session_switch",
        )
        activeSessionPackage = packageName
        activeSessionStartedAtMs = nowMs
        activeSessionToken += 1
        interstitialShownForSession = false
        Log.d("RevokeMonitor", "Session State changed to: $activeSessionPackage")
        scheduleInterstitialCheck(packageName, activeSessionToken)
        showSoftReminderForQa(presentation)
    }

    private fun clearActiveRestrictedSession(source: String) {
        cancelPendingSessionClear()
        if (activeSessionPackage.isBlank()) return
        activeSessionPackage = ""
        activeSessionStartedAtMs = 0L
        activeSessionToken += 1
        interstitialShownForSession = false
        Log.d("RevokeMonitor", "Session State changed to: $activeSessionPackage")
        BlockerOverlayController.hideReminder(
            context = applicationContext,
            source = source,
        )
    }

    private fun scheduleActiveRestrictedSessionClear(source: String) {
        val packageAtSchedule = activeSessionPackage
        if (packageAtSchedule.isBlank()) return

        pendingSessionClearToken += 1
        val token = pendingSessionClearToken

        BlockerOverlayController.hideReminder(
            context = applicationContext,
            source = source,
        )

        mainHandler.postDelayed({
            if (token != pendingSessionClearToken) return@postDelayed
            if (packageAtSchedule != activeSessionPackage) return@postDelayed
            clearActiveRestrictedSession(source)
        }, SESSION_END_GRACE_MS)
    }

    private fun cancelPendingSessionClear() {
        pendingSessionClearToken += 1
    }

    private fun isTransientIgnoredPackage(packageName: String): Boolean {
        val normalized = packageName.trim().lowercase()
        if (normalized == applicationContext.packageName.lowercase()) return true
        if (normalized == "com.android.systemui" || normalized.contains(".systemui")) return true
        if (normalized.contains("inputmethod")) return true
        if (normalized.contains("keyboard")) return true
        if (normalized.contains("latinime")) return true
        if (normalized.contains("honeyboard")) return true
        if (normalized.contains("swiftkey")) return true
        return false
    }

    private fun isLauncherPackage(packageName: String): Boolean {
        val normalized = packageName.trim().lowercase()
        return normalized.contains("launcher") || normalized.contains("trebuchet")
    }

    private fun showSoftReminderForQa(presentation: ReminderPresentation) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_SOFT_REMINDER_ENABLED, true)) return

        if (presentation.remainingMs <= 0L) return
        BlockerOverlayController.showSoftReminder(
            context = applicationContext,
            presentation = presentation,
            source = "accessibility_app_open",
        )
    }

    private fun scheduleInterstitialCheck(packageName: String, sessionToken: Long) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val thresholdMs =
            prefs.getLong(KEY_INTERSTITIAL_THRESHOLD_MS, DEFAULT_INTERSTITIAL_THRESHOLD_MS)
                .coerceAtLeast(0L)
        if (thresholdMs <= 0L) return

        mainHandler.postDelayed({
            if (sessionToken != activeSessionToken) return@postDelayed
            if (packageName != activeSessionPackage) return@postDelayed
            if (packageName != currentForegroundPackage) return@postDelayed
            if (interstitialShownForSession) return@postDelayed
            if (BlockerOverlayController.isShowing()) return@postDelayed

            val presentation =
                EnforcementEngine.findReminderPresentation(
                    context = applicationContext,
                    packageName = packageName,
                    nowMs = System.currentTimeMillis(),
                    shouldLog = false,
                ) ?: return@postDelayed

            if (presentation.remainingMs <= 0L) return@postDelayed
            interstitialShownForSession = true
            BlockerOverlayController.showInterstitialReminder(
                context = applicationContext,
                presentation = presentation,
                source = "accessibility_session_threshold",
            )
        }, thresholdMs)
    }

    private fun triggerEscapeAndOverlay(presentation: BlockPresentation) {
        val packageName = presentation.packageName
        val token = System.currentTimeMillis()
        pendingOverlayToken = token

        val actionUsed =
            when {
                tryPerformGlobalActionIfAvailable(GLOBAL_ACTION_HOME) -> "home"
                tryPerformGlobalActionIfAvailable(GLOBAL_ACTION_RECENTS) -> "recents"
                else -> "none"
            }

        val delayMs =
            when (actionUsed) {
                "home" -> HOME_OVERLAY_DELAY_MS
                "recents" -> RECENTS_OVERLAY_DELAY_MS
                else -> 0L
            }

        EnforcementEngine.beginAccessibilityEscape(
            packageName = packageName,
            holdMs = delayMs + 1_500L,
        )

        Log.d(
            "RevokeAccessibility",
            "Blocked $packageName from accessibility. action=$actionUsed delayMs=$delayMs",
        )

        mainHandler.postDelayed({
            if (pendingOverlayToken != token) {
                return@postDelayed
            }
            BlockerOverlayController.show(
                context = applicationContext,
                presentation = presentation,
                source = "accessibility_${actionUsed}_killswitch",
            )
        }, delayMs)
    }

    private fun tryPerformGlobalActionIfAvailable(action: Int): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val isAvailable =
                    getSystemActions().any { systemAction ->
                        systemAction.id == action
                    }
                if (!isAvailable) {
                    return false
                }
            }
            performGlobalAction(action)
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = applicationContext,
                source = "RevokeAccessibilityService",
                message = "Failed to perform accessibility global action.",
                error = error,
                extraKeys = mapOf("action" to action.toString()),
            )
            false
        }
    }
}
