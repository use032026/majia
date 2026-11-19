package com.fsst.stmini_flutter.runtime

import android.content.ComponentCallbacks2
import android.content.Context
import android.content.res.Configuration
import android.webkit.WebView
import com.fsst.stmini_flutter.bridge.StminiWebBridge

/**
 * Process-memory runtime pool for verified Mini sessions.
 *
 * The pool deliberately contains no host Task, account state or business
 * routing. An entry is reusable only when its verified package version still
 * matches disk. Ordinary entries use insertion-order FIFO (capacity two);
 * eligible continuous entries have a separate pool and are controlled solely
 * by [StminiHostConfiguration]. Process death, renderer loss and actual memory
 * pressure destroy entries rather than trying to resurrect an untrusted view.
 *
 * A retained entry may contain the root plus package-owned local child pages.
 * Android Activities are never retained: a later entry creates fresh
 * containers and reattaches only these already-verified WebViews. This keeps
 * the component independent of the embedding host's task implementation.
 */
internal object StminiRuntimePool {
    private const val ORDINARY_LIMIT = 2
    private const val PREFS = "stmini_flutter_runtime_keep_alive"
    private const val OPT_OUT_IDS = "continuous_keep_alive_opt_out_ids"

    internal data class RetainedChildPage(
        val webView: WebView,
        val url: String,
        val title: String?,
        val showNavigation: Boolean
    )

    internal data class RetainedSession(
        val rootWebView: WebView,
        val childPages: List<RetainedChildPage>
    )

    private data class Entry(
        val miniId: String,
        val version: String,
        val session: RetainedSession
    )

    private val ordinaryEntries = LinkedHashMap<String, Entry>()
    private val continuousEntries = LinkedHashMap<String, Entry>()
    /** One-shot handoff while a fresh root recreates its child Activity stack. */
    private val stagedChildren = mutableMapOf<String, MutableMap<Int, RetainedChildPage>>()
    private var callbacksRegistered = false
    /** Test-visible receipt after a hidden runtime's actual WebView post runs. */
    @Volatile internal var hiddenLifecycleDeliveryObserver: ((String, String) -> Unit)? = null

    @Synchronized
    fun acquire(context: Context, info: MiniPackageStore.InstalledPackage): WebView? =
        acquireSession(context, info)?.rootWebView

    @Synchronized
    fun acquireSession(context: Context, info: MiniPackageStore.InstalledPackage): RetainedSession? {
        reconcileContinuousEntries(context)
        val id = info.miniId.lowercase()
        val entry = continuousEntries.remove(id) ?: ordinaryEntries.remove(id) ?: return null
        if (entry.version != info.version) {
            destroy(entry)
            return null
        }
        return entry.session
    }

    @Synchronized
    fun retain(context: Context, info: MiniPackageStore.InstalledPackage, webView: WebView): Boolean {
        return retainSession(context, info, RetainedSession(webView, emptyList()))
    }

    @Synchronized
    fun retainSession(
        context: Context,
        info: MiniPackageStore.InstalledPackage,
        session: RetainedSession
    ): Boolean {
        reconcileContinuousEntries(context)
        val id = info.miniId.lowercase()
        if (id.isBlank()) return false
        ensureMemoryCallbacks(context.applicationContext)
        remove(id)?.let(::destroy)
        val entry = Entry(id, info.version, session)
        if (isContinuousKeepAliveEnabled(context, id)) {
            continuousEntries[id] = entry
        } else {
            ordinaryEntries[id] = entry
            while (ordinaryEntries.size > ORDINARY_LIMIT) {
                val oldest = ordinaryEntries.entries.iterator().next()
                ordinaryEntries.remove(oldest.key)
                destroy(oldest.value)
            }
        }
        return true
    }

    @Synchronized
    fun stageRestoredChildren(sessionId: String, children: List<RetainedChildPage>) {
        if (sessionId.isBlank() || children.isEmpty()) return
        stagedChildren.remove(sessionId)?.values?.forEach { destroyWebView(it.webView) }
        stagedChildren[sessionId] = children.mapIndexed { index, page -> index to page }.toMap().toMutableMap()
    }

    @Synchronized
    fun takeRestoredChild(sessionId: String, index: Int): RetainedChildPage? {
        val children = stagedChildren[sessionId] ?: return null
        val child = children.remove(index)
        if (children.isEmpty()) stagedChildren.remove(sessionId)
        return child
    }

    /** Restore launch failed before every child could claim its one-shot handoff. */
    @Synchronized
    fun discardStagedChildren(sessionId: String) {
        stagedChildren.remove(sessionId)?.values?.map { it.webView }?.distinct()?.forEach(::destroyWebView)
    }

    /** A root bridge rejection must not leave detached child renderers alive. */
    @Synchronized
    fun discardDetachedChildren(children: List<RetainedChildPage>) {
        children.map { it.webView }.distinct().forEach(::destroyWebView)
    }

    @Synchronized
    fun discard(miniId: String, webView: WebView? = null) {
        val id = miniId.lowercase()
        listOfNotNull(ordinaryEntries[id], continuousEntries[id])
            .filter { entry ->
                webView == null || entry.session.rootWebView === webView ||
                    entry.session.childPages.any { it.webView === webView }
            }
            .forEach { entry ->
                ordinaryEntries.remove(entry.miniId)
                continuousEntries.remove(entry.miniId)
                destroy(entry)
            }
    }

    @Synchronized
    fun setContinuousKeepAlive(context: Context, miniId: String, enabled: Boolean): StminiWebBridge.ContinuousKeepAliveState {
        val id = miniId.lowercase()
        val supported = supportsContinuousKeepAlive(id)
        if (!supported) return StminiWebBridge.ContinuousKeepAliveState(false, false)
        val optOut = optOutIds(context)
        if (enabled) optOut.remove(id) else optOut.add(id)
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putStringSet(OPT_OUT_IDS, optOut).apply()
        if (enabled) {
            ordinaryEntries.remove(id)?.let { continuousEntries[id] = it }
        } else {
            continuousEntries.remove(id)?.let { entry ->
                ordinaryEntries[id] = entry
                while (ordinaryEntries.size > ORDINARY_LIMIT) {
                    val oldest = ordinaryEntries.entries.iterator().next()
                    ordinaryEntries.remove(oldest.key)
                    destroy(oldest.value)
                }
            }
        }
        return state(context, id)
    }

    @Synchronized
    fun state(context: Context, miniId: String): StminiWebBridge.ContinuousKeepAliveState =
        StminiWebBridge.ContinuousKeepAliveState(
            supported = supportsContinuousKeepAlive(miniId),
            enabled = isContinuousKeepAliveEnabled(context, miniId)
        ).also { reconcileContinuousEntries(context) }

    @Synchronized
    fun notifyHiddenRuntimes(name: String, payload: Map<String, Any?>) {
        if (name != "appHide" && name != "appShow") return
        (ordinaryEntries.values + continuousEntries.values).forEach { entry ->
            val parameters = org.json.JSONObject(payload)
            val message = org.json.JSONObject().apply {
                put("method", name)
                if (parameters.length() > 0) put("params", parameters)
            }.toString().replace("</", "<\\/")
            // The dispatch is synchronous at the pool boundary; WebView then
            // serializes the script on its own UI queue. Keep the test hook at
            // this boundary so provider-less Robolectric still proves that
            // every hidden runtime is targeted for both lifecycle events.
            hiddenLifecycleDeliveryObserver?.invoke(entry.miniId, name)
            entry.session.rootWebView.post {
                entry.session.rootWebView.evaluateJavascript(
                    "javascript:typeof window.CMSCallJsMessage==='function'&&window.CMSCallJsMessage($message)",
                    null
                )
            }
        }
    }

    @Synchronized
    fun releaseForMemoryPressure() {
        val entries = (ordinaryEntries.values + continuousEntries.values).distinctBy { it.miniId }
        ordinaryEntries.clear()
        continuousEntries.clear()
        val pending = stagedChildren.values.flatMap { it.values }.distinctBy { it.webView }
        stagedChildren.clear()
        entries.forEach(::destroy)
        pending.forEach { destroyWebView(it.webView) }
    }

    @Synchronized
    private fun remove(id: String): Entry? = continuousEntries.remove(id) ?: ordinaryEntries.remove(id)

    private fun supportsContinuousKeepAlive(miniId: String): Boolean =
        miniId.isNotBlank() && miniId.lowercase() in StminiHostConfiguration.security.continuousKeepAliveMiniIds

    private fun isContinuousKeepAliveEnabled(context: Context, miniId: String): Boolean =
        supportsContinuousKeepAlive(miniId) && miniId.lowercase() !in optOutIds(context)

    private fun optOutIds(context: Context): MutableSet<String> = context.applicationContext
        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        .getStringSet(OPT_OUT_IDS, emptySet())
        .orEmpty().map { it.lowercase() }.filter { it.isNotBlank() }.toMutableSet()

    private fun destroy(entry: Entry) {
        (listOf(entry.session.rootWebView) + entry.session.childPages.map { it.webView })
            .distinct()
            .forEach(::destroyWebView)
    }

    private fun destroyWebView(webView: WebView) {
        webView.post {
            webView.stopLoading()
            webView.removeAllViews()
            webView.destroy()
        }
    }

    /**
     * The Flutter host may call initialize again after account/environment
     * changes. A previously continuous WebView must not keep its elevated
     * residency merely because it entered the pool under an old allow-list.
     * It remains an ordinary candidate (or is FIFO-evicted), never continuous.
     */
    private fun reconcileContinuousEntries(context: Context) {
        val noLongerContinuous = continuousEntries.values
            .filter { !isContinuousKeepAliveEnabled(context, it.miniId) }
        noLongerContinuous.forEach { entry ->
            continuousEntries.remove(entry.miniId)
            ordinaryEntries[entry.miniId] = entry
        }
        while (ordinaryEntries.size > ORDINARY_LIMIT) {
            val oldest = ordinaryEntries.entries.iterator().next()
            ordinaryEntries.remove(oldest.key)
            destroy(oldest.value)
        }
    }

    private fun ensureMemoryCallbacks(context: Context) {
        if (callbacksRegistered) return
        context.registerComponentCallbacks(object : ComponentCallbacks2 {
            override fun onConfigurationChanged(newConfig: Configuration) = Unit
            override fun onTrimMemory(level: Int) {
                // UI_HIDDEN/BACKGROUND is the normal outcome of switching to
                // another App. Keep the cached session through that boundary;
                // release it only under actual moderate-or-worse pressure.
                if (level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW ||
                    level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL ||
                    level >= ComponentCallbacks2.TRIM_MEMORY_MODERATE) releaseForMemoryPressure()
            }
            override fun onLowMemory() = releaseForMemoryPressure()
        })
        callbacksRegistered = true
    }
}
