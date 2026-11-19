package com.fsst.stmini_flutter

import android.net.Uri
import android.util.Log

/**
 * Debug-only, non-persistent route diagnostics. Keep user credentials out of
 * console output: URLs retain only scheme, host and path.
 */
internal object StminiDebugLog {
    private const val TAG = "STMiniFlutter"

    fun webRouter(event: String, fields: Map<String, Any?> = emptyMap()) {
        if (!BuildConfig.DEBUG) return
        val detail = fields.toSortedMap().entries.joinToString(" ") { (key, value) ->
            "$key=${safeValue(value)}"
        }
        Log.d(TAG, "[web-router] event=$event${if (detail.isEmpty()) "" else " $detail"}")
    }

    fun redactedUrl(rawUrl: String?): String {
        if (rawUrl.isNullOrBlank()) return "<empty>"
        return runCatching {
            val uri = Uri.parse(rawUrl)
            "${uri.scheme ?: ""}://${uri.host ?: ""}${uri.path ?: ""}"
        }.getOrElse { "<invalid-url>" }
    }

    private fun safeValue(value: Any?): String = when (value) {
        null -> "<absent>"
        is String -> value.replace(Regex("[\\r\\n]"), " ").take(120)
        else -> value.toString().take(120)
    }
}
