package com.crescence.revoke

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

object UsageEventsSessionCalculator {
    private const val SESSION_LOOKBACK_MS = 24L * 60L * 60L * 1000L

    fun getSessionUsage(
        context: Context,
        packageNames: Collection<String>,
        activationTimestamp: Long,
        nowMs: Long = System.currentTimeMillis(),
    ): Map<String, Long> {
        val requestedPackages =
            packageNames
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .toSet()
        val trackedPackages =
            requestedPackages
                .filterNot { EnforcementEngine.isWhitelistedPackage(context, it) }
                .toSet()
        val usageByPackage = requestedPackages.associateWith { 0L }.toMutableMap()
        if (trackedPackages.isEmpty()) return usageByPackage
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return usageByPackage
        if (!hasUsageStatsPermission(context)) return usageByPackage

        val startMs = effectiveDailyStartMs(activationTimestamp, nowMs)
        if (startMs <= 0L || nowMs <= startMs) return usageByPackage

        val usageStatsManager =
            context.applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                ?: return usageByPackage

        return try {
            val queryStartMs = (startMs - SESSION_LOOKBACK_MS).coerceAtLeast(0L)
            val events = usageStatsManager.queryEvents(queryStartMs, nowMs)
            val event = UsageEvents.Event()
            val lastForegroundTime = mutableMapOf<String, Long>()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val packageName = event.packageName?.trim().orEmpty()
                if (!trackedPackages.contains(packageName)) continue

                when (event.eventType) {
                    UsageEvents.Event.MOVE_TO_FOREGROUND,
                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        lastForegroundTime[packageName] = event.timeStamp.coerceAtLeast(startMs)
                    }

                    UsageEvents.Event.MOVE_TO_BACKGROUND,
                    UsageEvents.Event.ACTIVITY_PAUSED,
                    UsageEvents.Event.ACTIVITY_STOPPED -> {
                        val foregroundStart = lastForegroundTime.remove(packageName) ?: continue
                        if (event.timeStamp > foregroundStart) {
                            usageByPackage[packageName] =
                                (usageByPackage[packageName] ?: 0L) +
                                    (event.timeStamp - foregroundStart)
                        }
                    }
                }
            }

            for ((packageName, foregroundStart) in lastForegroundTime) {
                if (nowMs > foregroundStart) {
                    usageByPackage[packageName] =
                        (usageByPackage[packageName] ?: 0L) + (nowMs - foregroundStart)
                }
            }

            usageByPackage
        } catch (_: Exception) {
            usageByPackage
        }
    }

    fun hasUsageStatsPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode =
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun effectiveDailyStartMs(
        activationTimestamp: Long,
        nowMs: Long = System.currentTimeMillis(),
    ): Long {
        val todayStart =
            java.util.Calendar.getInstance().apply {
                timeInMillis = nowMs
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }.timeInMillis
        val safeActivation = activationTimestamp.coerceAtLeast(0L)
        return maxOf(safeActivation, todayStart)
    }
}
