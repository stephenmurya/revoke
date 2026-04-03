package com.crescence.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class ServiceRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val restartRequested =
            action == "com.revoke.app.RESTART_SERVICE" ||
                action == AlarmScheduler.ACTION_WAKE_FOR_REGIME
        if (!restartRequested) return

        try {
            AppMonitorCoordinator.checkAndReviveService(
                context = context,
                trigger = action ?: "receiver_restart",
            )
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = context,
                source = "ServiceRestartReceiver",
                message = "Unhandled service restart failure.",
                error = error,
                extraKeys = mapOf("trigger" to (action ?: "unknown")),
            )
            Log.e("RevokeRestart", "Failed to restart AppMonitorService for action=$action.", error)
        }
    }
}
