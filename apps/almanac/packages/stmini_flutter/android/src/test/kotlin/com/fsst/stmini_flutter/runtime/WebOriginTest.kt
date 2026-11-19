package com.fsst.stmini_flutter.runtime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class WebOriginTest {
    @Test
    fun configurationOnlyAcceptsACompleteHttpsOrigin() {
        assertEquals("https://help.example", WebOrigin.normalizeHttps("https://HELP.example/"))
        assertEquals("https://help.example:8443", WebOrigin.normalizeHttps("https://help.example:8443"))
        assertNull(WebOrigin.normalizeHttps("https://help.example/private"))
        assertNull(WebOrigin.normalizeHttps("https://help.example?token=secret"))
        assertNull(WebOrigin.normalizeHttps("http://help.example"))
    }

    @Test
    fun pageUrlExtractsOnlyItsExactOrigin() {
        assertEquals("https://help.example", WebOrigin.originOfHttpsUrl("https://help.example/oauth/callback?state=x"))
        assertNull(WebOrigin.originOfHttpsUrl("http://help.example/oauth"))
    }
}
