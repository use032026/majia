package com.fsst.stmini_flutter.ui

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.*
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import com.fsst.stmini_flutter.runtime.LocalMiniResource
import com.fsst.stmini_flutter.runtime.LocalPackageInventory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.Executors
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.Future

/** Minimal derived local Mini renderer, not the upstream full container/Bridge. */
class LocalMiniViewFactory(private val messenger: BinaryMessenger, private val allowed: () -> Boolean) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val views = mutableSetOf<LocalMiniView>()
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return LocalMiniView(context, messenger, viewId, args, allowed) { views.remove(it) }.also { views.add(it) }
    }
    fun detach() { views.toList().forEach { it.dispose() }; views.clear() }
}

class LocalMiniView(private val context: Context, messenger: BinaryMessenger, viewId: Int,
    args: Any?, private val allowed: () -> Boolean, private val retired: (LocalMiniView) -> Unit) :
    PlatformView, MethodChannel.MethodCallHandler {
    private val root = object : FrameLayout(context) {
        override fun onWindowVisibilityChanged(visibility: Int) {
            super.onWindowVisibilityChanged(visibility)
            if (visibility == View.VISIBLE) webView?.onResume() else webView?.onPause()
        }
    }
    private val channel = MethodChannel(messenger, "stmini_flutter/local_view/$viewId")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newFixedThreadPool(1) { Thread(it, "stmini-local-renderer").apply { isDaemon = true } } as ThreadPoolExecutor
    private var identityFuture: Future<*>? = null
    private val history = mutableListOf<String>()
    private var historyIndex = -1
    private var requestedDocument: String? = null
    private var expectedDocument: String? = null
    @Volatile private var generation = 0
    @Volatile private var closed = false
    @Volatile private var mainResourceGeneration = -1
    private var phase = "loading"
    private var errorCode: String? = null
    private var webView: WebView? = null
    private var resource: LocalMiniResource? = null
    private var miniId: String? = null
    private var version: String? = null
    private var entry: String? = null
    private var deadline: Runnable? = null

    init {
        channel.setMethodCallHandler(this)
        val params = args as? Map<*, *>
        val id = params?.get("miniId") as? String
        val number = params?.get("version") as? String
        if (params == null || params.keys.toSet() != setOf("miniId", "version") ||
            id == null || !id.matches(Regex("^[a-z0-9][a-z0-9_-]{0,63}$")) ||
            number == null || !number.matches(Regex("^[0-9]{1,9}(\\.[0-9]{1,9}){0,7}$"))) {
            fail("invalid_parameters")
        } else if (!allowed()) fail("not_initialized")
        else { miniId = id; version = number; reload() }
    }
    override fun getView(): View = root
    private fun state(): Map<String, Any?> = mapOf("phase" to phase,
        "canGoBack" to (!closed && historyIndex > 0), "errorCode" to errorCode)
    private fun emit() { if (!closed) channel.invokeMethod("stateChanged", state()) }
    private fun fail(code: String) {
        if (closed) return
        cancelDeadline(); phase = "failed"; errorCode = code
        webView?.stopLoading()
        root.addView(TextView(context).apply { text = "Local Mini unavailable"; tag = "stmini-local-error" })
        emit()
    }
    private fun cancelDeadline() { deadline?.let(main::removeCallbacks); deadline = null }
    private fun beginNavigation(): Int {
        generation++; mainResourceGeneration = -1
        cancelDeadline(); phase = "loading"; errorCode = null
        val token = generation
        deadline = Runnable { if (!closed && generation == token && phase == "loading") fail("render_timeout") }
        main.postDelayed(deadline!!, 8000); emit()
        return token
    }
    private fun reload() {
        if (closed) return
        if (!allowed()) return fail("not_initialized")
        val id = miniId ?: return fail("invalid_parameters")
        val number = version ?: return fail("invalid_parameters")
        val token = beginNavigation()
        destroyWebView()
        identityFuture?.cancel(true)
        worker.purge()
        identityFuture = worker.submit {
            val outcome = runCatching {
                val inventory = LocalPackageInventory(context.applicationContext.filesDir)
                val until = System.nanoTime() + 4_000_000_000L
                val item = inventory.verifiedPackage(id, number, entry) {
                    if (closed || generation != token || Thread.currentThread().isInterrupted || System.nanoTime() >= until) throw LocalPackageInventory.Unavailable()
                }
                LocalMiniResource(inventory, id, number, item.getValue("entry"))
            }
            main.post {
                if (closed || phase != "loading" || generation != token) { outcome.getOrNull()?.close(); return@post }
                outcome.fold({ loaded -> entry = entry ?: loaded.entry; resource = loaded; createWebView(loaded) }, { fail("package_unavailable") })
            }
        }
    }
    @SuppressLint("SetJavaScriptEnabled")
    private fun createWebView(resources: LocalMiniResource) {
        root.removeAllViews()
        val view = WebView(context)
        val viewToken = generation
        val target = requestedDocument ?: resources.entryUrl
        if (historyIndex < 0) { history.add(target); historyIndex = 0 }
        expectedDocument = target
        webView = view
        view.settings.apply {
            javaScriptEnabled = true; domStorageEnabled = false; databaseEnabled = false
            allowFileAccess = false; allowContentAccess = false
            @Suppress("DEPRECATION")
            allowFileAccessFromFileURLs = false
            @Suppress("DEPRECATION")
            allowUniversalAccessFromFileURLs = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            blockNetworkLoads = true; cacheMode = WebSettings.LOAD_NO_CACHE
            javaScriptCanOpenWindowsAutomatically = false; setSupportMultipleWindows(false)
            mediaPlaybackRequiresUserGesture = true
        }
        view.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest) { request.deny() }
            override fun onGeolocationPermissionsShowPrompt(origin: String?, callback: GeolocationPermissions.Callback?) {
                callback?.invoke(origin, false, false)
            }
            override fun onShowFileChooser(view: WebView?, callback: android.webkit.ValueCallback<Array<Uri>>?, params: FileChooserParams?): Boolean {
                callback?.onReceiveValue(null); return true
            }
            override fun onCreateWindow(view: WebView?, isDialog: Boolean, isUserGesture: Boolean, resultMsg: android.os.Message?): Boolean = false
        }
        view.setDownloadListener { _, _, _, _, _ -> fail("navigation_rejected") }
        view.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val url = request.url.toString()
                if (view !== webView || closed || request.method != "GET" || !request.isForMainFrame ||
                    !resources.html(url) || resources.path(url) == null) return true
                if (Uri.parse(url).fragment != expectedDocument?.let { Uri.parse(it).fragment } && withoutFragment(url) == withoutFragment(expectedDocument)) {
                    expectedDocument = url; requestedDocument = url; return false
                }
                // Cross-document navigation gets a fresh WebView. Late callbacks
                // from the retired document cannot own the next launch.
                if (withoutFragment(url) != withoutFragment(expectedDocument)) {
                    while (history.size > historyIndex + 1) history.removeAt(history.lastIndex)
                    history.add(url); historyIndex++
                }
                requestedDocument = url; reload(); return true
            }
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                val token = viewToken
                val response = resources.response(request.url.toString(), request.method, identityInvalid = {
                    main.post {
                        if (!closed && generation == token && resources === resource && view === webView) {
                            resources.close(); fail("package_unavailable")
                        }
                    }
                }) { !closed && generation == token }
                if (request.isForMainFrame) {
                    if (response.statusCode == 200 && resources.html(request.url.toString()) &&
                        withoutFragment(request.url.toString()) == withoutFragment(target) && generation == token) mainResourceGeneration = token
                    else main.post { if (!closed && generation == token && view === webView) fail("resource_unavailable") }
                }
                return response
            }
            override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                if (view !== webView || closed) return
                if (resources.path(url) == null || !resources.html(url)) return fail("navigation_rejected")
                if (withoutFragment(url) != withoutFragment(target)) fail("navigation_rejected")
                else if (phase == "ready") reload()
            }
            override fun onPageCommitVisible(view: WebView, url: String) {
                val token = viewToken
                if (closed || generation != token || withoutFragment(url) != withoutFragment(expectedDocument) || view !== webView || resources.path(url) == null || !resources.html(url) || mainResourceGeneration != token) return
                if (phase != "loading") return
                cancelDeadline(); phase = "ready"; errorCode = null; emit()
            }
            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame && view === webView && !closed && generation == viewToken &&
                    withoutFragment(request.url.toString()) == withoutFragment(expectedDocument)) fail("resource_unavailable")
            }
            override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, response: WebResourceResponse) {
                if (request.isForMainFrame && view === webView && !closed && generation == viewToken &&
                    withoutFragment(request.url.toString()) == withoutFragment(expectedDocument)) fail("resource_unavailable")
            }
            override fun onReceivedSslError(view: WebView?, handler: android.webkit.SslErrorHandler?, error: android.net.http.SslError?) { handler?.cancel() }
            override fun onReceivedHttpAuthRequest(view: WebView?, handler: HttpAuthHandler?, host: String?, realm: String?) { handler?.cancel() }
            override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                if (view === webView) { destroyWebView(); fail("renderer_terminated") }; return true
            }
        }
        root.addView(view, FrameLayout.LayoutParams(-1, -1))
        view.loadUrl(target)
    }
    private fun destroyWebView() {
        resource?.close(); resource = null
        webView?.let { it.stopLoading(); root.removeView(it); it.webChromeClient = null; it.webViewClient = WebViewClient(); it.destroy() }
        webView = null
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.arguments != null) { result.error("invalid_parameters", "Control accepts no arguments.", null); return }
        when (call.method) {
            "state" -> result.success(state())
            "close" -> { close(); result.success(null) }
            "reload" -> { if (!closed) reload(); result.success(null) }
            "goBack" -> {
                val back = !closed && phase == "ready" && historyIndex > 0
                if (back) { historyIndex--; requestedDocument = history[historyIndex]; reload() }
                result.success(back)
            }
            else -> result.notImplemented()
        }
    }
    private fun close() {
        if (closed) return
        closed = true; generation++; identityFuture?.cancel(true); identityFuture = null; cancelDeadline(); destroyWebView(); worker.shutdownNow()
        root.removeAllViews(); phase = "closed"; errorCode = null
        channel.invokeMethod("stateChanged", state())
    }
    override fun dispose() { close(); channel.setMethodCallHandler(null); retired(this) }
    private fun withoutFragment(raw: String?): String? = raw?.let { Uri.parse(it).buildUpon().fragment(null).build().toString() }
}
