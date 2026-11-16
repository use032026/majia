package com.fsst.stmini_flutter

import android.os.Handler
import android.os.Looper

/** EventChannel values mirror the iOS `{name, payload}` schema. */
object StminiRuntimeEvents {
    @Volatile private var sink: ((Map<String, Any?>) -> Unit)? = null
    private val main = Handler(Looper.getMainLooper())

    fun attach(value: ((Map<String, Any?>) -> Unit)?) { sink = value }

    fun emit(name: String, payload: Map<String, Any?> = emptyMap()) {
        main.post { sink?.invoke(mapOf("name" to name, "payload" to payload)) }
    }
}
