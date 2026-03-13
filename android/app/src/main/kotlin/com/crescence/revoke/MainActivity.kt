package com.crescence.revoke

import android.app.AlarmManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private data class TimeWindow(val startTotalMin: Int, val endTotalMin: Int)

    private val CHANNEL = "com.revoke.app/overlay"
    private var methodChannel: MethodChannel? = null
    private var overlayReceiverRegistered = false
    private var pendingPleaPayload: Map<String, String?>? = null
    private var pendingBlockedAttemptPayload: Map<String, Any>? = null

    private val overlayReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                "com.revoke.app.SHOW_OVERLAY" -> {
                    methodChannel?.invokeMethod("showOverlay", null)
                }
                "com.revoke.app.REQUEST_PLEA" -> {
                    val appName = intent.getStringExtra("appName")
                    val packageName = intent.getStringExtra("packageName")
                    dispatchPleaRequest(appName, packageName)
                }
                "com.revoke.app.BLOCKED_ATTEMPT" -> {
                    val appName = intent.getStringExtra("appName")
                    val packageName = intent.getStringExtra("packageName")
                    val blockedAtMs = intent.getLongExtra("blockedAtMs", System.currentTimeMillis())
                    dispatchBlockedAttempt(appName, packageName, blockedAtMs)
                }
            }
        }
    }

    private fun dispatchPleaRequest(appName: String?, packageName: String?) {
        val payload = mapOf(
            "appName" to appName,
            "packageName" to packageName
        )
        if (methodChannel == null) {
            pendingPleaPayload = payload
            return
        }
        methodChannel?.invokeMethod("requestPlea", payload)
    }

    private fun dispatchBlockedAttempt(appName: String?, packageName: String?, blockedAtMs: Long) {
        val payload = mapOf(
            "appName" to (appName ?: "Unknown App"),
            "packageName" to (packageName ?: ""),
            "blockedAtMs" to blockedAtMs
        )
        if (methodChannel == null) {
            pendingBlockedAttemptPayload = payload
            return
        }
        methodChannel?.invokeMethod("blockedAttempt", payload)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent?.action == "com.revoke.app.REQUEST_PLEA") {
            val appName = intent.getStringExtra("appName")
            val packageName = intent.getStringExtra("packageName")
            dispatchPleaRequest(appName, packageName)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        pendingPleaPayload?.let {
            methodChannel?.invokeMethod("requestPlea", it)
            pendingPleaPayload = null
        }
        pendingBlockedAttemptPayload?.let {
            methodChannel?.invokeMethod("blockedAttempt", it)
            pendingBlockedAttemptPayload = null
        }
        handleIncomingIntent(intent)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> {
                    result.success(checkPermissions())
                }
                "requestUsageStats" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }
                "requestOverlay" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "requestBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "requestExactAlarms" -> {
                    requestExactAlarms()
                    result.success(true)
                }
                "getInstalledApps" -> {
                    // Running on a background thread to prevent UI stutter
                    Thread {
                        val apps = getInstalledApps()
                        runOnUiThread {
                            result.success(apps)
                        }
                    }.start()
                }
                "syncSchedules" -> {
                    val schedulesJson = call.argument<String>("schedules")
                    val nextWakeupMs =
                        call.argument<Number>("nextWakeupMs")?.toLong() ?: 0L
                    result.success(syncSchedulesToNative(schedulesJson, nextWakeupMs))
                }
                "scheduleNextWakeup" -> {
                    val timestampMs =
                        call.argument<Number>("timestampMs")?.toLong() ?: 0L
                    val scheduled = if (timestampMs > 0L) {
                        AlarmScheduler.scheduleNextRegimeWakeup(this, timestampMs)
                    } else {
                        AlarmScheduler.cancelNextRegimeWakeup(this)
                        true
                    }
                    result.success(scheduled)
                }
                "startService" -> {
                    val perms = checkPermissions()
                    val hasUsageStats = perms["usage_stats"] == true
                    val hasOverlay = perms["overlay"] == true
                    val hasBatteryOptOut =
                        perms["battery_optimization_ignored"] == true

                    if (!hasUsageStats || !hasOverlay || !hasBatteryOptOut) {
                        result.error(
                            "PERMISSION_DENIED",
                            "Usage Stats, Overlay, and Battery Optimization exemption are required before starting service.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val intent = Intent(this, AppMonitorService::class.java)
                    val started = startMonitorServiceSafely(intent, "startService")
                    result.success(started)
                }
                "getAppDetails" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val pm = packageManager
                        val appInfo = pm.getApplicationInfo(packageName, 0)
                        val appName = pm.getApplicationLabel(appInfo).toString()
                        val icon = getAppIcon(packageName)

                        val appMap = mutableMapOf<String, Any>(
                            "name" to appName,
                            "packageName" to packageName
                        )

                        icon?.let {
                            appMap["icon"] = it
                        }

                        result.success(appMap)
                    } catch (e: PackageManager.NameNotFoundException) {
                        android.util.Log.w(
                            "RevokeAppDiscovery",
                            "Package not found while fetching details: $packageName"
                        )
                        result.success(
                            mapOf<String, Any?>(
                                "name" to "Uninstalled App",
                                "packageName" to packageName,
                                "icon" to null,
                                "isSystemApp" to false
                            )
                        )
                    } catch (e: Exception) {
                        result.error("APP_NOT_FOUND", "Could not find app: $packageName", null)
                    }
                }
                "getRealityCheck" -> {
                    Thread {
                        val realityData = getRealityCheck()
                        runOnUiThread {
                            result.success(realityData)
                        }
                    }.start()
                }
                "getHourlyUsagePattern" -> {
                    Thread {
                        val pattern = getHourlyUsagePattern()
                        runOnUiThread {
                            result.success(pattern)
                        }
                    }.start()
                }
                "temporaryUnlock" -> {
                    val packageName = call.argument<String>("packageName")
                    val minutes = call.argument<Int>("minutes") ?: 5
                    if (packageName != null) {
                        val intent = Intent(this, AppMonitorService::class.java)
                        intent.action = "com.revoke.app.TEMP_UNLOCK"
                        intent.putExtra("packageName", packageName)
                        intent.putExtra("minutes", minutes)
                        val started = startMonitorServiceSafely(intent, "temporaryUnlock")
                        result.success(started)
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
                    }
                }
                "getTemporaryApprovals" -> {
                    result.success(getTemporaryApprovals())
                }
                "pauseMonitoring" -> {
                    val minutes = call.argument<Int>("minutes") ?: 60
                    setAmnestyExpiry(minutes)
                    result.success(true)
                }
                "broadcastAmnestyGranted" -> {
                    val minutes = call.argument<Int>("durationMinutes")
                        ?: call.argument<Int>("minutes")
                        ?: 60
                    try {
                        sendBroadcast(
                            Intent(AmnestyReceiver.ACTION_AMNESTY_GRANTED).apply {
                                setPackage(packageName)
                                putExtra(AmnestyReceiver.EXTRA_DURATION_MINUTES, minutes)
                            }
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e(
                            "RevokeAmnesty",
                            "Failed to broadcast native amnesty intent.",
                            e
                        )
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        registerOverlayReceiverIfNeeded()
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun registerOverlayReceiverIfNeeded() {
        if (overlayReceiverRegistered) return
        val filter = android.content.IntentFilter().apply {
            addAction("com.revoke.app.SHOW_OVERLAY")
            addAction("com.revoke.app.REQUEST_PLEA")
            addAction("com.revoke.app.BLOCKED_ATTEMPT")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(overlayReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(overlayReceiver, filter)
        }
        overlayReceiverRegistered = true
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (overlayReceiverRegistered) {
                unregisterReceiver(overlayReceiver)
                overlayReceiverRegistered = false
            }
        } catch (e: Exception) {
            // Ignore
        }
    }

    private fun syncSchedulesToNative(schedulesJson: String?, nextWakeupMs: Long): Boolean {
        val safeSchedulesJson = schedulesJson?.trim().takeUnless { it.isNullOrEmpty() } ?: "[]"
        persistSchedules(safeSchedulesJson)

        if (nextWakeupMs > 0L) {
            AlarmScheduler.scheduleNextRegimeWakeup(this, nextWakeupMs)
        } else {
            AlarmScheduler.cancelNextRegimeWakeup(this)
        }

        val serviceIntent = Intent(this, AppMonitorService::class.java).apply {
            action = "com.revoke.app.SYNC_SCHEDULES"
            putExtra("schedules", safeSchedulesJson)
        }

        return if (hasCurrentlyActiveRegimes(safeSchedulesJson)) {
            startMonitorServiceSafely(serviceIntent, "syncSchedules")
        } else {
            if (AppMonitorService.isRunning()) {
                dispatchScheduleSyncToRunningService(serviceIntent)
            }
            true
        }
    }

    private fun persistSchedules(schedulesJson: String) {
        val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        prefs.edit().putString("schedules", schedulesJson).apply()
    }

    private fun dispatchScheduleSyncToRunningService(intent: Intent) {
        try {
            startService(intent)
        } catch (error: Exception) {
            android.util.Log.e(
                "RevokeServiceSync",
                "Failed to deliver schedule sync to running AppMonitorService.",
                error
            )
        }
    }

    private fun hasCurrentlyActiveRegimes(schedulesJson: String): Boolean {
        val safeJson = schedulesJson.trim()
        if (safeJson.isEmpty() || safeJson == "[]") return false

        return try {
            val schedules = JSONArray(safeJson)
            val now = Calendar.getInstance()
            val modelDay = now.get(Calendar.DAY_OF_WEEK).let { day ->
                if (day == Calendar.SUNDAY) 7 else day - 1
            }
            val currentTotalMin =
                now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

            for (i in 0 until schedules.length()) {
                val schedule = schedules.optJSONObject(i) ?: continue
                if (!schedule.optBoolean("isActive", true)) continue
                if (!scheduleMatchesDay(schedule, modelDay)) continue

                when (schedule.optInt("type")) {
                    0 -> {
                        if (extractTimeWindows(schedule).any {
                                isMinuteWithinWindow(it, currentTotalMin)
                            }
                        ) {
                            return true
                        }
                    }
                    1 -> return true
                }
            }

            false
        } catch (error: Exception) {
            android.util.Log.e(
                "RevokeServiceSync",
                "Failed to evaluate synced regime payload.",
                error
            )
            false
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
                val window = toTimeWindow(
                    block.optInt("startHour", -1),
                    block.optInt("startMinute", -1),
                    block.optInt("endHour", -1),
                    block.optInt("endMinute", -1)
                )
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

    private fun getRealityCheck(): Map<String, Any> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.add(Calendar.DAY_OF_YEAR, -7)
        val startTime = calendar.timeInMillis

        val stats = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            usageStatsManager.queryAndAggregateUsageStats(startTime, endTime)
        } else {
            emptyMap()
        }
        
        var totalTimeMs = 0L
        val appUsageList = mutableListOf<Map<String, Any>>()

        for ((pkg, usage) in stats) {
            val timeInForeground = usage.totalTimeInForeground
            // Exclude common system apps and Revoke itself
            if (timeInForeground > 30000 && pkg != packageName && !pkg.contains("launcher") && !pkg.contains("systemui")) {
                totalTimeMs += timeInForeground
                appUsageList.add(mapOf(
                    "packageName" to pkg,
                    "usageMs" to timeInForeground
                ))
            }
        }

        // Sort to get top 3
        appUsageList.sortByDescending { it["usageMs"] as Long }
        val topApps = appUsageList.take(3)

        return mapOf(
            "totalAvgDailyHours" to (totalTimeMs / (1000 * 60 * 60 * 7.0)),
            "topApps" to topApps
        )
    }

    private fun getHourlyUsagePattern(): List<Int> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return List(24) { 0 }
        }

        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endMs = System.currentTimeMillis()
        val startMs = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -7)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val hourlyMs = LongArray(24)
        var activePackage: String? = null
        var activeStartMs = -1L

        val events = usageStatsManager.queryEvents(startMs, endMs)
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (_shouldExcludeUsagePackage(pkg)) continue

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (!activePackage.isNullOrBlank() &&
                        activeStartMs > 0L &&
                        event.timeStamp > activeStartMs
                    ) {
                        _accumulateIntoHourlyBuckets(
                            hourlyMs = hourlyMs,
                            startMs = activeStartMs,
                            endMs = event.timeStamp
                        )
                    }
                    activePackage = pkg
                    activeStartMs = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (activePackage == pkg &&
                        activeStartMs > 0L &&
                        event.timeStamp > activeStartMs
                    ) {
                        _accumulateIntoHourlyBuckets(
                            hourlyMs = hourlyMs,
                            startMs = activeStartMs,
                            endMs = event.timeStamp
                        )
                        activePackage = null
                        activeStartMs = -1L
                    }
                }
            }
        }

        if (!activePackage.isNullOrBlank() && activeStartMs > 0L && endMs > activeStartMs) {
            _accumulateIntoHourlyBuckets(
                hourlyMs = hourlyMs,
                startMs = activeStartMs,
                endMs = endMs
            )
        }

        return List(24) { hour ->
            val avgMinutes = (hourlyMs[hour] / (1000.0 * 60.0 * 7.0)).roundToInt()
            avgMinutes.coerceIn(0, 60)
        }
    }

    private fun _accumulateIntoHourlyBuckets(
        hourlyMs: LongArray,
        startMs: Long,
        endMs: Long
    ) {
        if (endMs <= startMs) return
        var cursorMs = startMs
        while (cursorMs < endMs) {
            val cursorCal = Calendar.getInstance().apply {
                timeInMillis = cursorMs
            }
            val hour = cursorCal.get(Calendar.HOUR_OF_DAY).coerceIn(0, 23)
            val nextHourBoundary = (cursorCal.clone() as Calendar).apply {
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.HOUR_OF_DAY, 1)
            }.timeInMillis
            val segmentEnd = minOf(endMs, nextHourBoundary)
            val delta = (segmentEnd - cursorMs).coerceAtLeast(0L)
            hourlyMs[hour] = hourlyMs[hour] + delta
            cursorMs = segmentEnd
        }
    }

    private fun _shouldExcludeUsagePackage(packageName: String): Boolean {
        val normalized = packageName.trim().lowercase()
        if (normalized.isEmpty()) return true
        if (normalized == this.packageName.lowercase()) return true
        if (normalized.contains("launcher")) return true
        if (normalized.contains("systemui")) return true
        return false
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        // Intent that searches for all apps that can be launched (have an icon)
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

        val resolveInfos: List<ResolveInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            pm.queryIntentActivities(mainIntent, 0)
        }

        val installedApps = mutableListOf<Map<String, Any>>()
        val seenPackages = mutableSetOf<String>()

        for (resolveInfo in resolveInfos) {
            val activityInfo = resolveInfo.activityInfo
            val packageName = activityInfo.packageName
            
            // Prevent duplicates (some apps have multiple launcher icons)
            if (!seenPackages.contains(packageName)) {
                try {
                    val appName = resolveInfo.loadLabel(pm).toString()
                    
                    val appMap = mutableMapOf<String, Any>(
                        "name" to appName,
                        "packageName" to packageName
                    )

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        appMap["category"] = activityInfo.applicationInfo.category
                    } else {
                        appMap["category"] = -1
                    }

                    getAppIcon(packageName)?.let {
                        appMap["icon"] = it
                    }

                    android.util.Log.d("RevokeAppDiscovery", "Found app: $appName ($packageName)")

                    installedApps.add(appMap)
                    seenPackages.add(packageName)
                } catch (e: PackageManager.NameNotFoundException) {
                    android.util.Log.w(
                        "RevokeAppDiscovery",
                        "Skipping package removed during discovery: $packageName"
                    )
                } catch (e: Exception) {
                    android.util.Log.w(
                        "RevokeAppDiscovery",
                        "Skipping malformed package entry: $packageName",
                        e
                    )
                }
            }
        }
        return installedApps
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val icon = packageManager.getApplicationIcon(packageName)
            val bitmap = if (icon is android.graphics.drawable.BitmapDrawable) {
                icon.bitmap
            } else {
                val width = icon.intrinsicWidth.takeIf { it > 0 } ?: 1
                val height = icon.intrinsicHeight.takeIf { it > 0 } ?: 1
                val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(bitmap)
                icon.setBounds(0, 0, canvas.width, canvas.height)
                icon.draw(canvas)
                bitmap
            }
            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun checkPermissions(): Map<String, Boolean> {
        val usageStats = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } else {
            true
        }

        val overlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }

        val exactAlarm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        val batteryOptimizationIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }

        return mapOf(
            "usage_stats" to usageStats,
            "overlay" to overlay,
            "exact_alarm" to exactAlarm,
            "battery_optimization_ignored" to batteryOptimizationIgnored
        )
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                // Ignore
            }
        }
    }

    private fun requestExactAlarms() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName")
                    )
                )
            } catch (_: Exception) {
                // Ignore
            }
        }
    }

    private fun getTemporaryApprovals(): List<String> {
        val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        val raw = prefs.getString("temp_unlocks", null) ?: return emptyList()
        val now = System.currentTimeMillis()
        return try {
            val json = JSONObject(raw)
            val active = mutableListOf<String>()
            val stale = mutableListOf<String>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val pkg = keys.next()
                val expiry = json.optLong(pkg, 0L)
                if (expiry > now && isPackageInstalled(pkg)) {
                    active.add(pkg)
                } else {
                    stale.add(pkg)
                }
            }
            if (stale.isNotEmpty()) {
                for (pkg in stale) {
                    json.remove(pkg)
                }
                prefs.edit().putString("temp_unlocks", json.toString()).apply()
            }
            active
        } catch (_: Exception) {
            emptyList()
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

    private fun setAmnestyExpiry(minutes: Int) {
        val safeMinutes = minutes.coerceAtLeast(0)
        val now = System.currentTimeMillis()
        val expiry = now + (safeMinutes.toLong() * 60L * 1000L)
        val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        prefs.edit().putLong("amnesty_expiry", expiry).apply()
        android.util.Log.d("RevokeAmnesty", "Monitoring paused for $safeMinutes minute(s).")
    }

    private fun startMonitorServiceSafely(intent: Intent, reason: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } catch (error: Exception) {
            if (isForegroundServiceStartNotAllowed(error)) {
                android.util.Log.e(
                    "RevokeServiceStart",
                    "Foreground service start blocked for $reason. " +
                        "Will retry when app returns to foreground.",
                    error
                )
            } else {
                android.util.Log.e(
                    "RevokeServiceStart",
                    "Failed to start monitor service for $reason.",
                    error
                )
            }
            false
        }
    }

    private fun isForegroundServiceStartNotAllowed(error: Exception): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return error.javaClass.name == "android.app.ForegroundServiceStartNotAllowedException"
    }
}
