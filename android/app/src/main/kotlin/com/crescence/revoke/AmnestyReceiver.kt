package com.crescence.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AmnestyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_AMNESTY_GRANTED) return
        val durationMinutes = extractDurationMinutes(intent)
        applyAmnesty(context, durationMinutes)
    }

    private fun extractDurationMinutes(intent: Intent): Int {
        val numericExtra = intent.extras?.get(EXTRA_DURATION_MINUTES)
        val parsed = parseDurationMinutes(numericExtra)
            ?: parseDurationMinutes(intent.getStringExtra(EXTRA_DURATION))
        return parsed ?: DEFAULT_DURATION_MINUTES
    }

    companion object {
        const val ACTION_AMNESTY_GRANTED = "com.revoke.app.AMNESTY_GRANTED"
        const val EXTRA_DURATION_MINUTES = "durationMinutes"
        const val EXTRA_DURATION = "duration"

        private const val PREFS_NAME = "RevokeConfig"
        private const val KEY_AMNESTY_EXPIRY = "amnesty_expiry"
        private const val DEFAULT_DURATION_MINUTES = 60
        private const val MAX_DURATION_MINUTES = 24 * 60

        fun applyAmnesty(context: Context, durationMinutes: Int) {
            val safeMinutes = durationMinutes.coerceIn(1, MAX_DURATION_MINUTES)
            val expiryMs = System.currentTimeMillis() + (safeMinutes * 60_000L)
            context
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putLong(KEY_AMNESTY_EXPIRY, expiryMs)
                .apply()
            Log.d("RevokeAmnesty", "Native amnesty applied for $safeMinutes minute(s).")
        }

        fun parseDurationMinutes(raw: Any?): Int? {
            return when (raw) {
                is Int -> raw
                is Long -> raw.toInt()
                is Double -> raw.toInt()
                is Float -> raw.toInt()
                is String -> raw.trim().toIntOrNull()
                else -> null
            }
        }
    }
}
