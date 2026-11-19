package com.fsst.stmini_flutter.web

import android.webkit.WebView
import java.util.WeakHashMap

/** Native page/session epochs also distinguish reloads of the same URL. */
internal object BridgeDocumentLease {
    private val epochs = WeakHashMap<WebView, Long>()
    @Synchronized fun generation(view: WebView): Long = epochs[view] ?: 0L
    @Synchronized fun invalidate(view: WebView) { epochs[view] = generation(view) + 1L }
    fun isCurrent(view: WebView, generation: Long, url: String?): Boolean =
        generation(view) == generation && url != null && view.url == url
}
