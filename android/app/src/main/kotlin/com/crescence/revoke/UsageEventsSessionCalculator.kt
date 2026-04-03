package com.crescence.revoke

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

object UsageEventsSessionCalculator {
    fun getSessionUsage(
        context: Context,
        packageNames: Collection<String>,
        activationTimestamp: Long,
        nowMs: Long = System.currentTimeMillis(),
    ): Map<String, Long> {
        val normalizedPackages =
            packageNames
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .toSet()
        val usageByPackage = normalizedPackages.associateWith { 0L }.toMutableMap()
        if (normalizedPackages.isEmpty()) return usageByPackage
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return usageByPackage
        if (!hasUsageStatsPermission(context)) return usageByPackage

        val startMs = activationTimestamp.coerceAtLeast(0L)
        if (startMs <= 0L || nowMs <= startMs) return usageByPackage

        val usageStatsManager =
            context.applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                ?: return usageByPackage

        return try {
            val events = usageStatsManager.queryEvents(startMs, nowMs)
            val event = UsageEvents.Event()
            val lastForegroundTime = mutableMapOf<String, Long>()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val packageName = event.packageName?.trim().orEmpty()
                if (!normalizedPackages.contains(packageName)) continue

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
}
