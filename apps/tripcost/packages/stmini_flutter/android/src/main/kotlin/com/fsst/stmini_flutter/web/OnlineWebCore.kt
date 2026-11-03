package com.fsst.stmini_flutter.web

import android.annotation.SuppressLint
import android.net.Uri
import android.os.Build
import android.view.View
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject

/**
 * Shared Web-only implementation.
 *
 * This class deliberately knows nothing about packages, retained runtimes,
 * launch overlays, or Activities. It is safe to compile without a local
 * runtime alongside it.
 */
internal class OnlineWebCore(private val webView: WebView) {
    /** Container UI binds these without giving the core an Activity dependency. */
    var onTitleChanged: ((String) -> Unit)? = null

    /**
     * This gate tracks the origin of the document which committed in this
     * top-level WebView. Iframes and stale documents never inherit authority.
     */
    internal class ExactMainFrameOriginGate(
        initialUrl: String?,
        private val allowInsecureHttpBridge: Boolean = false
    ) {
        private var committedOrigin: String? = OnlineWebOrigin.originOfBridgeUrl(initialUrl, allowInsecureHttpBridge)

        fun onTopLevelCommit(url: String) {
            committedOrigin = OnlineWebOrigin.originOfBridgeUrl(url, allowInsecureHttpBridge)
        }

        fun accepts(sourceOrigin: Uri, isMainFrame: Boolean): Boolean =
            isMainFrame && committedOrigin != null &&
                OnlineWebOrigin.matchesBridge(sourceOrigin, committedOrigin!!, allowInsecureHttpBridge)

        internal fun originForTest(): String? = committedOrigin
        fun currentOrigin(): String? = committedOrigin
        fun matchesCurrentDocument(url: String?): Boolean =
            OnlineWebOrigin.originOfBridgeUrl(url, allowInsecureHttpBridge) == committedOrigin
    }

    private data class BridgeRegistration(
        val gate: ExactMainFrameOriginGate,
        val onMessage: (String, String) -> Unit,
        val onUnavailable: () -> Unit
    )

    private var bridgeRegistration: BridgeRegistration? = null
    private var bridgeListenerInstalled = false

    /** Navigation is separate from bridge authorization. */
    internal object NavigationPolicy {
        fun blocks(request: WebResourceRequest, allowInsecureHttpNavigation: Boolean): Boolean {
            return blocks(request.url, request.isForMainFrame, allowInsecureHttpNavigation)
        }

        /** Iframes may navigate normally; only their bridge messages are denied. */
        fun blocks(uri: Uri, isMainFrame: Boolean, allowInsecureHttpNavigation: Boolean): Boolean {
            if (!isMainFrame) return false
            return uri.host.isNullOrBlank() ||
                (!uri.scheme.equals("https", true) &&
                    !(allowInsecureHttpNavigation && uri.scheme.equals("http", true)))
        }
    }

    /** All H5 callbacks use the same escaped `data` payload envelope. */
    internal object CmsJsCallback {
        /** The shared JS contract always returns payloads (and errors) in data. */
        fun response(method: String, methodId: String): JSONObject = JSONObject().apply {
            put("code", "1")
            put("method", method)
            put("methodId", methodId)
            put("data", JSONObject())
        }

        fun fail(response: JSONObject, message: String, errorCode: String? = null) {
            response.put("code", "0")
            response.put("data", JSONObject().apply {
                put("msg", message)
                errorCode?.let { put("errorCode", it) }
            })
        }

        fun deliver(webView: WebView, responseJson: String) {
            val safe = responseJson.replace("</", "<\\/")
            webView.post {
                webView.evaluateJavascript("javascript:CMSJsCallBack($safe)", null)
            }
        }

        fun deliverHostMessage(webView: WebView, messageJson: String) {
            val safe = messageJson.replace("</", "<\\/")
            webView.post {
                webView.evaluateJavascript(
                    "javascript:typeof window.CMSCallJsMessage==='function'&&window.CMSCallJsMessage($safe)",
                    null
                )
            }
        }
    }

    /**
     * Installs one ordinary-web bridge.  The listener is intentionally owned
     * here so web-only consumers do not need a legacy container or bridge to
     * enforce the origin/main-frame boundary.
     */
    fun installExactOriginBridge(
        initialUrl: String?,
        allowInsecureHttpBridge: Boolean,
        onMessage: (String, String) -> Unit,
        onUnavailable: () -> Unit
    ): ExactMainFrameOriginGate? {
        clearExactOriginBridge()
        val gate = ExactMainFrameOriginGate(initialUrl, allowInsecureHttpBridge)
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            onUnavailable()
            return null
        }
        bridgeRegistration = BridgeRegistration(gate, onMessage, onUnavailable)
        return gate.takeIf { ensureBridgeListener() }
    }

    /** 撤销当前页面权限，保留当前 WebView 已注入的消息通道。 */
    fun clearExactOriginBridge() {
        bridgeRegistration = null
    }

    /** 仅在 WebView 生命周期结束时移除监听，先撤销权限以拒绝晚到消息。 */
    fun releaseBridge() {
        clearExactOriginBridge()
        if (!bridgeListenerInstalled) return
        runCatching { WebViewCompat.removeWebMessageListener(webView, MESSAGE_CHANNEL) }
        bridgeListenerInstalled = false
    }

    /** Call only from WebViewClient.onPageCommitVisible for the top-level page. */
    fun onTopLevelPageCommit(url: String) {
        val registration = bridgeRegistration ?: return
        registration.gate.onTopLevelCommit(url)
    }

    private fun ensureBridgeListener(): Boolean {
        if (bridgeListenerInstalled) return true
        val registration = bridgeRegistration ?: return false
        // 同一 WebView 只安装一次。页面提交和新 Intent 只更新权限，
        // 避免旧文档继续向移除后重建的同名通道发送消息而触发 WebView 原生崩溃。
        return runCatching {
            WebViewCompat.addWebMessageListener(
                webView,
                MESSAGE_CHANNEL,
                setOf("*"),
                object : WebViewCompat.WebMessageListener {
                    override fun onPostMessage(
                        view: WebView,
                        message: WebMessageCompat,
                        sourceOrigin: Uri,
                        isMainFrame: Boolean,
                        replyProxy: JavaScriptReplyProxy
                    ) {
                        // 回调必须读取当前登记，不能捕获上一文档的权限或处理器。
                        val current = bridgeRegistration ?: return
                        if (!current.gate.accepts(sourceOrigin, isMainFrame)) return
                        val origin = current.gate.currentOrigin() ?: return
                        // A redirect can change WebView.url before its old
                        // document is fully torn down. Require the currently
                        // displayed top-level URL to retain the source origin
                        // as well as the listener's main-frame check.
                        if (!current.gate.matchesCurrentDocument(view.url)) return
                        message.data?.let { current.onMessage(it, origin) }
                    }
                }
            )
            bridgeListenerInstalled = true
            true
        }.getOrElse {
            clearExactOriginBridge()
            registration.onUnavailable()
            false
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    fun configureWebView() {
        // Online pages have no native progress chrome.  This is shared with
        // The platform's top edge effect must never resemble a download
        // indicator.
        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        }
    }

    fun receivedTitle(title: String?) {
        title?.takeIf(String::isNotBlank)?.let { onTitleChanged?.invoke(it) }
    }

    fun load(url: String) = webView.loadUrl(url)

    /** Returns true when browser history consumed the back operation. */
    fun goBackIfPossible(): Boolean {
        if (!webView.canGoBack()) return false
        webView.goBack()
        return true
    }

    fun pageVisibilityMessage(name: String) {
        CmsJsCallback.deliverHostMessage(webView, "{\"method\":${org.json.JSONObject.quote(name)}}")
    }

    companion object {
        const val MESSAGE_CHANNEL = "CMSScriptMessageChannel"
    }
}

/** Page visibility delivery state, independent from the Activity/WebView. */
internal class OnlineWebVisibilityLifecycle {
    private var resumed = false
    private var committed = false
    private var released = false

    /** True only when a committed page is becoming visible. */
    fun onResume(): Boolean {
        if (released) return false
        resumed = true
        return committed
    }

    fun onPause() { resumed = false }

    /** True for the first visible commit; false while covered or released. */
    fun onPageCommitted(): Boolean {
        if (released) return false
        committed = true
        return resumed
    }

    /** A replacement URL must commit before it receives pageWillAppear. */
    fun onNewDocument() { committed = false }

    fun release() {
        released = true
        resumed = false
    }
}
