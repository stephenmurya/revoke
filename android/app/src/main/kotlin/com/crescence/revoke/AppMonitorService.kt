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
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class AppMonitorService : Service() {
    companion object {
        @Volatile
        private var running: Boolean = false

        fun isRunning(): Boolean = running
    }

    private data class TimeWindow(val startTotalMin: Int, val endTotalMin: Int)

    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var overlayView: android.view.View? = null
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
    private var lastBlockedEventPackage: String = ""
    private var lastBlockedEventAtMs: Long = 0L
    private lateinit var prefs: android.content.SharedPreferences

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        running = true
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        
        // Load persisted schedules
        val savedSchedules = prefs.getString("schedules", null)
        if (savedSchedules != null) {
            updateSchedules(savedSchedules)
            android.util.Log.d("RevokeMonitor", "Loaded ${activeSchedules.size} persisted schedules")
        }
        loadTempUnlocks()
        
        startForegroundService()
        
        // CRITICAL: Start the monitoring loop
        startMonitorLoopIfNeeded()
        android.util.Log.d("RevokeMonitor", "Monitoring loop started")
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
                    hideBlockerOverlay()
                    nextDelayMs = 10_000L
                } else {
                    val restrictedDetected = checkForegroundApp(now)
                    nextDelayMs = computeNextPollDelayMs(now, restrictedDetected)
                }
            } catch (e: Exception) {
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
                    updateSchedules(schedulesJson)
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

    private fun isScreenInteractive(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isInteractive
    }

    private fun computeNextPollDelayMs(now: Long, restrictedDetected: Boolean): Long {
        if (restrictedDetected) return 2_000L

        // Stay in fast mode briefly after a block to reduce "open app then slip past" windows.
        if (now - lastRestrictedDetectedAt < 20_000L) return 2_000L

        return if (isRiskWindowNow(now)) 5_000L else 9_000L
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
        } catch (_: Exception) {
            // Best effort.
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
        } catch (_: Exception) {
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
        val activeRegimes = getCurrentlyActiveRegimes(now)
        return activeRegimes.isEmpty() && !hasActiveTemporaryState(now)
    }

    private fun stopMonitoringForIdle() {
        if (suppressAutoRestart) return

        suppressAutoRestart = true
        monitorLoopStarted = false
        handler.removeCallbacks(runnable)
        hideBlockerOverlay()

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
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(runnable)
        monitorLoopStarted = false
        if (!suppressAutoRestart) {
            scheduleRestart(5_000)
        }
        super.onDestroy()
    }

    private fun checkForegroundApp(now: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false
        if (isAmnestyActive()) {
            hideBlockerOverlay()
            return false
        }

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // queryEvents is cheaper than queryUsageStats, but it can still be heavy if the window is too large.
        // Scan only recent events and keep fallback logic for reliability.
        val start = if (lastEventsQueryAt <= 0L) {
            now - 15_000
        } else {
            (lastEventsQueryAt - 2_000).coerceAtLeast(now - 30_000)
        }
        lastEventsQueryAt = now
        val usageEvents = usageStatsManager.queryEvents(start, now)
        val event = UsageEvents.Event()
        var lastEventTime = 0L
        var foundViaEvents = false

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                if (event.timeStamp > lastEventTime) {
                    lastEventTime = event.timeStamp
                    lastKnownForegroundPackage = event.packageName
                    foundViaEvents = true
                }
            }
        }

        // Fallback: queryUsageStats is heavier, so run it at a lower cadence.
        val shouldRunUsageStatsFallback =
            (!foundViaEvents || lastKnownForegroundPackage.isEmpty()) &&
            (now - lastUsageStatsFallbackAt >= usageStatsFallbackIntervalMs)

        if (shouldRunUsageStatsFallback) {
            lastUsageStatsFallbackAt = now
            val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 1000 * 60 * 15, now)
            if (stats != null && stats.isNotEmpty()) {
                var latestStats: android.app.usage.UsageStats? = null
                for (usageStats in stats) {
                    if (latestStats == null || usageStats.lastTimeUsed > latestStats!!.lastTimeUsed) {
                        latestStats = usageStats
                    }
                }
                if (latestStats != null && (now - latestStats!!.lastTimeUsed) < 1000 * 60 * 5) {
                    val resolvedPackage = latestStats!!.packageName
                    if (resolvedPackage != lastKnownForegroundPackage) {
                        lastKnownForegroundPackage = resolvedPackage
                        android.util.Log.d("RevokeMonitor", "Found via stats: $lastKnownForegroundPackage")
                    }
                }
            }
        }
        
        if (lastKnownForegroundPackage.isNotEmpty()) {
            if (lastKnownForegroundPackage != packageName) { 
                // Only log if the app has changed to avoid spamming the logcat
                val shouldLogLogic = lastKnownForegroundPackage != lastLoggedApp
                if (shouldLogLogic) {
                     android.util.Log.d("RevokeMonitor", "Current App: $lastKnownForegroundPackage")
                     lastLoggedApp = lastKnownForegroundPackage
                }
                
                val restrictedAppName = getRestrictedAppName(lastKnownForegroundPackage, shouldLogLogic)
                if (restrictedAppName != null) {
                    lastRestrictedDetectedAt = now
                    if (shouldLogLogic) android.util.Log.d("RevokeMonitor", "Blocking $restrictedAppName")
                    showBlockerOverlay(restrictedAppName, lastKnownForegroundPackage)
                    return true
                } else {
                    hideBlockerOverlay()
                    return false
                }
            } else {
                // We are in Revoke, hide overlay
                hideBlockerOverlay()
                return false
            }
        }
        return false
    }

    private fun getRestrictedAppName(packageName: String, shouldLog: Boolean): String? {
        if (checkTempUnlock(packageName)) {
            if (shouldLog) android.util.Log.d("RevokeLogic", "App $packageName is temporarily unlocked.")
            return null
        }

        // Fast path: if this package is not referenced by any active schedule, it cannot be blocked.
        if (!blockedAppsIndex.contains(packageName)) {
            return null
        }
        val calendar = java.util.Calendar.getInstance()
        val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
        val modelDay = if (dayOfWeek == 1) 7 else dayOfWeek - 1

        val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(java.util.Calendar.MINUTE)
        val currentTotalMin = currentHour * 60 + currentMinute
        
        // Suppress all logs for the launcher (it's the home screen, very noisy)
        val isLauncher = packageName.contains("launcher") || packageName.contains("trebuchet")
        
        if (shouldLog && !isLauncher) {
            android.util.Log.d("RevokeLogic", "Checking $packageName. Day: $modelDay, Time: $currentTotalMin")
        }

        for ((index, schedule) in activeSchedules.withIndex()) {
            if (!schedule.optBoolean("isActive", true)) {
                if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: INACTIVE, skipping")
                continue
            }
            
            // Day check
            val days = schedule.optJSONArray("days")
            val daysList = mutableListOf<Int>()
            if (days != null) {
                for (i in 0 until days.length()) {
                    daysList.add(days.getInt(i))
                }
            }
            
            var dayMatch = false
            if (days != null) {
                for (i in 0 until days.length()) {
                    if (days.getInt(i) == modelDay) {
                        dayMatch = true
                        break
                    }
                }
            }
            
            if (!dayMatch) {
                if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: Day mismatch. Need: $modelDay, Current: $daysList")
                continue
            }

            // App check
            val apps = schedule.optJSONArray("targetApps")
            val appsList = mutableListOf<String>()
            if (apps != null) {
                for (i in 0 until apps.length()) {
                    appsList.add(apps.getString(i))
                }
            }
            
            var appMatch = false
            if (apps != null) {
                for (i in 0 until apps.length()) {
                    if (apps.getString(i) == packageName) {
                        appMatch = true
                        break
                    }
                }
            }
            
            if (!appMatch) {
                if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: App mismatch.")
                continue
            }

            // Constraint check
            val type = schedule.optInt("type") 
            var isBlocked = false
            if (type == 0) { // TimeBlock
                val windows = extractTimeWindows(schedule)
                if (windows.isEmpty()) {
                    if (shouldLog && !isLauncher) {
                        android.util.Log.d(
                            "RevokeLogic",
                            "Schedule $index: Missing/invalid time block data"
                        )
                    }
                    continue
                }

                if (shouldLog && !isLauncher) {
                    android.util.Log.d(
                        "RevokeLogic",
                        "Schedule $index: Evaluating ${windows.size} time block(s)"
                    )
                }

                if (windows.any { isMinuteWithinWindow(it, currentTotalMin) }) {
                    isBlocked = true
                    if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: MATCH - Time within range")
                } else {
                    if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: MISS - Time outside range")
                }
            } else if (type == 1) { // UsageLimit
                val windows = extractTimeWindows(schedule)
                if (windows.isNotEmpty() && !windows.any { isMinuteWithinWindow(it, currentTotalMin) }) {
                    isBlocked = true
                    if (shouldLog && !isLauncher) {
                        android.util.Log.d(
                            "RevokeLogic",
                            "Schedule $index: MATCH - Outside allowed usage window"
                        )
                    }
                    if (isBlocked) {
                        return try {
                            val pm = packageManager
                            val ai = pm.getApplicationInfo(packageName, 0)
                            pm.getApplicationLabel(ai).toString()
                        } catch (e: Exception) {
                            packageName
                        }
                    }
                }

                val limitMinutes = when {
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

                if (limitMinutes <= 0) {
                    if (shouldLog && !isLauncher) {
                        android.util.Log.d("RevokeLogic", "Schedule $index: UsageLimit missing/invalid duration")
                    }
                    continue
                }

                val usageStatsManager =
                    getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val startOfDay = java.util.Calendar.getInstance().apply {
                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                    set(java.util.Calendar.MINUTE, 0)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }.timeInMillis
                val nowMs = System.currentTimeMillis()

                val usageStats = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    startOfDay,
                    nowMs
                )

                var usedMs = 0L
                if (usageStats != null) {
                    for (stats in usageStats) {
                        if (stats.packageName == packageName) {
                            usedMs = stats.totalTimeInForeground
                            break
                        }
                    }
                }

                val usedMinutes = usedMs / (1000L * 60L)
                if (usedMinutes >= limitMinutes.toLong()) {
                    isBlocked = true
                    if (shouldLog && !isLauncher) {
                        android.util.Log.d(
                            "RevokeLogic",
                            "Schedule $index: ✓ MATCH - UsageLimit reached ($usedMinutes/$limitMinutes min)"
                        )
                    }
                } else if (shouldLog && !isLauncher) {
                    android.util.Log.d(
                        "RevokeLogic",
                        "Schedule $index: ✗ UsageLimit not reached ($usedMinutes/$limitMinutes min)"
                    )
                }
            }

            if (isBlocked) {
                return try {
                    val pm = packageManager
                    val ai = pm.getApplicationInfo(packageName, 0)
                    pm.getApplicationLabel(ai).toString()
                } catch (e: Exception) {
                    packageName
                }
            }
        }
        return null
    }

    private var currentBlockedApp: String? = null

    private fun showBlockerOverlay(blockedAppName: String, packageNameStr: String) {
        // Prevent flicker: If already showing for the same app, do nothing
        if (overlayView != null && currentBlockedApp == blockedAppName) return

        val blockedAttemptsToday = emitBlockedAttempt(blockedAppName, packageNameStr)
        
        handler.post {
            try {
                // If showing for a DIFFERENT app, clean up first
                if (overlayView != null) {
                    try {
                        windowManager?.removeView(overlayView)
                    } catch (e: Exception) { /* ignore */ }
                    overlayView = null
                }
                
                currentBlockedApp = blockedAppName
                val context = this

                // ROOT LAYOUT (Vertical LinearLayout to ensure spacing)
                val root = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    setBackgroundColor(android.graphics.Color.BLACK)
                    setPadding(60, 40, 60, 40)
                    weightSum = 10f
                }

                // TOP SECTION: HUD (Weight 1)
                val topHud = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                }
                val hudShield = TextView(context).apply {
                    text = "🛡️"
                    textSize = 20f
                }
                val hudText = TextView(context).apply {
                    text = " REVOKE"
                    setTextColor(android.graphics.Color.WHITE)
                    textSize = 14f
                    typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
                    letterSpacing = 0.2f
                }
                topHud.addView(hudShield)
                topHud.addView(hudText)
                
                val topParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.5f
                ).apply {
                    gravity = Gravity.TOP
                }
                root.addView(topHud, topParams)

                // CENTER SECTION: Brand & Text (Weight 5)
                val centerLayout = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                }
                val lockIcon = android.widget.ImageView(context).apply {
                    // Use the custom vector drawable we created
                    setImageResource(resources.getIdentifier("ic_lock_premium", "drawable", packageName))
                    setColorFilter(android.graphics.Color.parseColor("#FF4500")) // ORANGE
                    layoutParams = android.widget.LinearLayout.LayoutParams(350, 350)
                }
                val headline = TextView(context).apply {
                    text = "COOKED."
                    setTextColor(android.graphics.Color.parseColor("#FF4500"))
                    textSize = 48f
                    gravity = Gravity.CENTER
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    setPadding(0, 40, 0, 10)
                }
                val subtext = TextView(context).apply {
                    text = "You are trying to open $blockedAppName.\nThe Squad is judging you."
                    setTextColor(android.graphics.Color.WHITE)
                    textSize = 18f
                    gravity = Gravity.CENTER
                    setPadding(40, 0, 40, 40)
                    typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
                }
                val stats = TextView(context).apply {
                    text = "ATTEMPTS TODAY: $blockedAttemptsToday"
                    setTextColor(android.graphics.Color.GRAY)
                    textSize = 11f
                    gravity = Gravity.CENTER
                    typeface = android.graphics.Typeface.MONOSPACE
                }
                centerLayout.addView(lockIcon)
                centerLayout.addView(headline)
                centerLayout.addView(subtext)
                centerLayout.addView(stats)
                
                val centerParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 0, 5.5f
                )
                root.addView(centerLayout, centerParams)

                // BOTTOM SECTION: Actions (Weight 3)
                val bottomActions = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.BOTTOM
                }

                // ACCEPT FATE is now the PRIMARY action (ORANGE)
                val fateButton = android.widget.Button(context).apply {
                    text = "ACCEPT FATE"
                    setTextColor(android.graphics.Color.WHITE)
                    setBackgroundColor(android.graphics.Color.parseColor("#FF4500")) // Orange
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    transformationMethod = null 
                }
                fateButton.setOnClickListener {
                    val startMain = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(startMain)
                    hideBlockerOverlay()
                }

                // BEG FOR TIME is now the SECONDARY action (DARK GREY)
                val begButton = android.widget.Button(context).apply {
                    text = "BEG FOR TIME"
                    setTextColor(android.graphics.Color.WHITE)
                    setBackgroundColor(android.graphics.Color.parseColor("#121212")) // Dark Grey
                    typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
                    transformationMethod = null
                }
                begButton.setOnClickListener {
                    val intent = Intent(this@AppMonitorService, MainActivity::class.java).apply {
                        action = "com.revoke.app.REQUEST_PLEA"
                        putExtra("appName", blockedAppName)
                        putExtra("packageName", packageNameStr)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    startActivity(intent)
                    
                    // UI Feedback
                    begButton.text = "OPENING PLEA..."
                    begButton.isEnabled = false
                    begButton.alpha = 0.5f
                    
                    android.widget.Toast.makeText(context, "Open Revoke to send your plea.", android.widget.Toast.LENGTH_SHORT).show()
                }

                val btnParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 160
                ).apply {
                    setMargins(0, 20, 0, 20)
                }
                
                bottomActions.addView(fateButton, btnParams)
                bottomActions.addView(begButton, btnParams)

                val bottomParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 0, 3f
                )
                root.addView(bottomActions, bottomParams)

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN,
                    PixelFormat.TRANSLUCENT
                )

                windowManager?.addView(root, params)
                overlayView = root
                android.util.Log.d("Revoke", "Overlay Redesign Applied")

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun emitBlockedAttempt(appName: String, packageNameStr: String): Int {
        val now = System.currentTimeMillis()
        val isDuplicate =
            packageNameStr == lastBlockedEventPackage &&
            now - lastBlockedEventAtMs < 4000L

        if (!isDuplicate) {
            lastBlockedEventPackage = packageNameStr
            lastBlockedEventAtMs = now

            val intent = Intent("com.revoke.app.BLOCKED_ATTEMPT").apply {
                putExtra("appName", appName)
                putExtra("packageName", packageNameStr)
                putExtra("blockedAtMs", now)
            }
            sendBroadcast(intent)
            return incrementBlockedAttemptsToday(now)
        }

        return readBlockedAttemptsToday(now)
    }

    private fun readBlockedAttemptsToday(now: Long): Int {
        val today = dayKey(now)
        val storedDay = prefs.getString("blocked_attempt_day", "") ?: ""
        return if (storedDay == today) {
            prefs.getInt("blocked_attempt_count", 0)
        } else {
            0
        }
    }

    private fun incrementBlockedAttemptsToday(now: Long): Int {
        val today = dayKey(now)
        val storedDay = prefs.getString("blocked_attempt_day", "") ?: ""
        val nextCount = if (storedDay == today) {
            prefs.getInt("blocked_attempt_count", 0) + 1
        } else {
            1
        }
        prefs.edit()
            .putString("blocked_attempt_day", today)
            .putInt("blocked_attempt_count", nextCount)
            .apply()
        return nextCount
    }

    private fun dayKey(now: Long): String {
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getDefault()
        return formatter.format(java.util.Date(now))
    }

    private fun hideBlockerOverlay() {
        if (overlayView == null) return
        handler.post {
            try {
                if (overlayView?.parent != null) {
                    windowManager?.removeView(overlayView)
                }
                overlayView = null
                currentBlockedApp = null
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
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

