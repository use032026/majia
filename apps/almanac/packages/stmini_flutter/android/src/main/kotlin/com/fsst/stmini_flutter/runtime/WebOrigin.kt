package com.fsst.stmini_flutter.runtime

import android.net.Uri
import java.util.Locale

/** Exact HTTPS-origin normalization shared by host configuration and WebView. */
internal object WebOrigin {
    /** Strict parser for host configuration: only a literal origin is valid. */
    fun normalizeHttps(raw: String?): String? = raw?.trim()?.takeIf(String::isNotEmpty)?.let(Uri::parse)?.let { uri ->
        if (!uri.encodedPath.isNullOrEmpty() && uri.encodedPath != "/") return@let null
        if (uri.query != null || uri.fragment != null || uri.userInfo != null) return@let null
        originOfHttpsUrl(uri)
    }

    /** Extract the HTTPS origin from a page URL without treating its path as trust configuration. */
    fun originOfHttpsUrl(raw: String?): String? = raw?.trim()?.takeIf(String::isNotEmpty)?.let(Uri::parse)?.let(::originOfHttpsUrl)

    fun originOfHttpsUrl(uri: Uri): String? {
        if (!uri.scheme.equals("https", true) || uri.host.isNullOrBlank()) return null
        if (uri.userInfo != null) return null
        val host = uri.host!!.lowercase(Locale.US)
        val port = uri.port
        return when (port) {
            -1, 443 -> "https://$host"
            in 1..65535 -> "https://$host:$port"
            else -> null
        }
    }

    fun matchesHttps(uri: Uri, expectedOrigin: String): Boolean =
        originOfHttpsUrl(uri) == expectedOrigin
}
