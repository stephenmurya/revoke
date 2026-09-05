package com.crescence.revoke

import android.content.Context
import android.os.Bundle
import android.util.Log
import org.json.JSONObject

/** Applies only server-shaped, user-bound approval data from the FCM fallback. */
object NativeOverrideAccess {
    private const val PREFS_NAME = "RevokeConfig"
    private const val KEY_TEMP_UNLOCKS = "temp_unlocks"
    private const val KEY_UID = "revoke_uid"
    private const val KEY_DELIVERIES = "override_delivery_ids"
    private const val MAX_APPROVAL_MS = 15L * 60L * 1000L

    fun apply(context: Context, extras: Bundle): Boolean {
        val appContext = context.applicationContext
        val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val expectedUid = prefs.getString(KEY_UID, "")?.trim().orEmpty()
        val payloadUid = extras.getString("uid")?.trim().orEmpty()
        val packageName = extras.getString("packageName")?.trim().orEmpty()
        val deliveryId = (
            extras.getString("idempotencyKey")?.trim()
                ?: extras.getString("overrideId")?.trim()
                ?: extras.getString("pleaId")?.trim()
        ).orEmpty()
        val expiryMs = parseLong(extras.get("approvedUntilMs"))
        val now = System.currentTimeMillis()

        if (expectedUid.isEmpty() || payloadUid.isEmpty() || expectedUid != payloadUid) {
            Log.w("RevokeOverride", "Rejected approval with mismatched user identity")
            return false
        }
        if (packageName.isEmpty() || !packageName.contains('.') || packageName == appContext.packageName) {
            Log.w("RevokeOverride", "Rejected approval with invalid package")
            return false
        }
        if (expiryMs <= now || expiryMs - now > MAX_APPROVAL_MS) {
            Log.w("RevokeOverride", "Rejected expired or unbounded approval")
            return false
        }
        if (deliveryId.isEmpty()) return false

        val deliveries = readJson(prefs.getString(KEY_DELIVERIES, null))
        prune(deliveries, now)
        if (deliveries.optLong(deliveryId, 0L) > now) return true

        val unlocks = readJson(prefs.getString(KEY_TEMP_UNLOCKS, null))
        val existingExpiry = unlocks.optLong(packageName, 0L)
        unlocks.put(packageName, maxOf(existingExpiry, expiryMs))
        deliveries.put(deliveryId, expiryMs)
        prune(unlocks, now)
        prune(deliveries, now)
        prefs.edit()
            .putString(KEY_TEMP_UNLOCKS, unlocks.toString())
            .putString(KEY_DELIVERIES, deliveries.toString())
            .apply()

        AppMonitorCoordinator.checkAndReviveService(appContext, "override_approval_fcm")
        Log.d("RevokeOverride", "Applied native temporary access for $packageName")
        return true
    }

    private fun parseLong(raw: Any?): Long = when (raw) {
        is Long -> raw
        is Int -> raw.toLong()
        is Double -> raw.toLong()
        is Float -> raw.toLong()
        is String -> raw.trim().toLongOrNull() ?: 0L
        else -> 0L
    }

    private fun readJson(raw: String?): JSONObject = try {
        if (raw.isNullOrBlank()) JSONObject() else JSONObject(raw)
    } catch (_: Exception) {
        JSONObject()
    }

    private fun prune(json: JSONObject, now: Long) {
        val stale = mutableListOf<String>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            if (json.optLong(key, 0L) <= now) stale.add(key)
        }
        stale.forEach(json::remove)
    }
}
