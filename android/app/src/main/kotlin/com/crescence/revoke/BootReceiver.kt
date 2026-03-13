package com.crescence.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val isBootAction =
            action == Intent.ACTION_BOOT_COMPLETED || action == ACTION_QUICKBOOT_POWERON
        if (!isBootAction) return

        AlarmScheduler.restorePersistedNextRegimeWakeup(context)
        Log.d("RevokeBoot", "Boot action received: $action. Starting AppMonitorService.")
        val serviceIntent = Intent(context, AppMonitorService::class.java)
        try {
            ContextCompat.startForegroundService(context, serviceIntent)
        } catch (error: Exception) {
            if (isForegroundServiceStartNotAllowed(error)) {
                Log.e(
                    "RevokeBoot",
                    "Foreground start blocked at boot. Will retry when app returns to foreground.",
                    error
                )
            } else {
                Log.e("RevokeBoot", "Failed to start AppMonitorService at boot.", error)
            }
        }
    }

    companion object {
        private const val ACTION_QUICKBOOT_POWERON =
            "android.intent.action.QUICKBOOT_POWERON"

        private fun isForegroundServiceStartNotAllowed(error: Exception): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
            return error.javaClass.name == "android.app.ForegroundServiceStartNotAllowedException"
        }
    }
}
