package com.fsst.stmini_flutter.web

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.ConsoleMessage
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import com.fsst.stmini_flutter.BuildConfig
import org.json.JSONObject
import java.util.Locale

/** Standalone display owner for an ordinary online Web document. */
internal class OnlineWebActivity : Activity() {
    companion object {
        const val EXTRA_URL = "stmini.onlineWeb.url"
        const val EXTRA_TITLE = "stmini.onlineWeb.title"
        const val EXTRA_SHOW_NAVIGATION = "stmini.onlineWeb.showNavigation"
        const val EXTRA_ALLOW_INSECURE_HTTP = "stmini.onlineWeb.allowInsecureHttp"
        @Volatile private var active: OnlineWebActivity? = null
        private val pages = LinkedHashSet<OnlineWebActivity>()

        fun intent(
            context: Context,
            url: String,
            title: String?,
            showNavigation: Boolean,
            allowInsecureHttpNavigation: Boolean = false
        ) = Intent(context, OnlineWebActivity::class.java).apply {
            putExtra(EXTRA_URL, url)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_SHOW_NAVIGATION, showNavigation)
            putExtra(EXTRA_ALLOW_INSECURE_HTTP, allowInsecureHttpNavigation)
        }

        /** The common toolbar uses dp, never raw pixels. */
        internal fun navigationBarSizePx(density: Float): Int = (56f * density + 0.5f).toInt()

        fun closeActive() { active?.finish() }

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

        /**
         * Mirrors Mini's sibling `/web` refresh contract. The active page is
         * the login/route child that requested this delivery, so only earlier
         * pages receive the credential-free event before the child finishes.
         */
        fun notifySessionChanged(rawReason: String): Int {
            val reason = rawReason.take(64)
            val source = active
            val targets = synchronized(pages) { pages.filter { it !== source }.toList() }
            targets.forEach { it.deliverSessionChanged(reason) }
            if (BuildConfig.DEBUG) {
                Log.d("STMiniWeb", "[STMini][web_session_changed] reason=$reason notified=${targets.size}")
            }
            return targets.size
        }
    }

    private lateinit var root: FrameLayout
    private lateinit var webView: WebView
    private lateinit var core: OnlineWebCore
    private var header: FrameLayout? = null
    private var headerTitle: TextView? = null
    private lateinit var failureView: ScrollView
    private lateinit var spinner: ProgressBar
    private var navigationUrl: String? = null
    private var failedUrl: String? = null
    private var loadingPage = false
    private var usesChinese = false
    private var predictiveBackCallback: OnBackInvokedCallback? = null
    private val createdAtMs = SystemClock.elapsedRealtime()
    private var navigationStartedAtMs: Long? = null
    private var allowInsecureHttpNavigation = false
    private val visibility = OnlineWebVisibilityLifecycle()
    internal var loadedUrlForTest: String? = null
        private set
    internal var loadedTitleForTest: String? = null
        private set

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        active = this
        synchronized(pages) { pages += this }
        root = FrameLayout(this)
        webView = WebView(this)
        root.addView(webView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        ))
        configureFailureView()
        setContentView(root)
        core = OnlineWebCore(webView)
        core.onTitleChanged = { title -> headerTitle?.text = title }
        core.configureWebView()
        reportTiming("activity.created")
        webView.webChromeClient = object : WebChromeClient() {
            override fun onReceivedTitle(view: WebView, title: String?) = core.receivedTitle(title)

            override fun onConsoleMessage(message: ConsoleMessage): Boolean {
                if (BuildConfig.DEBUG && message.message().startsWith("[STMini Web Debug]")) {
                    Log.d("STMiniWeb", message.message())
                    return true
                }
                return super.onConsoleMessage(message)
            }
        }
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (request.url.scheme.equals("mailto", ignoreCase = true)) {
                    // Keep this user-driven OS hand-off outside Bridge and
                    // ordinary URL navigation. Iframes never open mail apps.
                    if (request.isForMainFrame && request.hasGesture()) {
                        try {
                            startActivity(Intent(Intent.ACTION_SENDTO, request.url))
                        } catch (_: ActivityNotFoundException) {
                            Toast.makeText(this@OnlineWebActivity, text(
                                "请先设置可用的邮件应用，或复制邮箱地址后联系。",
                                "Set up a mail app, or copy the email address to contact us."
                            ), Toast.LENGTH_LONG).show()
                        }
                    }
                    return true
                }
                val blocked = OnlineWebCore.NavigationPolicy.blocks(request, allowInsecureHttpNavigation)
                if (!blocked && request.isForMainFrame) navigationUrl = request.url.toString()
                return blocked
            }

            override fun onPageCommitVisible(view: WebView, committedUrl: String) {
                super.onPageCommitVisible(view, committedUrl)
                reportTiming("navigation.committed", committedUrl)
                // WebView may commit its own error document after reporting a
                // failed main request. It must not hide the native retry UI.
                if (failedUrl != null) return
                core.onTopLevelPageCommit(committedUrl)
                if (visibility.onPageCommitted()) sendPageWillAppear()
            }

            override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                navigationStartedAtMs = SystemClock.elapsedRealtime()
                if (isPermittedUrl(url)) navigationUrl = url
                failedUrl = null
                showLoading()
                reportTiming("navigation.started", url)
            }

            override fun onPageFinished(view: WebView, url: String?) {
                super.onPageFinished(view, url)
                reportTiming("navigation.finished", url)
                if (url == navigationUrl) {
                    loadingPage = false
                    spinner.visibility = View.GONE
                }
                // onPageFinished also follows onReceivedError. Only a fresh
                // attempt clears failedUrl; this callback never does.
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: android.webkit.WebResourceError) {
                super.onReceivedError(view, request, error)
                if (isCurrentMainRequest(request) && error.description?.toString() != "net::ERR_ABORTED") {
                    showFailure(request.url.toString())
                    reportTiming(
                        event = "navigation.failed",
                        url = request.url?.toString(),
                        errorCode = error.errorCode,
                        errorDescription = error.description?.toString()
                    )
                }
            }

            override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, response: WebResourceResponse) {
                super.onReceivedHttpError(view, request, response)
                if (isCurrentMainRequest(request) && response.statusCode >= 400) {
                    showFailure(request.url.toString())
                }
            }
        }
        registerPredictiveBackCallback()
        loadIntent(intent) ?: finish()
    }

    /** 保留系统重新投递 Intent 时的刷新能力；普通 `/web` 请求不会复用栈顶 Activity。 */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        loadIntent(intent)
    }

    private fun loadIntent(source: Intent): Boolean {
        val url = source.getStringExtra(EXTRA_URL) ?: return false
        allowInsecureHttpNavigation = source.getBooleanExtra(EXTRA_ALLOW_INSECURE_HTTP, false)
        val language = runCatching { Uri.parse(url).getQueryParameter("lang") }.getOrNull()
        usesChinese = when (language) {
            "zh" -> true
            "en" -> false
            else -> Locale.getDefault().language == "zh"
        }
        updateFailureText()
        visibility.onNewDocument()
        loadedUrlForTest = url
        loadedTitleForTest = source.getStringExtra(EXTRA_TITLE)
        updateHeader(
            showNavigation = source.getBooleanExtra(EXTRA_SHOW_NAVIGATION, true),
            title = source.getStringExtra(EXTRA_TITLE)
        )
        core.installExactOriginBridge(
            initialUrl = url,
            allowInsecureHttpBridge = allowInsecureHttpNavigation,
            onMessage = ::handleBridgeMessage,
            onUnavailable = { /* The document stays usable without a bridge. */ }
        )
        loadPage(url)
        return true
    }

    private fun reportTiming(
        event: String,
        url: String? = null,
        errorCode: Int? = null,
        errorDescription: String? = null
    ) {
        if (!BuildConfig.DEBUG) return
        val now = SystemClock.elapsedRealtime()
        val fields = mutableListOf(
            "event=$event",
            "activityElapsedMs=${now - createdAtMs}"
        )
        navigationStartedAtMs?.let { fields += "navigationElapsedMs=${now - it}" }
        url?.let { fields += "url=${redactUrl(it)}" }
        errorCode?.let { fields += "errorCode=$it" }
        errorDescription?.takeIf { it.isNotBlank() }?.let { fields += "error=${it.take(120)}" }
        Log.d("STMiniWeb", "[STMini][web_timing] ${fields.joinToString(" ")}")
    }

    private fun redactUrl(raw: String): String = runCatching {
        val parsed = Uri.parse(raw)
        "${parsed.scheme}://${parsed.host.orEmpty()}${parsed.path.orEmpty()}"
    }.getOrDefault("")

    private fun handleBridgeMessage(raw: String, origin: String) {
        val request = runCatching { JSONObject(raw) }.getOrNull() ?: return
        val method = request.optString("method")
        val params = request.optJSONObject("params") ?: JSONObject()
        val response = OnlineWebCore.CmsJsCallback.response(method, params.optString("methodId"))
        if (method.isBlank()) {
            OnlineWebCore.CmsJsCallback.fail(response, "网页 Bridge 请求无效")
            OnlineWebCore.CmsJsCallback.deliver(webView, response.toString())
            return
        }
        if (method == "setNavigationBarTitle") {
            headerTitle?.text = params.optString("title")
            OnlineWebCore.CmsJsCallback.deliver(webView, response.toString())
            return
        }
        OnlineWebSessionBridge.handle(this, method, params)?.let { builtInResponse ->
            if (BuildConfig.DEBUG && (method == "getUserInfo" || method == "getToken")) {
                val data = builtInResponse.opt("data")
                val dataObject = data as? JSONObject
                val token = dataObject?.optString("token").orEmpty().ifEmpty {
                    data as? String ?: ""
                }
                val userIdPresent = dataObject?.opt("user_id") != null || dataObject?.opt("id") != null
                Log.d("STMiniWeb", "[STMini][web_session_bridge] method=$method tokenPresent=${token.isNotEmpty()} userIdPresent=$userIdPresent")
            }
            response.put("code", builtInResponse.optString("code", "0"))
            response.put("data", builtInResponse.opt("data") ?: JSONObject().put("msg", "网页 Bridge 请求失败"))
            OnlineWebCore.CmsJsCallback.deliver(webView, response.toString())
            return
        }
        OnlineWebHostBridge.forward(method, params, origin) { hostResponse ->
            response.put("code", hostResponse.optString("code", "0"))
            response.put("data", hostResponse.opt("data") ?: JSONObject().put("msg", "宿主处理网页请求失败"))
            OnlineWebCore.CmsJsCallback.deliver(webView, response.toString())
        }
    }

    private fun updateHeader(showNavigation: Boolean, title: String?) {
        if (!showNavigation) {
            header?.let(root::removeView)
            header = null
            headerTitle = null
            (webView.layoutParams as FrameLayout.LayoutParams).topMargin = 0
            (failureView.layoutParams as FrameLayout.LayoutParams).topMargin = 0
            return
        }
        if (header == null) addHeader()
        headerTitle?.text = title.orEmpty()
        header?.findViewWithTag<ImageButton>("online-web-reload")?.contentDescription = text("重新加载", "Reload")
    }

    private fun addHeader() {
        val size = navigationBarSizePx(resources.displayMetrics.density)
        val bar = FrameLayout(this).apply { setBackgroundColor(0xFFFFFFFF.toInt()) }
        val back = ImageButton(this).apply {
            contentDescription = "返回"
            setImageResource(android.R.drawable.ic_media_previous)
            imageTintList = ColorStateList.valueOf(Color.BLACK)
            setBackgroundColor(0x00000000)
            setOnClickListener { if (!core.goBackIfPossible()) finish() }
        }
        val reload = ImageButton(this).apply {
            tag = "online-web-reload"
            contentDescription = text("重新加载", "Reload")
            setImageResource(android.R.drawable.ic_popup_sync)
            imageTintList = ColorStateList.valueOf(Color.BLACK)
            setBackgroundColor(0x00000000)
            setOnClickListener { reloadPage() }
        }
        val label = TextView(this).apply {
            gravity = Gravity.CENTER
            textSize = 16f
            setTextColor(Color.BLACK)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        bar.addView(back, FrameLayout.LayoutParams(size, size, Gravity.START or Gravity.CENTER_VERTICAL))
        bar.addView(label, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, size, Gravity.CENTER
        ).apply { leftMargin = size; rightMargin = size })
        bar.addView(reload, FrameLayout.LayoutParams(size, size, Gravity.END or Gravity.CENTER_VERTICAL))
        root.addView(bar, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, size, Gravity.TOP))
        header = bar
        headerTitle = label
        (webView.layoutParams as FrameLayout.LayoutParams).topMargin = size
        (failureView.layoutParams as FrameLayout.LayoutParams).topMargin = size
    }

    private fun text(chinese: String, english: String) = if (usesChinese) chinese else english

    private fun configureFailureView() {
        spinner = ProgressBar(this).apply { visibility = View.GONE }
        root.addView(spinner, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER
        ))
        val padding = (24 * resources.displayMetrics.density + 0.5f).toInt()
        val stack = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(padding, padding * 2, padding, padding)
        }
        stack.addView(TextView(this).apply {
            tag = "online-web-error-message"
            gravity = Gravity.CENTER
            textSize = 17f
            setTextColor(Color.BLACK)
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        stack.addView(Button(this).apply {
            tag = "online-web-retry"
            setOnClickListener { reloadPage() }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        stack.addView(Button(this).apply {
            tag = "online-web-error-back"
            setOnClickListener { goBackOrFinish() }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        failureView = ScrollView(this).apply {
            tag = "online-web-error"
            visibility = View.GONE
            setBackgroundColor(Color.WHITE)
            addView(stack)
        }
        root.addView(failureView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        ))
    }

    private fun updateFailureText() {
        failureView.findViewWithTag<TextView>("online-web-error-message").text = text(
            "网页加载失败，请检查网络连接及网络权限后重试。",
            "Unable to load the page. Check your connection and network access, then retry."
        )
        failureView.findViewWithTag<Button>("online-web-retry").text = text("重新加载", "Reload")
        failureView.findViewWithTag<Button>("online-web-error-back").text = text("返回", "Back")
    }

    private fun isPermittedUrl(url: String?): Boolean = runCatching {
        val uri = Uri.parse(url ?: return@runCatching false)
        !uri.host.isNullOrEmpty() && (uri.scheme == "https" || (allowInsecureHttpNavigation && uri.scheme == "http"))
    }.getOrDefault(false)

    private fun isCurrentMainRequest(request: WebResourceRequest): Boolean =
        request.isForMainFrame && request.url.toString() == navigationUrl

    private fun showLoading() {
        loadingPage = true
        failureView.visibility = View.GONE
        webView.visibility = View.VISIBLE
        spinner.visibility = View.VISIBLE
    }

    private fun showFailure(url: String) {
        if (isFinishing || isDestroyed) return
        failedUrl = url
        loadingPage = false
        spinner.visibility = View.GONE
        webView.visibility = View.INVISIBLE
        failureView.visibility = View.VISIBLE
    }

    private fun reloadPage() {
        val currentTarget = if (loadingPage) navigationUrl else webView.url?.takeIf(::isPermittedUrl)
        val url = failedUrl ?: currentTarget ?: navigationUrl ?: return
        loadPage(url)
    }

    private fun loadPage(url: String) {
        if (isFinishing || isDestroyed || !isPermittedUrl(url)) return
        // Update the target before stopping the preceding request. Late
        // failures for a different URL must not replace this fresh attempt.
        navigationUrl = url
        failedUrl = null
        webView.stopLoading()
        visibility.onNewDocument()
        showLoading()
        reportTiming("navigation.load_requested", url)
        core.load(url)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        goBackOrFinish()
    }

    /** Android gesture back and the three-button back key share this policy. */
    private fun goBackOrFinish() {
        if (!core.goBackIfPossible()) finish()
    }

    /** API 33+ edge-back bypasses the deprecated Activity callback when opted in. */
    private fun registerPredictiveBackCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val callback = OnBackInvokedCallback { goBackOrFinish() }
        predictiveBackCallback = callback
        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            callback
        )
    }

    override fun onResume() {
        super.onResume()
        active = this
        if (visibility.onResume()) sendPageWillAppear()
    }

    override fun onPause() {
        deliverHostLifecycle("pageWillDisappear")
        visibility.onPause()
        super.onPause()
    }

    private fun sendPageWillAppear() {
        deliverHostLifecycle("pageWillAppear")
    }

    internal fun deliverHostLifecycle(method: String, params: Map<String, Any?> = emptyMap()) {
        if (!::webView.isInitialized || isFinishing || isDestroyed) return
        val payload = JSONObject().put("method", method)
        if (params.isNotEmpty()) {
            val values = JSONObject()
            params.forEach { (key, value) -> values.put(key, value) }
            payload.put("params", values)
        }
        OnlineWebCore.CmsJsCallback.deliverHostMessage(webView, payload.toString())
    }

    internal fun deliverSessionChanged(reason: String) {
        if (!::webView.isInitialized || isFinishing || isDestroyed) return
        OnlineWebCore.CmsJsCallback.deliverHostMessage(
            webView,
            JSONObject()
                .put("method", "miniSessionChanged")
                .put("params", JSONObject().put("reason", reason))
                .toString()
        )
        OnlineWebCore.CmsJsCallback.deliverHostMessage(
            webView,
            JSONObject().put("method", "updateUserInfo").toString()
        )
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            predictiveBackCallback?.let(onBackInvokedDispatcher::unregisterOnBackInvokedCallback)
            predictiveBackCallback = null
        }
        visibility.release()
        if (active === this) active = null
        synchronized(pages) { pages -= this }
        if (!isChangingConfigurations) OnlineWebEvents.emit("web_closed")
        if (::webView.isInitialized) {
            if (::core.isInitialized) core.releaseBridge()
            webView.removeAllViews()
            webView.destroy()
        }
        super.onDestroy()
    }
}
