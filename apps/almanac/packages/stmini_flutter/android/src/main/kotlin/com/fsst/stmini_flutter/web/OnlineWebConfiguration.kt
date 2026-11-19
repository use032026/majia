package com.fsst.stmini_flutter.web

/**
 * Web-only host configuration shared by the full and trimmed runtimes.
 *
 * It deliberately carries only values needed by an exact-origin ordinary Web
 * bridge. Mini package configuration remains owned by the full runtime.
 */
internal object OnlineWebConfiguration {
    @Volatile private var bridgeContext: Map<String, Any?> = emptyMap()

    fun configure(context: Map<String, Any?>?) {
        bridgeContext = context?.toMap().orEmpty()
    }

    fun context(): Map<String, Any?> = bridgeContext
}
