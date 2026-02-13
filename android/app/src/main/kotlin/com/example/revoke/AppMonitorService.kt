package com.example.revoke

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
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
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class AppMonitorService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var overlayView: android.view.View? = null
    private var lastKnownForegroundPackage: String = ""
    private var lastLoggedApp: String = ""
    private var lastUsageStatsFallbackAt: Long = 0L
    private var activeSchedules: java.util.concurrent.CopyOnWriteArrayList<org.json.JSONObject> = java.util.concurrent.CopyOnWriteArrayList()
    private val tempUnlockedPackages = mutableMapOf<String, Long>()
    private val usageStatsFallbackIntervalMs = 12_000L

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // Load persisted schedules
        val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        val savedSchedules = prefs.getString("schedules", null)
        if (savedSchedules != null) {
            updateSchedules(savedSchedules)
            android.util.Log.d("RevokeMonitor", "Loaded ${activeSchedules.size} persisted schedules")
        }
        loadTempUnlocks()
        
        startForegroundService()
        
        // CRITICAL: Start the monitoring loop
        handler.post(runnable)
        android.util.Log.d("RevokeMonitor", "Monitoring loop started")
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
            try {
                checkForegroundApp()
            } catch (e: Exception) {
                android.util.Log.e("RevokeMonitor", "Error in monitor loop: ${e.message}", e)
            } finally {
                // Poll every 2 seconds to reduce background aggressiveness
                handler.postDelayed(this, 2000)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
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
        }
        // Loop already started in onCreate()
        return START_STICKY
    }

    private fun checkTempUnlock(packageName: String): Boolean {
        val expiry = tempUnlockedPackages[packageName] ?: return false
        if (System.currentTimeMillis() > expiry) {
            tempUnlockedPackages.remove(packageName)
            persistTempUnlocks()
            android.util.Log.d("RevokeMonitor", "Temp unlock expired for $packageName")
            return false
        }
        val remainingMs = expiry - System.currentTimeMillis()
        android.util.Log.d("RevokeMonitor", "Temp unlock active for $packageName (${remainingMs / 1000}s left)")
        return true
    }

    private fun loadTempUnlocks() {
        val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        val raw = prefs.getString("temp_unlocks", null) ?: return
        val now = System.currentTimeMillis()
        try {
            val json = JSONObject(raw)
            val keys = json.keys()
            while (keys.hasNext()) {
                val pkg = keys.next()
                val expiry = json.optLong(pkg, 0L)
                if (expiry > now) {
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
            if (entry.value > now) {
                json.put(entry.key, entry.value)
            } else {
                iterator.remove()
            }
        }
        val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
        prefs.edit().putString("temp_unlocks", json.toString()).apply()
    }

    private fun updateSchedules(json: String) {
        try {
            // Persist to SharedPreferences
            val prefs = getSharedPreferences("RevokeConfig", Context.MODE_PRIVATE)
            prefs.edit().putString("schedules", json).apply()
            
            // Update memory
            val array = org.json.JSONArray(json)
            activeSchedules.clear()
            for (i in 0 until array.length()) {
                activeSchedules.add(array.getJSONObject(i))
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
        handler.removeCallbacks(runnable)
        super.onDestroy()
    }

    private fun checkForegroundApp() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        
        // Try queryEvents first with a larger 5-minute window
        val usageEvents = usageStatsManager.queryEvents(now - 1000 * 60 * 5, now)
        val event = UsageEvents.Event()
        var lastEventTime = 0L
        var eventCount = 0
        var foundViaEvents = false

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            eventCount++
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
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
                    if (shouldLogLogic) android.util.Log.d("RevokeMonitor", "Blocking $restrictedAppName")
                    showBlockerOverlay(restrictedAppName, lastKnownForegroundPackage)
                } else {
                    hideBlockerOverlay()
                }
            } else {
                // We are in Revoke, hide overlay
                hideBlockerOverlay()
            }
        } else {
            android.util.Log.d("RevokeMonitor", "No foreground app detected (Checked 5m window)")
        }
    }

    private fun getRestrictedAppName(packageName: String, shouldLog: Boolean): String? {
        if (checkTempUnlock(packageName)) {
            if (shouldLog) android.util.Log.d("RevokeLogic", "App $packageName is temporarily unlocked.")
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
                // Check if time fields exist (not null)
                if (!schedule.has("startHour") || schedule.isNull("startHour") || 
                    !schedule.has("endHour") || schedule.isNull("endHour")) {
                    android.util.Log.d("RevokeLogic", "Schedule $index: Missing time data, skipping")
                    continue
                }
                
                val startHour = schedule.optInt("startHour", -1)
                val startMin = schedule.optInt("startMinute", 0)
                val endHour = schedule.optInt("endHour", -1)
                val endMin = schedule.optInt("endMinute", 0)
                
                if (startHour == -1 || endHour == -1) {
                    android.util.Log.d("RevokeLogic", "Schedule $index: Invalid time values")
                    continue
                }
                
                val startTotalMin = startHour * 60 + startMin
                val endTotalMin = endHour * 60 + endMin
                
                android.util.Log.d("RevokeLogic", "Schedule $index: TimeBlock ${startHour}:${startMin} - ${endHour}:${endMin} (${startTotalMin}-${endTotalMin})")
                
                val isWithinRange = if (startTotalMin <= endTotalMin) {
                    currentTotalMin in startTotalMin..endTotalMin
                } else {
                    // Overnight range (e.g., 9 PM to 2 AM) OR until midnight (e.g. 9 AM to 0 AM)
                    currentTotalMin >= startTotalMin || currentTotalMin <= endTotalMin
                }

                if (isWithinRange) {
                    isBlocked = true
                    if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: ✓ MATCH - Time within range")
                } else {
                    if (shouldLog && !isLauncher) android.util.Log.d("RevokeLogic", "Schedule $index: ✗ Time outside range")
                }
            } else if (type == 1) { // UsageLimit
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
                    text = "ATTEMPTS TODAY: 1"
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
}
