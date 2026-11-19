package com.fsst.stmini_flutter.runtime

import android.content.Context
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class StminiHostConfigurationTest {
    private val context: Context = RuntimeEnvironment.getApplication()

    @After fun reset() {
        StminiHostConfiguration.configure(null)
        context.getSharedPreferences("stmini_flutter_storage", Context.MODE_PRIVATE).edit().clear().apply()
        context.getSharedPreferences("stmini_flutter_host_state", Context.MODE_PRIVATE).edit().clear().apply()
    }

    @Test fun resetIsVersionedAndOnlyRemovesDeclaredPluginKeys() {
        val storage = context.getSharedPreferences("stmini_flutter_storage", Context.MODE_PRIVATE)
        storage.edit().putString("auth", "old").putString("unrelated", "keep").apply()
        val config = mapOf<String, Any?>("storageReset" to mapOf("version" to "20260921", "keys" to listOf("auth")))

        StminiHostConfiguration.configure(config, context, "host_loading")
        storage.edit().putString("auth", "new").apply()
        StminiHostConfiguration.configure(config, context, null)

        assertEquals("keep", storage.getString("unrelated", null))
        assertEquals("new", storage.getString("auth", null))
        assertEquals("host_loading", StminiHostConfiguration.loadingImage)
    }

    @Test fun legacyMirrorNeedsExactHttpsOriginAndDeclaredKey() {
        StminiHostConfiguration.configure(mapOf("legacyWebStorageMirror" to mapOf(
            "origins" to listOf("https://help.example"), "keys" to listOf("auth")
        )))

        assertTrue(StminiHostConfiguration.allowsLegacyStorageMirror("https://help.example", "auth"))
        assertFalse(StminiHostConfiguration.allowsLegacyStorageMirror("https://help.example/path", "auth"))
        assertFalse(StminiHostConfiguration.allowsLegacyStorageMirror("https://help.example", "other"))
        assertFalse(StminiHostConfiguration.allowsLegacyStorageMirror("https://third-party.example", "auth"))
    }

    @Test fun ordinaryWebHttpRequiresAnExplicitHostOptIn() {
        StminiHostConfiguration.configure(null)
        assertFalse(StminiHostConfiguration.allowInsecureHttpNavigation)

        StminiHostConfiguration.configure(mapOf("webSecurity" to mapOf(
            "allowInsecureHTTP" to true
        )))
        assertTrue(StminiHostConfiguration.allowInsecureHttpNavigation)
    }

    @Test fun languageUsesIosCompatibleNormalization() {
        StminiHostConfiguration.configure(null, context, null)
        assertEquals("zh-Hant", StminiHostConfiguration.setLanguage(context, "zh_TW"))
        assertEquals("en-US", StminiHostConfiguration.setLanguage(context, "en_GB"))
        assertEquals(null, StminiHostConfiguration.setLanguage(context, "not valid!"))
    }
}
