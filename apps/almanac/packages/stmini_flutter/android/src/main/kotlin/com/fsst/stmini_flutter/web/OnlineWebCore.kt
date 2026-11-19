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
 * The Web-only part of STMini.
 *
 * This class deliberately knows nothing about a Mini package, a retained
 * runtime, a launch overlay, or an Activity.  `main` uses it for both a
 * host-opened web page and a Mini-owned `/web` child; the web-only package can
 * compile the same code without carrying the Mini runtime along with it.
 */
internal class OnlineWebCore(private val webView: WebView) {
    /** Container UI binds these without giving the core an Activity dependency. */
    var onTitleChanged: ((String) -> Unit)? = null

    /**
     * This gate tracks the exact origin of the top-level document currently
     * committed in this WebView. Iframes and stale navigations never inherit
     * its bridge capability.
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

        fun acceptsCurrentDocument(url: String?): Boolean =
            committedOrigin != null &&
                OnlineWebOrigin.originOfBridgeUrl(url, allowInsecureHttpBridge) == committedOrigin

        internal fun originForTest(): String? = committedOrigin
        fun currentOrigin(): String? = committedOrigin
    }

    private data class BridgeRegistration(
        val gate: ExactMainFrameOriginGate,
        val onMessage: (String, String) -> Unit,
        val onUnavailable: () -> Unit
    )

    private var bridgeRegistration: BridgeRegistration? = null

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

        fun deliver(webView: WebView, responseJson: String, valid: () -> Boolean = { true }) {
            val safe = responseJson.replace("</", "<\\/")
            val generation = BridgeDocumentLease.generation(webView)
            val document = webView.url
            webView.post {
                if (!valid() || !BridgeDocumentLease.isCurrent(webView, generation, document)) return@post
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
     * here so web-only consumers do not need StminiContainerActivity or the
     * Mini bridge to enforce the origin/main-frame boundary.
     */
    fun installExactOriginBridge(
        initialUrl: String?,
        allowInsecureHttpBridge: Boolean,
        onMessage: (String, String) -> Unit,
        onUnavailable: () -> Unit
    ): ExactMainFrameOriginGate? {
        val gate = ExactMainFrameOriginGate(initialUrl, allowInsecureHttpBridge)
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            onUnavailable()
            return null
        }
        bridgeRegistration = BridgeRegistration(gate, onMessage, onUnavailable)
        return gate.takeIf { installListenerForCommittedOrigin() }
    }

    /** Call only from WebViewClient.onPageCommitVisible for the top-level page. */
    fun onTopLevelPageCommit(url: String) {
        val registration = bridgeRegistration ?: return
        registration.gate.onTopLevelCommit(url)
        installListenerForCommittedOrigin()
    }

    private fun installListenerForCommittedOrigin(): Boolean {
        val registration = bridgeRegistration ?: return true
        // The listener observes every allowed top-level document. The gate
        // below still requires a main-frame source that exactly matches the
        // document currently displayed by this WebView.
        runCatching { WebViewCompat.removeWebMessageListener(webView, MESSAGE_CHANNEL) }
        if (registration.gate.originForTest() == null) return true
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
                        if (!registration.gate.accepts(sourceOrigin, isMainFrame)) return
                        val origin = registration.gate.currentOrigin() ?: return
                        // A redirect can change WebView.url before its old
                        // document is fully torn down. Require the currently
                        // displayed top-level URL to retain the source origin
                        // as well as the listener's main-frame check.
                        if (!registration.gate.acceptsCurrentDocument(view.url)) return
                        message.data?.let { registration.onMessage(it, origin) }
                    }
                }
            )
            true
        }.getOrElse {
            registration.onUnavailable()
            false
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    fun configureWebView() {
        // Online pages have no native progress chrome.  This is shared with
        // Mini `/web` so the platform's top edge effect never looks like a
        // package download indicator.
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
