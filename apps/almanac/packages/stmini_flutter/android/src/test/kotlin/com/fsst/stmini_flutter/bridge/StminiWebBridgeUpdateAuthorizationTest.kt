package com.fsst.stmini_flutter.bridge

import android.content.Context
import android.os.Looper
import android.webkit.WebView
import com.fsst.stmini_flutter.runtime.MiniPackageStore
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

/**
 * Exercise the real bridge dispatch boundary: rejected pages must not reach
 * the Activity installer, which is the only path that can create update I/O
 * or an update Overlay.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class StminiWebBridgeUpdateAuthorizationTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
    }

    @Test
    fun rootRequestIsAcceptedAndReachesTheInstaller() {
        val host = FakeBridgeActivity(canRequestUpdate = true)
        requestUpdate(host, isForce = true)

        assertEquals(1, host.installCalls)
        assertEquals(listOf(true), host.forceFlags)
        assertEquals(0, host.loadingCalls)
    }

    @Test
    fun rejectedChildRequestsNeverStartInstallOrOwnLoadingForEitherForceFlag() {
        val host = FakeBridgeActivity(canRequestUpdate = false)

        requestUpdate(host, isForce = false)
        requestUpdate(host, isForce = true)

        assertEquals(0, host.installCalls)
        assertTrue(host.forceFlags.isEmpty())
        assertEquals(0, host.loadingCalls)
    }

    @Test
    fun authorityAllowsOnlyRootOrSameMiniTrustedChildDelegation() {
        assertEquals(
            MiniSelfManagedUpdateAuthority.Route.root,
            MiniSelfManagedUpdateAuthority.route(true, false, "signal-mini", "signal-mini")
        )
        assertEquals(
            MiniSelfManagedUpdateAuthority.Route.trustedChildDelegate,
            MiniSelfManagedUpdateAuthority.route(false, true, "signal-mini", "signal-mini")
        )
        assertEquals(
            MiniSelfManagedUpdateAuthority.Route.reject,
            MiniSelfManagedUpdateAuthority.route(false, false, "signal-mini", "signal-mini")
        )
        assertEquals(
            MiniSelfManagedUpdateAuthority.Route.reject,
            MiniSelfManagedUpdateAuthority.route(false, true, "signal-mini", null)
        )
        assertEquals(
            MiniSelfManagedUpdateAuthority.Route.reject,
            MiniSelfManagedUpdateAuthority.route(false, true, "signal-mini", "other-mini")
        )
        assertEquals("mini_update_root_delegate_unavailable", MiniSelfManagedUpdateAuthority.rootRequiredCode)
    }

    @Test
    fun onlyAParsedMiniLinkCanReachTheContainerMiniOpener() {
        val host = FakeBridgeActivity(canRequestUpdate = true, canOpenMini = true)
        val webView = WebView(context)
        val bridge = StminiWebBridge(host, webView)

        bridge.postMessage(JSONObject().put("method", "open").put("params", JSONObject()
            .put("router", "/mini").put("link", "mini://other-mini?currentVersion=1.0.0")
        ).toString())
        bridge.postMessage(JSONObject().put("method", "open").put("params", JSONObject()
            .put("router", "/mini").put("link", "https://other-mini")
        ).toString())
        listOf(
            "mini://other-mini/path",
            "mini://user@other-mini",
            "mini://other-mini:443",
            "mini://other-mini#fragment"
        ).forEach { malformedInternalLink ->
            bridge.postMessage(JSONObject().put("method", "open").put("params", JSONObject()
                .put("router", "/mini").put("link", malformedInternalLink)
            ).toString())
        }
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals(listOf("other-mini"), host.openedMiniIds)
    }

    @Test
    fun closeCountAndTrustedWebRouteAreForwardedOnlyThroughContainerPolicy() {
        val host = FakeBridgeActivity(canRequestUpdate = true, canOpenRouteChild = true)
        val bridge = StminiWebBridge(host, WebView(context))
        bridge.postMessage(JSONObject().put("method", "close").put("params", JSONObject().put("count", 2)).toString())
        bridge.postMessage(JSONObject().put("method", "open").put("params", JSONObject()
            .put("router", "/login").put("link", "https://ignored.example")
        ).toString())
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals(listOf(2), host.closeCounts)
        assertEquals(listOf("/login"), host.openedRouteChildren)
    }

    @Test
    fun unknownOnlineWebRequestForwardsOnlyTheCoreVerifiedOrigin() {
        val host = FakeBridgeActivity(canRequestUpdate = true)
        var forwardedMethod: String? = null
        var forwardedOrigin: String? = null
        var forwardedParams: JSONObject? = null
        val bridge = StminiWebBridge(host, WebView(context)) { method, params, origin, completed ->
            forwardedMethod = method
            forwardedParams = params
            forwardedOrigin = origin
            completed(JSONObject().put("code", "1").put("data", JSONObject().put("accepted", true)))
        }

        bridge.postMessage(
            JSONObject().put("method", "hostAction").put("params", JSONObject()
                .put("methodId", "call-7").put("id", "42")
            ).toString(),
            onlineWebOrigin = "https://help.example:8443"
        )
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals("hostAction", forwardedMethod)
        assertEquals("https://help.example:8443", forwardedOrigin)
        assertEquals("42", forwardedParams?.getString("id"))
        assertEquals("call-7", forwardedParams?.getString("methodId"))
    }

    @Test
    fun configuredOnlineWebForwardsHostMethodsOnlyAfterItsCapabilityGate() {
        val host = FakeBridgeActivity(canRequestUpdate = true)
        var forwarded = 0
        val bridge = StminiWebBridge(host, WebView(context)) { _, _, _, completed ->
            forwarded += 1
            completed(JSONObject().put("code", "1").put("data", JSONObject()))
        }
        val request = JSONObject().put("method", "hostSensitiveAction").put("params", JSONObject()).toString()

        // A page which reached this bridge without the online Core grant must
        // still be rejected before any embedding-app callback.
        bridge.postMessage(request, allowsSensitiveHostBridge = false, onlineWebOrigin = "https://help.example")
        // `installConfiguredWebMessageBridge` supplies true only after its
        // exact configured-origin/main-frame/current-document gate succeeded.
        bridge.postMessage(request, allowsSensitiveHostBridge = true, onlineWebOrigin = "https://help.example")
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals(1, forwarded)
    }

    @Test
    fun unknownLocalMiniRequestNeverFallsThroughToFlutterHost() {
        val host = FakeBridgeActivity(canRequestUpdate = true)
        var forwarded = false
        val bridge = StminiWebBridge(host, WebView(context)) { _, _, _, _ -> forwarded = true }

        bridge.postMessage(JSONObject().put("method", "hostAction").put("params", JSONObject()).toString())
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertTrue(!forwarded)
    }

    private fun requestUpdate(host: FakeBridgeActivity, isForce: Boolean) {
        val webView = WebView(context)
        StminiWebBridge(host, webView).postMessage(
            JSONObject().put("method", "mini_downloadMiniProgramUpdate").put("params", JSONObject()
                .put("downloadUrl", "https://packages.example.test/signal-mini.zip")
                .put("isforce", isForce)
            ).toString()
        )
        Shadows.shadowOf(Looper.getMainLooper()).idle()
    }

    private class FakeBridgeActivity(
        private val canRequestUpdate: Boolean,
        private val canOpenMini: Boolean = false,
        private val canOpenRouteChild: Boolean = false
    ) : StminiWebBridge.StminiBridgeActivity {
        var installCalls = 0
        var loadingCalls = 0
        val forceFlags = mutableListOf<Boolean>()
        val openedMiniIds = mutableListOf<String>()
        val closeCounts = mutableListOf<Int?>()
        val openedRouteChildren = mutableListOf<String>()

        override fun closeStminiPage(count: Int?) { closeCounts += count }
        override fun setStminiLoading(visible: Boolean, message: String) { loadingCalls += 1 }
        override fun stminiStatusBarHeight(): Int = 0
        override fun stminiLanguage(): String = "en-US"
        override fun setStminiLanguage(language: String): String? = language
        override fun showStminiMore() = Unit
        override fun setStminiStatusBarTextColor(isDark: Boolean) = Unit
        override fun showStminiPopup(url: String, left: Int, right: Int, ratio: Float): Boolean = false
        override fun completeStminiPopup(payload: org.json.JSONObject) = Unit
        override fun shareStminiImage(bytes: ByteArray, mimeType: String): Boolean = false
        override fun saveStminiImage(bytes: ByteArray, mimeType: String, completed: (Boolean, String?) -> Unit) = completed(false, "unsupported")
        override fun openStminiInternalWeb(url: String, title: String?, showNavigation: Boolean): Boolean = false
        override fun openStminiInternalMini(link: com.fsst.stmini_flutter.runtime.MiniLink): Boolean {
            if (canOpenMini) openedMiniIds += link.miniId
            return canOpenMini
        }
        override fun currentMiniPackage(): MiniPackageStore.InstalledPackage = installedPackage
        override fun openStminiLocalPage(path: String, title: String?): Boolean = false
        override fun openStminiRouteChild(router: String, params: org.json.JSONObject): Boolean {
            if (canOpenRouteChild) openedRouteChildren += router
            return canOpenRouteChild
        }
        override fun legacyStorageOrigin(): String? = null
        override fun notifyStminiSessionChanged(reason: String): Int = 0
        override fun continuousKeepAliveState(enabled: Boolean?): StminiWebBridge.ContinuousKeepAliveState? = null
        override fun canRequestSelfManagedUpdate(): Boolean = canRequestUpdate
        override fun installStminiUpdate(
            downloadUrl: String,
            isForce: Boolean,
            completed: (Result<MiniPackageStore.InstalledPackage>) -> Unit
        ): Boolean {
            installCalls += 1
            forceFlags += isForce
            return true
        }

        companion object {
            private val installedPackage = MiniPackageStore.InstalledPackage(
                miniId = "signal-mini",
                miniName = "Signal Mini",
                iconUrl = "",
                launchLink = "mini://signal-mini",
                version = "1.0.0",
                entry = "index.html",
                updateSelf = "1"
            )
        }
    }
}
