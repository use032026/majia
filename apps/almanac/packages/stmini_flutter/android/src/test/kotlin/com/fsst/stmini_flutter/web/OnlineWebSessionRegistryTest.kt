package com.fsst.stmini_flutter.web

import android.content.Intent
import android.app.Activity
import android.webkit.WebView
import com.fsst.stmini_flutter.StminiFlutterPlugin
import com.fsst.stmini_flutter.runtime.StminiHostConfiguration
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Before
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.Shadows

/** Regression coverage for the shared owner/session boundary. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class OnlineWebSessionRegistryTest {
    private val controllers = mutableListOf<ActivityController<OnlineWebActivity>>()

    @Before fun setUp() { OnlineWebSessionRegistry.clearForTest() }
    @After fun tearDown() {
        controllers.forEach { it.pause().stop().destroy() }
        StminiHostConfiguration.configure(null)
        OnlineWebConfiguration.configure(emptyMap())
    }

    @Test fun delegateStaysRegisteredForTheExactOwnerLifetime() {
        val key = OnlineWebSessionRegistry.register("mini-session", RecordingDelegate())
        assertTrue(OnlineWebSessionRegistry.containsForTest(key))
        val owner = owner(key)
        assertEquals(1, OnlineWebSessionRegistry.activeCountForTest())

        val controller = controllers.first { it.get() === owner }
        controllers.remove(controller)
        controller.pause().stop().destroy()
        assertFalse(OnlineWebSessionRegistry.containsForTest(key))
    }

    @Test fun closeCountClosesOnlyTheNewestOnlinePages() {
        val first = owner(OnlineWebSessionRegistry.register("mini-session", RecordingDelegate()))
        val second = owner(OnlineWebSessionRegistry.register("mini-session", RecordingDelegate()))

        OnlineWebSessionRegistry.closeCount("mini-session", 1)

        assertFalse(first.isFinishing)
        assertTrue(second.isFinishing)
    }

    @Test fun sessionBroadcastReachesOnlyLiveOnlineOwners() {
        val delegate = RecordingDelegate()
        owner(OnlineWebSessionRegistry.register("mini-session", delegate))

        assertEquals(1, OnlineWebSessionRegistry.notifySessionChanged("mini-session", "login"))
        assertEquals("login", delegate.lastSessionReason)
    }

    @Test fun closeBeforeAttachLeavesATombstoneAndTheLateOwnerFinishes() {
        val key = OnlineWebSessionRegistry.register("mini-session", RecordingDelegate())

        OnlineWebSessionRegistry.closeSession("mini-session")

        assertTrue(OnlineWebSessionRegistry.closedForTest(key))
        val lateOwner = owner(key)
        assertTrue(lateOwner.isFinishing)
        assertFalse(OnlineWebSessionRegistry.containsForTest(key))
    }

    @Test fun configRecreatedOwnerSurvivesOldOwnerDelayedDestroy() {
        val key = OnlineWebSessionRegistry.register("mini-session", RecordingDelegate())
        val oldOwner = owner(key)
        val oldEpoch = oldOwner.sessionEpochForTest()

        // Mirrors Activity.onDestroy while Android is recreating it: retain
        // the entry, then attach a replacement before the old destroy races.
        OnlineWebSessionRegistry.detach(key, oldOwner, oldEpoch, changingConfigurations = true)
        val newOwner = owner(key)
        OnlineWebSessionRegistry.detach(key, oldOwner, oldEpoch, changingConfigurations = false)

        assertTrue(OnlineWebSessionRegistry.containsForTest(key))
        assertFalse(newOwner.isFinishing)
    }

    @Test
    @Config(packageName = "com.almanac.lite")
    fun hostOpenWebTargetClosesThroughCompatibleCloseMiniMethod() {
        // Exercise the actual plugin host-open path, then its public legacy
        // closeMini MethodChannel branch against the displayed target.
        val host = Robolectric.buildActivity(Activity::class.java).setup().get()
        val plugin = StminiFlutterPlugin()
        StminiFlutterPlugin::class.java.getDeclaredField("activity").apply {
            isAccessible = true
            set(plugin, host)
        }
        // This JVM harness supplies only the Engine attachment context. The
        // real initialize receiver still validates the exact Deynu host and
        // must succeed before the real openWeb branch is exercised.
        val context = object : android.content.ContextWrapper(RuntimeEnvironment.getApplication()) {
            override fun getPackageName(): String = "com.almanac.lite"
        }
        assertEquals("com.almanac.lite", context.packageName)
        StminiFlutterPlugin::class.java.getDeclaredField("applicationContext").apply {
            isAccessible = true; set(plugin, context)
        }
        StminiFlutterPlugin::class.java.getDeclaredField("attached").apply {
            isAccessible = true; setBoolean(plugin, true)
        }
        var initialized = false
        plugin.onMethodCall(MethodCall("initialize", mapOf("bridgeContext" to mapOf("packageName" to context.packageName))),
            object : MethodChannel.Result {
                override fun success(result: Any?) { initialized = true }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) =
                    error("initialize rejected: $errorCode")
                override fun notImplemented() = error("initialize not implemented")
            })
        assertTrue(initialized)
        var completed = false
        val openResult = object : MethodChannel.Result {
            override fun success(result: Any?) { completed = true }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = error("unexpected")
            override fun notImplemented() = error("unexpected")
        }
        StminiFlutterPlugin::class.java.getDeclaredMethod(
            "openWeb", String::class.java, String::class.java,
            Boolean::class.javaPrimitiveType, MethodChannel.Result::class.java
        ).apply {
            isAccessible = true
            invoke(plugin, "https://host.example/page", null, true, openResult)
        }
        assertTrue(completed)
        val started = Shadows.shadowOf(host).nextStartedActivity
        assertEquals(OnlineWebActivity::class.java.name, started.component?.className)
        val hostOwner = Robolectric.buildActivity(OnlineWebActivity::class.java, started)
            .also(controllers::add).setup().get()

        completed = false
        StminiFlutterPlugin().onMethodCall(MethodCall("closeMini", null), object : MethodChannel.Result {
            override fun success(result: Any?) { completed = true }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = error("unexpected")
            override fun notImplemented() = error("unexpected")
        })

        assertTrue(completed)
        assertTrue(hostOwner.isFinishing)
    }

    @Test fun successfulStorageMirrorQueuesReloadBeforeSessionNotification() {
        val owner = hostOwner()

        owner.completeSessionStorageMirror(applied = true, reason = "login", reloadOnChange = true)

        assertEquals("login", owner.pendingSessionReasonForTest())
        // setup() makes the page visible, so the owner immediately starts its
        // reload; it intentionally does not send the session callback until
        // the replacement page commits.
        assertFalse(owner.pendingSessionReloadForTest())
    }

    @Test fun rejectedStorageMirrorDoesNotQueueReloadOrSessionNotification() {
        val owner = hostOwner()

        owner.completeSessionStorageMirror(applied = false, reason = "login", reloadOnChange = true)

        assertEquals(null, owner.pendingSessionReasonForTest())
        assertFalse(owner.pendingSessionReloadForTest())
    }

    private fun owner(key: String): OnlineWebActivity {
        val context = RuntimeEnvironment.getApplication()
        return Robolectric.buildActivity(
            OnlineWebActivity::class.java,
            OnlineWebActivity.intent(
                context = context,
                url = "https://trusted.example/page",
                title = null,
                showNavigation = true,
                sessionDelegate = key
            )
        ).also(controllers::add).setup().get()
    }

    private fun hostOwner(): OnlineWebActivity {
        val context = RuntimeEnvironment.getApplication()
        return Robolectric.buildActivity(
            OnlineWebActivity::class.java,
            OnlineWebActivity.intent(context, "https://host.example/page", null, true)
        ).also(controllers::add).setup().get()
    }

    private class RecordingDelegate : OnlineWebSessionDelegate {
        var lastSessionReason: String? = null
        override fun handleMessage(raw: String, origin: String, webView: WebView, closePage: () -> Unit) = false
        override fun leavePage(closePage: () -> Unit) = closePage()
        override fun sessionChanged(owner: OnlineWebActivity, webView: WebView, reason: String) {
            lastSessionReason = reason
        }
    }
}
