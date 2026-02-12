package com.example.revoke

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.usage.UsageStatsManager
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.revoke.app/overlay"
    private var methodChannel: MethodChannel? = null
    private var overlayReceiverRegistered = false
    private var pendingPleaPayload: Map<String, String?>? = null

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
                    val intent = Intent(this, AppMonitorService::class.java)
                    intent.action = "com.revoke.app.SYNC_SCHEDULES"
                    intent.putExtra("schedules", schedulesJson)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "startService" -> {
                    val perms = checkPermissions()
                    val hasUsageStats = perms["usage_stats"] == true
                    val hasOverlay = perms["overlay"] == true

                    if (!hasUsageStats || !hasOverlay) {
                        result.error(
                            "PERMISSION_DENIED",
                            "Usage Stats and Overlay permissions are required before starting service.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val intent = Intent(this, AppMonitorService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
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
                "temporaryUnlock" -> {
                    val packageName = call.argument<String>("packageName")
                    val minutes = call.argument<Int>("minutes") ?: 5
                    if (packageName != null) {
                        val intent = Intent(this, AppMonitorService::class.java)
                        intent.action = "com.revoke.app.TEMP_UNLOCK"
                        intent.putExtra("packageName", packageName)
                        intent.putExtra("minutes", minutes)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
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

        return mapOf(
            "usage_stats" to usageStats,
            "overlay" to overlay
        )
    }
}
