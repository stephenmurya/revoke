package com.crescence.revoke

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

object UsageInsightsCalculator {
    private const val LOOKBACK_PADDING_MS = 24L * 60L * 60L * 1000L
    private const val THIRTY_MINUTES_MS = 30L * 60L * 1000L
    private const val CONTINUOUS_GAP_MS = 2L * 60L * 1000L

    private data class Session(
        val packageName: String,
        val startMs: Long,
        val endMs: Long,
    )

    private data class Bucket(
        val index: Int,
        val startMs: Long,
        val endMs: Long,
        val label: String,
        val isFuture: Boolean,
    )

    fun getUsageInsights(
        context: Context,
        mode: String,
        anchorDateMs: Long,
        packageName: String?,
        periodDays: Int,
    ): Map<String, Any> {
        val nowMs = System.currentTimeMillis()
        val safeMode =
            when (mode.trim().lowercase(Locale.US)) {
                "week" -> "week"
                "trend" -> "trend"
                else -> "day"
            }
        val safeAnchor = if (anchorDateMs > 0L) anchorDateMs else nowMs
        val safePackage = packageName?.trim()?.takeIf { it.isNotEmpty() }
        val hasUsageAccess =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP &&
                UsageEventsSessionCalculator.hasUsageStatsPermission(context)

        if (!hasUsageAccess) {
            return emptyResult(
                mode = safeMode,
                anchorDateMs = safeAnchor,
                packageName = safePackage,
                periodDays = periodDays,
                hasUsageAccess = false,
                generatedAtMs = nowMs,
            )
        }

        return when (safeMode) {
            "week" -> buildWeekResult(context, safeAnchor, safePackage, nowMs)
            "trend" -> buildTrendResult(context, safeAnchor, safePackage, periodDays, nowMs)
            else -> buildDayResult(context, safeAnchor, safePackage, nowMs)
        }
    }

    private fun buildDayResult(
        context: Context,
        anchorDateMs: Long,
        packageName: String?,
        nowMs: Long,
    ): Map<String, Any> {
        val rangeStart = startOfDay(anchorDateMs)
        val rangeEnd = addDays(rangeStart, 1)
        val queryEnd = minOf(rangeEnd, nowMs).coerceAtLeast(rangeStart)
        val sessions = collectSessions(context, rangeStart, queryEnd, packageName)
        val buckets =
            List(48) { index ->
                val start = rangeStart + (index * THIRTY_MINUTES_MS)
                Bucket(
                    index = index,
                    startMs = start,
                    endMs = start + THIRTY_MINUTES_MS,
                    label = timeLabel(start),
                    isFuture = start > nowMs,
                )
            }
        return buildResult(
            mode = "day",
            anchorDateMs = anchorDateMs,
            packageName = packageName,
            periodDays = 1,
            rangeStart = rangeStart,
            rangeEnd = rangeEnd,
            generatedAtMs = nowMs,
            sessions = sessions,
            buckets = buckets,
            averageDailyUsageMs = sessions.sumOf { it.endMs - it.startMs },
            trendDeltaMs = 0L,
            trendPercent = 0,
        )
    }

    private fun buildWeekResult(
        context: Context,
        anchorDateMs: Long,
        packageName: String?,
        nowMs: Long,
    ): Map<String, Any> {
        val rangeStart = startOfWeek(anchorDateMs)
        val rangeEnd = addDays(rangeStart, 7)
        val queryEnd = minOf(rangeEnd, nowMs).coerceAtLeast(rangeStart)
        val sessions = collectSessions(context, rangeStart, queryEnd, packageName)
        val todayStart = startOfDay(nowMs)
        val buckets =
            List(7) { index ->
                val start = addDays(rangeStart, index)
                Bucket(
                    index = index,
                    startMs = start,
                    endMs = addDays(start, 1),
                    label = SimpleDateFormat("EEE", Locale.getDefault()).format(start),
                    isFuture = start > todayStart,
                )
            }
        val elapsedDays = buckets.count { !it.isFuture }.coerceAtLeast(1)
        val averageMs = sessions.sumOf { it.endMs - it.startMs } / elapsedDays
        return buildResult(
            mode = "week",
            anchorDateMs = anchorDateMs,
            packageName = packageName,
            periodDays = 7,
            rangeStart = rangeStart,
            rangeEnd = rangeEnd,
            generatedAtMs = nowMs,
            sessions = sessions,
            buckets = buckets,
            averageDailyUsageMs = averageMs,
            trendDeltaMs = 0L,
            trendPercent = 0,
        )
    }

    private fun buildTrendResult(
        context: Context,
        anchorDateMs: Long,
        packageName: String?,
        periodDays: Int,
        nowMs: Long,
    ): Map<String, Any> {
        val safeDays = if (periodDays <= 14) 14 else 30
        val todayStart = startOfDay(anchorDateMs)
        val rangeStart = addDays(todayStart, -(safeDays - 1))
        val rangeEnd = minOf(addDays(todayStart, 1), nowMs).coerceAtLeast(rangeStart)
        val previousStart = addDays(rangeStart, -safeDays)
        val previousEnd = rangeStart
        val sessions = collectSessions(context, rangeStart, rangeEnd, packageName)
        val previousSessions = collectSessions(context, previousStart, previousEnd, packageName)
        val buckets =
            List(safeDays) { index ->
                val start = addDays(rangeStart, index)
                Bucket(
                    index = index,
                    startMs = start,
                    endMs = addDays(start, 1),
                    label = SimpleDateFormat("MMM d", Locale.getDefault()).format(start),
                    isFuture = start > todayStart,
                )
            }

        val currentAverage = sessions.sumOf { it.endMs - it.startMs } / safeDays
        val previousAverage = previousSessions.sumOf { it.endMs - it.startMs } / safeDays
        val delta = currentAverage - previousAverage
        val percent =
            if (previousAverage <= 0L) {
                if (currentAverage <= 0L) 0 else 100
            } else {
                ((abs(delta).toDouble() / previousAverage.toDouble()) * 100.0).roundToInt()
            }

        return buildResult(
            mode = "trend",
            anchorDateMs = anchorDateMs,
            packageName = packageName,
            periodDays = safeDays,
            rangeStart = rangeStart,
            rangeEnd = rangeEnd,
            generatedAtMs = nowMs,
            sessions = sessions,
            buckets = buckets,
            averageDailyUsageMs = currentAverage,
            trendDeltaMs = delta,
            trendPercent = percent,
        )
    }

    private fun buildResult(
        mode: String,
        anchorDateMs: Long,
        packageName: String?,
        periodDays: Int,
        rangeStart: Long,
        rangeEnd: Long,
        generatedAtMs: Long,
        sessions: List<Session>,
        buckets: List<Bucket>,
        averageDailyUsageMs: Long,
        trendDeltaMs: Long,
        trendPercent: Int,
    ): Map<String, Any> {
        val bucketUsage = usageByBucket(sessions, buckets)
        val bucketMaps =
            buckets.mapIndexed { index, bucket ->
                val usageMs = bucketUsage.getOrElse(index) { 0L }
                mapOf(
                    "index" to bucket.index,
                    "startMs" to bucket.startMs,
                    "endMs" to bucket.endMs,
                    "label" to bucket.label,
                    "isFuture" to bucket.isFuture,
                    "usageMs" to usageMs,
                    "minutes" to minutesRounded(usageMs),
                )
            }
        val peak =
            bucketMaps
                .filter { it["isFuture"] != true }
                .maxByOrNull { (it["usageMs"] as? Long) ?: 0L }
                ?: emptyMap<String, Any>()
        val usageByPackage =
            sessions
                .groupBy { it.packageName }
                .mapValues { (_, values) -> values.sumOf { it.endMs - it.startMs } }
        val topApps =
            usageByPackage
                .entries
                .filter { it.value > 30_000L }
                .sortedByDescending { it.value }
                .take(20)
                .map { entry ->
                    mapOf(
                        "packageName" to entry.key,
                        "usageMs" to entry.value,
                        "minutes" to minutesRounded(entry.value),
                    )
                }
        val totalUsageMs = sessions.sumOf { it.endMs - it.startMs }
        val trendDirection =
            when {
                trendDeltaMs < 0L -> "down"
                trendDeltaMs > 0L -> "up"
                else -> "flat"
            }

        return mapOf(
            "mode" to mode,
            "packageName" to (packageName ?: ""),
            "anchorDateMs" to anchorDateMs,
            "rangeStartMs" to rangeStart,
            "rangeEndMs" to rangeEnd,
            "generatedAtMs" to generatedAtMs,
            "hasUsageAccess" to true,
            "periodDays" to periodDays,
            "totalUsageMs" to totalUsageMs,
            "totalMinutes" to minutesRounded(totalUsageMs).coerceIn(0, 1440 * periodDays),
            "averageDailyUsageMs" to averageDailyUsageMs,
            "averageDailyMinutes" to minutesRounded(averageDailyUsageMs).coerceAtLeast(0),
            "trendDeltaMs" to trendDeltaMs,
            "trendDeltaMinutes" to minutesRounded(abs(trendDeltaMs)) * if (trendDeltaMs < 0L) -1 else 1,
            "trendPercent" to trendPercent,
            "trendDirection" to trendDirection,
            "buckets" to bucketMaps,
            "bucketMinutes" to bucketMaps.map { (it["minutes"] as? Int) ?: 0 },
            "peak" to peak,
            "topApps" to topApps,
            "longestFocusMs" to longestFocusMs(sessions),
            "longestContinuousUseMs" to longestContinuousUseMs(sessions),
        )
    }

    private fun collectSessions(
        context: Context,
        rangeStart: Long,
        rangeEnd: Long,
        packageFilter: String?,
    ): List<Session> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return emptyList()
        if (rangeEnd <= rangeStart) return emptyList()

        val usageStatsManager =
            context.applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                ?: return emptyList()
        val events = usageStatsManager.queryEvents((rangeStart - LOOKBACK_PADDING_MS).coerceAtLeast(0L), rangeEnd)
        val event = UsageEvents.Event()
        val sessions = mutableListOf<Session>()
        val filter = packageFilter?.trim()?.takeIf { it.isNotEmpty() }
        var activePackage: String? = null
        var activeStartMs = -1L

        fun closeActive(endTimeMs: Long) {
            val pkg = activePackage
            if (!pkg.isNullOrBlank() && activeStartMs > 0L) {
                val clippedStart = activeStartMs.coerceAtLeast(rangeStart)
                val clippedEnd = endTimeMs.coerceIn(rangeStart, rangeEnd)
                if (clippedEnd > clippedStart) {
                    sessions.add(Session(pkg, clippedStart, clippedEnd))
                }
            }
            activePackage = null
            activeStartMs = -1L
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName?.trim().orEmpty()
            val eventTime = event.timeStamp.coerceIn(rangeStart, rangeEnd)

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (activePackage != pkg || activeStartMs <= 0L) {
                        closeActive(eventTime)
                    }
                    if (isTrackablePackage(context, pkg, filter)) {
                        activePackage = pkg
                        activeStartMs = eventTime
                    }
                }

                UsageEvents.Event.MOVE_TO_BACKGROUND,
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (activePackage == pkg) {
                        closeActive(eventTime)
                    }
                }
            }
        }

        closeActive(rangeEnd)
        return sessions.sortedBy { it.startMs }
    }

    private fun isTrackablePackage(
        context: Context,
        packageName: String,
        packageFilter: String?,
    ): Boolean {
        val normalized = packageName.trim().lowercase(Locale.US)
        if (normalized.isEmpty()) return false
        if (normalized == context.packageName.lowercase(Locale.US)) return false
        if (normalized == "android") return false
        if (normalized.contains("systemui")) return false
        if (normalized.contains("launcher")) return false
        if (EnforcementEngine.isWhitelistedPackage(context, packageName.trim())) return false
        return packageFilter == null || packageName.trim() == packageFilter
    }

    private fun usageByBucket(sessions: List<Session>, buckets: List<Bucket>): LongArray {
        val result = LongArray(buckets.size)
        for (session in sessions) {
            for (bucket in buckets) {
                val overlapStart = maxOf(session.startMs, bucket.startMs)
                val overlapEnd = minOf(session.endMs, bucket.endMs)
                if (overlapEnd > overlapStart) {
                    result[bucket.index] = result[bucket.index] + (overlapEnd - overlapStart)
                }
            }
        }
        return result
    }

    private fun longestFocusMs(sessions: List<Session>): Long {
        val normalized = mergeOverlapping(sessions)
        if (normalized.size < 2) return 0L
        var longest = 0L
        for (index in 1 until normalized.size) {
            val previous = normalized[index - 1]
            val current = normalized[index]
            if (!sameLocalDay(previous.endMs, current.startMs)) continue
            val gap = current.startMs - previous.endMs
            if (gap > longest) longest = gap
        }
        return longest
    }

    private fun longestContinuousUseMs(sessions: List<Session>): Long {
        val normalized = mergeOverlapping(sessions)
        if (normalized.isEmpty()) return 0L
        var chainStart = normalized.first().startMs
        var chainEnd = normalized.first().endMs
        var longest = chainEnd - chainStart

        for (session in normalized.drop(1)) {
            val gap = session.startMs - chainEnd
            if (gap <= CONTINUOUS_GAP_MS) {
                chainEnd = maxOf(chainEnd, session.endMs)
            } else {
                longest = maxOf(longest, chainEnd - chainStart)
                chainStart = session.startMs
                chainEnd = session.endMs
            }
        }
        return maxOf(longest, chainEnd - chainStart)
    }

    private fun mergeOverlapping(sessions: List<Session>): List<Session> {
        if (sessions.isEmpty()) return emptyList()
        val sorted = sessions.sortedBy { it.startMs }
        val merged = mutableListOf<Session>()
        var current = sorted.first()
        for (session in sorted.drop(1)) {
            if (session.startMs <= current.endMs) {
                current = current.copy(endMs = maxOf(current.endMs, session.endMs))
            } else {
                merged.add(current)
                current = session
            }
        }
        merged.add(current)
        return merged
    }

    private fun sameLocalDay(aMs: Long, bMs: Long): Boolean {
        val a =
            Calendar.getInstance().apply {
                timeInMillis = aMs
            }
        val b =
            Calendar.getInstance().apply {
                timeInMillis = bMs
            }
        return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    }

    private fun startOfDay(timestampMs: Long): Long =
        Calendar.getInstance().apply {
            timeInMillis = timestampMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun startOfWeek(timestampMs: Long): Long =
        Calendar.getInstance().apply {
            timeInMillis = timestampMs
            firstDayOfWeek = Calendar.MONDAY
            set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun addDays(timestampMs: Long, days: Int): Long =
        Calendar.getInstance().apply {
            timeInMillis = timestampMs
            add(Calendar.DAY_OF_YEAR, days)
        }.timeInMillis

    private fun timeLabel(timestampMs: Long): String =
        SimpleDateFormat("h:mm a", Locale.getDefault()).format(timestampMs)

    private fun minutesRounded(ms: Long): Int =
        ((ms.coerceAtLeast(0L) + 59_999L) / 60_000L).toInt()

    private fun emptyResult(
        mode: String,
        anchorDateMs: Long,
        packageName: String?,
        periodDays: Int,
        hasUsageAccess: Boolean,
        generatedAtMs: Long,
    ): Map<String, Any> =
        mapOf(
            "mode" to mode,
            "packageName" to (packageName ?: ""),
            "anchorDateMs" to anchorDateMs,
            "rangeStartMs" to 0L,
            "rangeEndMs" to 0L,
            "generatedAtMs" to generatedAtMs,
            "hasUsageAccess" to hasUsageAccess,
            "periodDays" to periodDays,
            "totalUsageMs" to 0L,
            "totalMinutes" to 0,
            "averageDailyUsageMs" to 0L,
            "averageDailyMinutes" to 0,
            "trendDeltaMs" to 0L,
            "trendDeltaMinutes" to 0,
            "trendPercent" to 0,
            "trendDirection" to "flat",
            "buckets" to emptyList<Map<String, Any>>(),
            "bucketMinutes" to emptyList<Int>(),
            "peak" to emptyMap<String, Any>(),
            "topApps" to emptyList<Map<String, Any>>(),
            "longestFocusMs" to 0L,
            "longestContinuousUseMs" to 0L,
        )
}
