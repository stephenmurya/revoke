package com.crescence.revoke

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object AlarmScheduler {
    const val ACTION_WAKE_FOR_REGIME = "com.revoke.app.WAKE_FOR_REGIME"

    private const val PREFS_NAME = "RevokeConfig"
    private const val KEY_NEXT_REGIME_WAKEUP_MS = "next_regime_wakeup_ms"
    private const val REQUEST_CODE_NEXT_REGIME_WAKEUP = 1002

    fun scheduleNextRegimeWakeup(context: Context, startTimeMs: Long): Boolean {
        val appContext = context.applicationContext
        if (startTimeMs <= 0L) {
            cancelNextRegimeWakeup(appContext)
            return false
        }

        val now = System.currentTimeMillis()
        if (startTimeMs <= now) {
            Log.w(
                "RevokeAlarm",
                "Ignoring stale next wakeup timestamp: $startTimeMs (now=$now).",
            )
            cancelNextRegimeWakeup(appContext)
            return false
        }

        val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            Log.w(
                "RevokeAlarm",
                "Exact alarm permission unavailable. Next regime wakeup was not scheduled.",
            )
            return false
        }

        val pendingIntent = buildNextRegimeWakeupPendingIntent(appContext)
        return try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        startTimeMs,
                        pendingIntent,
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        startTimeMs,
                        pendingIntent,
                    )
                }
                else -> {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        startTimeMs,
                        pendingIntent,
                    )
                }
            }

            appContext
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putLong(KEY_NEXT_REGIME_WAKEUP_MS, startTimeMs)
                .apply()

            Log.d("RevokeAlarm", "Scheduled next regime wakeup for $startTimeMs.")
            true
        } catch (error: SecurityException) {
            Log.e(
                "RevokeAlarm",
                "Exact alarm permission revoked before wakeup scheduling completed.",
                error,
            )
            false
        }
    }

    fun cancelNextRegimeWakeup(context: Context) {
        val appContext = context.applicationContext
        val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildNextRegimeWakeupPendingIntent(appContext))
        appContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_NEXT_REGIME_WAKEUP_MS)
            .apply()
        Log.d("RevokeAlarm", "Canceled next regime wakeup alarm.")
    }

    fun restorePersistedNextRegimeWakeup(context: Context): Boolean {
        val appContext = context.applicationContext
        val startTimeMs = appContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(KEY_NEXT_REGIME_WAKEUP_MS, 0L)

        return if (startTimeMs > System.currentTimeMillis()) {
            scheduleNextRegimeWakeup(appContext, startTimeMs)
        } else {
            cancelNextRegimeWakeup(appContext)
            false
        }
    }

    private fun buildNextRegimeWakeupPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ServiceRestartReceiver::class.java).apply {
            action = ACTION_WAKE_FOR_REGIME
        }

        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_NEXT_REGIME_WAKEUP,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
