package com.crescence.revoke

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class AppMonitorService : Service() {
    companion object {
        @Volatile
        private var running: Boolean = false
        @Volatile
        private var currentInstance: AppMonitorService? = null

        fun isRunning(): Boolean = running

        fun syncSchedulesAndEvaluate(schedulesJson: String, trigger: String): Boolean {
            val instance = currentInstance ?: return false
            instance.handler.post {
                instance.handleScheduleSync(schedulesJson, trigger)
            }
            return true
        }

        fun requestImmediateForegroundEvaluation(trigger: String): Boolean {
            val instance = currentInstance ?: return false
            instance.handler.post {
                instance.forceEvaluateForegroundApp(trigger)
            }
            return true
        }

        fun stopForAccountSwitch(context: Context) {
            currentInstance?.suppressAutoRestart = true
            context.applicationContext.stopService(
                Intent(context.applicationContext, AppMonitorService::class.java),
            )
        }
    }

    private data class TimeWindow(val startTotalMin: Int, val endTotalMin: Int)

    private val handler = Handler(Looper.getMainLooper())
    private var lastKnownForegroundPackage: String = ""
    private var lastLoggedApp: String = ""
    private var lastUsageStatsFallbackAt: Long = 0L
    private var lastEventsQueryAt: Long = 0L
    private var activeSchedules: java.util.concurrent.CopyOnWriteArrayList<org.json.JSONObject> = java.util.concurrent.CopyOnWriteArrayList()
    private var blockedAppsIndex: HashSet<String> = HashSet()
    private val tempUnlockedPackages = mutableMapOf<String, Long>()
    private val usageStatsFallbackIntervalMs = 12_000L
    private var lastAmnestyLogAt: Long = 0L
    private var lastRestrictedDetectedAt: Long = 0L
    private var lastHealthWriteAt: Long = 0L
    private var cachedRiskWindow: Boolean = false
    private var lastRiskEvalAt: Long = 0L
    private var monitorLoopStarted: Boolean = false
    private var suppressAutoRestart: Boolean = false
    private lateinit var prefs: android.content.SharedPreferences

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        try {
            running = true
            currentInstance = this
            prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)

            EnforcementEngine.ensureLoaded(this)
            android.util.Log.d(
                "RevokeMonitor",
                "Loaded ${EnforcementEngine.getScheduleCount(this)} persisted schedules",
            )
            loadTempUnlocks()

            startForegroundService()

            // CRITICAL: Start the monitoring loop
            startMonitorLoopIfNeeded()
            android.util.Log.d("RevokeMonitor", "Monitoring loop started")
        } catch (error: Exception) {
            AppMonitorCoordinator.recordServiceException(this, "onCreate", error)
            throw error
        }
    }

    private fun startMonitorLoopIfNeeded() {
        if (monitorLoopStarted) return
        suppressAutoRestart = false
        monitorLoopStarted = true
        handler.post(runnable)
    }

    private fun startForegroundService() {
        val channelId = "AppMonitorChannel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "App Monitor Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Revoke is active")
            .setContentText("Guarding your focus.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(1, notification)
        }
    }

    private val runnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            var nextDelayMs = 5_000L
            try {
                if (shouldStopForIdle(now)) {
                    android.util.Log.d(
                        "RevokeMonitor",
                        "No active regimes or temporary overrides. Stopping foreground service."
                    )
                    stopMonitoringForIdle()
                    return
                }

                writeSelfHealth(now)

                if (!isScreenInteractive()) {
                    BlockerOverlayController.hide(this@AppMonitorService, "screen_not_interactive")
                    nextDelayMs = 10_000L
                } else {
                    val fastPathActive = AccessibilityPermissionUtils.isFastPathActive(this@AppMonitorService)
                    val restrictedDetected =
                        if (fastPathActive) {
                            maintainEnforcementWhileAccessibilityActive(now)
                        } else {
                            checkForegroundApp(now)
                        }
                    nextDelayMs = computeNextPollDelayMs(now, restrictedDetected, fastPathActive)
                }
            } catch (e: Exception) {
                AppMonitorCoordinator.recordServiceException(
                    this@AppMonitorService,
                    "monitor_loop",
                    e,
                )
                android.util.Log.e("RevokeMonitor", "Error in monitor loop: ${e.message}", e)
                nextDelayMs = 5_000L
            }

            if (monitorLoopStarted && !suppressAutoRestart) {
                handler.postDelayed(this, nextDelayMs)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        suppressAutoRestart = false
        when (intent?.action) {
            "com.revoke.app.SYNC_SCHEDULES" -> {
                val schedulesJson = intent.getStringExtra("schedules")
                if (schedulesJson != null) {
                    handleScheduleSync(schedulesJson, "syncSchedules_intent")
                }
            }
            "com.revoke.app.TEMP_UNLOCK" -> {
                val pkg = intent.getStringExtra("packageName")
                val mins = intent.getIntExtra("minutes", 5)
                if (pkg != null) {
                    val expiry = System.currentTimeMillis() + (mins * 60 * 1000)
                    tempUnlockedPackages[pkg] = expiry
                    persistTempUnlocks()
                    android.util.Log.d("RevokeMonitor", "Temporarily unlocking $pkg for $mins minutes.")
                }
            }
            PackageRemovedReceiver.ACTION_REMOVE_TEMP_UNLOCK -> {
                val packageName = intent.getStringExtra(PackageRemovedReceiver.EXTRA_PACKAGE_NAME)
                    ?.trim()
                    .orEmpty()
                if (packageName.isNotEmpty()) {
                    if (tempUnlockedPackages.remove(packageName) != null) {
                        persistTempUnlocks()
                        android.util.Log.d(
                            "RevokeMonitor",
                            "Removed temporary unlock for uninstalled package: $packageName"
                        )
                    }
                }
            }
        }
        // Loop already started in onCreate()
        startMonitorLoopIfNeeded()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!suppressAutoRestart) {
            scheduleRestart(3_000)
        }
        super.onTaskRemoved(rootIntent)
    }

    private fun writeSelfHealth(now: Long) {
        if (now - lastHealthWriteAt < 5_000L) return
        lastHealthWriteAt = now
        prefs.edit().putLong("monitor_last_tick_ms", now).apply()
    }

    private fun handleScheduleSync(schedulesJson: String, trigger: String) {
        EnforcementEngine.syncSchedules(this, schedulesJson)
        forceEvaluateForegroundApp(trigger)
    }

    private fun forceEvaluateForegroundApp(trigger: String) {
        try {
            val now = System.currentTimeMillis()
            val packageName = resolveForegroundPackage(now)
            val restrictedDetected =
                if (packageName.isNullOrBlank()) {
                    EnforcementEngine.clearForegroundPackage()
                    BlockerOverlayController.hide(this, "$trigger:no_foreground_package")
                    false
                } else {
                    EnforcementEngine.evaluateAndApply(
                        context = this,
                        packageName = packageName,
                        source = trigger,
                        shouldLog = true,
                    )
                }
            resetMonitorLoop(delayMs = 2_000L)
            android.util.Log.d(
                "RevokeMonitor",
                "Forced foreground evaluation completed from $trigger. restricted=$restrictedDetected",
            )
        } catch (error: Exception) {
            AppMonitorCoordinator.recordServiceException(
                this,
                "force_evaluate_foreground_app",
                error,
                extraKeys = mapOf("trigger" to trigger),
            )
        }
    }

    private fun resetMonitorLoop(delayMs: Long = 2_000L) {
        if (!monitorLoopStarted) return
        handler.removeCallbacks(runnable)
        handler.postDelayed(runnable, delayMs)
    }

    private fun isScreenInteractive(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isInteractive
    }

    private fun computeNextPollDelayMs(now: Long, restrictedDetected: Boolean): Long {
        return computeNextPollDelayMs(now, restrictedDetected, fastPathActive = false)
    }

    private fun computeNextPollDelayMs(
        now: Long,
        restrictedDetected: Boolean,
        fastPathActive: Boolean,
    ): Long {
        if (restrictedDetected) return if (fastPathActive) 15_000L else 2_000L

        return if (fastPathActive) {
            if (EnforcementEngine.hasActiveUsageLimitRegimeNow(this, now) || BlockerOverlayController.isShowing()) {
                5_000L
            } else {
                12_000L
            }
        } else if (now - lastRestrictedDetectedAt < 20_000L) {
            2_000L
        } else {
            5_000L
        }
    }

    private fun isRiskWindowNow(now: Long): Boolean {
        if (now - lastRiskEvalAt < 15_000L) return cachedRiskWindow
        cachedRiskWindow = computeRiskWindowNow()
        lastRiskEvalAt = now
        return cachedRiskWindow
    }

    private fun computeRiskWindowNow(): Boolean {
        return getCurrentlyActiveRegimes(System.currentTimeMillis()).isNotEmpty()
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

    private fun toTimeWindow(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ): TimeWindow? {
        if (startHour !in 0..23 || endHour !in 0..23) return null
        if (startMinute !in 0..59 || endMinute !in 0..59) return null
        val startTotalMin = startHour * 60 + startMinute
        val endTotalMin = endHour * 60 + endMinute
        if (startTotalMin == endTotalMin) return null
        return TimeWindow(startTotalMin, endTotalMin)
    }

    private fun extractTimeWindows(schedule: JSONObject): List<TimeWindow> {
        val windows = mutableListOf<TimeWindow>()
        val blocks = schedule.optJSONArray("blocks")
        if (blocks != null) {
            for (i in 0 until blocks.length()) {
                val block = blocks.optJSONObject(i) ?: continue
                val startHour = block.optInt("startHour", -1)
                val startMinute = block.optInt("startMinute", -1)
                val endHour = block.optInt("endHour", -1)
                val endMinute = block.optInt("endMinute", -1)
                val window = toTimeWindow(startHour, startMinute, endHour, endMinute)
                if (window != null) {
                    windows.add(window)
                }
            }
        }
        if (windows.isNotEmpty()) return windows

        val legacyWindow = toTimeWindow(
            schedule.optInt("startHour", -1),
            schedule.optInt("startMinute", -1),
            schedule.optInt("endHour", -1),
            schedule.optInt("endMinute", -1)
        )
        if (legacyWindow != null) {
            windows.add(legacyWindow)
            return windows
        }

        val startTimeRaw = schedule.optString("startTime").trim().takeIf { it.isNotEmpty() }
        val endTimeRaw = schedule.optString("endTime").trim().takeIf { it.isNotEmpty() }
        val startTotalMin = parseHourMinuteStringToTotalMin(startTimeRaw)
        val endTotalMin = parseHourMinuteStringToTotalMin(endTimeRaw)
        if (startTotalMin != null && endTotalMin != null && startTotalMin != endTotalMin) {
            windows.add(TimeWindow(startTotalMin, endTotalMin))
        }

        return windows
    }

    private fun isMinuteWithinWindow(window: TimeWindow, currentTotalMin: Int): Boolean {
        return if (window.startTotalMin < window.endTotalMin) {
            currentTotalMin >= window.startTotalMin && currentTotalMin < window.endTotalMin
        } else {
            currentTotalMin >= window.startTotalMin || currentTotalMin < window.endTotalMin
        }
    }

    private fun isWithinAnyTimeBlock(schedule: JSONObject, currentTotalMin: Int): Boolean {
        val windows = extractTimeWindows(schedule)
        for (window in windows) {
            if (isMinuteWithinWindow(window, currentTotalMin)) {
                return true
            }
        }
        return false
    }

    private fun scheduleRestart(delayMs: Long) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent("com.revoke.app.RESTART_SERVICE").apply {
                setClass(this@AppMonitorService, ServiceRestartReceiver::class.java)
            }
            val pending = PendingIntent.getBroadcast(
                this,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + delayMs.coerceAtLeast(0L),
                pending
            )
        } catch (error: Exception) {
            AppMonitorCoordinator.recordServiceException(this, "schedule_restart", error)
        }
    }

    private fun checkTempUnlock(packageName: String): Boolean {
        val expiry = tempUnlockedPackages[packageName] ?: return false
        val now = System.currentTimeMillis()

        // If package was uninstalled (or is missing), immediately purge stale approval.
        if (!isPackageInstalled(packageName)) {
            tempUnlockedPackages.remove(packageName)
            persistTempUnlocks()
            android.util.Log.d("RevokeMonitor", "Temp unlock cleared for missing package $packageName")
            return false
        }

        // Keep in-memory approvals aligned with SharedPreferences updates from native receivers.
        val persistedExpiry = getPersistedTempUnlockExpiry(packageName)
        if (persistedExpiry <= now) {
            tempUnlockedPackages.remove(packageName)
            persistTempUnlocks()
            android.util.Log.d("RevokeMonitor", "Temp unlock expired for $packageName")
            return false
        }
        if (persistedExpiry <= 0L) {
            tempUnlockedPackages.remove(packageName)
            return false
        }
        if (persistedExpiry != expiry) {
            tempUnlockedPackages[packageName] = persistedExpiry
        }
        return true
    }

    private fun loadTempUnlocks() {
        val raw = prefs.getString("temp_unlocks", null) ?: return
        val now = System.currentTimeMillis()
        try {
            val json = JSONObject(raw)
            val keys = json.keys()
            while (keys.hasNext()) {
                val pkg = keys.next()
                val expiry = json.optLong(pkg, 0L)
                if (expiry > now && isPackageInstalled(pkg)) {
                    tempUnlockedPackages[pkg] = expiry
                }
            }
            persistTempUnlocks()
        } catch (error: Exception) {
            AppMonitorCoordinator.recordServiceException(this, "load_temp_unlocks", error)
            tempUnlockedPackages.clear()
        }
    }

    private fun persistTempUnlocks() {
        val now = System.currentTimeMillis()
        val json = JSONObject()
        val iterator = tempUnlockedPackages.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            if (entry.value > now && isPackageInstalled(entry.key)) {
                json.put(entry.key, entry.value)
            } else {
                iterator.remove()
            }
        }
        prefs.edit().putString("temp_unlocks", json.toString()).apply()
    }

    private fun getPersistedTempUnlockExpiry(packageName: String): Long {
        val raw = prefs.getString("temp_unlocks", null) ?: return 0L
        return try {
            val json = JSONObject(raw)
            json.optLong(packageName, 0L)
        } catch (_: Exception) {
            0L
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        return try {
            packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun pruneExpiredTempUnlocks(now: Long) {
        var changed = false
        val iterator = tempUnlockedPackages.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            val packageName = entry.key
            val expiry = entry.value
            if (expiry <= now || !isPackageInstalled(packageName)) {
                iterator.remove()
                changed = true
            }
        }

        if (changed) {
            persistTempUnlocks()
        }
    }

    private fun hasActiveTemporaryState(now: Long): Boolean {
        pruneExpiredTempUnlocks(now)
        return tempUnlockedPackages.isNotEmpty() || isAmnestyActive()
    }

    private fun getCurrentlyActiveRegimes(now: Long): List<JSONObject> {
        if (blockedAppsIndex.isEmpty()) return emptyList()

        val calendar = java.util.Calendar.getInstance().apply {
            timeInMillis = now
        }
        val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
        val modelDay = if (dayOfWeek == 1) 7 else dayOfWeek - 1
        val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(java.util.Calendar.MINUTE)
        val currentTotalMin = currentHour * 60 + currentMinute

        val matches = mutableListOf<JSONObject>()
        for (schedule in activeSchedules) {
            if (!schedule.optBoolean("isActive", true)) continue

            val days = schedule.optJSONArray("days") ?: continue
            var dayMatch = false
            for (i in 0 until days.length()) {
                if (days.optInt(i, -1) == modelDay) {
                    dayMatch = true
                    break
                }
            }
            if (!dayMatch) continue

            when (schedule.optInt("type")) {
                0 -> {
                    if (isWithinAnyTimeBlock(schedule, currentTotalMin)) {
                        matches.add(schedule)
                    }
                }
                1 -> {
                    matches.add(schedule)
                }
            }
        }

        return matches
    }

    private fun shouldStopForIdle(now: Long): Boolean {
        return !AppMonitorCoordinator.shouldServiceBeRunning(this, now)
    }

    private fun stopMonitoringForIdle() {
        if (suppressAutoRestart) return

        suppressAutoRestart = true
        monitorLoopStarted = false
        handler.removeCallbacks(runnable)
        BlockerOverlayController.hide(this, "stop_monitoring_for_idle")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun updateSchedules(json: String) {
        try {
            // Persist to SharedPreferences
            prefs.edit().putString("schedules", json).apply()
            
            // Update memory
            val array = org.json.JSONArray(json)
            activeSchedules.clear()
            blockedAppsIndex.clear()
            for (i in 0 until array.length()) {
                val schedule = array.getJSONObject(i)
                activeSchedules.add(schedule)
                // Build an index of targeted packages for fast hot-loop checks.
                if (schedule.optBoolean("isActive", true)) {
                    val apps = schedule.optJSONArray("targetApps")
                    if (apps != null) {
                        for (j in 0 until apps.length()) {
                            val pkg = apps.optString(j, "").trim()
                            if (pkg.isNotEmpty()) blockedAppsIndex.add(pkg)
                        }
                    }
                }
            }
            
            android.util.Log.d("RevokeMonitor", "Synced ${activeSchedules.size} active schedules")
            
            // Visual feedback
            Handler(Looper.getMainLooper()).post {
                android.widget.Toast.makeText(
                    this,
                    "Synced ${activeSchedules.size} Rules",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            }
        } catch (e: Exception) {
            AppMonitorCoordinator.recordServiceException(this, "update_schedules", e)
            android.util.Log.e("RevokeMonitor", "Failed to sync schedules into service.", e)
        }
    }

    override fun onDestroy() {
        running = false
        if (currentInstance === this) {
            currentInstance = null
        }
        handler.removeCallbacks(runnable)
        monitorLoopStarted = false
        if (!suppressAutoRestart) {
            scheduleRestart(5_000)
        }
        super.onDestroy()
    }

    private fun checkForegroundApp(now: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false

        val foregroundPackage = resolveForegroundPackage(now)
        if (foregroundPackage.isNullOrBlank()) {
            if (lastLoggedApp.isNotEmpty()) {
                android.util.Log.d("RevokeMonitor", "No valid foreground app detected")
                lastLoggedApp = ""
            }
            EnforcementEngine.clearForegroundPackage()
            BlockerOverlayController.hide(this, "service_poll:no_foreground_package")
            return false
        }

        if (foregroundPackage == packageName) {
            EnforcementEngine.recordForegroundPackage(foregroundPackage)
            BlockerOverlayController.hide(this, "service_poll:revoke_foreground")
            return false
        }

        val shouldLogLogic = foregroundPackage != lastLoggedApp
        if (shouldLogLogic) {
            android.util.Log.d("RevokeMonitor", "Current App: $foregroundPackage")
            lastLoggedApp = foregroundPackage
        }

        val restrictedDetected =
            EnforcementEngine.evaluateAndApply(
                context = this,
                packageName = foregroundPackage,
                source = "service_poll",
                shouldLog = shouldLogLogic,
            )
        if (restrictedDetected) {
            lastRestrictedDetectedAt = now
        }
        return restrictedDetected
    }

    private fun maintainEnforcementWhileAccessibilityActive(now: Long): Boolean {
        if (BlockerOverlayController.isShowing()) {
            return true
        }

        if (!EnforcementEngine.hasActiveUsageLimitRegimeNow(this, now)) {
            return false
        }

        val restrictedDetected =
            EnforcementEngine.evaluateLastObservedPackage(
                context = this,
                source = "service_accessibility_backstop",
            )
        if (restrictedDetected) {
            lastRestrictedDetectedAt = now
        }
        return restrictedDetected
    }

    private fun resolveForegroundPackage(now: Long): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return null

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val start =
            if (lastEventsQueryAt <= 0L) {
                now - 15_000L
            } else {
                (lastEventsQueryAt - 2_000L).coerceAtLeast(now - 30_000L)
            }
        lastEventsQueryAt = now

        val usageEvents = usageStatsManager.queryEvents(start, now)
        val event = UsageEvents.Event()
        var lastEventTime = 0L
        var foundViaEvents = false

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            ) {
                if (event.timeStamp > lastEventTime) {
                    lastEventTime = event.timeStamp
                    lastKnownForegroundPackage = event.packageName?.toString()?.trim().orEmpty()
                    foundViaEvents = lastKnownForegroundPackage.isNotEmpty()
                }
            }
        }

        val shouldRunUsageStatsFallback =
            (!foundViaEvents || lastKnownForegroundPackage.isEmpty()) &&
                (now - lastUsageStatsFallbackAt >= usageStatsFallbackIntervalMs)

        if (shouldRunUsageStatsFallback) {
            lastUsageStatsFallbackAt = now
            val stats =
                usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    now - 1000L * 60L * 15L,
                    now,
                )
            if (!stats.isNullOrEmpty()) {
                var latestStats: android.app.usage.UsageStats? = null
                for (usageStats in stats) {
                    if (latestStats == null || usageStats.lastTimeUsed > latestStats!!.lastTimeUsed) {
                        latestStats = usageStats
                    }
                }
                if (latestStats != null && (now - latestStats!!.lastTimeUsed) < 1000L * 60L * 5L) {
                    val resolvedPackage = latestStats!!.packageName.orEmpty()
                    if (resolvedPackage.isNotEmpty()) {
                        lastKnownForegroundPackage = resolvedPackage
                    }
                }
            }
        }

        return lastKnownForegroundPackage.takeIf { it.isNotBlank() }
    }


    private fun isAmnestyActive(): Boolean {
        val expiry = prefs.getLong("amnesty_expiry", 0L)
        if (expiry <= 0L) return false

        val now = System.currentTimeMillis()
        if (now >= expiry) {
            prefs.edit().putLong("amnesty_expiry", 0L).apply()
            return false
        }

        if (now - lastAmnestyLogAt > 15_000L) {
            lastAmnestyLogAt = now
            val remainingSec = (expiry - now) / 1000L
            android.util.Log.d(
                "RevokeAmnesty",
                "Amnesty active. Monitoring paused (${remainingSec}s remaining)."
            )
        }
        return true
    }
}
