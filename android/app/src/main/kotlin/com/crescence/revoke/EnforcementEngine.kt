package com.crescence.revoke

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object EnforcementEngine {
    private const val PREFS_NAME = "RevokeConfig"
    private const val KEY_SCHEDULES = "schedules"
    private const val KEY_TEMP_UNLOCKS = "temp_unlocks"
    private const val KEY_AMNESTY_EXPIRY = "amnesty_expiry"
    private const val TAG = "RevokeEngine"

    private data class TimeWindow(val startTotalMin: Int, val endTotalMin: Int)

    private val cacheLock = Any()

    @Volatile
    private var cachedSchedulesRaw: String = ""

    @Volatile
    private var cachedSchedules: List<JSONObject> = emptyList()

    @Volatile
    private var blockedAppsIndex: Set<String> = emptySet()

    @Volatile
    private var lastObservedPackage: String = ""

    fun ensureLoaded(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        updateCacheIfNeeded(prefs.getString(KEY_SCHEDULES, "[]").orEmpty())
    }

    fun syncSchedules(context: Context, schedulesJson: String): Int {
        val appContext = context.applicationContext
        val safeJson = schedulesJson.trim().ifEmpty { "[]" }
        return try {
            appContext
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_SCHEDULES, safeJson)
                .apply()
            updateCacheIfNeeded(safeJson, force = true)
            cachedSchedules.size
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = appContext,
                source = "EnforcementEngine",
                message = "Failed to sync native schedules.",
                error = error,
            )
            0
        }
    }

    fun getScheduleCount(context: Context): Int {
        ensureLoaded(context)
        return cachedSchedules.size
    }

    fun recordForegroundPackage(packageName: String?) {
        val normalized = packageName?.trim().orEmpty()
        if (normalized.isNotEmpty()) {
            lastObservedPackage = normalized
        }
    }

    fun clearForegroundPackage(packageName: String? = null) {
        val normalized = packageName?.trim().orEmpty()
        if (normalized.isEmpty() || lastObservedPackage == normalized) {
            lastObservedPackage = ""
        }
    }

    fun evaluateLastObservedPackage(
        context: Context,
        source: String,
        shouldLog: Boolean = false,
    ): Boolean {
        val packageName = lastObservedPackage.trim()
        if (packageName.isEmpty()) {
            BlockerOverlayController.hide(context, "$source:no_observed_package")
            return false
        }
        return evaluateAndApply(context, packageName, source, shouldLog)
    }

    fun evaluateAndApply(
        context: Context,
        packageName: String,
        source: String,
        shouldLog: Boolean = false,
    ): Boolean {
        val appContext = context.applicationContext
        val normalizedPackage = packageName.trim()
        if (normalizedPackage.isEmpty()) {
            BlockerOverlayController.hide(appContext, "$source:empty_package")
            return false
        }

        recordForegroundPackage(normalizedPackage)

        if (shouldIgnorePackage(appContext, normalizedPackage)) {
            BlockerOverlayController.hide(appContext, "$source:ignored_package")
            return false
        }

        return try {
            val blockedAppName = findBlockedAppLabel(appContext, normalizedPackage, shouldLog)
            if (blockedAppName != null) {
                BlockerOverlayController.show(appContext, blockedAppName, normalizedPackage, source)
                true
            } else {
                BlockerOverlayController.hide(appContext, "$source:not_blocked")
                false
            }
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = appContext,
                source = "EnforcementEngine",
                message = "Unhandled enforcement failure.",
                error = error,
                extraKeys = mapOf("trigger" to source, "packageName" to normalizedPackage),
            )
            false
        }
    }

    fun findBlockedAppLabel(
        context: Context,
        packageName: String,
        shouldLog: Boolean = false,
    ): String? {
        val normalizedPackage = packageName.trim()
        if (normalizedPackage.isEmpty()) return null
        if (shouldIgnorePackage(context, normalizedPackage)) return null
        return shouldBlockPackage(context, normalizedPackage, shouldLog)
    }

    fun hasActiveUsageLimitRegimeNow(
        context: Context,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean {
        ensureLoaded(context)
        val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
        val modelDay =
            calendar.get(Calendar.DAY_OF_WEEK).let { day ->
                if (day == Calendar.SUNDAY) 7 else day - 1
            }
        val currentTotalMin = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)

        for (schedule in cachedSchedules) {
            if (!schedule.optBoolean("isActive", true)) continue
            if (schedule.optInt("type", 0) != 1) continue
            if (!scheduleMatchesDay(schedule, modelDay)) continue
            if (extractTargetPackages(schedule).isEmpty()) continue

            val windows = extractTimeWindows(schedule)
            if (windows.isNotEmpty() && !windows.any { isMinuteWithinWindow(it, currentTotalMin) }) {
                continue
            }
            return true
        }

        return false
    }

    private fun shouldBlockPackage(
        context: Context,
        packageName: String,
        shouldLog: Boolean,
    ): String? {
        return try {
            val nowMs = System.currentTimeMillis()
            if (isAmnestyActive(context, nowMs)) {
                if (shouldLog) android.util.Log.d(TAG, "Amnesty active. Skipping $packageName")
                return null
            }
            if (isPackageTemporarilyUnlocked(context, packageName, nowMs)) {
                if (shouldLog) android.util.Log.d(TAG, "Temp unlock active for $packageName")
                return null
            }

            ensureLoaded(context)
            if (!blockedAppsIndex.contains(packageName)) {
                return null
            }

            val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
            val modelDay =
                calendar.get(Calendar.DAY_OF_WEEK).let { day ->
                    if (day == Calendar.SUNDAY) 7 else day - 1
                }
            val currentTotalMin =
                calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)

            for (schedule in cachedSchedules) {
                if (!schedule.optBoolean("isActive", true)) continue
                if (!scheduleMatchesDay(schedule, modelDay)) continue
                if (!scheduleTargetsPackage(schedule, packageName)) continue

                val shouldBlock =
                    when (schedule.optInt("type", 0)) {
                        0 -> evaluateTimeBlockRegime(schedule, currentTotalMin)
                        1 -> evaluateUsageLimitRegime(context, schedule, currentTotalMin, nowMs)
                        else -> false
                    }

                if (shouldBlock) {
                    return resolvePackageLabel(context, packageName)
                }
            }

            null
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = context,
                source = "EnforcementEngine",
                message = "Failed to evaluate package.",
                error = error,
                extraKeys = mapOf("packageName" to packageName),
            )
            null
        }
    }

    private fun evaluateTimeBlockRegime(schedule: JSONObject, currentTotalMin: Int): Boolean {
        val windows = extractTimeWindows(schedule)
        if (windows.isEmpty()) return false
        return windows.any { isMinuteWithinWindow(it, currentTotalMin) }
    }

    private fun evaluateUsageLimitRegime(
        context: Context,
        schedule: JSONObject,
        currentTotalMin: Int,
        nowMs: Long,
    ): Boolean {
        val windows = extractTimeWindows(schedule)
        if (windows.isNotEmpty() && !windows.any { isMinuteWithinWindow(it, currentTotalMin) }) {
            return true
        }

        val limitMinutes =
            when {
                schedule.has("limitMinutes") && !schedule.isNull("limitMinutes") ->
                    schedule.optInt("limitMinutes", -1)
                schedule.has("durationMinutes") && !schedule.isNull("durationMinutes") ->
                    schedule.optInt("durationMinutes", -1)
                schedule.has("durationSeconds") && !schedule.isNull("durationSeconds") -> {
                    val seconds = schedule.optLong("durationSeconds", -1L)
                    if (seconds <= 0L) -1 else (seconds / 60L).toInt()
                }
                else -> -1
            }

        if (limitMinutes <= 0) return false

        val targetPackages = extractTargetPackages(schedule)
        if (targetPackages.isEmpty()) return false

        val activationTimestamp = resolveActivationTimestamp(schedule, nowMs)
        val usageByPackage =
            UsageEventsSessionCalculator.getSessionUsage(
                context = context,
                packageNames = targetPackages,
                activationTimestamp = activationTimestamp,
                nowMs = nowMs,
            )
        val usedMs = targetPackages.sumOf { usageByPackage[it] ?: 0L }
        return usedMs >= limitMinutes.toLong() * 60_000L
    }

    private fun isAmnestyActive(context: Context, nowMs: Long): Boolean {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val expiry = prefs.getLong(KEY_AMNESTY_EXPIRY, 0L)
        if (expiry <= 0L) return false
        if (nowMs < expiry) return true
        prefs.edit().putLong(KEY_AMNESTY_EXPIRY, 0L).apply()
        return false
    }

    private fun isPackageTemporarilyUnlocked(
        context: Context,
        packageName: String,
        nowMs: Long,
    ): Boolean {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rawUnlocks = prefs.getString(KEY_TEMP_UNLOCKS, null) ?: return false
        return try {
            val json = JSONObject(rawUnlocks)
            val expiry = json.optLong(packageName, 0L)
            if (expiry > nowMs) {
                true
            } else {
                if (expiry > 0L) {
                    json.remove(packageName)
                    prefs.edit().putString(KEY_TEMP_UNLOCKS, json.toString()).apply()
                }
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun updateCacheIfNeeded(rawJson: String, force: Boolean = false) {
        val safeJson = rawJson.trim().ifEmpty { "[]" }
        if (!force && safeJson == cachedSchedulesRaw) return

        synchronized(cacheLock) {
            if (!force && safeJson == cachedSchedulesRaw) return
            val parsedSchedules = mutableListOf<JSONObject>()
            val parsedIndex = linkedSetOf<String>()

            try {
                val array = JSONArray(safeJson)
                for (i in 0 until array.length()) {
                    val schedule = array.optJSONObject(i) ?: continue
                    parsedSchedules.add(schedule)
                    if (schedule.optBoolean("isActive", true)) {
                        extractTargetPackages(schedule).forEach { parsedIndex.add(it) }
                    }
                }
            } catch (_: Exception) {
                parsedSchedules.clear()
                parsedIndex.clear()
            }

            cachedSchedulesRaw = safeJson
            cachedSchedules = parsedSchedules
            blockedAppsIndex = parsedIndex
        }
    }

    fun shouldIgnorePackage(context: Context, packageName: String): Boolean {
        val normalized = packageName.trim()
        if (normalized.isEmpty()) return true
        if (normalized == context.packageName) return true
        val lowercase = normalized.lowercase()
        if (lowercase == "com.android.systemui") return true
        if (lowercase.contains("launcher")) return true
        if (lowercase.contains("trebuchet")) return true
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

    private fun scheduleTargetsPackage(schedule: JSONObject, packageName: String): Boolean {
        return extractTargetPackages(schedule).any { it == packageName }
    }

    private fun extractTargetPackages(schedule: JSONObject): List<String> {
        val apps = schedule.optJSONArray("targetApps") ?: schedule.optJSONArray("apps") ?: return emptyList()
        val packages = mutableListOf<String>()
        for (i in 0 until apps.length()) {
            val raw = apps.opt(i)
            val packageName =
                when (raw) {
                    is String -> raw.trim()
                    is JSONObject ->
                        listOf(
                            raw.optString("packageName", "").trim(),
                            raw.optString("pkg", "").trim(),
                            raw.optString("id", "").trim(),
                        ).firstOrNull { it.isNotEmpty() }.orEmpty()
                    else -> apps.optString(i, "").trim()
                }
            if (packageName.isNotEmpty()) {
                packages.add(packageName)
            }
        }
        return packages
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

    private fun isMinuteWithinWindow(window: TimeWindow, currentTotalMin: Int): Boolean {
        return if (window.startTotalMin < window.endTotalMin) {
            currentTotalMin >= window.startTotalMin && currentTotalMin < window.endTotalMin
        } else {
            currentTotalMin >= window.startTotalMin || currentTotalMin < window.endTotalMin
        }
    }

    private fun resolveActivationTimestamp(schedule: JSONObject, nowMs: Long): Long {
        val rawTimestamp =
            when {
                schedule.has("activatedAtMs") && !schedule.isNull("activatedAtMs") ->
                    schedule.optLong("activatedAtMs", 0L)
                else -> 0L
            }
        return when {
            rawTimestamp <= 0L -> nowMs
            rawTimestamp > nowMs -> nowMs
            else -> rawTimestamp
        }
    }

    private fun resolvePackageLabel(context: Context, packageName: String): String {
        return try {
            val pm = context.packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(ai).toString()
        } catch (_: Exception) {
            packageName
        }
    }
}
