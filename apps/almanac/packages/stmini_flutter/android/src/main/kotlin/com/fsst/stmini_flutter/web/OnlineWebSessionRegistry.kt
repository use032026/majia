package com.fsst.stmini_flutter.web

import android.webkit.WebView
import java.lang.ref.WeakReference
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Narrow optional seam from the shared online-Web owner back into a Mini
 * session. The owner knows no Mini package, storage, router or runtime class;
 * those concerns stay behind this interface in the main package.
 */
internal interface OnlineWebSessionDelegate {
    fun handleMessage(raw: String, origin: String, webView: WebView, closePage: () -> Unit): Boolean
    fun leavePage(closePage: () -> Unit)
    /** The delegate may apply an allow-listed storage mirror before asking the owner to reload. */
    fun sessionChanged(owner: OnlineWebActivity, webView: WebView, reason: String)
}

/** Result of attaching an owner to a short-lived Mini `/web` session entry. */
internal data class OnlineWebSessionAttachment(
    val delegate: OnlineWebSessionDelegate?,
    val epoch: Long,
    val wasClosedBeforeAttach: Boolean
)

/**
 * Strongly retains the runtime delegate for exactly the displayed owner's
 * lifetime. A close that arrives between `startActivity` and `onCreate` is a
 * tombstone: the eventual Activity attaches, immediately finishes, and
 * removes the entry. Epochs protect a new config-recreated owner from an old
 * owner's delayed `onDestroy`.
 */
internal object OnlineWebSessionRegistry {
    private data class Entry(
        val sessionId: String,
        val delegate: OnlineWebSessionDelegate,
        var owner: WeakReference<OnlineWebActivity>? = null,
        var ownerEpoch: Long = 0,
        var sequence: Long = 0,
        var closed: Boolean = false
    )

    private val entries = ConcurrentHashMap<String, Entry>()
    @Volatile private var nextSequence = 0L
    @Volatile private var nextEpoch = 0L

    fun register(sessionId: String, delegate: OnlineWebSessionDelegate): String {
        val key = UUID.randomUUID().toString()
        entries[key] = Entry(sessionId, delegate)
        return key
    }

    fun attach(key: String?, owner: OnlineWebActivity): OnlineWebSessionAttachment {
        val entry = key?.let(entries::get) ?: return OnlineWebSessionAttachment(null, 0, false)
        synchronized(entry) {
            if (entry.closed) {
                entries.remove(key, entry)
                return OnlineWebSessionAttachment(null, entry.ownerEpoch, true)
            }
            entry.owner = WeakReference(owner)
            entry.ownerEpoch = synchronized(this) { ++nextEpoch }
            entry.sequence = synchronized(this) { ++nextSequence }
            return OnlineWebSessionAttachment(entry.delegate, entry.ownerEpoch, false)
        }
    }

    /**
     * Keep the entry while Android rotates the owner. A later owner gets a new
     * epoch; an old delayed destroy can therefore never erase that new owner.
     */
    fun detach(key: String?, owner: OnlineWebActivity, epoch: Long, changingConfigurations: Boolean) {
        val entry = key?.let(entries::get) ?: return
        synchronized(entry) {
            if (entry.ownerEpoch != epoch || entry.owner?.get() !== owner) return
            if (changingConfigurations) {
                entry.owner = null
            } else {
                entries.remove(key, entry)
            }
        }
    }

    private fun markClosed(entry: Entry): OnlineWebActivity? = synchronized(entry) {
        entry.closed = true
        entry.owner?.get()
    }

    fun closeSession(sessionId: String) = entries.values
        .filter { it.sessionId == sessionId }
        .sortedByDescending { it.sequence }
        .forEach { markClosed(it)?.finishFromMiniSession() }

    fun closeCount(sessionId: String, count: Int) = entries.values
        .filter { it.sessionId == sessionId }
        .sortedByDescending { it.sequence }
        .take(count.coerceAtLeast(1))
        .forEach { markClosed(it)?.finishFromMiniSession() }

    fun notifySessionChanged(sessionId: String, reason: String): Int {
        var notified = 0
        entries.values.filter { it.sessionId == sessionId }.forEach { entry ->
            val owner = synchronized(entry) { if (entry.closed) null else entry.owner?.get() } ?: return@forEach
            owner.deliverSessionChanged(entry.delegate, reason)
            notified += 1
        }
        return notified
    }

    internal fun activeCountForTest(): Int = entries.size
    internal fun containsForTest(key: String): Boolean = entries.containsKey(key)
    internal fun closedForTest(key: String): Boolean = entries[key]?.closed == true
    internal fun clearForTest() { entries.clear() }
}
