package com.fsst.stmini_flutter.web

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import com.fsst.stmini_flutter.BuildConfig
import org.json.JSONObject

/**
 * One display owner for host `openWeb` and Mini-owned `/web` pages.
 *
 * It depends only on the Shared Online Web Core. A caller may attach the
 * narrow [OnlineWebSessionDelegate] when it needs Mini-only routing; ordinary
 * host pages have no such delegate and forward only to Flutter.
 */
internal class OnlineWebActivity : Activity() {
    companion object {
        const val EXTRA_URL = "stmini.onlineWeb.url"
        const val EXTRA_TITLE = "stmini.onlineWeb.title"
        const val EXTRA_SHOW_NAVIGATION = "stmini.onlineWeb.showNavigation"
        const val EXTRA_ALLOW_INSECURE_HTTP = "stmini.onlineWeb.allowInsecureHttp"
        const val EXTRA_SESSION_DELEGATE = "stmini.onlineWeb.sessionDelegate"
        @Volatile private var active: OnlineWebActivity? = null
        private val pages = LinkedHashSet<OnlineWebActivity>()
        /** Test-only seam; production always invokes the real WebView APIs. */
        @Volatile internal var scriptExecutorForTest: OnlineWebScriptExecutor? = null

        fun intent(
            context: Context,
            url: String,
            title: String?,
            showNavigation: Boolean,
            sessionDelegate: String? = null,
            allowInsecureHttpNavigation: Boolean = false
        ) = Intent(context, OnlineWebActivity::class.java).apply {
            putExtra(EXTRA_URL, url)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_SHOW_NAVIGATION, showNavigation)
            putExtra(EXTRA_ALLOW_INSECURE_HTTP, allowInsecureHttpNavigation)
            sessionDelegate?.let { putExtra(EXTRA_SESSION_DELEGATE, it) }
        }

        fun closeActive() { active?.finish() }
        fun notifyHostSessionChanged(reason: String): Int {
            val targets = synchronized(pages) { pages.filter { it.sessionDelegate == null } }
            targets.forEach { it.deliverSessionChangedWithoutReload(reason) }
            return targets.size
        }

        /**
         * Every retained page receives `appHide` so it can persist state before
         * suspension. `appShow` belongs only to the visible page; covered
         * pages recover when their own `pageWillAppear` is delivered.
         */
        fun notifyAppLifecycle(method: String, params: Map<String, Any?> = emptyMap()) {
            if (method == "appShow") {
                active?.deliverHostLifecycle(method, params)
                return
            }
            val targets = synchronized(pages) { pages.toList() }
            targets.forEach { it.deliverHostLifecycle(method, params) }
        }
    }

    private lateinit var webView: WebView
    private lateinit var core: OnlineWebCore
    private var header: FrameLayout? = null
    private var sessionKey: String? = null
    private var sessionDelegate: OnlineWebSessionDelegate? = null
    private var sessionEpoch: Long = 0
    private var pageVisible = false
    private var pendingSessionReload = false
    private var pendingSessionReason: String? = null
    private var pendingPageWillAppearAfterSessionReload = false
    private var allowInsecureHttpNavigation = false
    private val lifecycleHandler = Handler(Looper.getMainLooper())

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        active = this
        synchronized(pages) { pages += this }
        val url = intent.getStringExtra(EXTRA_URL) ?: return finish()
        allowInsecureHttpNavigation = intent.getBooleanExtra(EXTRA_ALLOW_INSECURE_HTTP, false)
        sessionKey = intent.getStringExtra(EXTRA_SESSION_DELEGATE)
        val root = FrameLayout(this)
        webView = WebView(this)
        root.addView(webView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        ))
        if (intent.getBooleanExtra(EXTRA_SHOW_NAVIGATION, true)) {
            addHeader(root, intent.getStringExtra(EXTRA_TITLE))
        }
        setContentView(root)
        val attachment = OnlineWebSessionRegistry.attach(sessionKey, this)
        sessionDelegate = attachment.delegate
        sessionEpoch = attachment.epoch
        // A Mini session can be closed immediately after startActivity, before
        // Android creates this owner. Consume that tombstone without loading a
        // page or resurrecting the just-closed session.
        if (attachment.wasClosedBeforeAttach) {
            finish()
            return
        }
        core = OnlineWebCore(webView)
        core.onTitleChanged = { title -> (header?.getChildAt(1) as? TextView)?.text = title }
        core.configureWebView()
        webView.webChromeClient = object : WebChromeClient() {
            override fun onReceivedTitle(view: WebView, title: String?) = core.receivedTitle(title)
        }
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                OnlineWebCore.NavigationPolicy.blocks(request, allowInsecureHttpNavigation)

            override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
                BridgeDocumentLease.invalidate(view)
            }
            override fun onPageCommitVisible(view: WebView, committedUrl: String) {
                super.onPageCommitVisible(view, committedUrl)
                core.onTopLevelPageCommit(committedUrl)
                deliverPendingSessionLifecycle(committedUrl)
            }
        }
        core.installExactOriginBridge(
            initialUrl = url,
            allowInsecureHttpBridge = allowInsecureHttpNavigation,
            onMessage = { raw, origin -> handleBridgeMessage(raw, origin) },
            onUnavailable = { /* page remains usable, bridge stays unavailable */ }
        )
        core.load(url)
    }

    private fun handleBridgeMessage(raw: String, origin: String) {
        if (sessionDelegate?.handleMessage(raw, origin, webView, ::finish) == true) return
        val generation = BridgeDocumentLease.generation(webView)
        val document = webView.url
        val request = runCatching { JSONObject(raw) }.getOrNull() ?: return
        val method = request.optString("method")
        val params = request.optJSONObject("params") ?: JSONObject()
        val methodId = params.optString("methodId")
        val response = OnlineWebCore.CmsJsCallback.response(method, methodId)
        if (method.isBlank()) {
            OnlineWebCore.CmsJsCallback.fail(response, "网页 Bridge 请求无效")
            OnlineWebCore.CmsJsCallback.deliver(webView, response.toString())
            return
        }
        // Ordinary host Web pages share the session-only bridge with the
        // Web-only runtime. Mini-owned sessions still take their dedicated
        // route above and retain their additional package capabilities.
        if (sessionDelegate == null) {
            OnlineWebSessionBridge.handle(this, method, params, origin)?.let { builtInResponse ->
                response.put("code", builtInResponse.optString("code", "0"))
                response.put("data", builtInResponse.opt("data") ?: JSONObject().put("msg", "网页 Bridge 请求失败"))
                OnlineWebCore.CmsJsCallback.deliver(webView, response.toString())
                return
            }
        }
        OnlineWebHostBridge.forward(method, params, origin) { hostResponse ->
            if (!BridgeDocumentLease.isCurrent(webView, generation, document)) return@forward
            response.put("code", hostResponse.optString("code", "0"))
            response.put("data", hostResponse.opt("data") ?: JSONObject().put("msg", "宿主处理网页请求失败"))
            OnlineWebCore.CmsJsCallback.deliver(webView, response.toString())
        }
    }

    private fun addHeader(root: FrameLayout, title: String?) {
        val bar = FrameLayout(this).apply { setBackgroundColor(0xFFFFFFFF.toInt()) }
        val back = ImageButton(this).apply {
            contentDescription = "返回"
            setImageResource(android.R.drawable.ic_media_previous)
            setBackgroundColor(0x00000000)
            setOnClickListener { leaveFromHeader() }
        }
        val label = TextView(this).apply { text = title.orEmpty(); gravity = Gravity.CENTER; textSize = 16f }
        bar.addView(back, FrameLayout.LayoutParams(56, 56, Gravity.START or Gravity.CENTER_VERTICAL))
        bar.addView(label, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 56, Gravity.CENTER
        ).apply { leftMargin = 56; rightMargin = 56 })
        root.addView(bar, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 56, Gravity.TOP))
        header = bar
        (webView.layoutParams as FrameLayout.LayoutParams).topMargin = 56
    }

    private fun leaveFromHeader() {
        val delegate = sessionDelegate
        if (delegate != null) delegate.leavePage(::finish) else if (!core.goBackIfPossible()) finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (!core.goBackIfPossible()) finish()
    }

    override fun onResume() {
        super.onResume()
        active = this
        pageVisible = true
        if (::core.isInitialized) {
            if (pendingSessionReload) {
                pendingSessionReload = false
                scriptExecutor().reload(webView)
            } else {
                core.pageVisibilityMessage("pageWillAppear")
                // A session change without a storage mirror may have arrived
                // while this child was covered. Deliver it only after this
                // document is visible again instead of silently dropping it.
                if (pendingSessionReason != null) {
                    deliverPendingSessionLifecycle(webView.url.orEmpty())
                }
            }
        }
    }

    override fun onPause() {
        pageVisible = false
        if (::core.isInitialized) core.pageVisibilityMessage("pageWillDisAppear")
        super.onPause()
    }

    /** Called only by the Mini runtime registry; host Web has no session key. */
    internal fun finishFromMiniSession() = finish()
    internal fun sessionEpochForTest(): Long = sessionEpoch

    /** Delivers the Mini session broadcast through its retained narrow delegate. */
    internal fun deliverSessionChanged(delegate: OnlineWebSessionDelegate, reason: String) {
        if (::webView.isInitialized && !isFinishing && !isDestroyed) {
            BridgeDocumentLease.invalidate(webView)
            delegate.sessionChanged(this, webView, reason)
        }
    }

    /**
     * Called by the Mini delegate only after it created an explicitly
     * allow-listed localStorage script. Lifecycle messages are held until the
     * replacement document commits, never sent into the old page being
     * reloaded.
     */
    internal fun applySessionStorageMirror(script: String, reason: String, reloadOnChange: Boolean) {
        if (!::webView.isInitialized || isFinishing || isDestroyed) return
        webView.post {
            if (isFinishing || isDestroyed) return@post
            scriptExecutor().evaluate(webView, script) { applied ->
                completeSessionStorageMirror(applied == "true", reason, reloadOnChange)
            }
        }
    }

    /** Isolated for deterministic tests of the write → reload → notify gate. */
    internal fun completeSessionStorageMirror(applied: Boolean, reason: String, reloadOnChange: Boolean) {
        if (!applied || isFinishing || isDestroyed) return
        pendingSessionReason = reason
        pendingPageWillAppearAfterSessionReload = true
        if (reloadOnChange) {
            if (pageVisible) scriptExecutor().reload(webView) else pendingSessionReload = true
        } else {
            deliverPendingSessionLifecycle(webView.url.orEmpty())
        }
    }

    internal fun pendingSessionReasonForTest(): String? = pendingSessionReason
    internal fun pendingSessionReloadForTest(): Boolean = pendingSessionReload

    /** No mirrored storage was configured, so notify the current document directly. */
    internal fun deliverSessionChangedWithoutReload(reason: String) {
        BridgeDocumentLease.invalidate(webView)
        pendingSessionReason = reason
        if (pageVisible) deliverPendingSessionLifecycle(webView.url.orEmpty())
    }

    /** Delivers an app-level lifecycle message without coupling this owner to Mini runtime APIs. */
    internal fun deliverHostLifecycle(method: String, params: Map<String, Any?> = emptyMap()) {
        if (!::webView.isInitialized || isFinishing || isDestroyed) return
        val payload = JSONObject().put("method", method)
        if (params.isNotEmpty()) {
            payload.put("params", JSONObject().apply {
                params.forEach { (key, value) -> put(key, value) }
            })
        }
        OnlineWebCore.CmsJsCallback.deliverHostMessage(webView, payload.toString())
    }

    private fun deliverPendingSessionLifecycle(url: String, attempt: Int = 0) {
        if (!pageVisible || isFinishing || isDestroyed) return
        val reason = pendingSessionReason ?: return
        val expectedOrigin = OnlineWebOrigin.originOfHttpsUrl(url) ?: return
        if (OnlineWebOrigin.originOfHttpsUrl(webView.url) != expectedOrigin) return
        val appear = pendingPageWillAppearAfterSessionReload
        val calls = org.json.JSONArray().apply {
            put(JSONObject().put("method", "miniSessionChanged").put("params", JSONObject().put("reason", reason)))
            put(JSONObject().put("method", "updateUserInfo"))
            if (appear) put(JSONObject().put("method", "pageWillAppear"))
        }.toString().replace("</", "<\\/")
        scriptExecutor().evaluate(webView,
            """(() => { if (typeof window.CMSCallJsMessage !== 'function') return false; $calls.forEach((m) => window.CMSCallJsMessage(m)); return true; })();"""
        ) { delivered ->
            if (delivered == "true") {
                pendingSessionReason = null
                pendingPageWillAppearAfterSessionReload = false
            } else if (attempt < 8 && pageVisible && !isFinishing && !isDestroyed) {
                lifecycleHandler.postDelayed({ deliverPendingSessionLifecycle(url, attempt + 1) }, 50L)
            }
        }
    }

    override fun onDestroy() {
        if (active === this) active = null
        synchronized(pages) { pages -= this }
        lifecycleHandler.removeCallbacksAndMessages(null)
        OnlineWebSessionRegistry.detach(sessionKey, this, sessionEpoch, isChangingConfigurations)
        if (::webView.isInitialized) { BridgeDocumentLease.invalidate(webView); webView.removeAllViews(); webView.destroy() }
        super.onDestroy()
    }

    private fun scriptExecutor(): OnlineWebScriptExecutor = scriptExecutorForTest ?: OnlineWebScriptExecutor.system
}

/** Keeps WebView side effects observable without changing production semantics. */
internal interface OnlineWebScriptExecutor {
    fun evaluate(webView: WebView, script: String, completed: (String?) -> Unit)
    fun reload(webView: WebView)

    companion object {
        val system = object : OnlineWebScriptExecutor {
            override fun evaluate(webView: WebView, script: String, completed: (String?) -> Unit) =
                webView.evaluateJavascript(script, completed)
            override fun reload(webView: WebView) = webView.reload()
        }
    }
}
