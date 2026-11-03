package com.fsst.stmini_flutter.web

import android.net.Uri
import java.util.Locale

/** Current-document origin handling owned by the Web-only Core, not Mini runtime. */
internal object OnlineWebOrigin {
    /** Configuration accepts a literal origin only: no path, query, fragment or user info. */
    fun normalizeHttps(raw: String?): String? = raw?.trim()?.takeIf(String::isNotEmpty)?.let(Uri::parse)?.let { uri ->
        if (!uri.encodedPath.isNullOrEmpty() && uri.encodedPath != "/") return@let null
        if (uri.query != null || uri.fragment != null || uri.userInfo != null) return@let null
        originOfHttpsUrl(uri)
    }

    fun originOfHttpsUrl(raw: String?): String? =
        raw?.trim()?.takeIf(String::isNotEmpty)?.let(Uri::parse)?.let(::originOfHttpsUrl)

    fun originOfHttpsUrl(uri: Uri): String? {
        if (!uri.scheme.equals("https", true) || uri.host.isNullOrBlank() || uri.userInfo != null) return null
        val host = uri.host!!.lowercase(Locale.US)
        return when (val port = uri.port) {
            -1, 443 -> "https://$host"
            in 1..65535 -> "https://$host:$port"
            else -> null
        }
    }

    /** HTTP documents require the global host opt-in before using the bridge. */
    fun normalizeBridgeOrigin(raw: String?, allowInsecureHttp: Boolean): String? {
        return raw?.trim()?.takeIf(String::isNotEmpty)?.let(Uri::parse)?.let { uri ->
            if (!uri.encodedPath.isNullOrEmpty() && uri.encodedPath != "/") return@let null
            if (uri.query != null || uri.fragment != null || uri.userInfo != null) return@let null
            originOfBridgeUrl(uri, allowInsecureHttp)
        }
    }

    fun originOfBridgeUrl(raw: String?, allowInsecureHttp: Boolean = false): String? =
        raw?.trim()?.takeIf(String::isNotEmpty)?.let(Uri::parse)?.let { originOfBridgeUrl(it, allowInsecureHttp) }

    fun originOfBridgeUrl(uri: Uri, allowInsecureHttp: Boolean = false): String? {
        val scheme = uri.scheme?.lowercase(Locale.US) ?: return null
        val defaultPort = when (scheme) {
            "https" -> 443
            "http" -> if (allowInsecureHttp) 80 else return null
            else -> return null
        }
        if (uri.host.isNullOrBlank() || uri.userInfo != null) return null
        val host = uri.host!!.lowercase(Locale.US)
        return when (val port = uri.port) {
            -1 -> "$scheme://$host"
            defaultPort -> "$scheme://$host"
            in 1..65535 -> "$scheme://$host:$port"
            else -> null
        }
    }

    fun matchesHttps(uri: Uri, expectedOrigin: String): Boolean =
        originOfHttpsUrl(uri) == expectedOrigin

    fun matchesBridge(uri: Uri, expectedOrigin: String, allowInsecureHttp: Boolean = false): Boolean =
        originOfBridgeUrl(uri, allowInsecureHttp) == expectedOrigin
}
