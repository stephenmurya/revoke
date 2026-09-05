package com.crescence.revoke

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.UUID

/** Durable local evidence journal for Credit-backed Commitments. */
class CreditEvidenceStore(private val appContext: Context) : SQLiteOpenHelper(
    appContext.applicationContext,
    "revoke_credit_evidence.db",
    null,
    1,
) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE evidence (
                event_id TEXT PRIMARY KEY,
                backing_id TEXT NOT NULL,
                commitment_id TEXT NOT NULL,
                sequence INTEGER NOT NULL,
                event_type TEXT NOT NULL,
                boot_session_id TEXT NOT NULL,
                elapsed_realtime_ms INTEGER NOT NULL,
                observed_wall_clock_ms INTEGER NOT NULL,
                package_name TEXT,
                monitoring_healthy INTEGER NOT NULL,
                payload_json TEXT NOT NULL,
                previous_hash TEXT,
                event_hash TEXT NOT NULL,
                uploaded INTEGER NOT NULL DEFAULT 0,
                created_at_ms INTEGER NOT NULL,
                UNIQUE(backing_id, sequence)
            )""".trimIndent(),
        )
        db.execSQL("CREATE INDEX evidence_pending ON evidence(uploaded, created_at_ms)")
        db.execSQL("CREATE INDEX evidence_backing ON evidence(backing_id, sequence)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    @Synchronized
    fun append(payload: Map<String, Any?>): Map<String, Any?> {
        val backingId = payload["backingId"].toString().trim()
        val commitmentId = payload["commitmentId"].toString().trim()
        if (backingId.isEmpty() || commitmentId.isEmpty()) return mapOf("accepted" to false)
        val eventType = payload["eventType"].toString().trim().ifEmpty { "FOREGROUND_OBSERVED" }
        val packageName = payload["packageName"]?.toString()?.trim().orEmpty()
        val now = System.currentTimeMillis()
        val bootSessionId = payload["bootSessionId"]?.toString()?.trim()
            ?.takeIf { it.isNotEmpty() } ?: bootSessionId()
        val elapsed = (payload["elapsedRealtimeMs"] as? Number)?.toLong()
            ?: SystemClock.elapsedRealtime()
        val sequence = nextSequence(backingId)
        val eventId = payload["eventId"]?.toString()?.trim()
            ?.takeIf { it.isNotEmpty() } ?: "native_${backingId}_${sequence}"
        val body = JSONObject().apply {
            put("backingId", backingId)
            put("commitmentId", commitmentId)
            put("sequence", sequence)
            put("eventType", eventType)
            put("bootSessionId", bootSessionId)
            put("elapsedRealtimeMs", elapsed)
            put("observedWallClockMs", now)
            put("packageName", packageName)
            put("monitoringHealthy", payload["monitoringHealthy"] == true)
        }
        val previousHash = latestHash(backingId)
        val hash = sha256("${previousHash.orEmpty()}|$eventId|$body")
        val values = ContentValues().apply {
            put("event_id", eventId)
            put("backing_id", backingId)
            put("commitment_id", commitmentId)
            put("sequence", sequence)
            put("event_type", eventType)
            put("boot_session_id", bootSessionId)
            put("elapsed_realtime_ms", elapsed)
            put("observed_wall_clock_ms", now)
            put("package_name", packageName)
            put("monitoring_healthy", if (payload["monitoringHealthy"] == true) 1 else 0)
            put("payload_json", body.toString())
            put("previous_hash", previousHash)
            put("event_hash", hash)
            put("created_at_ms", now)
        }
        val inserted = writableDatabase.insertWithOnConflict(
            "evidence", null, values, SQLiteDatabase.CONFLICT_IGNORE,
        ) != -1L
        return mapOf("accepted" to inserted, "eventId" to eventId, "sequence" to sequence, "eventHash" to hash)
    }

    @Synchronized
    fun pending(limit: Int = 100): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.query(
            "evidence", null, "uploaded = 0", null, null, null, "created_at_ms ASC", limit.toString(),
        ).use { cursor ->
            val eventId = cursor.getColumnIndexOrThrow("event_id")
            val payload = cursor.getColumnIndexOrThrow("payload_json")
            while (cursor.moveToNext()) {
                val row = JSONObject(cursor.getString(payload))
                result += mapOf(
                    "eventId" to cursor.getString(eventId),
                    "backingId" to row.optString("backingId"),
                    "commitmentId" to row.optString("commitmentId"),
                    "sequence" to row.optInt("sequence"),
                    "eventType" to row.optString("eventType"),
                    "bootSessionId" to row.optString("bootSessionId"),
                    "elapsedRealtimeMs" to row.optLong("elapsedRealtimeMs"),
                    "observedWallClockMs" to row.optLong("observedWallClockMs"),
                    "packageName" to row.optString("packageName"),
                    "monitoringHealthy" to row.optBoolean("monitoringHealthy"),
                    "eventHash" to cursorHash(cursor),
                )
            }
        }
        return result
    }

    @Synchronized
    fun markUploaded(ids: List<String>): Int {
        var updated = 0
        val values = ContentValues().apply { put("uploaded", 1) }
        for (id in ids.map { it.trim() }.filter { it.isNotEmpty() }) {
            updated += writableDatabase.update("evidence", values, "event_id = ?", arrayOf(id))
        }
        return updated
    }

    private fun nextSequence(backingId: String): Int {
        readableDatabase.rawQuery(
            "SELECT COALESCE(MAX(sequence), 0) + 1 FROM evidence WHERE backing_id = ?",
            arrayOf(backingId),
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getInt(0) else 1
        }
    }

    private fun latestHash(backingId: String): String? {
        readableDatabase.query(
            "evidence", arrayOf("event_hash"), "backing_id = ?", arrayOf(backingId),
            null, null, "sequence DESC", "1",
        ).use { cursor -> return if (cursor.moveToFirst()) cursor.getString(0) else null }
    }

    private fun cursorHash(cursor: android.database.Cursor): String =
        cursor.getString(cursor.getColumnIndexOrThrow("event_hash"))

    private fun bootSessionId(): String =
        contextBootId().ifEmpty { "boot_${SystemClock.elapsedRealtime()}_${UUID.randomUUID()}" }

    private fun contextBootId(): String = try {
        java.io.File("/proc/sys/kernel/random/boot_id").readText().trim()
    } catch (_: Exception) { "" }

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray())
        .joinToString("") { byte -> "%02x".format(byte) }
}

object CreditBackingStore {
    private const val PREFS = "RevokeCreditBackings"
    private const val KEY = "active_backings"

    @Synchronized
    fun sync(context: Context, backing: Map<String, Any?>) {
        val id = backing["backingId"]?.toString()?.trim().orEmpty()
        if (id.isEmpty()) return
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY, "[]"))
        val next = JSONArray()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            if (item.optString("backingId") != id) next.put(item)
        }
        next.put(JSONObject(backing))
        prefs.edit().putString(KEY, next.toString()).apply()
    }

    @Synchronized
    fun active(context: Context): List<JSONObject> {
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY, "[]"))
        return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
    }

    @Synchronized
    fun remove(context: Context, backingId: String) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY, "[]"))
        val next = JSONArray()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            if (item.optString("backingId") != backingId) next.put(item)
        }
        prefs.edit().putString(KEY, next.toString()).apply()
    }
}

object CreditEvidenceRecorder {
    fun recordForeground(context: Context, packageName: String, violation: Boolean = false) {
        for (backing in CreditBackingStore.active(context)) {
            val apps = backing.optJSONArray("targetApps") ?: continue
            var targeted = false
            for (i in 0 until apps.length()) if (apps.optString(i) == packageName) targeted = true
            if (!targeted) continue
            CreditEvidenceStore(context).use { store ->
                val result = store.append(
                    mapOf(
                        "backingId" to backing.optString("backingId"),
                        "commitmentId" to backing.optString("commitmentId"),
                        "eventType" to if (violation) "RULE_VIOLATION_OBSERVED" else "FOREGROUND_OBSERVED",
                        "packageName" to packageName,
                        "monitoringHealthy" to true,
                    ),
                )
                if (violation && result["accepted"] == true) {
                    CreditLocalSettlement.record(
                        context,
                        result["eventId"].toString(),
                        backing.optInt("lockedCredits", 0),
                        backing.optString("backingId"),
                    )
                }
            }
        }
    }

    fun recordHealth(context: Context) {
        for (backing in CreditBackingStore.active(context)) {
            CreditEvidenceStore(context).use { store ->
                store.append(
                    mapOf(
                        "backingId" to backing.optString("backingId"),
                        "commitmentId" to backing.optString("commitmentId"),
                        "eventType" to "MONITORING_HEALTH",
                        "monitoringHealthy" to true,
                    ),
                )
            }
        }
    }
}

object CreditLocalSettlement {
    private const val PREFS = "RevokeCreditBackings"
    private const val KEY = "pending_local_forfeitures"

    @Synchronized
    fun record(context: Context, eventId: String, amount: Int, backingId: String) {
        if (eventId.isBlank() || backingId.isBlank() || amount <= 0) return
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY, "[]"))
        for (i in 0 until array.length()) {
            if (array.optJSONObject(i)?.optString("eventId") == eventId) return
        }
        array.put(JSONObject().apply {
            put("eventId", eventId)
            put("backingId", backingId)
            put("amount", amount)
            put("state", "FAILURE_VERIFIED_LOCAL")
        })
        prefs.edit().putString(KEY, array.toString()).apply()
    }

    @Synchronized
    fun pending(context: Context): List<Map<String, Any>> {
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY, "[]"))
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            mapOf(
                "eventId" to item.optString("eventId"),
                "backingId" to item.optString("backingId"),
                "amount" to item.optInt("amount"),
                "state" to item.optString("state"),
            )
        }
    }

    @Synchronized
    fun clear(context: Context, eventIds: List<String>) {
        val ids = eventIds.toSet()
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY, "[]"))
        val next = JSONArray()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            if (!ids.contains(item.optString("eventId"))) next.put(item)
        }
        prefs.edit().putString(KEY, next.toString()).apply()
    }
}
