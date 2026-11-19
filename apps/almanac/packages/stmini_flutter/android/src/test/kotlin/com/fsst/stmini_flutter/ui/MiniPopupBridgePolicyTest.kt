package com.fsst.stmini_flutter.ui

import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class MiniPopupBridgePolicyTest {
    @Test fun localPopupOnlyAcceptsMainFrameVerificationCallback() {
        val target = MiniPopupBridgePolicy.target("signal-mini", "https://signal-mini.stmini.local/index.html")
        assertNotNull(target)
        assertEquals("https://signal-mini.stmini.local", target?.originRule)
        assertTrue(MiniPopupBridgePolicy.accepts(target!!, Uri.parse("https://signal-mini.stmini.local/check"), true, "codeVerifSucc"))
        assertFalse(MiniPopupBridgePolicy.accepts(target, Uri.parse("https://signal-mini.stmini.local/check"), false, "codeVerifSucc"))
        assertFalse(MiniPopupBridgePolicy.accepts(target, Uri.parse("https://other.stmini.local/check"), true, "codeVerifSucc"))
        assertFalse(MiniPopupBridgePolicy.accepts(target, Uri.parse("https://signal-mini.stmini.local/check"), true, "getToken"))
    }

    @Test fun externalPopupPinsItsInitialExactHttpsOrigin() {
        val target = MiniPopupBridgePolicy.target("signal-mini", "https://verify.example/check")!!
        assertEquals("https://verify.example", target.originRule)
        assertTrue(MiniPopupBridgePolicy.accepts(target, Uri.parse("https://verify.example/next"), true, "codeVerifSucc"))
        assertFalse(MiniPopupBridgePolicy.accepts(target, Uri.parse("https://redirect.example/next"), true, "codeVerifSucc"))
        assertFalse(MiniPopupBridgePolicy.target(null, "http://verify.example") != null)
    }
}
