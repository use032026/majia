package com.fsst.stmini_flutter.ui

import android.content.Context
import android.content.Intent
import android.os.Looper
import android.webkit.WebView
import com.fsst.stmini_flutter.runtime.MiniLink
import com.fsst.stmini_flutter.runtime.MiniPackageStore
import com.fsst.stmini_flutter.runtime.StminiHostConfiguration
import com.fsst.stmini_flutter.runtime.StminiRuntimePool
import com.fsst.stmini_flutter.web.OnlineWebActivity
import com.fsst.stmini_flutter.web.OnlineWebScriptExecutor
import com.fsst.stmini_flutter.web.OnlineWebSessionDelegate
import com.fsst.stmini_flutter.web.OnlineWebSessionRegistry
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.io.File

/** Container-level regression coverage for the runtime-pool boundaries. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class StminiContainerRuntimeLifecycleTest {
    private lateinit var context: Context
    private lateinit var packageDirectory: File

    @Before fun setUp() {
        context = RuntimeEnvironment.getApplication()
        StminiRuntimePool.releaseForMemoryPressure()
        StminiContainerActivity.retainedBridgeRemovalObserver = null
        packageDirectory = File(context.filesDir, "STMini/signal-mini").apply {
            deleteRecursively(); mkdirs()
        }
        File(packageDirectory, "index.html").writeText("root")
        File(packageDirectory, "mini-manifest.json").writeText(JSONObject()
            .put("miniId", "signal-mini").put("miniName", "Signal")
            .put("version", "1.0.0").put("entry", "index.html").toString())
        File(packageDirectory, ".st-mini-package.json").writeText(JSONObject()
            .put("miniId", "signal-mini").put("miniName", "Signal")
            .put("iconUrl", "").put("launchLink", "mini://signal-mini")
            .put("version", "1.0.0").put("entry", "index.html").put("updateself", "1").toString())
    }

    @After fun tearDown() {
        StminiRuntimePool.releaseForMemoryPressure()
        StminiContainerActivity.retainedBridgeRemovalObserver = null
        StminiHostConfiguration.configure(null)
        OnlineWebActivity.scriptExecutorForTest = null
        packageDirectory.deleteRecursively()
    }

    @Test fun closingAReadyRootAndReopeningReattachesTheSameVerifiedRuntime() {
        val first = root()
        val retained = first.webView()
        first.setBoolean("firstContentReady", true)

        first.closeStminiPage()
        val second = root()

        assertSame(retained, second.webView())
    }

    @Test fun hostCloseMiniAlsoClosesSharedOnlineWebChildrenInThatSession() {
        val root = root()
        val child = Robolectric.buildActivity(
            OnlineWebActivity::class.java,
            OnlineWebActivity.intent(
                context, "https://trusted.example/page", null, true,
                OnlineWebSessionRegistry.register(root.sessionId(), object : OnlineWebSessionDelegate {
                    override fun handleMessage(raw: String, origin: String, webView: WebView, closePage: () -> Unit) = false
                    override fun leavePage(closePage: () -> Unit) = closePage()
                    override fun sessionChanged(owner: OnlineWebActivity, webView: WebView, reason: String) = Unit
                })
            )
        ).setup().get()

        StminiContainerActivity.closeActive()

        assertTrue(child.isFinishing)
    }

    @Test fun declaredOriginAndKeysExecuteOnlyAllowedStorageMirrorThenReloadAndNotifyAfterCommit() {
        val root = root()
        StminiHostConfiguration.configure(mapOf(
            "authStorageKey" to "auth",
            "legacyWebStorageMirror" to mapOf(
                "origins" to listOf("https://trusted.example"),
                "keys" to listOf("token"),
                "storageKey" to "auth",
                "reloadOnChange" to true
            )
        ))
        context.getSharedPreferences("stmini_flutter_storage", Context.MODE_PRIVATE).edit()
            .putString("auth", JSONObject().put("token", "allowed").put("secret", "must-not-leak").toString())
            .apply()
        val owner = onlineOwner("https://trusted.example/page")
        val executor = RecordingWebExecutor()
        OnlineWebActivity.scriptExecutorForTest = executor

        root.invokeSharedOnlineMirror(owner, owner.webView(), "login")
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals(1, executor.evaluated.size)
        assertTrue(executor.evaluated.single().contains("localStorage"))
        assertTrue(executor.evaluated.single().contains("allowed"))
        assertFalse(executor.evaluated.single().contains("must-not-leak"))
        assertEquals(1, executor.reloads)
        assertFalse(executor.evaluated.any { it.contains("CMSCallJsMessage") })

        owner.webView().client().onPageCommitVisible(owner.webView(), "https://trusted.example/replacement")

        assertTrue(executor.evaluated.any { it.contains("CMSCallJsMessage") })
    }

    @Test fun thirdPartyOriginNeverExecutesStorageMirrorOrReload() {
        val root = root()
        StminiHostConfiguration.configure(mapOf(
            "authStorageKey" to "auth",
            "legacyWebStorageMirror" to mapOf(
                "origins" to listOf("https://trusted.example"),
                "keys" to listOf("token"),
                "storageKey" to "auth"
            )
        ))
        context.getSharedPreferences("stmini_flutter_storage", Context.MODE_PRIVATE).edit()
            .putString("auth", JSONObject().put("token", "would-leak").toString()).apply()
        val owner = onlineOwner("https://third-party.example/page")
        val executor = RecordingWebExecutor()
        OnlineWebActivity.scriptExecutorForTest = executor

        root.invokeSharedOnlineMirror(owner, owner.webView(), "login")
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertFalse(executor.evaluated.any { it.contains("localStorage") })
        assertEquals(0, executor.reloads)
    }

    @Test fun documentReentryKeepsTheLiveRootAndTransfersTheOpeningOperation() {
        val root = root()
        root.setBoolean("firstContentReady", true)
        val liveWebView = root.webView()

        root.invokeNewIntent(Intent(context, StminiContainerActivity::class.java).apply {
            data = StminiContainerActivity.rootTaskIntentData("SIGNAL-MINI")
            putExtra(StminiContainerActivity.EXTRA_MINI_LINK, "mini://signal-mini")
            putExtra(StminiContainerActivity.EXTRA_OPERATION_ID, "reopened-operation")
        })

        assertSame(liveWebView, root.webView())
        assertEquals("reopened-operation", root.getString("operationId"))
    }

    @Test fun verifiedHomeMiniLaunchUsesTheHostTaskInsteadOfADocumentTask() {
        val link = MiniLink.parse("mini://signal-mini")!!

        val homeIntent = StminiContainerActivity.rootLaunchIntent(context, link, "home-open", isHome = true)
        assertEquals(StminiHomeActivity::class.java.name, homeIntent.component?.className)
        assertTrue(homeIntent.flags and Intent.FLAG_ACTIVITY_CLEAR_TOP != 0)
        assertTrue(homeIntent.flags and Intent.FLAG_ACTIVITY_SINGLE_TOP != 0)
        assertEquals(0, homeIntent.flags and Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
        assertEquals(null, homeIntent.data)

        val ordinaryIntent = StminiContainerActivity.rootLaunchIntent(context, link, "mini-open", isHome = false)
        assertEquals(StminiContainerActivity::class.java.name, ordinaryIntent.component?.className)
        assertTrue(ordinaryIntent.flags and Intent.FLAG_ACTIVITY_NEW_DOCUMENT != 0)
        assertEquals(StminiContainerActivity.rootTaskIntentData("signal-mini"), ordinaryIntent.data)
    }

    @Test fun closingTrustedChildRetainsAndRestoresTheWholeMiniSession() {
        val firstRoot = root()
        firstRoot.setBoolean("firstContentReady", true)
        val rootWebView = firstRoot.webView()
        val childUrl = "https://signal-mini.stmini.local/page.html"
        File(packageDirectory, "page.html").writeText("child")
        val child = child(firstRoot.sessionId(), childUrl)
        // Provider-less Robolectric does not expose WebMessageListener
        // capability. The session-state test supplies the already-verified
        // bridge precondition; bridge authorization has dedicated coverage.
        child.setBoolean("secureBridgeInstalled", true)
        child.setBoolean("isExternalMiniWebPage", false)
        child.setString("trustedChildUrl", childUrl)
        val childWebView = child.webView()
        assertFalse(child.isFinishing)

        // This is the same close target used by Flutter `closeMini`; JS close
        // and system back without local history delegate to it as well.
        StminiContainerActivity.closeActive()

        assertTrue(firstRoot.isFinishing)
        assertTrue(child.isFinishing)
        val retainedSession = StminiRuntimePool.acquireSession(context, packageInfo("signal-mini"))
        assertSame(childWebView, retainedSession?.childPages?.single()?.webView)
        StminiRuntimePool.retainSession(context, packageInfo("signal-mini"), retainedSession!!)
        val reopenedRoot = root()
        assertSame(rootWebView, reopenedRoot.webView())
    }

    @Test fun closeCountPopsOnlyRequestedMiniOwnedLevelsAndZeroReturnsToRoot() {
        val root = root()
        File(packageDirectory, "one.html").writeText("one")
        File(packageDirectory, "two.html").writeText("two")
        val one = child(root.sessionId(), "https://signal-mini.stmini.local/one.html")
        val two = child(root.sessionId(), "https://signal-mini.stmini.local/two.html")

        two.closeStminiPage(1)

        assertTrue(two.isFinishing)
        assertFalse(one.isFinishing)
        assertFalse(root.isFinishing)
        // `0` preserves the verified root rather than invoking Flutter's
        // full-session close contract.
        one.closeStminiPage(0)
        assertTrue(one.isFinishing)
        assertFalse(root.isFinishing)
    }

    @Test fun idleRetainedSessionImmediatelyRemovesRootAndChildActivityBridges() {
        val root = root()
        root.setBoolean("firstContentReady", true)
        val childUrl = "https://signal-mini.stmini.local/page.html"
        File(packageDirectory, "page.html").writeText("child")
        val child = child(root.sessionId(), childUrl)
        child.setBoolean("secureBridgeInstalled", true)
        child.setBoolean("isExternalMiniWebPage", false)
        child.setString("trustedChildUrl", childUrl)
        val removed = mutableListOf<WebView>()
        StminiContainerActivity.retainedBridgeRemovalObserver = { removed += it }

        StminiContainerActivity.closeActive()

        // This assertion occurs before any subsequent acquire, proving an
        // idle pooled session no longer retains the finishing Activity through
        // CMSScriptMessageChannel. The pool still owns both renderers.
        assertTrue(root.webView() in removed)
        assertTrue(child.webView() in removed)
        val session = StminiRuntimePool.acquireSession(context, packageInfo("signal-mini"))
        assertSame(root.webView(), session?.rootWebView)
        assertSame(child.webView(), session?.childPages?.single()?.webView)
    }

    @Test fun externalChildDoesNotJoinTheRetainedMiniSession() {
        val firstRoot = root()
        firstRoot.setBoolean("firstContentReady", true)
        val external = child(firstRoot.sessionId(), "https://login.example.test/start")

        StminiContainerActivity.closeActive()

        assertTrue(external.isFinishing)
        val reopenedRoot = root()
        assertEquals(null, Shadows.shadowOf(reopenedRoot).nextStartedActivity)
    }

    @Test fun rendererLossRebuildsRootAndPackageChildFromVerifiedLocalFiles() {
        val root = root()
        val rootBefore = root.webView()
        root.invokeRendererRecovery(rootBefore)
        assertNotSame(rootBefore, root.webView())

        val child = Robolectric.buildActivity(
            StminiContainerActivity::class.java,
            Intent(context, StminiContainerActivity::class.java).apply {
                putExtra(StminiContainerActivity.EXTRA_WEB_URL, "https://signal-mini.stmini.local/index.html")
                putExtra(StminiContainerActivity.EXTRA_PARENT_MINI_ID, "signal-mini")
            }
        ).setup().get()
        val childBefore = child.webView()
        child.invokeRendererRecovery(childBefore)
        assertNotSame(childBefore, child.webView())
    }

    @Test fun externalMiniWebRendererLossFailsWithoutCreatingAMiniRecoveryWebView() {
        val external = Robolectric.buildActivity(
            StminiContainerActivity::class.java,
            Intent(context, StminiContainerActivity::class.java).apply {
                putExtra(StminiContainerActivity.EXTRA_WEB_URL, "https://login.example.test/start")
                putExtra(StminiContainerActivity.EXTRA_PARENT_MINI_ID, "signal-mini")
            }
        ).setup().get()
        val before = external.webView()
        external.invokeRendererRecovery(before)
        assertSame(before, external.webView())
        assertEquals(MiniLaunchPhase.FAILURE, external.launchOverlay().phase)
    }

    private fun root(): StminiContainerActivity = Robolectric.buildActivity(
        StminiContainerActivity::class.java,
        Intent(context, StminiContainerActivity::class.java).putExtra(
            StminiContainerActivity.EXTRA_MINI_LINK, "mini://signal-mini"
        )
    ).setup().get()

    private fun child(sessionId: String, url: String): StminiContainerActivity = Robolectric.buildActivity(
        StminiContainerActivity::class.java,
        Intent(context, StminiContainerActivity::class.java).apply {
            putExtra(StminiContainerActivity.EXTRA_WEB_URL, url)
            putExtra(StminiContainerActivity.EXTRA_PARENT_MINI_ID, "signal-mini")
            putExtra("stmini.runtimeSessionId", sessionId)
        }
    ).setup().get()

    private fun StminiContainerActivity.webView(): WebView = StminiContainerActivity::class.java
        .getDeclaredField("webView").apply { isAccessible = true }.get(this) as WebView

    private fun onlineOwner(url: String): OnlineWebActivity = Robolectric.buildActivity(
        OnlineWebActivity::class.java,
        OnlineWebActivity.intent(context, url, null, true)
    ).setup().get()

    private fun OnlineWebActivity.webView(): WebView = OnlineWebActivity::class.java
        .getDeclaredField("webView").apply { isAccessible = true }.get(this) as WebView

    private fun StminiContainerActivity.invokeSharedOnlineMirror(
        owner: OnlineWebActivity,
        webView: WebView,
        reason: String
    ) {
        StminiContainerActivity::class.java.getDeclaredMethod(
            "mirrorSessionToSharedOnlineWebIfAllowed",
            OnlineWebActivity::class.java,
            WebView::class.java,
            String::class.java
        ).apply { isAccessible = true }.invoke(this, owner, webView, reason)
    }

    private fun WebView.client() = Shadows.shadowOf(this).webViewClient

    private class RecordingWebExecutor : OnlineWebScriptExecutor {
        val evaluated = mutableListOf<String>()
        var reloads = 0

        override fun evaluate(webView: WebView, script: String, completed: (String?) -> Unit) {
            evaluated += script
            completed("true")
        }

        override fun reload(webView: WebView) { reloads += 1 }
    }

    private fun StminiContainerActivity.setBoolean(name: String, value: Boolean) {
        StminiContainerActivity::class.java.getDeclaredField(name).apply { isAccessible = true }
            .setBoolean(this, value)
    }

    private fun StminiContainerActivity.setString(name: String, value: String) {
        StminiContainerActivity::class.java.getDeclaredField(name).apply { isAccessible = true }
            .set(this, value)
    }

    private fun StminiContainerActivity.getString(name: String): String? =
        StminiContainerActivity::class.java.getDeclaredField(name).apply { isAccessible = true }
            .get(this) as? String

    private fun StminiContainerActivity.invokeNewIntent(intent: Intent) {
        StminiContainerActivity::class.java.getDeclaredMethod("onNewIntent", Intent::class.java)
            .apply { isAccessible = true }
            .invoke(this, intent)
    }

    private fun StminiContainerActivity.sessionId(): String = StminiContainerActivity::class.java
        .getDeclaredField("runtimeSessionId").apply { isAccessible = true }.get(this) as String


    private fun StminiContainerActivity.invokeRendererRecovery(webView: WebView) {
        StminiContainerActivity::class.java.getDeclaredMethod("onMiniRenderProcessGone", WebView::class.java)
            .apply { isAccessible = true }.invoke(this, webView)
    }

    private fun StminiContainerActivity.launchOverlay(): MiniLaunchOverlay = StminiContainerActivity::class.java
        .getDeclaredField("launchOverlay").apply { isAccessible = true }.get(this) as MiniLaunchOverlay

    private fun packageInfo(id: String) = MiniPackageStore.InstalledPackage(
        miniId = id, miniName = id, iconUrl = "", launchLink = "mini://$id",
        version = "1.0.0", entry = "index.html", updateSelf = "1"
    )
}
