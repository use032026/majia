package com.fsst.stmini_flutter

import android.os.Handler
import android.os.Looper

/** EventChannel values mirror the iOS `{name, payload}` schema. */
object StminiRuntimeEvents {
    private val lock = Any()
    private var current: Subscription? = null
    private val main = Handler(Looper.getMainLooper())

    /** Cancelling an obsolete owner cannot detach a newer engine/listener. */
    class Subscription internal constructor(internal val sink: (Map<String, Any?>) -> Unit) {
        internal var active = true
        fun cancel() = synchronized(lock) {
            active = false
            if (current === this) current = null
        }
        fun emit(name: String, payload: Map<String, Any?> = emptyMap()) = enqueue(this, name, payload)
    }

    fun attach(value: (Map<String, Any?>) -> Unit): Subscription = synchronized(lock) {
        current?.active = false
        Subscription(value).also { current = it }
    }

    fun emit(name: String, payload: Map<String, Any?> = emptyMap()) {
        val owner = synchronized(lock) { current } ?: return
        enqueue(owner, name, payload)
    }

    private fun enqueue(owner: Subscription, name: String, payload: Map<String, Any?>) {
        // Snapshot the recipient and payload before yielding to the main queue.
        synchronized(lock) { if (current !== owner || !owner.active) return }
        val message = mapOf("name" to name, "payload" to payload.toMap())
        main.post {
            synchronized(lock) {
                if (current === owner && owner.active) {
                    // An engine may detach while an optional diagnostic is queued.
                    try { owner.sink(message) } catch (_: RuntimeException) { owner.cancel() }
                }
            }
        }
    }
}
