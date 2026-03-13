package com.crescence.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat

class ServiceRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val restartRequested =
            action == "com.revoke.app.RESTART_SERVICE" ||
                action == AlarmScheduler.ACTION_WAKE_FOR_REGIME
        if (!restartRequested) return

        val serviceIntent = Intent(context, AppMonitorService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (error: Exception) {
            if (isForegroundServiceStartNotAllowed(error)) {
                Log.e(
                    "RevokeRestart",
                    "Foreground restart blocked for action=$action. Will retry on next app foreground.",
                    error
                )
            } else {
                Log.e(
                    "RevokeRestart",
                    "Failed to restart AppMonitorService for action=$action.",
                    error
                )
            }
        }
    }

    private fun isForegroundServiceStartNotAllowed(error: Exception): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return error.javaClass.name == "android.app.ForegroundServiceStartNotAllowedException"
    }
}
