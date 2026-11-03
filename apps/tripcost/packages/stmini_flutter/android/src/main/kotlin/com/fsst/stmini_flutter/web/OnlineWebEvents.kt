package com.fsst.stmini_flutter.web

import io.flutter.plugin.common.EventChannel

/** Event stream for ordinary Web presentation only. */
internal object OnlineWebEvents {
    @Volatile private var sink: EventChannel.EventSink? = null

    fun attach(value: EventChannel.EventSink?) { sink = value }

    fun emit(name: String, payload: Map<String, Any?> = emptyMap()) {
        sink?.success(mapOf("name" to name, "payload" to payload))
    }
}
