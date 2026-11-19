package com.fsst.stmini_flutter.runtime

import android.content.Context
import android.os.Looper
import android.webkit.WebView
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class StminiRuntimePoolTest {
    private lateinit var context: Context

    @Before fun setUp() {
        context = RuntimeEnvironment.getApplication()
        StminiRuntimePool.releaseForMemoryPressure()
        StminiRuntimePool.hiddenLifecycleDeliveryObserver = null
        StminiHostConfiguration.configure(null)
    }

    @After fun tearDown() {
        StminiRuntimePool.releaseForMemoryPressure()
        StminiRuntimePool.hiddenLifecycleDeliveryObserver = null
        StminiHostConfiguration.configure(null)
    }

    @Test fun ordinaryEntriesAreFifoAndVersionBound() {
        val first = WebView(context)
        val second = WebView(context)
        val third = WebView(context)
        StminiRuntimePool.retain(context, info("one"), first)
        StminiRuntimePool.retain(context, info("two"), second)
        StminiRuntimePool.retain(context, info("three"), third)

        assertNull(StminiRuntimePool.acquire(context, info("one")))
        assertSame(second, StminiRuntimePool.acquire(context, info("two")))
        assertSame(third, StminiRuntimePool.acquire(context, info("three")))
    }

    @Test fun continuousEligibilityComesOnlyFromFlutterHostConfiguration() {
        StminiHostConfiguration.configure(mapOf("miniSecurity" to mapOf(
            "continuousKeepAliveMiniIds" to listOf("continuous")
        )))
        val unsupported = StminiRuntimePool.state(context, "ordinary")
        assertFalse(unsupported.supported)
        assertFalse(unsupported.enabled)

        val enabled = StminiRuntimePool.setContinuousKeepAlive(context, "continuous", true)
        assertTrue(enabled.supported)
        assertTrue(enabled.enabled)
        val disabled = StminiRuntimePool.setContinuousKeepAlive(context, "continuous", false)
        assertTrue(disabled.supported)
        assertFalse(disabled.enabled)
    }

    @Test fun hostReconfigurationDemotesAContinuousRuntimeToOrdinaryFifo() {
        StminiHostConfiguration.configure(mapOf("miniSecurity" to mapOf(
            "continuousKeepAliveMiniIds" to listOf("continuous")
        )))
        val continuous = WebView(context)
        StminiRuntimePool.retain(context, info("continuous"), continuous)

        // A subsequent host initialize removes the capability. Reconciliation
        // must leave no unbounded continuous entry behind.
        StminiHostConfiguration.configure(null)
        StminiRuntimePool.retain(context, info("one"), WebView(context))
        StminiRuntimePool.retain(context, info("two"), WebView(context))

        assertNull(StminiRuntimePool.acquire(context, info("continuous")))
    }

    @Test fun memoryPressureDropsEveryHiddenRuntimeBeforeItCanBeReused() {
        val ordinary = WebView(context)
        StminiRuntimePool.retain(context, info("ordinary"), ordinary)
        StminiRuntimePool.releaseForMemoryPressure()

        assertNull(StminiRuntimePool.acquire(context, info("ordinary")))
    }

    @Test fun sessionKeepsTrustedChildWithItsVersionBoundRoot() {
        val root = WebView(context)
        val child = WebView(context)
        StminiRuntimePool.retainSession(
            context,
            info("session"),
            StminiRuntimePool.RetainedSession(
                root,
                listOf(StminiRuntimePool.RetainedChildPage(child, "https://session.stmini.local/page.html", "Page", true))
            )
        )

        val restored = StminiRuntimePool.acquireSession(context, info("session"))

        assertSame(root, restored?.rootWebView)
        assertSame(child, restored?.childPages?.single()?.webView)
    }

    @Test fun continuousSessionAndMemoryPressureTreatChildrenAsOneRuntime() {
        StminiHostConfiguration.configure(mapOf("miniSecurity" to mapOf(
            "continuousKeepAliveMiniIds" to listOf("continuous")
        )))
        val root = WebView(context)
        val child = WebView(context)
        StminiRuntimePool.retainSession(
            context,
            info("continuous"),
            StminiRuntimePool.RetainedSession(
                root,
                listOf(StminiRuntimePool.RetainedChildPage(child, "https://continuous.stmini.local/page.html", null, true))
            )
        )
        assertSame(child, StminiRuntimePool.acquireSession(context, info("continuous"))?.childPages?.single()?.webView)

        StminiRuntimePool.retainSession(
            context,
            info("continuous"),
            StminiRuntimePool.RetainedSession(root, listOf(StminiRuntimePool.RetainedChildPage(child, "https://continuous.stmini.local/page.html", null, true)))
        )
        StminiRuntimePool.releaseForMemoryPressure()

        assertNull(StminiRuntimePool.acquireSession(context, info("continuous")))
    }

    @Test fun sessionRestoreStagesChildrenInOrderAndDiscardClearsTheWholeSession() {
        val root = WebView(context)
        val firstChild = WebView(context)
        val secondChild = WebView(context)
        StminiRuntimePool.retainSession(
            context,
            info("stack"),
            StminiRuntimePool.RetainedSession(
                root,
                listOf(
                    StminiRuntimePool.RetainedChildPage(firstChild, "https://stack.stmini.local/one.html", null, true),
                    StminiRuntimePool.RetainedChildPage(secondChild, "https://stack.stmini.local/two.html", "Two", false)
                )
            )
        )

        val session = StminiRuntimePool.acquireSession(context, info("stack"))!!
        assertSame(root, session.rootWebView)
        StminiRuntimePool.stageRestoredChildren("reopened-stack", session.childPages)
        assertSame(firstChild, StminiRuntimePool.takeRestoredChild("reopened-stack", 0)?.webView)
        assertSame(secondChild, StminiRuntimePool.takeRestoredChild("reopened-stack", 1)?.webView)
        assertNull(StminiRuntimePool.takeRestoredChild("reopened-stack", 2))

        val failedChild = WebView(context)
        StminiRuntimePool.stageRestoredChildren(
            "failed-stack",
            listOf(StminiRuntimePool.RetainedChildPage(failedChild, "https://stack.stmini.local/failed.html", null, true))
        )
        StminiRuntimePool.discardStagedChildren("failed-stack")
        assertNull(StminiRuntimePool.takeRestoredChild("failed-stack", 0))

        StminiRuntimePool.retainSession(context, info("stack"), session)
        StminiRuntimePool.discard("stack")
        assertNull(StminiRuntimePool.acquireSession(context, info("stack")))
    }

    @Test fun hiddenLifecycleDeliveryKeepsTheVerifiedRuntimeReusable() {
        val retained = WebView(context)
        StminiRuntimePool.retain(context, info("hidden"), retained)
        val delivered = mutableListOf<Pair<String, String>>()
        StminiRuntimePool.hiddenLifecycleDeliveryObserver = { miniId, name -> delivered += miniId to name }

        StminiRuntimePool.notifyHiddenRuntimes("appHide", mapOf("reason" to "test"))
        StminiRuntimePool.notifyHiddenRuntimes("appShow", mapOf("backgroundDurationMs" to 5L))
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals(listOf("hidden" to "appHide", "hidden" to "appShow"), delivered)
        assertSame(retained, StminiRuntimePool.acquire(context, info("hidden")))
    }

    private fun info(id: String) = MiniPackageStore.InstalledPackage(
        miniId = id, miniName = id, iconUrl = "", launchLink = "mini://$id",
        version = "1.0.0", entry = "index.html", updateSelf = "1"
    )
}
