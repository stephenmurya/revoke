package com.crescence.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * Native fallback path for AMNESTY FCM data messages when Flutter background
 * isolate/channel plumbing is unavailable.
 */
class AmnestyPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != ACTION_FCM_RECEIVE) return

        val extras = intent.extras ?: return
        val type = extras.getString("type")?.trim()?.uppercase() ?: return
        if (type != "AMNESTY") return

        val durationMinutes = parseDurationFromExtras(extras)
        AmnestyReceiver.applyAmnesty(context, durationMinutes)

        // Also fan out an internal app broadcast for any interested listeners.
        val local = Intent(AmnestyReceiver.ACTION_AMNESTY_GRANTED).apply {
            setPackage(context.packageName)
            putExtra(AmnestyReceiver.EXTRA_DURATION_MINUTES, durationMinutes)
        }
        context.sendBroadcast(local)

        Log.d(
            "RevokeAmnesty",
            "Handled AMNESTY push natively via broadcast receiver."
        )
    }

    private fun parseDurationFromExtras(extras: Bundle): Int {
        val fromMinutes = AmnestyReceiver.parseDurationMinutes(
            extras.get(AmnestyReceiver.EXTRA_DURATION_MINUTES)
        )
        if (fromMinutes != null) return fromMinutes

        val fromDuration = AmnestyReceiver.parseDurationMinutes(
            extras.get(AmnestyReceiver.EXTRA_DURATION)
        )
        if (fromDuration != null) return fromDuration

        return 60
    }

    companion object {
        private const val ACTION_FCM_RECEIVE = "com.google.android.c2dm.intent.RECEIVE"
    }
}
