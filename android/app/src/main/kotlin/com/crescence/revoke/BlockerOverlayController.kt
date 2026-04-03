package com.crescence.revoke

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView

object BlockerOverlayController {
    private const val PREFS_NAME = "RevokeConfig"
    private val handler = Handler(Looper.getMainLooper())

    @Volatile
    private var overlayView: android.view.View? = null

    @Volatile
    private var currentBlockedApp: String? = null

    @Volatile
    private var lastBlockedEventPackage: String = ""

    @Volatile
    private var lastBlockedEventAtMs: Long = 0L

    fun isShowing(): Boolean = overlayView != null

    fun show(context: Context, blockedAppName: String, packageNameStr: String, source: String) {
        val appContext = context.applicationContext
        if (blockedAppName.isBlank() || packageNameStr.isBlank()) return
        if (overlayView != null && currentBlockedApp == blockedAppName) return

        val blockedAttemptsToday = emitBlockedAttempt(appContext, blockedAppName, packageNameStr)

        handler.post {
            try {
                val windowManager =
                    appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                        ?: return@post

                if (overlayView != null) {
                    try {
                        windowManager.removeView(overlayView)
                    } catch (_: Exception) {
                    }
                    overlayView = null
                }

                currentBlockedApp = blockedAppName

                val root =
                    android.widget.LinearLayout(appContext).apply {
                        orientation = android.widget.LinearLayout.VERTICAL
                        setBackgroundColor(android.graphics.Color.BLACK)
                        setPadding(60, 40, 60, 40)
                        weightSum = 10f
                    }

                val topHud =
                    android.widget.LinearLayout(appContext).apply {
                        orientation = android.widget.LinearLayout.HORIZONTAL
                        gravity = Gravity.CENTER_VERTICAL
                    }
                val hudText =
                    TextView(appContext).apply {
                        text = "REVOKE"
                        setTextColor(android.graphics.Color.WHITE)
                        textSize = 14f
                        typeface =
                            android.graphics.Typeface.create(
                                "sans-serif-medium",
                                android.graphics.Typeface.NORMAL,
                            )
                        letterSpacing = 0.2f
                    }
                topHud.addView(hudText)

                val topParams =
                    android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                        0,
                        1.5f,
                    ).apply {
                        gravity = Gravity.TOP
                    }
                root.addView(topHud, topParams)

                val centerLayout =
                    android.widget.LinearLayout(appContext).apply {
                        orientation = android.widget.LinearLayout.VERTICAL
                        gravity = Gravity.CENTER
                    }
                val lockIcon =
                    ImageView(appContext).apply {
                        setImageResource(
                            appContext.resources.getIdentifier(
                                "ic_lock_premium",
                                "drawable",
                                appContext.packageName,
                            ),
                        )
                        setColorFilter(android.graphics.Color.parseColor("#FF4500"))
                        layoutParams = android.widget.LinearLayout.LayoutParams(350, 350)
                    }
                val headline =
                    TextView(appContext).apply {
                        text = "COOKED."
                        setTextColor(android.graphics.Color.parseColor("#FF4500"))
                        textSize = 48f
                        gravity = Gravity.CENTER
                        typeface = android.graphics.Typeface.DEFAULT_BOLD
                        setPadding(0, 40, 0, 10)
                    }
                val subtext =
                    TextView(appContext).apply {
                        text = "You are trying to open $blockedAppName.\nThe Squad is judging you."
                        setTextColor(android.graphics.Color.WHITE)
                        textSize = 18f
                        gravity = Gravity.CENTER
                        setPadding(40, 0, 40, 40)
                        typeface =
                            android.graphics.Typeface.create(
                                "sans-serif-light",
                                android.graphics.Typeface.NORMAL,
                            )
                    }
                val stats =
                    TextView(appContext).apply {
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

                val centerParams =
                    android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                        0,
                        5.5f,
                    )
                root.addView(centerLayout, centerParams)

                val bottomActions =
                    android.widget.LinearLayout(appContext).apply {
                        orientation = android.widget.LinearLayout.VERTICAL
                        gravity = Gravity.BOTTOM
                    }

                val fateButton =
                    android.widget.Button(appContext).apply {
                        text = "ACCEPT FATE"
                        setTextColor(android.graphics.Color.WHITE)
                        setBackgroundColor(android.graphics.Color.parseColor("#FF4500"))
                        typeface = android.graphics.Typeface.DEFAULT_BOLD
                        transformationMethod = null
                    }
                fateButton.setOnClickListener {
                    val startMain =
                        Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                    appContext.startActivity(startMain)
                    hide(appContext, "accept_fate")
                }

                val begButton =
                    android.widget.Button(appContext).apply {
                        text = "BEG FOR TIME"
                        setTextColor(android.graphics.Color.WHITE)
                        setBackgroundColor(android.graphics.Color.parseColor("#121212"))
                        typeface =
                            android.graphics.Typeface.create(
                                "sans-serif-medium",
                                android.graphics.Typeface.NORMAL,
                            )
                        transformationMethod = null
                    }
                begButton.setOnClickListener {
                    val intent =
                        Intent(appContext, MainActivity::class.java).apply {
                            action = "com.revoke.app.REQUEST_PLEA"
                            putExtra("appName", blockedAppName)
                            putExtra("packageName", packageNameStr)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                    appContext.startActivity(intent)
                    begButton.text = "OPENING PLEA..."
                    begButton.isEnabled = false
                    begButton.alpha = 0.5f

                    android.widget.Toast.makeText(
                        appContext,
                        "Open Revoke to send your plea.",
                        android.widget.Toast.LENGTH_SHORT,
                    ).show()
                }

                val btnParams =
                    android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                        160,
                    ).apply {
                        setMargins(0, 20, 0, 20)
                    }

                bottomActions.addView(fateButton, btnParams)
                bottomActions.addView(begButton, btnParams)

                val bottomParams =
                    android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                        0,
                        3f,
                    )
                root.addView(bottomActions, bottomParams)

                val params =
                    WindowManager.LayoutParams(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.MATCH_PARENT,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        } else {
                            WindowManager.LayoutParams.TYPE_PHONE
                        },
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_FULLSCREEN,
                        PixelFormat.TRANSLUCENT,
                    )

                windowManager.addView(root, params)
                overlayView = root
                android.util.Log.d("RevokeOverlay", "Showing blocker overlay from $source")
            } catch (error: Exception) {
                AppMonitorCoordinator.recordNonFatal(
                    context = appContext,
                    source = "BlockerOverlayController",
                    message = "Failed to render blocker overlay.",
                    error = error,
                    extraKeys = mapOf("trigger" to source, "packageName" to packageNameStr),
                )
                android.util.Log.e("RevokeOverlay", "Failed to render blocker overlay.", error)
            }
        }
    }

    fun hide(context: Context, source: String) {
        val appContext = context.applicationContext
        if (overlayView == null) return
        handler.post {
            try {
                val windowManager =
                    appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                        ?: return@post
                if (overlayView?.parent != null) {
                    windowManager.removeView(overlayView)
                }
                overlayView = null
                currentBlockedApp = null
                android.util.Log.d("RevokeOverlay", "Hiding blocker overlay from $source")
            } catch (error: Exception) {
                AppMonitorCoordinator.recordNonFatal(
                    context = appContext,
                    source = "BlockerOverlayController",
                    message = "Failed to remove blocker overlay.",
                    error = error,
                    extraKeys = mapOf("trigger" to source),
                )
                android.util.Log.e("RevokeOverlay", "Failed to remove blocker overlay.", error)
            }
        }
    }

    private fun emitBlockedAttempt(context: Context, appName: String, packageNameStr: String): Int {
        val now = System.currentTimeMillis()
        val isDuplicate =
            packageNameStr == lastBlockedEventPackage &&
                now - lastBlockedEventAtMs < 4_000L

        if (!isDuplicate) {
            lastBlockedEventPackage = packageNameStr
            lastBlockedEventAtMs = now

            val intent =
                Intent("com.revoke.app.BLOCKED_ATTEMPT").apply {
                    putExtra("appName", appName)
                    putExtra("packageName", packageNameStr)
                    putExtra("blockedAtMs", now)
                }
            context.sendBroadcast(intent)
            return incrementBlockedAttemptsToday(context, now)
        }

        return readBlockedAttemptsToday(context, now)
    }

    private fun readBlockedAttemptsToday(context: Context, now: Long): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = dayKey(now)
        val storedDay = prefs.getString("blocked_attempt_day", "") ?: ""
        return if (storedDay == today) {
            prefs.getInt("blocked_attempt_count", 0)
        } else {
            0
        }
    }

    private fun incrementBlockedAttemptsToday(context: Context, now: Long): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = dayKey(now)
        val storedDay = prefs.getString("blocked_attempt_day", "") ?: ""
        val nextCount =
            if (storedDay == today) {
                prefs.getInt("blocked_attempt_count", 0) + 1
            } else {
                1
            }
        prefs
            .edit()
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
}
