package com.crescence.revoke

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class RevokeAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        private var running: Boolean = false

        fun isRunning(): Boolean = running
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastEvaluatedPackage: String = ""
    private var lastEvaluationAtMs: Long = 0L

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

        val now = System.currentTimeMillis()
        if (observedPackage == lastEvaluatedPackage && now - lastEvaluationAtMs < 250L) {
            return
        }

        lastEvaluatedPackage = observedPackage
        lastEvaluationAtMs = now

        try {
            EnforcementEngine.recordForegroundPackage(observedPackage)
            val blockedAppName =
                EnforcementEngine.findBlockedAppLabel(
                    context = applicationContext,
                    packageName = observedPackage,
                    shouldLog = false,
                )

            if (blockedAppName != null) {
                val wentHome = performGlobalAction(GLOBAL_ACTION_HOME)
                Log.d(
                    "RevokeAccessibility",
                    "Blocked $observedPackage from accessibility. homeAction=$wentHome",
                )
                mainHandler.post {
                    BlockerOverlayController.show(
                        context = applicationContext,
                        blockedAppName = blockedAppName,
                        packageNameStr = observedPackage,
                        source = "accessibility_home_killswitch",
                    )
                }
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
}
