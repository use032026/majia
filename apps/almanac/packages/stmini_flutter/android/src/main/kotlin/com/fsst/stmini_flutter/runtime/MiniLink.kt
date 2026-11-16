package com.fsst.stmini_flutter.runtime

import android.net.Uri
import com.fsst.stmini_flutter.BuildConfig

/** Shared `mini://` contract.  This deliberately contains no host routes or
 * business identifiers, so an embedding application can safely reuse it. */
data class MiniLink(
    val miniId: String,
    val rawLink: String,
    val downloadUrl: String?,
    val currentVersion: String?,
    val minSupportVersion: String?,
    val displayName: String?,
    val displayNameEn: String?,
    val iconUrl: String?,
    val path: String?
) {
    companion object {
        private val idPattern = Regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}$")

        fun parse(raw: String): MiniLink? {
            val uri = runCatching { Uri.parse(raw.trim()) }.getOrNull() ?: return null
            if (!uri.scheme.equals("mini", ignoreCase = true)) return null
            val id = (uri.host ?: uri.schemeSpecificPart.substringBefore('?').substringBefore('/'))
                .trim().lowercase()
            if (!idPattern.matches(id)) return null
            return MiniLink(
                miniId = id,
                rawLink = raw,
                downloadUrl = uri.getQueryParameter("downloadUrl")?.trim()?.takeIf { it.isNotEmpty() },
                currentVersion = uri.getQueryParameter("currentVersion")?.trim()?.takeIf { it.isNotEmpty() },
                minSupportVersion = uri.getQueryParameter("minSupportVersion")?.trim()?.takeIf { it.isNotEmpty() },
                displayName = uri.getQueryParameter("miniName")?.trim()?.takeIf { it.isNotEmpty() },
                // This is a presentation-only label, matching the native
                // Mini contract. It never changes a package's identity or
                // verified manifest metadata.
                displayNameEn = uri.getQueryParameter("miniNameEn")?.trim()?.takeIf { it.isNotEmpty() },
                iconUrl = uri.getQueryParameter("iconUrl")?.trim()?.takeIf { it.isNotEmpty() },
                path = uri.getQueryParameter("path")?.trim()?.takeIf { it.isNotEmpty() }
            )
        }
    }
}

data class MiniSecurity(
    val trustedDownloadUrl: String?,
    val allowInsecureHttpForDebug: Boolean,
    val continuousKeepAliveMiniIds: Set<String>
) {
    /**
     * Download-host pinning is temporarily disabled because the backend may
     * rotate its package endpoint. The component still requires a valid URL
     * and HTTPS in release builds.
     */
    fun configurationRejectionReason(): String? {
        return null
    }

    fun urlRejectionReason(rawUrl: String): String? {
        val candidate = origin(rawUrl) ?: return "小程序下载地址无效"
        if (candidate.scheme == "https") return null
        if (BuildConfig.DEBUG && allowInsecureHttpForDebug && candidate.scheme == "http") return null
        return "小程序下载仅支持 HTTPS"
    }

    private data class Origin(val scheme: String, val host: String, val port: Int)

    private fun origin(value: String): Origin? {
        val uri = runCatching { Uri.parse(value.trim()) }.getOrNull() ?: return null
        val scheme = uri.scheme?.lowercase() ?: return null
        val host = uri.host?.lowercase() ?: return null
        if (scheme != "https" && scheme != "http") return null
        val port = if (uri.port >= 0) uri.port else if (scheme == "https") 443 else 80
        return Origin(scheme, host, port)
    }
}
