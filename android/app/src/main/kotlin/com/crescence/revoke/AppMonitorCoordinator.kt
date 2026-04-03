package com.crescence.revoke

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.google.firebase.crashlytics.FirebaseCrashlytics
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.concurrent.TimeUnit

object AppMonitorCoordinator {
    private const val PREFS_NAME = "RevokeConfig"
    private const val KEY_SCHEDULES = "schedules"
    private const val KEY_TEMP_UNLOCKS = "temp_unlocks"
    private const val KEY_AMNESTY_EXPIRY = "amnesty_expiry"
    private const val KEY_MONITOR_LAST_TICK_MS = "monitor_last_tick_ms"
    private const val HEARTBEAT_STALE_MS = 30_000L
    private const val MINUTES_PER_DAY = 1440
    private const val TAG = "RevokeMonitorCoord"
    const val WATCHDOG_WORK_NAME = "revoke_app_monitor_watchdog"

    data class ServiceReviveStatus(
        val serviceRunning: Boolean,
        val restartAttempted: Boolean,
        val restartSucceeded: Boolean,
        val trigger: String,
    ) {
        fun toMap(): Map<String, Any> =
            mapOf(
                "serviceRunning" to serviceRunning,
                "restartAttempted" to restartAttempted,
                "restartSucceeded" to restartSucceeded,
                "trigger" to trigger,
            )
    }

    private data class TimeWindow(val startTotalMin: Int, val endTotalMin: Int)

    fun enqueueWatchdog(context: Context) {
        val appContext = context.applicationContext
        val request =
            PeriodicWorkRequestBuilder<AppMonitorWatchdogWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(appContext).enqueueUniquePeriodicWork(
            WATCHDOG_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    fun shouldServiceBeRunning(context: Context, nowMs: Long = System.currentTimeMillis()): Boolean {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return hasActiveRegime(prefs.getString(KEY_SCHEDULES, "[]"), nowMs) ||
            hasActiveTemporaryState(prefs, nowMs)
    }

    fun checkAndReviveService(context: Context, trigger: String): ServiceReviveStatus {
        val appContext = context.applicationContext
        enqueueWatchdog(appContext)

        val shouldRun = shouldServiceBeRunning(appContext)
        val serviceHealthy = isServiceHealthy(appContext)
        if (!shouldRun) {
            return ServiceReviveStatus(
                serviceRunning = serviceHealthy,
                restartAttempted = false,
                restartSucceeded = false,
                trigger = trigger,
            )
        }

        if (serviceHealthy) {
            return ServiceReviveStatus(
                serviceRunning = true,
                restartAttempted = false,
                restartSucceeded = false,
                trigger = trigger,
            )
        }

        val restartSucceeded = startMonitorServiceSafely(
            context = appContext,
            intent = Intent(appContext, AppMonitorService::class.java),
            reason = trigger,
        )
        return ServiceReviveStatus(
            serviceRunning = restartSucceeded || isServiceHealthy(appContext),
            restartAttempted = true,
            restartSucceeded = restartSucceeded,
            trigger = trigger,
        )
    }

    fun startMonitorServiceSafely(context: Context, intent: Intent, reason: String): Boolean {
        val appContext = context.applicationContext
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(appContext, intent)
            } else {
                appContext.startService(intent)
            }
            true
        } catch (error: Exception) {
            val message = if (isForegroundServiceStartNotAllowed(error)) {
                "Foreground service start blocked for $reason."
            } else {
                "Failed to start AppMonitorService for $reason."
            }
            recordNonFatal(
                context = appContext,
                source = "AppMonitorCoordinator",
                message = message,
                error = error,
                extraKeys = mapOf("trigger" to reason),
            )
            Log.e(TAG, message, error)
            false
        }
    }

    fun recordServiceException(
        context: Context,
        stage: String,
        error: Throwable,
        extraKeys: Map<String, Any> = emptyMap(),
    ) {
        recordNonFatal(
            context = context,
            source = "AppMonitorService",
            message = "AppMonitorService exception at $stage.",
            error = error,
            extraKeys =
                extraKeys + mapOf(
                    "service_stage" to stage,
                ),
        )
    }

    fun recordNonFatal(
        context: Context,
        source: String,
        message: String,
        error: Throwable,
        extraKeys: Map<String, Any> = emptyMap(),
    ) {
        val crashlytics = FirebaseCrashlytics.getInstance()
        crashlytics.setCustomKey("error_source", source)
        crashlytics.setCustomKey("device_manufacturer", Build.MANUFACTURER ?: "unknown")
        crashlytics.setCustomKey("os_version", Build.VERSION.RELEASE ?: "unknown")
        crashlytics.setCustomKey(
            "is_battery_optimized",
            isBatteryOptimized(context.applicationContext),
        )
        for ((key, value) in extraKeys) {
            when (value) {
                is Boolean -> crashlytics.setCustomKey(key, value)
                is Int -> crashlytics.setCustomKey(key, value)
                is Long -> crashlytics.setCustomKey(key, value)
                is Float -> crashlytics.setCustomKey(key, value)
                is Double -> crashlytics.setCustomKey(key, value)
                else -> crashlytics.setCustomKey(key, value.toString())
            }
        }
        crashlytics.log("$source: $message")
        crashlytics.recordException(error)
    }

    private fun isServiceHealthy(context: Context, nowMs: Long = System.currentTimeMillis()): Boolean {
        if (AppMonitorService.isRunning()) return true
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastTickMs = prefs.getLong(KEY_MONITOR_LAST_TICK_MS, 0L)
        return lastTickMs > 0L && nowMs - lastTickMs <= HEARTBEAT_STALE_MS
    }

    private fun hasActiveTemporaryState(prefs: android.content.SharedPreferences, nowMs: Long): Boolean {
        if (prefs.getLong(KEY_AMNESTY_EXPIRY, 0L) > nowMs) {
            return true
        }

        val rawUnlocks = prefs.getString(KEY_TEMP_UNLOCKS, null) ?: return false
        return try {
            val json = JSONObject(rawUnlocks)
            val keys = json.keys()
            while (keys.hasNext()) {
                val packageName = keys.next()
                val expiry = json.optLong(packageName, 0L)
                if (expiry > nowMs) {
                    return true
                }
            }
            false
        } catch (error: Exception) {
            false
        }
    }

    private fun hasActiveRegime(rawSchedules: String?, nowMs: Long): Boolean {
        val safeJson = rawSchedules?.trim().orEmpty()
        if (safeJson.isEmpty() || safeJson == "[]") return false

        return try {
            val schedules = JSONArray(safeJson)
            val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
            val modelDay =
                calendar.get(Calendar.DAY_OF_WEEK).let { day ->
                    if (day == Calendar.SUNDAY) 7 else day - 1
                }
            val currentTotalMin = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)

            for (i in 0 until schedules.length()) {
                val schedule = schedules.optJSONObject(i) ?: continue
                if (!schedule.optBoolean("isActive", true)) continue
                if (!hasTargetApps(schedule)) continue
                if (!scheduleMatchesDay(schedule, modelDay)) continue

                when (schedule.optInt("type", 0)) {
                    0 -> {
                        if (extractTimeWindows(schedule).any { isMinuteWithinWindow(it, currentTotalMin) }) {
                            return true
                        }
                    }

                    1 -> return true
                }
            }
            false
        } catch (error: Exception) {
            false
        }
    }

    private fun hasTargetApps(schedule: JSONObject): Boolean {
        val targetApps = schedule.optJSONArray("targetApps") ?: return false
        for (i in 0 until targetApps.length()) {
            if (targetApps.optString(i, "").trim().isNotEmpty()) {
                return true
            }
        }
        return false
    }

    private fun scheduleMatchesDay(schedule: JSONObject, modelDay: Int): Boolean {
        val days = schedule.optJSONArray("days") ?: return false
        for (i in 0 until days.length()) {
            if (days.optInt(i, -1) == modelDay) {
                return true
            }
        }
        return false
    }

    private fun extractTimeWindows(schedule: JSONObject): List<TimeWindow> {
        val windows = mutableListOf<TimeWindow>()
        val blocks = schedule.optJSONArray("blocks")
        if (blocks != null) {
            for (i in 0 until blocks.length()) {
                val block = blocks.optJSONObject(i) ?: continue
                val window =
                    toTimeWindow(
                        startHour = block.optInt("startHour", -1),
                        startMinute = block.optInt("startMinute", -1),
                        endHour = block.optInt("endHour", -1),
                        endMinute = block.optInt("endMinute", -1),
                    )
                if (window != null) {
                    windows.add(window)
                }
            }
        }
        if (windows.isNotEmpty()) return windows

        val legacyWindow =
            toTimeWindow(
                startHour = schedule.optInt("startHour", -1),
                startMinute = schedule.optInt("startMinute", -1),
                endHour = schedule.optInt("endHour", -1),
                endMinute = schedule.optInt("endMinute", -1),
            )
        if (legacyWindow != null) {
            return listOf(legacyWindow)
        }

        val startTotalMin = parseHourMinuteStringToTotalMin(schedule.optString("startTime"))
        val endTotalMin = parseHourMinuteStringToTotalMin(schedule.optString("endTime"))
        return if (startTotalMin != null && endTotalMin != null && startTotalMin != endTotalMin) {
            listOf(TimeWindow(startTotalMin, endTotalMin))
        } else {
            emptyList()
        }
    }

    private fun toTimeWindow(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
    ): TimeWindow? {
        if (startHour !in 0..23 || endHour !in 0..23) return null
        if (startMinute !in 0..59 || endMinute !in 0..59) return null
        val startTotalMin = startHour * 60 + startMinute
        val endTotalMin = endHour * 60 + endMinute
        if (startTotalMin == endTotalMin) return null
        return TimeWindow(startTotalMin, endTotalMin)
    }

    private fun parseHourMinuteStringToTotalMin(raw: String?): Int? {
        val value = raw?.trim()
        if (value.isNullOrEmpty()) return null
        val parts = value.split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) return null
        return hour * 60 + minute
    }

    private fun isMinuteWithinWindow(window: TimeWindow, minuteOfDay: Int): Boolean {
        val now = minuteOfDay.coerceIn(0, MINUTES_PER_DAY - 1)
        return if (window.startTotalMin < window.endTotalMin) {
            now >= window.startTotalMin && now < window.endTotalMin
        } else {
            now >= window.startTotalMin || now < window.endTotalMin
        }
    }

    private fun isForegroundServiceStartNotAllowed(error: Exception): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return error.javaClass.name == "android.app.ForegroundServiceStartNotAllowedException"
    }

    private fun isBatteryOptimized(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return !powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }
}
