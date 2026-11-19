package com.fsst.stmini_flutter.web

import android.net.Uri
import android.webkit.WebView
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

/** The web-only security boundary must stay executable without Mini runtime tests. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class OnlineWebCoreTest {
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
        val customPortGate = OnlineWebCore.ExactMainFrameOriginGate("https://HELP.example:8443/start?token=private")
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
    fun httpNavigationAndBridgeNeedTheSameExplicitHostOptIn() {
        val httpPage = Uri.parse("http://192.168.111.11:3000/")
        assertTrue(OnlineWebCore.NavigationPolicy.blocks(httpPage, true, false))
        assertFalse(OnlineWebCore.NavigationPolicy.blocks(httpPage, true, true))

        val disabledGate = OnlineWebCore.ExactMainFrameOriginGate(httpPage.toString())
        assertEquals(null, disabledGate.currentOrigin())
        assertFalse(disabledGate.accepts(httpPage, true))

        val enabledGate = OnlineWebCore.ExactMainFrameOriginGate(httpPage.toString(), true)
        assertEquals("http://192.168.111.11:3000", enabledGate.currentOrigin())
        assertTrue(enabledGate.accepts(httpPage, true))
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
}
