package com.fsst.stmini_flutter.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Looper
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import org.json.JSONObject
import com.fsst.stmini_flutter.web.OnlineWebActivity
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.io.File

/**
 * WebView navigation is the last boundary before a Mini document can expose
 * the native bridge to another origin.  Keep this as an Android-only
 * Robolectric regression suite: it exercises the actual WebViewClient rather
 * than duplicating the policy in a helper.
 */
@RunWith(RobolectricTestRunner::class)
// WebSettings.setMixedContentMode is available from API 21.  Pin an API that
// is within the plugin's API-24 baseline rather than relying on Robolectric's
// legacy default SDK.
@Config(manifest = Config.NONE, sdk = [28])
class MiniWebViewNavigationPolicyTest {
    private lateinit var context: Context
    private lateinit var packageDirectory: File

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        packageDirectory = File(context.filesDir, "STMini/signal-mini")
        packageDirectory.deleteRecursively()
        packageDirectory.mkdirs()
        File(packageDirectory, "index.html").writeText("<html>root</html>")
        File(packageDirectory, "mini-manifest.json").writeText(
            JSONObject()
                .put("miniId", "signal-mini")
                .put("miniName", "Signal Mini")
                .put("version", "1.0.0")
                .put("entry", "index.html")
                .toString()
        )
        File(packageDirectory, ".st-mini-package.json").writeText(
            JSONObject()
                .put("miniId", "signal-mini")
                .put("miniName", "Signal Mini")
                .put("iconUrl", "")
                .put("launchLink", "mini://signal-mini")
                .put("version", "1.0.0")
                .put("entry", "index.html")
                .toString()
        )
    }

    @After
    fun tearDown() {
        packageDirectory.deleteRecursively()
    }

    @Test
    fun miniRootBlocksAnExternalIframeBeforeItCanReceiveTheBridge() {
        val activity = launchMiniRoot()
        val webView = activity.webView()
        val client = webView.client()

        assertTrue(
            "A foreign iframe must be cancelled; JavaScript interfaces are shared by frames.",
            client.shouldOverrideUrlLoading(
                webView,
                request("https://untrusted.example/embedded.html", isMainFrame = false)
            )
        )
    }

    @Test
    fun miniContainerDisablesTheWebViewTopEdgeEffectInsteadOfShowingProgressChrome() {
        val activity = launchMiniRoot()

        assertTrue(
            "Mini loading uses the centred launch overlay; WebView must not draw a top edge line.",
            activity.webView().overScrollMode == android.view.View.OVER_SCROLL_NEVER
        )
    }

    @Test
    fun controlledMiniWebChildAllowsOnlyTopLevelHttpsRedirects() {
        val activity = Robolectric.buildActivity(
            StminiContainerActivity::class.java,
            Intent(context, StminiContainerActivity::class.java).apply {
                putExtra(StminiContainerActivity.EXTRA_WEB_URL, "https://login.example/start")
                putExtra(StminiContainerActivity.EXTRA_PARENT_MINI_ID, "signal-mini")
            }
        ).setup().get()
        val webView = activity.webView()
        val client = webView.client()

        assertFalse(
            "A controlled /web page needs HTTPS redirects for OAuth/login.",
            client.shouldOverrideUrlLoading(webView, request("https://login.example/callback", isMainFrame = true))
        )
        assertTrue(
            "A controlled /web page must never downgrade to HTTP.",
            client.shouldOverrideUrlLoading(webView, request("http://login.example/callback", isMainFrame = true))
        )
    }

    @Test
    fun miniWebOpensTheSharedOnlineWebOwnerInsteadOfAnotherDocumentTask() {
        val root = launchMiniRoot()

        assertTrue(root.openStminiInternalWeb("https://login.example/start", null, false))

        val intent = Shadows.shadowOf(root).nextStartedActivity
        assertEquals(OnlineWebActivity::class.java.name, intent.component?.className)
    }

    @Test
    fun miniWebRouteChildStartsWithoutPresentingPageSnapshotOrLaunchOverlay() {
        val root = launchMiniRoot()
        val webChild = launchMiniChild(root, "https://login.example/partner", showNavigation = false)

        assertTrue(webChild.openStminiRouteChild("/login", JSONObject()))
        val intent = Shadows.shadowOf(webChild).nextStartedActivity

        assertEquals(StminiWebPageActivity::class.java.name, intent.component?.className)
        assertTrue(intent.getBooleanExtra("stmini.routeChild", false))
        assertEquals(
            "Route children must not retain the presenting online page as a bitmap.",
            null,
            intent.getStringExtra("stmini.launchSnapshotKey")
        )
        val routeChild = Robolectric.buildActivity(
            StminiWebPageActivity::class.java,
            intent
        ).create().get()
        assertTrue(routeChild.getBoolean("isMiniRouteChild"))
        // Robolectric lacks the WebMessage listener and deliberately makes
        // this child show its bridge-capability failure. Clear that unrelated
        // error state, then prove that a route child's own bootstrap loading
        // request cannot re-enable the root Mini launch overlay.
        routeChild.launchOverlay().finishFirstDocument()
        routeChild.setStminiLoading(true, "")
        assertEquals(View.GONE, routeChild.launchOverlay().visibility)
        assertFalse(webChild.isFinishing)
    }

    @Test
    fun rootMiniCannotOpenOnlineOnlyRouteWithoutTheRegisteredWebDelegate() {
        val root = launchMiniRoot()

        assertFalse(root.openStminiRouteChild("/login", JSONObject()))
    }

    @Test
    fun hiddenMiniWebDefersASessionReloadUntilItReturnsToTheTopOfTheStack() {
        val root = launchMiniRoot()
        val child = launchMiniChild(root, "https://login.example/center", showNavigation = true)

        child.invokeLifecycle("onPause")
        child.setBoolean("pendingLegacySessionReload", true)
        assertTrue(child.getBoolean("pendingLegacySessionReload"))

        child.invokeLifecycle("onResume")

        assertFalse(child.getBoolean("pendingLegacySessionReload"))
        assertTrue("The visible-page callback must wait for the replacement document.",
            child.getBoolean("pendingPageWillAppearAfterSessionReload"))

        child.webView().client().onPageCommitVisible(child.webView(), "https://login.example/center")
        assertFalse("The deferred callback must be consumed by the replacement document only.",
            child.getBoolean("pendingPageWillAppearAfterSessionReload"))
    }

    @Test
    fun directOpenWebCannotDowngradeAnHttpsSessionInRelease() {
        val activity = Robolectric.buildActivity(
            StminiContainerActivity::class.java,
            Intent(context, StminiContainerActivity::class.java).apply {
                putExtra(StminiContainerActivity.EXTRA_WEB_URL, "https://help.example/start")
            }
        ).setup().get()
        val webView = activity.webView()
        val client = webView.client()

        assertFalse(client.shouldOverrideUrlLoading(webView, request("https://help.example/next", isMainFrame = true)))
        val blocksHttp = client.shouldOverrideUrlLoading(webView, request("http://help.example/downgrade", isMainFrame = true))
        assertTrue(blocksHttp)
    }

    @Test
    fun onlyTheExpectedRootLocalDocumentCanCompleteTheNativeLaunchPresentation() {
        val activity = launchMiniRoot()
        val webView = activity.webView()
        val client = webView.client()
        activity.setLaunchExpectation("https://signal-mini.stmini.local/index.html?__st_root_launch=current#/trade")

        // A foreign page, an external `/web` child, or an early redirect must
        // not make a root Mini look ready just because WebView emitted a page
        // callback. The state is deliberately checked through the real client.
        client.onPageCommitVisible(webView, "https://login.example/callback")
        assertFalse(activity.firstContentReady())

        // A stale commit for the same local entry file still carries the old
        // navigation nonce, so it cannot complete the new root launch.
        client.onPageCommitVisible(webView, "https://signal-mini.stmini.local/index.html?__st_root_launch=old#/trade")
        assertFalse(activity.firstContentReady())

        client.onPageCommitVisible(webView, "https://signal-mini.stmini.local/index.html?__st_root_launch=current#/trade")
        assertTrue(activity.firstContentReady())
    }

    @Test
    fun rootH5FirstFrameSignalCompletesOnlyTheExpectedLocalLaunch() {
        val activity = launchMiniRoot()
        val expected = "https://signal-mini.stmini.local/index.html?__st_root_launch=foreground#/trade"
        activity.setLaunchExpectation(expected)
        activity.webView().loadUrl(expected)

        // This models a cold launch that was sent to background before
        // WebView could call onPageCommitVisible. The H5 signal is accepted
        // only when the current local document still carries this launch nonce.
        activity.setStminiLoading(false, "")

        assertTrue(activity.firstContentReady())
    }

    @Test
    fun downloadCompletionImmediatelyReturnsTheLaunchOverlayToProcessing() {
        val activity = launchMiniRoot()
        activity.setPackageEventState(token = 7L)
        val overlay = activity.launchOverlay()

        activity.consumePackageEvent("mini_download_progress", mapOf(
            "miniId" to "signal-mini", "downloadedBytes" to 10L, "totalBytes" to 10L
        ), 7L)
        Shadows.shadowOf(Looper.getMainLooper()).idle()
        assertTrue(overlay.phase == MiniLaunchPhase.DOWNLOAD_PROGRESS)

        activity.consumePackageEvent("mini_download_completed", mapOf("miniId" to "signal-mini"), 7L)
        Shadows.shadowOf(Looper.getMainLooper()).idle()
        assertTrue(overlay.phase == MiniLaunchPhase.PROCESSING)
    }

    @Test
    fun homeMiniRootDoesNotFinishWhenSystemBackHasNoLocalHistory() {
        val activity = launchMiniRoot()
        activity.setRootHome(true)

        activity.onBackPressed()

        assertFalse(activity.isFinishing)
    }

    @Test
    fun homeMiniRootUsesWebHistoryBeforeItsNoCloseBackPolicy() {
        val activity = launchMiniRoot()
        activity.setRootHome(true)
        val webView = activity.webView()
        val shadow = Shadows.shadowOf(webView)
        shadow.setCanGoBack(true)

        activity.onBackPressed()

        assertEquals(1, shadow.goBackInvocations)
        assertFalse(activity.isFinishing)
    }

    @Test
    fun localChildSystemBackWithoutHistoryFinishesOnlyTheChild() {
        val root = launchMiniRoot()
        File(packageDirectory, "child.html").writeText("<html>child</html>")
        val child = launchMiniChild(root, "https://signal-mini.stmini.local/child.html", showNavigation = true)

        child.onBackPressed()

        assertTrue(child.isFinishing)
        assertFalse("System back from a pushed local page must not close its root session.", root.isFinishing)
    }

    @Test
    fun trustedWebChildNavigationBackWithoutHistoryFinishesOnlyTheChild() {
        val root = launchMiniRoot()
        val child = launchMiniChild(root, "https://login.example/authorize", showNavigation = true)
        child.setBoolean("isExternalMiniWebPage", true)

        child.navigationBackButton().performClick()

        assertTrue(child.isFinishing)
        assertFalse("Navigation-bar back from /web must return to the Mini root.", root.isFinishing)
    }

    @Test
    fun childSystemBackUsesWebHistoryBeforeFinishing() {
        val root = launchMiniRoot()
        File(packageDirectory, "history-child.html").writeText("<html>child</html>")
        val systemChild = launchMiniChild(root, "https://signal-mini.stmini.local/history-child.html", showNavigation = true)
        val systemShadow = Shadows.shadowOf(systemChild.webView())
        systemShadow.setCanGoBack(true)

        systemChild.onBackPressed()

        assertEquals(1, systemShadow.goBackInvocations)
        assertFalse(systemChild.isFinishing)

        val webChild = launchMiniChild(root, "https://login.example/history", showNavigation = true)
        webChild.setBoolean("isExternalMiniWebPage", true)
        val webShadow = Shadows.shadowOf(webChild.webView())
        webShadow.setCanGoBack(true)

        webChild.onBackPressed()

        assertEquals("System/gesture back must preserve /web redirect-history semantics.", 1, webShadow.goBackInvocations)
        assertFalse(webChild.isFinishing)
        assertFalse(root.isFinishing)
    }

    @Test
    fun trustedWebChildNavigationBackPopsTheChildInsteadOfConsumingRedirectHistory() {
        val root = launchMiniRoot()
        val webChild = launchMiniChild(root, "https://login.example/history", showNavigation = true)
        webChild.setBoolean("isExternalMiniWebPage", true)
        val webShadow = Shadows.shadowOf(webChild.webView())
        webShadow.setCanGoBack(true)

        webChild.navigationBackButton().performClick()

        assertEquals("The /web container button must pop its native child, not replay redirect history.", 0, webShadow.goBackInvocations)
        assertTrue(webChild.isFinishing)
        assertFalse("Popping /web must leave the Mini root/session alive.", root.isFinishing)
    }

    @Test
    fun localChildNavigationBackStillUsesWebHistoryBeforeFinishing() {
        val root = launchMiniRoot()
        File(packageDirectory, "local-navigation-history.html").writeText("<html>child</html>")
        val localChild = launchMiniChild(
            root,
            "https://signal-mini.stmini.local/local-navigation-history.html",
            showNavigation = true
        )
        val localShadow = Shadows.shadowOf(localChild.webView())
        localShadow.setCanGoBack(true)

        localChild.navigationBackButton().performClick()

        assertEquals(1, localShadow.goBackInvocations)
        assertFalse(localChild.isFinishing)
        assertFalse(root.isFinishing)
    }

    @Test
    fun archiveCompletionIsNotForwardedToFlutterButOtherPackageEventsAre() {
        assertFalse(StminiContainerActivity.shouldForwardPackageEventToFlutter("mini_download_completed"))
        assertTrue(StminiContainerActivity.shouldForwardPackageEventToFlutter("mini_download_progress"))
        assertTrue(StminiContainerActivity.shouldForwardPackageEventToFlutter("mini_package_installed"))
    }

    private fun launchMiniRoot(): StminiContainerActivity = Robolectric.buildActivity(
        StminiContainerActivity::class.java,
        Intent(context, StminiContainerActivity::class.java).apply {
            putExtra(StminiContainerActivity.EXTRA_MINI_LINK, "mini://signal-mini")
        }
    ).setup().get()

    private fun launchMiniChild(
        root: StminiContainerActivity,
        url: String,
        showNavigation: Boolean
    ): StminiContainerActivity = Robolectric.buildActivity(
        StminiWebPageActivity::class.java,
        Intent(context, StminiWebPageActivity::class.java).apply {
            putExtra(StminiContainerActivity.EXTRA_WEB_URL, url)
            putExtra(StminiContainerActivity.EXTRA_PARENT_MINI_ID, "signal-mini")
            putExtra(StminiContainerActivity.EXTRA_SHOW_NAVIGATION, showNavigation)
            putExtra("stmini.runtimeSessionId", root.sessionId())
        }
    ).setup().get()

    private fun StminiContainerActivity.webView(): WebView {
        val field = StminiContainerActivity::class.java.getDeclaredField("webView")
        field.isAccessible = true
        return field.get(this) as WebView
    }

    private fun StminiContainerActivity.navigationBackButton(): ImageButton {
        val navigationBar = StminiContainerActivity::class.java.getDeclaredField("navigationBar").apply {
            isAccessible = true
        }.get(this) as ViewGroup
        return (0 until navigationBar.childCount)
            .map(navigationBar::getChildAt)
            .filterIsInstance<ImageButton>()
            .single()
    }

    private fun StminiContainerActivity.sessionId(): String = StminiContainerActivity::class.java
        .getDeclaredField("runtimeSessionId").apply { isAccessible = true }.get(this) as String

    private fun StminiContainerActivity.setBoolean(name: String, value: Boolean) {
        StminiContainerActivity::class.java.getDeclaredField(name).apply { isAccessible = true }
            .setBoolean(this, value)
    }

    private fun StminiContainerActivity.getBoolean(name: String): Boolean = StminiContainerActivity::class.java
        .getDeclaredField(name).apply { isAccessible = true }.getBoolean(this)


    private fun StminiContainerActivity.invokeLifecycle(name: String) {
        StminiContainerActivity::class.java.getDeclaredMethod(name)
            .apply { isAccessible = true }
            .invoke(this)
    }

    private fun WebView.client(): WebViewClient = Shadows.shadowOf(this).webViewClient

    private fun StminiContainerActivity.firstContentReady(): Boolean {
        val field = StminiContainerActivity::class.java.getDeclaredField("firstContentReady")
        field.isAccessible = true
        return field.getBoolean(this)
    }

    private fun StminiContainerActivity.setLaunchExpectation(url: String) {
        StminiContainerActivity::class.java.getDeclaredField("isRootMini").apply {
            isAccessible = true
            setBoolean(this@setLaunchExpectation, true)
        }
        StminiContainerActivity::class.java.getDeclaredField("miniId").apply {
            isAccessible = true
            set(this@setLaunchExpectation, "signal-mini")
        }
        StminiContainerActivity::class.java.getDeclaredField("expectedRootDocumentUrl").apply {
            isAccessible = true
            set(this@setLaunchExpectation, url)
        }
    }

    private fun StminiContainerActivity.setPackageEventState(token: Long) {
        StminiContainerActivity::class.java.getDeclaredField("isRootMini").apply {
            isAccessible = true
            setBoolean(this@setPackageEventState, true)
        }
        StminiContainerActivity::class.java.getDeclaredField("miniId").apply {
            isAccessible = true
            set(this@setPackageEventState, "signal-mini")
        }
        StminiContainerActivity::class.java.getDeclaredField("launchGeneration").apply {
            isAccessible = true
            setLong(this@setPackageEventState, token)
        }
    }

    private fun StminiContainerActivity.setRootHome(value: Boolean) {
        StminiContainerActivity::class.java.getDeclaredField("isRootMini").apply {
            isAccessible = true
            setBoolean(this@setRootHome, true)
        }
        StminiContainerActivity::class.java.getDeclaredField("rootIsHome").apply {
            isAccessible = true
            setBoolean(this@setRootHome, value)
        }
    }

    private fun StminiContainerActivity.launchOverlay(): MiniLaunchOverlay {
        val field = StminiContainerActivity::class.java.getDeclaredField("launchOverlay")
        field.isAccessible = true
        return field.get(this) as MiniLaunchOverlay
    }

    private fun StminiContainerActivity.consumePackageEvent(
        name: String,
        payload: Map<String, Any?>,
        token: Long
    ) {
        StminiContainerActivity::class.java.getDeclaredMethod(
            "consumePackagePresentationEvent", String::class.java, Map::class.java, java.lang.Long::class.java
        ).apply {
            isAccessible = true
            invoke(this@consumePackageEvent, name, payload, token)
        }
    }

    private fun request(url: String, isMainFrame: Boolean): WebResourceRequest = object : WebResourceRequest {
        override fun getUrl(): Uri = Uri.parse(url)
        override fun isForMainFrame(): Boolean = isMainFrame
        override fun isRedirect(): Boolean = false
        override fun hasGesture(): Boolean = false
        override fun getMethod(): String = "GET"
        override fun getRequestHeaders(): MutableMap<String, String> = mutableMapOf()
    }
}
