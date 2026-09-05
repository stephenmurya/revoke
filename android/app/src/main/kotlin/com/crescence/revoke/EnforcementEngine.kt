package com.crescence.revoke

import android.content.Context
import android.graphics.drawable.Drawable
import org.json.JSONArray
import org.json.JSONObject
import java.text.DateFormat
import java.util.Calendar
import java.util.Date
import kotlin.random.Random

object EnforcementEngine {
    private const val PREFS_NAME = "RevokeConfig"
    private const val KEY_SCHEDULES = "schedules"
    private const val KEY_TEMP_UNLOCKS = "temp_unlocks"
    private const val KEY_AMNESTY_EXPIRY = "amnesty_expiry"
    private const val KEY_OVERLAY_HAS_SQUAD = "overlay_has_squad"
    private const val KEY_WHITELIST_PACKAGES = "whitelist_packages"
    private const val TAG = "RevokeEngine"
    private const val MILLIS_PER_MINUTE = 60_000L
    private const val MILLIS_PER_DAY = 24L * 60L * 60L * 1000L

    private data class TimeWindow(
        val startTotalMin: Int,
        val endTotalMin: Int,
    )

    private data class WindowOccurrence(
        val startMs: Long,
        val endMs: Long,
    )

    private data class BlockMatch(
        val appName: String,
        val packageName: String,
        val commitmentId: String,
        val blockState: BlockState,
        val regimeName: String,
        val blockedSinceMs: Long?,
        val nextUnlockMs: Long?,
        val limitMinutes: Int?,
        val usedMs: Long?,
        val activationTimestamp: Long?,
    )

    private data class UsageBudgetMatch(
        val appName: String,
        val packageName: String,
        val regimeName: String,
        val usedMs: Long,
        val limitMs: Long,
        val remainingMs: Long,
    )

    private val cacheLock = Any()
    private val copySelectionLock = Any()

    @Volatile
    private var cachedSchedulesRaw: String = ""

    @Volatile
    private var cachedSchedules: List<JSONObject> = emptyList()

    @Volatile
    private var blockedAppsIndex: Set<String> = emptySet()

    @Volatile
    private var whitelistedPackages: Set<String> = emptySet()

    @Volatile
    private var lastObservedPackage: String = ""

    @Volatile
    private var accessibilityEscapePackage: String = ""

    @Volatile
    private var accessibilityEscapeUntilMs: Long = 0L

    private val lastCopyIndexByKey = mutableMapOf<String, Int>()

    fun ensureLoaded(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        updateCacheIfNeeded(prefs.getString(KEY_SCHEDULES, "[]").orEmpty())
        reloadIgnoredPackages(context)
    }

    fun reloadIgnoredPackages(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        whitelistedPackages =
            (prefs.getStringSet(KEY_WHITELIST_PACKAGES, emptySet()) ?: emptySet())
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .toSet()
    }

    fun isWhitelistedPackage(context: Context, packageName: String): Boolean {
        val normalized = packageName.trim()
        if (normalized.isEmpty()) return false
        reloadIgnoredPackages(context)
        return whitelistedPackages.contains(normalized)
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

    fun syncUserOverlayContext(context: Context, hasSquad: Boolean) {
        context
            .applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_OVERLAY_HAS_SQUAD, hasSquad)
            .apply()
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

    fun beginAccessibilityEscape(packageName: String, holdMs: Long) {
        val normalized = packageName.trim()
        if (normalized.isEmpty()) return
        recordForegroundPackage(normalized)
        accessibilityEscapePackage = normalized
        accessibilityEscapeUntilMs =
            System.currentTimeMillis() + holdMs.coerceAtLeast(250L)
    }

    fun isAccessibilityEscapePending(packageName: String? = null): Boolean {
        val now = System.currentTimeMillis()
        if (accessibilityEscapeUntilMs <= now) {
            accessibilityEscapePackage = ""
            accessibilityEscapeUntilMs = 0L
            return false
        }

        val normalized = packageName?.trim().orEmpty()
        return normalized.isEmpty() || normalized == accessibilityEscapePackage
    }

    fun evaluateLastObservedPackage(
        context: Context,
        source: String,
        shouldLog: Boolean = false,
    ): Boolean {
        val packageName = lastObservedPackage.trim()
        if (packageName.isEmpty()) {
            if (shouldDeferUiToAccessibility(packageName = null, source = source)) {
                return false
            }
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
            if (shouldDeferUiToAccessibility(packageName = null, source = source)) {
                return false
            }
            BlockerOverlayController.hide(appContext, "$source:empty_package")
            return false
        }

        recordForegroundPackage(normalizedPackage)

        if (shouldIgnorePackage(appContext, normalizedPackage)) {
            if (shouldDeferUiToAccessibility(normalizedPackage, source)) {
                return false
            }
            BlockerOverlayController.hide(appContext, "$source:ignored_package")
            return false
        }

        return try {
            val match = findBlockMatch(appContext, normalizedPackage, shouldLog)
            if (match != null) {
                if (shouldDeferUiToAccessibility(normalizedPackage, source)) {
                    return true
                }
                BlockerOverlayController.show(
                    appContext,
                    toBlockPresentation(appContext, match),
                    source,
                )
                true
            } else {
                if (shouldDeferUiToAccessibility(normalizedPackage, source)) {
                    return false
                }
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
    ): String? =
        findBlockMatch(
            context = context.applicationContext,
            packageName = packageName.trim(),
            shouldLog = shouldLog,
        )?.appName

    fun findBlockPresentation(
        context: Context,
        packageName: String,
        shouldLog: Boolean = false,
    ): BlockPresentation? {
        val appContext = context.applicationContext
        val normalizedPackage = packageName.trim()
        if (normalizedPackage.isEmpty()) return null
        val match = findBlockMatch(appContext, normalizedPackage, shouldLog) ?: return null
        return toBlockPresentation(appContext, match)
    }

    fun findReminderPresentation(
        context: Context,
        packageName: String,
        nowMs: Long = System.currentTimeMillis(),
        shouldLog: Boolean = false,
    ): ReminderPresentation? {
        val appContext = context.applicationContext
        val normalizedPackage = packageName.trim()
        if (normalizedPackage.isEmpty()) return null
        val budget =
            findUsageBudgetMatch(
                context = appContext,
                packageName = normalizedPackage,
                nowMs = nowMs,
                shouldLog = shouldLog,
            ) ?: return null
        return ReminderPresentation(
            appName = budget.appName,
            packageName = budget.packageName,
            appIcon = resolvePackageIcon(appContext, budget.packageName),
            regimeName = budget.regimeName,
            usedMs = budget.usedMs,
            limitMs = budget.limitMs,
            remainingMs = budget.remainingMs,
        )
    }

    fun enrichBlockPresentation(
        presentation: BlockPresentation,
        attemptsToday: Int,
    ): BlockPresentation {
        val stats =
            (listOf(BlockStatChip(label = "Attempts today", value = attemptsToday.toString())) +
                presentation.contextualStats)
                .take(3)
        return presentation.copy(attemptsToday = attemptsToday, stats = stats)
    }

    fun hasActiveUsageLimitRegimeNow(
        context: Context,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean {
        ensureLoaded(context)
        val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
        val modelDay = modelDayFromCalendar(calendar)
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

    fun shouldIgnorePackage(context: Context, packageName: String): Boolean {
        val normalized = packageName.trim()
        if (normalized.isEmpty()) return true
        reloadIgnoredPackages(context)
        if (whitelistedPackages.contains(normalized)) return true
        if (normalized == context.packageName) return true
        val lowercase = normalized.lowercase()
        if (lowercase == "com.android.systemui") return true
        if (lowercase.contains("launcher")) return true
        if (lowercase.contains("trebuchet")) return true
        return false
    }

    private fun findBlockMatch(
        context: Context,
        packageName: String,
        shouldLog: Boolean,
    ): BlockMatch? {
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
            val modelDay = modelDayFromCalendar(calendar)
            val currentTotalMin =
                calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)

            for (schedule in cachedSchedules) {
                if (!schedule.optBoolean("isActive", true)) continue
                if (!scheduleMatchesDay(schedule, modelDay)) continue
                if (!scheduleTargetsPackage(schedule, packageName)) continue

                val match =
                    when (schedule.optInt("type", 0)) {
                        0 -> evaluateTimeBlockMatch(context, schedule, packageName, currentTotalMin, nowMs)
                        1 -> evaluateUsageLimitMatch(context, schedule, packageName, currentTotalMin, nowMs)
                        else -> null
                    }
                if (match != null) {
                    return match
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

    private fun findUsageBudgetMatch(
        context: Context,
        packageName: String,
        nowMs: Long,
        shouldLog: Boolean,
    ): UsageBudgetMatch? {
        return try {
            if (isAmnestyActive(context, nowMs)) {
                if (shouldLog) android.util.Log.d(TAG, "Amnesty active. Skipping reminder $packageName")
                return null
            }
            if (isPackageTemporarilyUnlocked(context, packageName, nowMs)) {
                if (shouldLog) android.util.Log.d(TAG, "Temp unlock active. Skipping reminder $packageName")
                return null
            }

            ensureLoaded(context)
            if (!blockedAppsIndex.contains(packageName)) return null

            val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
            val modelDay = modelDayFromCalendar(calendar)
            val currentTotalMin =
                calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)

            for (schedule in cachedSchedules) {
                if (!schedule.optBoolean("isActive", true)) continue
                if (schedule.optInt("type", 0) != 1) continue
                if (!scheduleMatchesDay(schedule, modelDay)) continue
                if (!scheduleTargetsPackage(schedule, packageName)) continue

                val windows = extractTimeWindows(schedule)
                if (windows.isNotEmpty() && !windows.any { isMinuteWithinWindow(it, currentTotalMin) }) {
                    continue
                }

                val limitMinutes = resolveLimitMinutes(schedule)
                if (limitMinutes <= 0) continue

                val targetPackages = extractTargetPackages(schedule)
                if (targetPackages.isEmpty()) continue

                val activationTimestamp = resolveActivationTimestamp(schedule, nowMs)
                val usageByPackage =
                    UsageEventsSessionCalculator.getSessionUsage(
                        context = context,
                        packageNames = targetPackages,
                        activationTimestamp = activationTimestamp,
                        nowMs = nowMs,
                    )
                val usedMs = targetPackages.sumOf { usageByPackage[it] ?: 0L }
                val limitMs = limitMinutes.toLong() * MILLIS_PER_MINUTE
                if (usedMs >= limitMs) continue

                return UsageBudgetMatch(
                    appName = resolvePackageLabel(context, packageName),
                    packageName = packageName,
                    regimeName = resolveRegimeName(schedule),
                    usedMs = usedMs,
                    limitMs = limitMs,
                    remainingMs = limitMs - usedMs,
                )
            }

            null
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = context,
                source = "EnforcementEngine",
                message = "Failed to evaluate reminder budget.",
                error = error,
                extraKeys = mapOf("packageName" to packageName),
            )
            null
        }
    }

    private fun evaluateTimeBlockMatch(
        context: Context,
        schedule: JSONObject,
        packageName: String,
        currentTotalMin: Int,
        nowMs: Long,
    ): BlockMatch? {
        val windows = extractTimeWindows(schedule)
        if (windows.isEmpty()) return null
        val activeWindow =
            windows
                .firstOrNull { isMinuteWithinWindow(it, currentTotalMin) }
                ?.let { window -> currentDayOccurrence(nowMs, window) }
                ?: return null

        return BlockMatch(
            appName = resolvePackageLabel(context, packageName),
            packageName = packageName,
            commitmentId = schedule.optString("id", "").trim(),
            blockState = BlockState.TIME_BLOCK,
            regimeName = resolveRegimeName(schedule),
            blockedSinceMs = activeWindow.startMs,
            nextUnlockMs = activeWindow.endMs,
            limitMinutes = null,
            usedMs = null,
            activationTimestamp = null,
        )
    }

    private fun evaluateUsageLimitMatch(
        context: Context,
        schedule: JSONObject,
        packageName: String,
        currentTotalMin: Int,
        nowMs: Long,
    ): BlockMatch? {
        val windows = extractTimeWindows(schedule)
        val limitMinutes = resolveLimitMinutes(schedule)

        if (windows.isNotEmpty() && !windows.any { isMinuteWithinWindow(it, currentTotalMin) }) {
            return BlockMatch(
                appName = resolvePackageLabel(context, packageName),
                packageName = packageName,
                commitmentId = schedule.optString("id", "").trim(),
                blockState = BlockState.WINDOW_CLOSED,
                regimeName = resolveRegimeName(schedule),
                blockedSinceMs = resolvePreviousWindowEnd(schedule, windows, nowMs) ?: nowMs,
                nextUnlockMs = resolveNextWindowStart(schedule, windows, nowMs),
                limitMinutes = limitMinutes.takeIf { it > 0 },
                usedMs = null,
                activationTimestamp = null,
            )
        }

        if (limitMinutes <= 0) return null

        val targetPackages = extractTargetPackages(schedule)
        if (targetPackages.isEmpty()) return null

        val activationTimestamp = resolveActivationTimestamp(schedule, nowMs)
        val usageByPackage =
            UsageEventsSessionCalculator.getSessionUsage(
                context = context,
                packageNames = targetPackages,
                activationTimestamp = activationTimestamp,
                nowMs = nowMs,
            )
        val usedMs = targetPackages.sumOf { usageByPackage[it] ?: 0L }
        val limitMs = limitMinutes.toLong() * MILLIS_PER_MINUTE
        if (usedMs < limitMs) return null

        return BlockMatch(
            appName = resolvePackageLabel(context, packageName),
            packageName = packageName,
            commitmentId = schedule.optString("id", "").trim(),
            blockState = BlockState.USAGE_LIMIT_REACHED,
            regimeName = resolveRegimeName(schedule),
            blockedSinceMs = null,
            nextUnlockMs = resolveUsageLimitNextUnlock(schedule, windows, nowMs),
            limitMinutes = limitMinutes,
            usedMs = usedMs,
            activationTimestamp = activationTimestamp,
        )
    }

    private fun toBlockPresentation(
        context: Context,
        match: BlockMatch,
    ): BlockPresentation {
        val hasSquad =
            context
                .applicationContext
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_OVERLAY_HAS_SQUAD, false)

        return BlockPresentation(
            appName = match.appName,
            packageName = match.packageName,
            commitmentId = match.commitmentId,
            appIcon = resolvePackageIcon(context, match.packageName),
            blockState = match.blockState,
            regimeName = match.regimeName,
            headlineAccent = buildHeadlineAccent(match.blockState),
            headlineMain = buildHeadlineMain(match),
            explanatoryLine = buildExplanatoryLine(match),
            secondaryLine = buildSecondaryLine(match, hasSquad),
            contextualStats = buildContextualStats(match),
            hasSquad = hasSquad,
        )
    }

    private fun buildHeadlineAccent(blockState: BlockState): String =
        when (blockState) {
            BlockState.TIME_BLOCK ->
                pickCopy(
                    "accent_time_block",
                    listOf("COOKED", "BLOCKED", "DENIED"),
                )
            BlockState.USAGE_LIMIT_REACHED ->
                pickCopy(
                    "accent_usage_limit_reached",
                    listOf("TIME'S UP", "LIMIT HIT", "DENIED"),
                )
            BlockState.WINDOW_CLOSED ->
                pickCopy(
                    "accent_window_closed",
                    listOf("BLOCKED", "DENIED", "CLOSED"),
                )
        }

    private fun buildHeadlineMain(match: BlockMatch): String =
        when (match.blockState) {
            BlockState.TIME_BLOCK ->
                pickCopy(
                    "headline_time_block",
                    listOf(
                        "${match.appName} is locked",
                        "${match.appName} can wait",
                        "${match.appName} is off-limits",
                    ),
                )
            BlockState.USAGE_LIMIT_REACHED ->
                pickCopy(
                    "headline_usage_limit_reached",
                    listOf(
                        "${match.appName} limit reached",
                        "${match.appName} session ended",
                        "${match.appName} can wait",
                    ),
                )
            BlockState.WINDOW_CLOSED ->
                pickCopy(
                    "headline_window_closed",
                    listOf(
                        "${match.appName} can wait",
                        "${match.appName} is off-limits",
                        "${match.appName} stays closed",
                    ),
                )
        }

    private fun buildExplanatoryLine(match: BlockMatch): String {
        val unlockLabel = match.nextUnlockMs?.let(::formatShortTime)
        val limitLabel = match.limitMinutes?.let(::formatCompactMinutes)
        return when (match.blockState) {
            BlockState.TIME_BLOCK ->
                if (unlockLabel != null) {
                    pickCopy(
                        "explain_time_block",
                        listOf(
                    "Blocked by your ${match.regimeName} Commitment until $unlockLabel.",
                    "${match.regimeName} keeps this app locked until $unlockLabel.",
                    "This app stays blocked under ${match.regimeName} until $unlockLabel.",
                        ),
                    )
                } else {
                    "Blocked by your ${match.regimeName} Commitment right now."
                }
            BlockState.USAGE_LIMIT_REACHED -> {
                val safeLimit = limitLabel ?: "daily"
                pickCopy(
                    "explain_usage_limit_reached",
                    listOf(
                        "You used your $safeLimit allowance today.",
                        "Your $safeLimit budget for this app is gone.",
                        "You've used the full $safeLimit limit for this app.",
                    ),
                )
            }
            BlockState.WINDOW_CLOSED ->
                if (unlockLabel != null) {
                    pickCopy(
                        "explain_window_closed",
                        listOf(
                            "Your ${match.regimeName} window opens at $unlockLabel.",
                            "${match.regimeName} does not allow this app again until $unlockLabel.",
                            "This app is outside the current ${match.regimeName} window until $unlockLabel.",
                        ),
                    )
                } else {
                    "This app is outside the current ${match.regimeName} window."
                }
        }
    }

    private fun buildSecondaryLine(match: BlockMatch, hasSquad: Boolean): String {
        if (!hasSquad) {
            return pickCopy(
                "secondary_no_squad_${match.blockState.name.lowercase()}",
                listOf(
                    "Circle is optional. Request short access for yourself or set one up.",
                    "You can request short access without a Circle.",
                    "Set up a Circle only when you want shared accountability.",
                ),
            )
        }

        return when (match.blockState) {
            BlockState.TIME_BLOCK ->
                pickCopy(
                    "secondary_time_block",
                    listOf(
                        "Need access? Request a short exception.",
                        "If it matters, request access from your selected authority.",
                        "Need more time? Request access before reopening this app.",
                    ),
                )
            BlockState.USAGE_LIMIT_REACHED ->
                pickCopy(
                    "secondary_usage_limit_reached",
                    listOf(
                        "Need more time? Request a short exception.",
                        "If this matters, request access deliberately.",
                        "Need access? Request it before opening this app again.",
                    ),
                )
            BlockState.WINDOW_CLOSED ->
                pickCopy(
                    "secondary_window_closed",
                    listOf(
                        "Need access? Request a short exception.",
                        "If it cannot wait, request access deliberately.",
                        "Next window is set. Request access if you need an exception.",
                    ),
                )
        }
    }

    private fun buildContextualStats(match: BlockMatch): List<BlockStatChip> =
        when (match.blockState) {
            BlockState.TIME_BLOCK,
            BlockState.WINDOW_CLOSED -> {
                val blockedSince =
                    match.blockedSinceMs?.let(::formatShortTime)
                        ?: "Now"
                val nextUnlock =
                    match.nextUnlockMs?.let(::formatShortTime)
                        ?: "TBD"
                listOf(
                    BlockStatChip(label = "Blocked since", value = blockedSince),
                    BlockStatChip(label = "Next unlock", value = nextUnlock),
                )
            }
            BlockState.USAGE_LIMIT_REACHED -> {
                val usedMinutes =
                    ((match.usedMs ?: 0L) + MILLIS_PER_MINUTE - 1L) / MILLIS_PER_MINUTE
                val allowanceValue =
                    if (match.limitMinutes != null && match.limitMinutes > 0) {
                        "${formatCompactMinutes(usedMinutes.toInt())} / ${formatCompactMinutes(match.limitMinutes)}"
                    } else {
                        formatCompactMinutes(usedMinutes.toInt())
                    }
                val secondChip =
                    match.nextUnlockMs?.let {
                        BlockStatChip(label = "Next unlock", value = formatShortTime(it))
                    }
                        ?: BlockStatChip(
                            label = "Session started",
                            value = match.activationTimestamp?.let(::formatShortTime) ?: "Now",
                        )
                listOf(
                    BlockStatChip(label = "Allowance used", value = allowanceValue),
                    secondChip,
                )
            }
        }

    private fun resolveLimitMinutes(schedule: JSONObject): Int =
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

    private fun resolveUsageLimitNextUnlock(
        schedule: JSONObject,
        windows: List<TimeWindow>,
        nowMs: Long,
    ): Long? =
        if (windows.isNotEmpty()) {
            resolveNextWindowStart(schedule, windows, nowMs)
        } else {
            resolveNextUsageLimitDayStart(schedule, nowMs)
        }

    private fun resolveNextUsageLimitDayStart(schedule: JSONObject, nowMs: Long): Long? {
        val todayStart = startOfDay(nowMs)
        for (offset in 1..8) {
            val candidateStart = todayStart + offset * MILLIS_PER_DAY
            if (scheduleMatchesDay(schedule, modelDayFromMillis(candidateStart))) {
                return candidateStart
            }
        }
        return null
    }

    private fun resolvePreviousWindowEnd(
        schedule: JSONObject,
        windows: List<TimeWindow>,
        nowMs: Long,
    ): Long? {
        val todayStart = startOfDay(nowMs)
        var latest: Long? = null
        for (offset in -7..0) {
            val dayStart = todayStart + offset * MILLIS_PER_DAY
            if (!scheduleMatchesDay(schedule, modelDayFromMillis(dayStart))) continue
            for (window in windows) {
                val occurrence = occurrenceForDay(dayStart, window)
                if (occurrence.endMs <= nowMs && (latest == null || occurrence.endMs > latest)) {
                    latest = occurrence.endMs
                }
            }
        }
        return latest
    }

    private fun resolveNextWindowStart(
        schedule: JSONObject,
        windows: List<TimeWindow>,
        nowMs: Long,
    ): Long? {
        val todayStart = startOfDay(nowMs)
        var earliest: Long? = null
        for (offset in 0..8) {
            val dayStart = todayStart + offset * MILLIS_PER_DAY
            if (!scheduleMatchesDay(schedule, modelDayFromMillis(dayStart))) continue
            for (window in windows) {
                val startMs = dayStart + window.startTotalMin * MILLIS_PER_MINUTE
                if (startMs <= nowMs) continue
                if (earliest == null || startMs < earliest) {
                    earliest = startMs
                }
            }
        }
        return earliest
    }

    private fun currentDayOccurrence(nowMs: Long, window: TimeWindow): WindowOccurrence {
        val dayStart = startOfDay(nowMs)
        return occurrenceForDay(dayStart, window)
    }

    private fun occurrenceForDay(dayStart: Long, window: TimeWindow): WindowOccurrence {
        val startMs = dayStart + window.startTotalMin * MILLIS_PER_MINUTE
        val endMs =
            if (window.startTotalMin < window.endTotalMin) {
                dayStart + window.endTotalMin * MILLIS_PER_MINUTE
            } else {
                dayStart + MILLIS_PER_DAY + window.endTotalMin * MILLIS_PER_MINUTE
            }
        return WindowOccurrence(startMs = startMs, endMs = endMs)
    }

    private fun startOfDay(timeMs: Long): Long {
        val calendar = Calendar.getInstance().apply {
            timeInMillis = timeMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return calendar.timeInMillis
    }

    private fun modelDayFromMillis(timeMs: Long): Int =
        modelDayFromCalendar(Calendar.getInstance().apply { timeInMillis = timeMs })

    private fun modelDayFromCalendar(calendar: Calendar): Int =
        calendar.get(Calendar.DAY_OF_WEEK).let { day ->
            if (day == Calendar.SUNDAY) 7 else day - 1
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

    private fun shouldDeferUiToAccessibility(packageName: String?, source: String): Boolean {
        if (source.startsWith("accessibility")) return false
        return isAccessibilityEscapePending(packageName)
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

    private fun isMinuteWithinWindow(window: TimeWindow, currentTotalMin: Int): Boolean =
        if (window.startTotalMin < window.endTotalMin) {
            currentTotalMin >= window.startTotalMin && currentTotalMin < window.endTotalMin
        } else {
            currentTotalMin >= window.startTotalMin || currentTotalMin < window.endTotalMin
        }

    private fun resolveActivationTimestamp(schedule: JSONObject, nowMs: Long): Long {
        val rawTimestamp =
            when {
                schedule.has("activatedAtMs") && !schedule.isNull("activatedAtMs") ->
                    schedule.optLong("activatedAtMs", 0L)
                else -> 0L
        }
        val boundedTimestamp =
            when {
                rawTimestamp <= 0L -> nowMs
                rawTimestamp > nowMs -> nowMs
                else -> rawTimestamp
            }
        return UsageEventsSessionCalculator.effectiveDailyStartMs(
            activationTimestamp = boundedTimestamp,
            nowMs = nowMs,
        )
    }

    private fun resolvePackageLabel(context: Context, packageName: String): String =
        try {
            val pm = context.packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(ai).toString()
        } catch (_: Exception) {
            packageName
        }

    private fun resolvePackageIcon(context: Context, packageName: String): Drawable? =
        try {
            context.packageManager.getApplicationIcon(packageName)
        } catch (_: Exception) {
            null
        }

    private fun resolveRegimeName(schedule: JSONObject): String {
        val raw = schedule.optString("name", "").trim()
        return if (raw.isEmpty()) "Focus Lock" else raw
    }

    private fun formatShortTime(timeMs: Long): String {
        val formatter = DateFormat.getTimeInstance(DateFormat.SHORT)
        return formatter.format(Date(timeMs))
    }

    private fun formatCompactMinutes(totalMinutes: Int): String {
        if (totalMinutes <= 0) return "0m"
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return when {
            hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
            hours > 0 -> "${hours}h"
            else -> "${minutes}m"
        }
    }

    private fun pickCopy(key: String, options: List<String>): String {
        if (options.isEmpty()) return ""
        if (options.size == 1) return options.first()

        synchronized(copySelectionLock) {
            val lastIndex = lastCopyIndexByKey[key]
            var nextIndex = Random.nextInt(options.size)
            if (lastIndex != null && options.size > 1) {
                while (nextIndex == lastIndex) {
                    nextIndex = Random.nextInt(options.size)
                }
            }
            lastCopyIndexByKey[key] = nextIndex
            return options[nextIndex]
        }
    }
}
