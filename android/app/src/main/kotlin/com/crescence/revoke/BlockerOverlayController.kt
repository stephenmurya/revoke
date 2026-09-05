package com.crescence.revoke

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

object BlockerOverlayController {
    private const val PREFS_NAME = "RevokeConfig"
    private const val COLOR_BG = R.color.revoke_background
    private const val COLOR_SURFACE = R.color.revoke_surface
    private const val COLOR_SURFACE_ALT = R.color.revoke_surface_elevated
    private const val COLOR_STROKE = R.color.revoke_border_subtle
    private const val COLOR_STROKE_SOFT = R.color.revoke_border_soft
    private const val COLOR_TEXT_PRIMARY = R.color.revoke_text_primary
    private const val COLOR_TEXT_SECONDARY = R.color.revoke_text_secondary
    private const val COLOR_TEXT_MUTED = R.color.revoke_text_muted
    private const val COLOR_TEXT_STAT_VALUE = R.color.revoke_text_stat
    private const val COLOR_ORANGE = R.color.revoke_action_primary
    private const val COLOR_ORANGE_SOFT = R.color.revoke_action_soft
    private const val COLOR_BADGE_BG = R.color.revoke_badge_surface

    private data class OverlayViews(
        val root: View,
        val card: View,
        val pulseView: View,
        val heroUnit: View,
        val badgeView: View,
    )

    private val handler = Handler(Looper.getMainLooper())

    @Volatile
    private var overlayView: View? = null

    @Volatile
    private var reminderView: View? = null

    @Volatile
    private var currentReminderKey: String? = null

    @Volatile
    private var currentBlockedPackage: String? = null

    @Volatile
    private var dismissLocked: Boolean = false

    @Volatile
    private var lastBlockedEventPackage: String = ""

    @Volatile
    private var lastBlockedEventAtMs: Long = 0L

    @Volatile
    private var pulseAnimator: AnimatorSet? = null

    fun isShowing(): Boolean = overlayView != null

    fun show(context: Context, presentation: BlockPresentation, source: String) {
        val appContext = context.applicationContext
        if (presentation.appName.isBlank() || presentation.packageName.isBlank()) return
        if (overlayView != null && currentBlockedPackage == presentation.packageName) return

        val blockedAttemptsToday =
            emitBlockedAttempt(appContext, presentation.appName, presentation.packageName)
        val renderPresentation =
            EnforcementEngine.enrichBlockPresentation(presentation, blockedAttemptsToday)

        handler.post {
            try {
                val windowManager =
                    appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                        ?: return@post

                removeReminderView(windowManager)
                pulseAnimator?.cancel()
                pulseAnimator = null

                if (overlayView != null) {
                    try {
                        windowManager.removeView(overlayView)
                    } catch (_: Exception) {
                    }
                    overlayView = null
                }

                currentBlockedPackage = renderPresentation.packageName
                dismissLocked = true

                val overlayViews = buildOverlayViews(appContext, renderPresentation)

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
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                            WindowManager.LayoutParams.FLAG_FULLSCREEN,
                        PixelFormat.TRANSLUCENT,
                    )
                params.gravity = Gravity.TOP or Gravity.START
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    params.layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                }

                windowManager.addView(overlayViews.root, params)
                overlayView = overlayViews.root
                startEntryMotion(overlayViews)
                android.util.Log.d("RevokeOverlay", "Showing blocker overlay from $source")
            } catch (error: Exception) {
                AppMonitorCoordinator.recordNonFatal(
                    context = appContext,
                    source = "BlockerOverlayController",
                    message = "Failed to render blocker overlay.",
                    error = error,
                    extraKeys = mapOf("trigger" to source, "packageName" to presentation.packageName),
                )
                android.util.Log.e("RevokeOverlay", "Failed to render blocker overlay.", error)
            }
        }
    }

    fun hide(context: Context, source: String) {
        val appContext = context.applicationContext
        if (overlayView == null) return
        if (!shouldAllowDismiss(source)) {
            android.util.Log.d(
                "RevokeOverlay",
                "Ignoring auto-hide from $source while blocker is latched",
            )
            return
        }
        handler.post {
            try {
                val windowManager =
                    appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                        ?: return@post
                pulseAnimator?.cancel()
                pulseAnimator = null
                if (overlayView?.parent != null) {
                    windowManager.removeView(overlayView)
                }
                overlayView = null
                currentBlockedPackage = null
                dismissLocked = false
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

    fun showSoftReminder(context: Context, presentation: ReminderPresentation, source: String) {
        if (overlayView != null) return
        val appContext = context.applicationContext
        val key = "soft:${presentation.packageName}"
        if (reminderView != null && currentReminderKey == key) return

        handler.post {
            try {
                val windowManager =
                    appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                        ?: return@post
                removeReminderView(windowManager)
                val root = buildSoftReminderView(appContext, presentation)
                val params =
                    WindowManager.LayoutParams(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.MATCH_PARENT,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        } else {
                            WindowManager.LayoutParams.TYPE_PHONE
                        },
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                            WindowManager.LayoutParams.FLAG_FULLSCREEN,
                        PixelFormat.TRANSLUCENT,
                    )
                params.gravity = Gravity.TOP or Gravity.START
                windowManager.addView(root, params)
                reminderView = root
                currentReminderKey = key
                root.alpha = 0f
                root.animate().alpha(1f).setDuration(120L).start()
                android.util.Log.d("RevokeOverlay", "Showing soft reminder from $source")
            } catch (error: Exception) {
                AppMonitorCoordinator.recordNonFatal(
                    context = appContext,
                    source = "BlockerOverlayController",
                    message = "Failed to render soft reminder.",
                    error = error,
                    extraKeys = mapOf("trigger" to source, "packageName" to presentation.packageName),
                )
            }
        }
    }

    fun showInterstitialReminder(context: Context, presentation: ReminderPresentation, source: String) {
        if (overlayView != null) return
        val appContext = context.applicationContext
        val key = "interstitial:${presentation.packageName}"
        if (reminderView != null && currentReminderKey == key) return

        handler.post {
            try {
                val windowManager =
                    appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                        ?: return@post
                removeReminderView(windowManager)
                val root = buildInterstitialReminderView(appContext, presentation)
                val params =
                    WindowManager.LayoutParams(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.MATCH_PARENT,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        } else {
                            WindowManager.LayoutParams.TYPE_PHONE
                        },
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                            WindowManager.LayoutParams.FLAG_FULLSCREEN,
                        PixelFormat.TRANSLUCENT,
                    )
                params.gravity = Gravity.TOP or Gravity.START
                windowManager.addView(root, params)
                reminderView = root
                currentReminderKey = key
                root.alpha = 0f
                root.animate().alpha(1f).setDuration(140L).start()
                android.util.Log.d("RevokeOverlay", "Showing interstitial reminder from $source")
            } catch (error: Exception) {
                AppMonitorCoordinator.recordNonFatal(
                    context = appContext,
                    source = "BlockerOverlayController",
                    message = "Failed to render interstitial reminder.",
                    error = error,
                    extraKeys = mapOf("trigger" to source, "packageName" to presentation.packageName),
                )
            }
        }
    }

    fun hideReminder(context: Context, source: String) {
        val appContext = context.applicationContext
        if (reminderView == null) return
        handler.post {
            try {
                val windowManager =
                    appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                        ?: return@post
                removeReminderView(windowManager)
                android.util.Log.d("RevokeOverlay", "Hiding reminder overlay from $source")
            } catch (error: Exception) {
                AppMonitorCoordinator.recordNonFatal(
                    context = appContext,
                    source = "BlockerOverlayController",
                    message = "Failed to remove reminder overlay.",
                    error = error,
                    extraKeys = mapOf("trigger" to source),
                )
            }
        }
    }

    private fun removeReminderView(windowManager: WindowManager) {
        try {
            if (reminderView?.parent != null) {
                windowManager.removeView(reminderView)
            }
        } catch (_: Exception) {
        }
        reminderView = null
        currentReminderKey = null
    }

    private fun emitBlockedAttempt(context: Context, appName: String, packageName: String): Int {
        val now = System.currentTimeMillis()
        val isDuplicate =
            packageName == lastBlockedEventPackage &&
                now - lastBlockedEventAtMs < 4_000L

        if (!isDuplicate) {
            lastBlockedEventPackage = packageName
            lastBlockedEventAtMs = now

            val intent =
                Intent("com.revoke.app.BLOCKED_ATTEMPT").apply {
                    putExtra("appName", appName)
                    putExtra("packageName", packageName)
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

    private fun buildSoftReminderView(context: Context, presentation: ReminderPresentation): View {
        val reminderFrequency = readSoftReminderFrequencyLabel(context)
        val root =
            FrameLayout(context).apply {
                setBackgroundColor(color(context, R.color.revoke_scrim_soft))
                setPadding(dp(context, 24), dp(context, 32), dp(context, 24), dp(context, 32))
            }
        val card =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                background =
                    roundedRect(
                        context = context,
                        fill = color(context, COLOR_SURFACE),
                        stroke = color(context, COLOR_STROKE),
                        radiusDp = 24,
                    )
                elevation = dp(context, 8).toFloat()
                setPadding(dp(context, 22), dp(context, 24), dp(context, 22), dp(context, 22))
            }
        card.addView(buildReminderIcon(context, presentation, 78))
        card.addView(space(context, 18, false))
        card.addView(
            buildText(context, "Take a moment", 12f, COLOR_ORANGE_SOFT, true).apply {
                gravity = Gravity.CENTER
                letterSpacing = 0.18f
            },
        )
        card.addView(
            buildText(context, "${presentation.appName} is open", 26f, COLOR_TEXT_PRIMARY, true).apply {
                gravity = Gravity.CENTER
                maxLines = 2
                setPadding(0, dp(context, 8), 0, 0)
            },
        )
        card.addView(
            buildText(
                context,
                "You committed to ${formatReminderMinutes(presentation.limitMs)} today for ${presentation.regimeName}.",
                15f,
                COLOR_TEXT_PRIMARY,
                false,
            ).apply {
                gravity = Gravity.CENTER
                alpha = 0.9f
                maxLines = 3
                setPadding(0, dp(context, 16), 0, 0)
            },
        )
        card.addView(
            buildText(
                context,
                "${formatReminderMinutes(presentation.remainingMs)} remains. This reminder returns in $reminderFrequency.",
                14f,
                COLOR_TEXT_SECONDARY,
                false,
            ).apply {
                gravity = Gravity.CENTER
                maxLines = 3
                setPadding(0, dp(context, 10), 0, 0)
            },
        )
        card.addView(space(context, 24, false))
        card.addView(
            buildPrimaryButton(context, "Continue") {
                hideReminder(context, "soft_reminder_dismissed")
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(context, 56),
            ),
        )
        root.addView(
            card,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )
        return root
    }

    private fun buildInterstitialReminderView(context: Context, presentation: ReminderPresentation): View {
        val root =
            FrameLayout(context).apply {
                setBackgroundColor(color(context, R.color.revoke_scrim_strong))
                setPadding(dp(context, 24), dp(context, 32), dp(context, 24), dp(context, 32))
            }
        val card =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                background =
                    roundedRect(
                        context = context,
                        fill = color(context, COLOR_SURFACE),
                        stroke = color(context, COLOR_STROKE),
                        radiusDp = 24,
                    )
                setPadding(dp(context, 22), dp(context, 24), dp(context, 22), dp(context, 22))
            }
        card.addView(buildReminderIcon(context, presentation, 72))
        card.addView(space(context, 18, false))
        card.addView(
            buildText(context, "Review your boundary", 11f, COLOR_ORANGE_SOFT, true).apply {
                gravity = Gravity.CENTER
                letterSpacing = 0.18f
            },
        )
        card.addView(
            buildText(context, "${presentation.appName} is still inside budget", 24f, COLOR_TEXT_PRIMARY, true).apply {
                gravity = Gravity.CENTER
                maxLines = 2
                setPadding(0, dp(context, 8), 0, 0)
            },
        )
        card.addView(
            buildText(
                context,
                "You have used ${formatReminderMinutes(presentation.usedMs)} of ${formatReminderMinutes(presentation.limitMs)}.",
                15f,
                COLOR_TEXT_SECONDARY,
                false,
            ).apply {
                gravity = Gravity.CENTER
                maxLines = 2
                setPadding(0, dp(context, 14), 0, 0)
            },
        )
        card.addView(space(context, 22, false))
        card.addView(
            buildPrimaryButton(context, "Acknowledge") {
                hideReminder(context, "interstitial_acknowledged")
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(context, 54),
            ),
        )
        root.addView(
            card,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )
        return root
    }

    private fun buildReminderIcon(
        context: Context,
        presentation: ReminderPresentation,
        sizeDp: Int,
    ): View =
        FrameLayout(context).apply {
            background =
                roundedRect(
                    context = context,
                    fill = color(context, COLOR_SURFACE_ALT),
                    stroke = color(context, COLOR_STROKE),
                    radiusDp = sizeDp / 3,
                )
            addView(
                ImageView(context).apply {
                    presentation.appIcon?.let(::setImageDrawable)
                        ?: setImageResource(R.mipmap.ic_launcher)
                    scaleType = ImageView.ScaleType.FIT_CENTER
                    contentDescription = presentation.appName
                },
                FrameLayout.LayoutParams(
                    dp(context, (sizeDp * 0.64f).toInt()),
                    dp(context, (sizeDp * 0.64f).toInt()),
                    Gravity.CENTER,
                ),
            )
            layoutParams = LinearLayout.LayoutParams(dp(context, sizeDp), dp(context, sizeDp))
        }

    private fun buildOverlayViews(
        context: Context,
        presentation: BlockPresentation,
    ): OverlayViews {
        val root =
            FrameLayout(context).apply {
                setBackgroundColor(color(context, COLOR_BG))
                clipChildren = false
                clipToPadding = false
                fitsSystemWindows = false
                @Suppress("DEPRECATION")
                systemUiVisibility =
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                        View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                        View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            }

        val topGlow =
            View(context).apply {
                background =
                    GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        gradientType = GradientDrawable.RADIAL_GRADIENT
                        setColor(Color.TRANSPARENT)
                        colors =
                            intArrayOf(
                                color(context, R.color.revoke_glow_outer),
                                color(context, R.color.revoke_glow_inner),
                                Color.TRANSPARENT,
                            )
                        gradientRadius = dp(context, 170).toFloat()
                    }
                alpha = 0.75f
            }
        root.addView(
            topGlow,
            FrameLayout.LayoutParams(dp(context, 420), dp(context, 420), Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
                topMargin = dp(context, 92)
            },
        )

        val content =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(context, 24), dp(context, 42), dp(context, 24), dp(context, 24))
                alpha = 0f
                scaleX = 0.97f
                scaleY = 0.97f
            }
        root.addView(
            content,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.TOP,
            ).apply {
                topMargin = 0
            },
        )

        content.addView(space(context, 14, false))

        content.addView(
            buildHeader(context),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        content.addView(space(context, 34, false))

        val heroUnit = buildHeroUnit(context, presentation)
        content.addView(heroUnit)

        content.addView(
            buildText(context, presentation.headlineAccent, 11f, COLOR_ORANGE_SOFT, true).apply {
                letterSpacing = 0.25f
                gravity = Gravity.CENTER
                setPadding(0, dp(context, 6), 0, dp(context, 8))
            },
        )
        content.addView(
            buildText(context, presentation.headlineMain, 28f, COLOR_TEXT_PRIMARY, true).apply {
                gravity = Gravity.CENTER
                maxLines = 2
            },
        )
        content.addView(
            buildText(context, presentation.explanatoryLine, 15f, COLOR_TEXT_PRIMARY, false).apply {
                gravity = Gravity.CENTER
                alpha = 0.88f
                maxLines = 2
                setPadding(0, dp(context, 16), 0, 0)
            },
        )

        content.addView(
            View(context),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                0.28f,
            ),
        )

        content.addView(
            buildStatsSection(context, presentation.stats).apply {
                setPadding(0, dp(context, 8), 0, 0)
            },
        )

        content.addView(
            View(context),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                0.12f,
            ),
        )

        val actions = buildActionZone(context, presentation)
        content.addView(
            actions,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = dp(context, 12)
            },
        )

        val pulseView = heroUnit.findViewWithTag<View>("pulse")
        val badgeView = heroUnit.findViewWithTag<View>("badge")

        return OverlayViews(
            root = root,
            card = content,
            pulseView = pulseView ?: heroUnit,
            heroUnit = heroUnit,
            badgeView = badgeView ?: heroUnit,
        )
    }

    private fun buildHeader(context: Context): View =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            clipChildren = false
            clipToPadding = false
            addView(
                ImageView(context).apply {
                    setImageResource(R.drawable.ic_launcher_foreground)
                    contentDescription = "Revoke"
                    layoutParams = LinearLayout.LayoutParams(dp(context, 52), dp(context, 52))
                },
            )
            addView(
                TextView(context).apply {
                    text = "Revoke"
                    textSize = 18f
                    setTextColor(color(context, COLOR_TEXT_PRIMARY))
                    typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                    letterSpacing = 0.0f
                    gravity = Gravity.CENTER
                    isSingleLine = true
                    maxLines = 1
                    minWidth = dp(context, 112)
                    includeFontPadding = false
                    setPadding(dp(context, 10), dp(context, 10), dp(context, 10), 0)
                },
            )
        }

    private fun buildHeroUnit(
        context: Context,
        presentation: BlockPresentation,
    ): View =
        FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(context, 244), dp(context, 244))
            clipChildren = false
            clipToPadding = false

            addView(
                View(context).apply {
                    tag = "pulse"
                    background =
                        GradientDrawable().apply {
                            shape = GradientDrawable.OVAL
                            gradientType = GradientDrawable.RADIAL_GRADIENT
                            setColor(Color.TRANSPARENT)
                            colors =
                                intArrayOf(
                                    color(context, R.color.revoke_glow_outer),
                                    color(context, R.color.revoke_glow_inner),
                                    Color.TRANSPARENT,
                                )
                            gradientRadius = dp(context, 110).toFloat()
                        }
                    alpha = 0.62f
                },
                FrameLayout.LayoutParams(dp(context, 212), dp(context, 212), Gravity.CENTER),
            )

            addView(
                View(context).apply {
                    background =
                        GradientDrawable().apply {
                            shape = GradientDrawable.OVAL
                            setColor(color(context, R.color.revoke_hero_surface))
                            setStroke(dp(context, 1), color(context, COLOR_STROKE))
                        }
                },
                FrameLayout.LayoutParams(dp(context, 182), dp(context, 182), Gravity.CENTER),
            )

            addView(
                FrameLayout(context).apply {
                    clipChildren = false
                    clipToPadding = false

                    val appTile =
                        FrameLayout(context).apply {
                            background =
                                roundedRect(
                                    context = context,
                                    fill = color(context, COLOR_SURFACE_ALT),
                                    stroke = color(context, COLOR_STROKE),
                                    radiusDp = 32,
                                )
                            elevation = dp(context, 6).toFloat()
                        }
                    val appIconView = ImageView(context).apply {
                        presentation.appIcon?.let(::setImageDrawable)
                            ?: setImageResource(R.mipmap.ic_launcher)
                        scaleType = ImageView.ScaleType.FIT_CENTER
                        contentDescription = presentation.appName
                    }
                    appTile.addView(
                        appIconView,
                        FrameLayout.LayoutParams(dp(context, 74), dp(context, 74), Gravity.CENTER),
                    )
                    addView(
                        appTile,
                        FrameLayout.LayoutParams(dp(context, 104), dp(context, 104), Gravity.CENTER),
                    )

                    val badge =
                        FrameLayout(context).apply {
                            tag = "badge"
                            background =
                                GradientDrawable().apply {
                                    shape = GradientDrawable.OVAL
                                    setColor(color(context, COLOR_BADGE_BG))
                                    setStroke(dp(context, 2), color(context, COLOR_ORANGE))
                                }
                            elevation = dp(context, 14).toFloat()
                        }
                    badge.addView(
                        ImageView(context).apply {
                            setImageResource(R.drawable.ic_lock_premium)
                            setColorFilter(color(context, COLOR_ORANGE_SOFT))
                        },
                        FrameLayout.LayoutParams(dp(context, 20), dp(context, 20), Gravity.CENTER),
                    )
                    addView(
                        badge,
                        FrameLayout.LayoutParams(dp(context, 42), dp(context, 42), Gravity.END or Gravity.BOTTOM).apply {
                            rightMargin = dp(context, 8)
                            bottomMargin = dp(context, 10)
                        },
                    )
                },
                FrameLayout.LayoutParams(dp(context, 124), dp(context, 124), Gravity.CENTER),
            )
        }

    private fun buildStatsSection(context: Context, stats: List<BlockStatChip>): View {
        val section =
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }

        if (stats.isEmpty()) {
            return section
        }

        stats.take(3).forEachIndexed { index, chip ->
            if (index > 0) {
                section.addView(space(context, 8, true))
            }
            section.addView(
                buildStatChip(context, chip),
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
            )
        }

        return section
    }

    private fun buildStatChip(context: Context, chip: BlockStatChip): View =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background =
                roundedRect(
                    context = context,
                    fill = color(context, R.color.revoke_stat_surface),
                    stroke = color(context, COLOR_STROKE_SOFT),
                    radiusDp = 18,
                )
            alpha = 0.9f
            setPadding(dp(context, 10), dp(context, 9), dp(context, 10), dp(context, 9))
            addView(
                buildText(context, chip.label, 10f, COLOR_TEXT_MUTED, false).apply {
                    letterSpacing = 0.1f
                    gravity = Gravity.CENTER
                    maxLines = 1
                },
            )
            addView(
                buildText(context, chip.value, 12f, COLOR_TEXT_STAT_VALUE, true).apply {
                    gravity = Gravity.CENTER
                    maxLines = 1
                    setPadding(0, dp(context, 3), 0, 0)
                },
            )
        }

    private fun buildActionZone(
        context: Context,
        presentation: BlockPresentation,
    ): View =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL

            addView(
                buildPrimaryButton(context, "ACCEPT") {
                    acceptFate(context, presentation.packageName)
                },
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(context, 56),
                ),
            )

            addView(
                buildSecondaryButton(context, "REQUEST ACCESS") {
                    openPleaFlow(context, presentation)
                },
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(context, 56),
                ).apply {
                    topMargin = dp(context, 12)
                },
            )

            if (!presentation.hasSquad) {
                addView(
                    buildStatusTreatment(context, "CIRCLE IS OPTIONAL"),
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        topMargin = dp(context, 12)
                    },
                )
                addView(
                    buildSecondaryButton(context, "OPEN CIRCLE SETUP") {
                        openSquadSetup(context, presentation.packageName)
                    },
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        dp(context, 56),
                    ).apply {
                        topMargin = dp(context, 12)
                    },
                )
            }
        }

    private fun buildStatusTreatment(context: Context, text: String): View =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background =
                roundedRect(
                    context = context,
                    fill = color(context, R.color.revoke_surface_subtle),
                    stroke = color(context, COLOR_STROKE_SOFT),
                    radiusDp = 18,
                )
            setPadding(dp(context, 18), dp(context, 16), dp(context, 18), dp(context, 16))
            addView(
                buildText(context, text, 13f, COLOR_ORANGE_SOFT, true).apply {
                    gravity = Gravity.CENTER
                    letterSpacing = 0.12f
                },
            )
        }

    private fun buildPrimaryButton(
        context: Context,
        text: String,
        onClick: () -> Unit,
    ): Button =
        Button(context).apply {
            this.text = text
            transformationMethod = null
            setTextColor(color(context, COLOR_TEXT_PRIMARY))
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            background =
                roundedRect(
                    context = context,
                    fill = color(context, COLOR_ORANGE),
                    stroke = color(context, COLOR_ORANGE_SOFT),
                    radiusDp = 18,
                )
            setOnClickListener { onClick() }
            stateListAnimator = null
        }

    private fun buildSecondaryButton(
        context: Context,
        text: String,
        onClick: () -> Unit,
    ): Button =
        Button(context).apply {
            this.text = text
            transformationMethod = null
            setTextColor(color(context, COLOR_TEXT_PRIMARY))
            textSize = 14f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            background =
                roundedRect(
                    context = context,
                    fill = color(context, COLOR_SURFACE_ALT),
                    stroke = color(context, COLOR_STROKE),
                    radiusDp = 18,
                )
            setOnClickListener { onClick() }
            stateListAnimator = null
        }

    private fun acceptFate(context: Context, packageName: String) {
        EnforcementEngine.clearForegroundPackage(packageName)
        val startMain =
            Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
        context.startActivity(startMain)
        hide(context, "accept_fate")
    }

    private fun openPleaFlow(context: Context, presentation: BlockPresentation) {
        EnforcementEngine.clearForegroundPackage(presentation.packageName)
        val intent =
            Intent(context, MainActivity::class.java).apply {
                action = "com.revoke.app.REQUEST_PLEA"
                putExtra("appName", presentation.appName)
                putExtra("packageName", presentation.packageName)
                putExtra("commitmentId", presentation.commitmentId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
        hide(context, "request_access")
        context.startActivity(intent)
    }

    private fun openSquadSetup(context: Context, packageName: String) {
        EnforcementEngine.clearForegroundPackage(packageName)
        val intent =
            Intent(context, MainActivity::class.java).apply {
                action = "com.revoke.app.OPEN_SQUAD_SETUP"
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
        hide(context, "manual_open_squad_setup")
        context.startActivity(intent)
    }

    private fun buildText(
        context: Context,
        text: String,
        sizeSp: Float,
        colorRes: Int,
        bold: Boolean,
    ): TextView =
        TextView(context).apply {
            this.text = text
            textSize = sizeSp
            setTextColor(color(context, colorRes))
            typeface =
                if (bold) {
                    Typeface.create("sans-serif-medium", Typeface.NORMAL)
                } else {
                    Typeface.create("sans-serif", Typeface.NORMAL)
                }
        }

    private fun color(context: Context, colorRes: Int): Int =
        androidx.core.content.ContextCompat.getColor(context, colorRes)

    private fun roundedRect(
        context: Context,
        fill: Int,
        stroke: Int,
        radiusDp: Int,
    ): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(context, radiusDp).toFloat()
            setColor(fill)
            setStroke(dp(context, 1), stroke)
        }

    private fun space(context: Context, sizeDp: Int, horizontal: Boolean): View =
        View(context).apply {
            layoutParams =
                if (horizontal) {
                    LinearLayout.LayoutParams(dp(context, sizeDp), 1)
                } else {
                    LinearLayout.LayoutParams(1, dp(context, sizeDp))
                }
        }

    private fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    private fun dayKey(now: Long): String {
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getDefault()
        return formatter.format(java.util.Date(now))
    }

    private fun formatReminderMinutes(ms: Long): String {
        val totalMinutes = ((ms.coerceAtLeast(0L) + 59_999L) / 60_000L).toInt()
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return when {
            hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
            hours > 0 -> "${hours}h"
            else -> "${minutes}m"
        }
    }

    private fun readSoftReminderFrequencyLabel(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cooldownMs = prefs.getLong("soft_reminder_cooldown_ms", 300_000L).coerceAtLeast(0L)
        val minutes = ((cooldownMs + 59_999L) / 60_000L).toInt()
        return if (minutes <= 0) {
            "every app open"
        } else {
            "$minutes min"
        }
    }

    private fun startEntryMotion(views: OverlayViews) {
        views.root.alpha = 0f
        views.heroUnit.alpha = 0f
        views.heroUnit.scaleX = 0.94f
        views.heroUnit.scaleY = 0.94f
        views.badgeView.alpha = 0f
        views.badgeView.scaleX = 0.82f
        views.badgeView.scaleY = 0.82f

        views.root.animate()
            .alpha(1f)
            .setDuration(120L)
            .setInterpolator(DecelerateInterpolator())
            .start()

        views.card.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(190L)
            .setInterpolator(DecelerateInterpolator())
            .start()

        views.heroUnit.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setStartDelay(40L)
            .setDuration(220L)
            .setInterpolator(DecelerateInterpolator())
            .start()

        views.badgeView.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setStartDelay(110L)
            .setDuration(170L)
            .setInterpolator(DecelerateInterpolator())
            .start()

        val pulseAlpha =
            ObjectAnimator.ofFloat(views.pulseView, View.ALPHA, 0.45f, 0.82f, 0.45f).apply {
                duration = 2200L
                repeatCount = ObjectAnimator.INFINITE
                repeatMode = ObjectAnimator.RESTART
                interpolator = LinearInterpolator()
            }
        val pulseScaleX =
            ObjectAnimator.ofFloat(views.pulseView, View.SCALE_X, 0.96f, 1.05f, 0.96f).apply {
                duration = 2200L
                repeatCount = ObjectAnimator.INFINITE
                repeatMode = ObjectAnimator.RESTART
                interpolator = LinearInterpolator()
            }
        val pulseScaleY =
            ObjectAnimator.ofFloat(views.pulseView, View.SCALE_Y, 0.96f, 1.05f, 0.96f).apply {
                duration = 2200L
                repeatCount = ObjectAnimator.INFINITE
                repeatMode = ObjectAnimator.RESTART
                interpolator = LinearInterpolator()
            }
        pulseAnimator =
            AnimatorSet().apply {
                playTogether(pulseAlpha, pulseScaleX, pulseScaleY)
                start()
            }
    }

    private fun shouldAllowDismiss(source: String): Boolean {
        if (!dismissLocked) return true
        return source == "accept_fate" ||
            source == "beg_for_time" ||
            source.startsWith("manual_")
    }
}
