package com.crescence.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val isBootAction =
            action == Intent.ACTION_BOOT_COMPLETED || action == ACTION_QUICKBOOT_POWERON
        if (!isBootAction) return

        AlarmScheduler.restorePersistedNextRegimeWakeup(context)
        AppMonitorCoordinator.enqueueWatchdog(context)
        Log.d("RevokeBoot", "Boot action received: $action. Checking AppMonitorService.")
        try {
            AppMonitorCoordinator.checkAndReviveService(context, "boot")
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = context,
                source = "BootReceiver",
                message = "Unhandled boot revive failure.",
                error = error,
                extraKeys = mapOf("trigger" to "boot"),
            )
            Log.e("RevokeBoot", "Failed to check AppMonitorService at boot.", error)
        }
    }

    companion object {
        private const val ACTION_QUICKBOOT_POWERON =
            "android.intent.action.QUICKBOOT_POWERON"
    }
}
