package com.fsst.stmini_flutter.web

/** Web-only host configuration shared by the full and trimmed runtimes. */
internal object OnlineWebConfiguration {
    @Volatile private var allowInsecureHttpNavigation = false
    @Volatile private var bridgeContext: Map<String, Any?> = emptyMap()

    fun configure(context: Map<String, Any?>?) {
        bridgeContext = context?.toMap().orEmpty()
        @Suppress("UNCHECKED_CAST")
        val security = context?.get("webSecurity") as? Map<String, Any?>
        allowInsecureHttpNavigation = security?.get("allowInsecureHTTP") as? Boolean ?: false
    }

    fun allowsInsecureHttpNavigation(): Boolean = allowInsecureHttpNavigation
    fun context(): Map<String, Any?> = bridgeContext
}
