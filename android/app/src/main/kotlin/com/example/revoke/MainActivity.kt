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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.revoke.app/overlay"
    private var methodChannel: MethodChannel? = null

    private val overlayReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == "com.revoke.app.SHOW_OVERLAY") {
                methodChannel?.invokeMethod("showOverlay", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(overlayReceiver, android.content.IntentFilter("com.revoke.app.SHOW_OVERLAY"), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(overlayReceiver, android.content.IntentFilter("com.revoke.app.SHOW_OVERLAY"))
        }
    }

    override fun onPause() {
        super.onPause()
        try {
            unregisterReceiver(overlayReceiver)
        } catch (e: Exception) {
            // Ignore
        }
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