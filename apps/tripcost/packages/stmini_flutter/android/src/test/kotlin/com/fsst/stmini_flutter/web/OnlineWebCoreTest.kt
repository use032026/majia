package com.fsst.stmini_flutter.web

import android.net.Uri
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.junit.Before
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

/** The web-only security boundary must stay executable without Mini runtime tests. */
@RunWith(RobolectricTestRunner::class)
@Config(
    manifest = Config.NONE, sdk = [34],
    shadows = [BridgeWebViewCompatShadow::class, BridgeWebViewFeatureShadow::class]
)
class OnlineWebCoreTest {
    @Before
    fun resetBridgeApi() {
        BridgeWebViewCompatShadow.listeners.clear()
        BridgeWebViewCompatShadow.addCount = 0
        BridgeWebViewCompatShadow.removeCount = 0
        BridgeWebViewCompatShadow.failInstall = false
        BridgeWebViewFeatureShadow.supported = true
    }

    private fun sendMessage(view: WebView, source: String, mainFrame: Boolean = true) {
        BridgeWebViewCompatShadow.listeners.getValue(view).onPostMessage(
            view, WebMessageCompat("probe"), Uri.parse(source), mainFrame,
            object : JavaScriptReplyProxy() {
                override fun postMessage(message: String) = Unit
                override fun postMessage(message: ByteArray) = Unit
            }
        )
    }

    @Test
    fun messagesSurviveCommitsWithoutReplacingTheInjectedChannel() {
        val view = WebView(RuntimeEnvironment.getApplication())
        val core = OnlineWebCore(view)
        val received = mutableListOf<String>()
        core.installExactOriginBridge("https://a.example", false, { _, origin -> received += origin }, {})
        view.loadUrl("https://a.example/one")
        repeat(100) {
            core.onTopLevelPageCommit("https://a.example/one")
            sendMessage(view, "https://a.example")
        }
        view.loadUrl("https://b.example/two")
        sendMessage(view, "https://a.example")
        sendMessage(view, "https://b.example")
        assertEquals(100, received.size)
        core.onTopLevelPageCommit("https://b.example/two")
        sendMessage(view, "https://a.example")
        sendMessage(view, "https://b.example", mainFrame = false)
        sendMessage(view, "https://b.example")
        assertEquals(101, received.size)
        assertEquals("https://b.example", received.last())
        assertEquals(1, BridgeWebViewCompatShadow.addCount)
        assertEquals(0, BridgeWebViewCompatShadow.removeCount)
        core.releaseBridge()
        view.destroy()
    }

    @Test
    fun replacementDocumentUsesItsCurrentHandlerAndHttpPermission() {
        val view = WebView(RuntimeEnvironment.getApplication())
        val core = OnlineWebCore(view)
        var oldMessages = 0
        var newMessages = 0
        core.installExactOriginBridge("https://a.example", false, { _, _ -> oldMessages++ }, {})
        view.loadUrl("https://a.example")
        sendMessage(view, "https://a.example")
        core.clearExactOriginBridge()
        sendMessage(view, "https://a.example")
        core.installExactOriginBridge("http://b.example", true, { _, _ -> newMessages++ }, {})
        sendMessage(view, "https://a.example")
        view.loadUrl("http://b.example")
        core.onTopLevelPageCommit("http://b.example")
        sendMessage(view, "http://b.example")
        assertEquals(1, oldMessages)
        assertEquals(1, newMessages)
        core.installExactOriginBridge("http://b.example", false, { _, _ -> newMessages++ }, {})
        core.onTopLevelPageCommit("http://b.example")
        sendMessage(view, "http://b.example")
        assertEquals(1, newMessages)
        assertEquals(1, BridgeWebViewCompatShadow.addCount)
        assertEquals(0, BridgeWebViewCompatShadow.removeCount)
        core.releaseBridge()
        view.destroy()
    }

    @Test
    fun releaseRevokesLateMessagesWithoutAffectingAnotherWebView() {
        val first = WebView(RuntimeEnvironment.getApplication())
        val second = WebView(RuntimeEnvironment.getApplication())
        val firstCore = OnlineWebCore(first)
        val secondCore = OnlineWebCore(second)
        var firstMessages = 0
        var secondMessages = 0
        firstCore.installExactOriginBridge("https://a.example", false, { _, _ -> firstMessages++ }, {})
        secondCore.installExactOriginBridge("https://b.example", false, { _, _ -> secondMessages++ }, {})
        first.loadUrl("https://a.example")
        second.loadUrl("https://b.example")
        firstCore.releaseBridge()
        firstCore.releaseBridge()
        // 模拟移除前已排队的回调，测试替身有意保留旧监听引用。
        sendMessage(first, "https://a.example")
        sendMessage(second, "https://a.example")
        sendMessage(second, "https://b.example")
        assertEquals(0, firstMessages)
        assertEquals(1, secondMessages)
        assertEquals(1, BridgeWebViewCompatShadow.removeCount)
        secondCore.releaseBridge()
        first.destroy()
        second.destroy()
    }

    @Test
    fun unavailableBridgeLeavesNoAuthorityAndReportsFailureOncePerRequest() {
        val view = WebView(RuntimeEnvironment.getApplication())
        val core = OnlineWebCore(view)
        var unavailable = 0
        BridgeWebViewFeatureShadow.supported = false
        assertEquals(null, core.installExactOriginBridge("https://a.example", false, { _, _ -> error("不应接收消息") }, { unavailable++ }))
        assertEquals(0, BridgeWebViewCompatShadow.addCount)
        BridgeWebViewFeatureShadow.supported = true
        BridgeWebViewCompatShadow.failInstall = true
        assertEquals(null, core.installExactOriginBridge("https://a.example", false, { _, _ -> error("不应接收消息") }, { unavailable++ }))
        core.onTopLevelPageCommit("https://a.example")
        assertEquals(2, unavailable)
        assertEquals(1, BridgeWebViewCompatShadow.addCount)
        core.releaseBridge()
        assertEquals(0, BridgeWebViewCompatShadow.removeCount)
        view.destroy()
    }

    @Test
    fun topLevelCurrentDocumentAndMainFrameAreRequired() {
        val gate = OnlineWebCore.ExactMainFrameOriginGate("https://help.example/start")

        assertTrue(gate.accepts(Uri.parse("https://help.example/path"), true))
        assertFalse(gate.accepts(Uri.parse("https://help.example/frame"), false))
        assertFalse(gate.accepts(Uri.parse("https://third.example/page"), true))
    }

    @Test
    fun redirectGetsBridgeAfterItsTopLevelDocumentCommits() {
        val gate = OnlineWebCore.ExactMainFrameOriginGate("https://login.example/start")

        assertTrue(gate.accepts(Uri.parse("https://login.example/start"), true))
        gate.onTopLevelCommit("https://help.example/callback?state=ok")
        assertEquals("https://help.example", gate.originForTest())
        assertTrue(gate.accepts(Uri.parse("https://help.example/callback"), true))
    }

    @Test
    fun forwardedOriginIsNormalizedWithoutPathQueryOrDefaultPort() {
        val gate = OnlineWebCore.ExactMainFrameOriginGate("https://HELP.example:443/start?token=private")
        assertEquals("https://help.example", gate.currentOrigin())

        gate.onTopLevelCommit("https://HELP.example:8443/next?token=private")
        assertEquals("https://help.example:8443", gate.currentOrigin())
        val customPortGate = OnlineWebCore.ExactMainFrameOriginGate(
            "https://HELP.example:8443/start?token=private"
        )
        assertEquals("https://help.example:8443", customPortGate.currentOrigin())
    }

    @Test
    fun thirdPartyRedirectGetsItsOwnTopLevelBridgeAuthority() {
        val gate = OnlineWebCore.ExactMainFrameOriginGate("https://help.example/start")

        gate.onTopLevelCommit("https://third.example/oauth")
        assertEquals("https://third.example", gate.originForTest())
        assertTrue(gate.accepts(Uri.parse("https://third.example/oauth"), true))
        assertFalse(gate.accepts(Uri.parse("https://help.example/frame"), false))
    }

    @Test
    fun callbackEnvelopeKeepsSuccessAndFailurePayloadsInData() {
        val success = OnlineWebCore.CmsJsCallback.response("getUserInfo", "call-1")
        success.getJSONObject("data").put("id", "42")
        assertEquals("1", success.getString("code"))
        assertEquals("42", success.getJSONObject("data").getString("id"))

        OnlineWebCore.CmsJsCallback.fail(success, "当前页面未获宿主 Bridge 授权", "bridge_not_allowed")
        assertEquals("0", success.getString("code"))
        assertEquals("当前页面未获宿主 Bridge 授权", success.getJSONObject("data").getString("msg"))
        assertEquals("bridge_not_allowed", success.getJSONObject("data").getString("errorCode"))
    }

    @Test
    fun browserBackConsumesOnlyWebHistorySoContainerCanCloseAnExhaustedPage() {
        val webView = WebView(RuntimeEnvironment.getApplication())
        val core = OnlineWebCore(webView)
        val shadow = Shadows.shadowOf(webView)

        shadow.setCanGoBack(true)
        assertTrue(core.goBackIfPossible())
        assertEquals(1, shadow.goBackInvocations)

        shadow.setCanGoBack(false)
        assertFalse(core.goBackIfPossible())
    }

    @Test
    fun iframeNavigationIsAllowedWhileItsBridgeMessageRemainsRejected() {
        val iframe = Uri.parse("https://trusted.example/frame")
        assertFalse(OnlineWebCore.NavigationPolicy.blocks(iframe, isMainFrame = false, allowInsecureHttpNavigation = false))
        val gate = OnlineWebCore.ExactMainFrameOriginGate("https://trusted.example/root")
        assertFalse(gate.accepts(iframe, isMainFrame = false))
    }

    @Test
    fun httpTopLevelNavigationAndBridgeRequireHostOptIn() {
        val httpPage = Uri.parse("http://192.168.111.11:3000/")
        assertTrue(OnlineWebCore.NavigationPolicy.blocks(
            httpPage, isMainFrame = true, allowInsecureHttpNavigation = false
        ))
        assertFalse(OnlineWebCore.NavigationPolicy.blocks(
            httpPage, isMainFrame = true, allowInsecureHttpNavigation = true
        ))

        val gate = OnlineWebCore.ExactMainFrameOriginGate(httpPage.toString())
        assertEquals(null, gate.currentOrigin())
        assertFalse(gate.accepts(httpPage, isMainFrame = true))

        val optedInGate = OnlineWebCore.ExactMainFrameOriginGate(httpPage.toString(), true)
        assertEquals("http://192.168.111.11:3000", optedInGate.currentOrigin())
        assertTrue(optedInGate.accepts(httpPage, isMainFrame = true))
    }

    @Test
    fun pageWillAppearIsDeferredUntilFirstCommitThenRepeatedOnlyOnVisibleResume() {
        val lifecycle = OnlineWebVisibilityLifecycle()
        assertFalse(lifecycle.onResume())
        assertTrue(lifecycle.onPageCommitted()) // first visible document
        lifecycle.onPause()
        assertFalse(lifecycle.onPageCommitted()) // covered native login reload
        assertTrue(lifecycle.onResume()) // returning from native login

        lifecycle.onNewDocument()
        assertFalse(lifecycle.onResume()) // replacement B waits for its commit
        assertTrue(lifecycle.onPageCommitted())
        lifecycle.release()
        assertFalse(lifecycle.onResume()) // destruction never sends an event
        assertFalse(lifecycle.onPageCommitted())
    }

    @Test
    fun navigationBarUsesDpConversion() {
        assertEquals(56, OnlineWebActivity.navigationBarSizePx(1f))
        assertEquals(112, OnlineWebActivity.navigationBarSizePx(2f))
        assertEquals(140, OnlineWebActivity.navigationBarSizePx(2.5f))
    }

    @Test
    fun systemNewIntentReplacesUrlAndTitle() {
        val context = RuntimeEnvironment.getApplication()
        val first = OnlineWebActivity.intent(
            context, "https://a.example/one", "A", true
        )
        val controller = Robolectric.buildActivity(OnlineWebActivity::class.java, first).create().start().resume()
        val second = OnlineWebActivity.intent(
            context, "https://b.example/two", "B", false
        )
        controller.newIntent(second)
        val activity = controller.get()
        assertEquals("https://b.example/two", activity.loadedUrlForTest)
        assertEquals("B", activity.loadedTitleForTest)
        controller.pause().stop().destroy()
    }
}

/** 仅替代平台注册 API；权限校验和回调处理执行真实 Core。 */
@Implements(value = WebViewCompat::class, isInAndroidSdk = false)
class BridgeWebViewCompatShadow {
    companion object {
        val listeners = mutableMapOf<WebView, WebViewCompat.WebMessageListener>()
        var addCount = 0
        var removeCount = 0
        var failInstall = false

        @JvmStatic
        @Implementation
        fun addWebMessageListener(view: WebView, name: String, rules: Set<String>, listener: WebViewCompat.WebMessageListener) {
            check(name == OnlineWebCore.MESSAGE_CHANNEL && rules == setOf("*"))
            addCount++
            if (failInstall) error("模拟安装失败")
            listeners[view] = listener
        }

        @JvmStatic
        @Implementation
        fun removeWebMessageListener(view: WebView, name: String) {
            check(name == OnlineWebCore.MESSAGE_CHANNEL && listeners.containsKey(view))
            removeCount++
        }
    }
}

@Implements(value = WebViewFeature::class, isInAndroidSdk = false)
class BridgeWebViewFeatureShadow {
    companion object {
        var supported = true

        @JvmStatic
        @Implementation
        fun isFeatureSupported(feature: String): Boolean =
            feature == WebViewFeature.WEB_MESSAGE_LISTENER && supported
    }
}
