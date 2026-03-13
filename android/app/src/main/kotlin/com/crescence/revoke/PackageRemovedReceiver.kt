package com.crescence.revoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

class PackageRemovedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_PACKAGE_REMOVED) return
        if (intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)) return

        val packageName = intent.data?.schemeSpecificPart?.trim().orEmpty()
        if (packageName.isEmpty()) return

        removePackageTempUnlock(context, packageName)

        try {
            context.startService(
                Intent(context, AppMonitorService::class.java).apply {
                    action = ACTION_REMOVE_TEMP_UNLOCK
                    putExtra(EXTRA_PACKAGE_NAME, packageName)
                }
            )
        } catch (error: Exception) {
            Log.e(
                "RevokePackage",
                "Unable to notify monitor service about package removal: $packageName",
                error
            )
        }
    }

    private fun removePackageTempUnlock(context: Context, packageName: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_TEMP_UNLOCKS, null) ?: return
        try {
            val now = System.currentTimeMillis()
            val source = JSONObject(raw)
            val cleaned = JSONObject()
            var removed = false

            val keys = source.keys()
            while (keys.hasNext()) {
                val pkg = keys.next()
                val expiry = source.optLong(pkg, 0L)
                if (pkg == packageName) {
                    removed = true
                    continue
                }
                if (expiry > now) {
                    cleaned.put(pkg, expiry)
                } else {
                    removed = true
                }
            }

            if (removed) {
                prefs.edit().putString(KEY_TEMP_UNLOCKS, cleaned.toString()).apply()
                Log.d(
                    "RevokePackage",
                    "Cleared stale temporary unlock for removed package: $packageName"
                )
            }
        } catch (error: Exception) {
            Log.e(
                "RevokePackage",
                "Failed pruning temporary unlock state for removed package: $packageName",
                error
            )
        }
    }

    companion object {
        const val ACTION_REMOVE_TEMP_UNLOCK = "com.revoke.app.REMOVE_TEMP_UNLOCK"
        const val EXTRA_PACKAGE_NAME = "packageName"
        private const val PREFS_NAME = "RevokeConfig"
        private const val KEY_TEMP_UNLOCKS = "temp_unlocks"
    }
}
