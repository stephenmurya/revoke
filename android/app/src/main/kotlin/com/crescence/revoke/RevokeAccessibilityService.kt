package com.crescence.revoke

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class RevokeAccessibilityService : AccessibilityService() {
    companion object {
        private const val HOME_OVERLAY_DELAY_MS = 140L
        private const val RECENTS_OVERLAY_DELAY_MS = 220L

        @Volatile
        private var running: Boolean = false

        fun isRunning(): Boolean = running
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastEvaluatedPackage: String = ""
    private var lastEvaluationAtMs: Long = 0L
    private var pendingOverlayToken: Long = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        running = true
        EnforcementEngine.ensureLoaded(applicationContext)
        Log.d("RevokeAccessibility", "Accessibility fast path connected.")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val observedPackage = event.packageName?.toString()?.trim().orEmpty()
        if (observedPackage.isEmpty()) return
        if (EnforcementEngine.shouldIgnorePackage(applicationContext, observedPackage)) return
        if (BlockerOverlayController.isShowing()) {
            Log.d(
                "RevokeAccessibility",
                "Ignoring accessibility event while blocker overlay is already showing. package=$observedPackage",
            )
            return
        }

        val now = System.currentTimeMillis()
        if (observedPackage == lastEvaluatedPackage && now - lastEvaluationAtMs < 250L) {
            return
        }

        lastEvaluatedPackage = observedPackage
        lastEvaluationAtMs = now

        try {
            EnforcementEngine.recordForegroundPackage(observedPackage)
            val blockPresentation =
                EnforcementEngine.findBlockPresentation(
                    context = applicationContext,
                    packageName = observedPackage,
                    shouldLog = false,
                )

            if (blockPresentation != null) {
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

            BlockerOverlayController.hide(
                context = applicationContext,
                source = "accessibility_window_state_changed:not_blocked",
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
