package com.fsst.stmini_flutter.ui

import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.runner.RunWith
import org.junit.Test
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class MiniBridgeOriginPolicyTest {
    @Test
    fun listenerRuleIsExactToTheVerifiedMiniOrigin() {
        assertEquals("https://signal-mini.stmini.local", MiniBridgeOriginPolicy.originRule("Signal-Mini"))
        assertTrue(MiniBridgeOriginPolicy.accepts(Uri.parse("https://signal-mini.stmini.local/index.html"), "signal-mini", true))
        assertTrue(MiniBridgeOriginPolicy.accepts(Uri.parse("https://signal-mini.stmini.local:443/index.html"), "signal-mini", true))
    }

    @Test
    fun listenerRejectsIframesAndAnyOtherOrigin() {
        assertFalse(MiniBridgeOriginPolicy.accepts(Uri.parse("https://signal-mini.stmini.local/frame.html"), "signal-mini", false))
        assertFalse(MiniBridgeOriginPolicy.accepts(Uri.parse("https://other.stmini.local/index.html"), "signal-mini", true))
        assertFalse(MiniBridgeOriginPolicy.accepts(Uri.parse("http://signal-mini.stmini.local/index.html"), "signal-mini", true))
        assertFalse(MiniBridgeOriginPolicy.accepts(Uri.parse("https://signal-mini.stmini.local:8443/index.html"), "signal-mini", true))
    }

    @Test
    fun configuredWebOriginRequiresACompleteExactHttpsOrigin() {
        assertTrue(MiniBridgeOriginPolicy.acceptsConfiguredWeb(Uri.parse("https://help.example/page"), "https://help.example", true))
        assertFalse(MiniBridgeOriginPolicy.acceptsConfiguredWeb(Uri.parse("https://help.example/page"), "https://other.example", true))
        assertFalse(MiniBridgeOriginPolicy.acceptsConfiguredWeb(Uri.parse("https://help.example/page"), "https://help.example", false))
    }
}
