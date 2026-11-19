package com.fsst.stmini_flutter.runtime

import android.content.Context
import android.os.Looper
import com.fsst.stmini_flutter.BuildConfig
import com.fsst.stmini_flutter.StminiRuntimeEvents
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.io.File

/**
 * Regression coverage for the boundaries that must not change when the host
 * gains new bridge APIs: release download transport, trusted-origin matching,
 * and serving only verified files inside one Mini package.
 *
 * Run this suite with `:stmini_flutter:testReleaseUnitTest`; that variant also
 * proves the HTTP debug escape hatch cannot leak into a release artifact.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class MiniRuntimeSecurityTest {
    private lateinit var context: Context
    private lateinit var packageDirectory: File

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        packageDirectory = File(context.filesDir, "STMini/signal-mini")
        packageDirectory.deleteRecursively()
        packageDirectory.mkdirs()
        File(packageDirectory, "index.html").writeText("root")
        File(packageDirectory, "pages").mkdirs()
        File(packageDirectory, "pages/detail.html").writeText("detail")
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
                .put("updateself", "")
                .toString()
        )
        // The strict inventory uses Android's real API-21+ lstat surface.
        // Pin a supported Robolectric SDK above instead of its manifest-free
        // legacy default, and fail fixture setup directly if validation fails.
        assertEquals("signal-mini", LocalPackageInventory(context.filesDir).read { }.single()["miniId"])
    }

    @After
    fun tearDown() {
        packageDirectory.deleteRecursively()
        StminiRuntimeEvents.attach { }.cancel()
        StminiHostConfiguration.configure(null)
    }

    @Test
    fun miniLinkNormalizesIdAndRejectsMalformedId() {
        val link = MiniLink.parse("mini://Signal-Mini?path=%2Fpages%2Fdetail.html")

        assertNotNull(link)
        assertEquals("signal-mini", link!!.miniId)
        assertEquals("/pages/detail.html", link.path)
        assertNull(MiniLink.parse("mini://../outside"))
        assertNull(MiniLink.parse("https://signal-mini"))
    }

    @Test
    fun miniLinkPreservesTheNativeEnglishPresentationFieldWithoutChangingIdentity() {
        val link = MiniLink.parse("mini://signal-mini?miniName=%E4%BF%A1%E5%8F%B7&miniNameEn=Signal%20Mini")

        assertEquals("signal-mini", link?.miniId)
        assertEquals("信号", link?.displayName)
        assertEquals("Signal Mini", link?.displayNameEn)
    }

    @Test
    fun anyHttpsDownloadOriginIsTemporarilyAllowed() {
        val security = MiniSecurity(
            trustedDownloadUrl = "https://packages.example.com/mini/root.zip",
            allowInsecureHttpForDebug = true,
            continuousKeepAliveMiniIds = emptySet()
        )

        assertNull(security.configurationRejectionReason())
        assertNull(security.urlRejectionReason("https://packages.example.com/mini/update.zip"))
        assertNull(security.urlRejectionReason("https://api.example.com/mini/update.zip"))
        assertNull(security.urlRejectionReason("https://packages.example.com:8443/mini/update.zip"))
    }

    @Test
    fun releaseVariantCannotPermitHttpEvenWhenDebugFlagIsRequested() {
        val insecure = MiniSecurity(
            trustedDownloadUrl = "http://packages.example.com/mini/root.zip",
            allowInsecureHttpForDebug = true,
            continuousKeepAliveMiniIds = emptySet()
        )

        if (BuildConfig.DEBUG) {
            // Debug keeps the explicitly requested developer-only escape hatch.
            assertNull(insecure.configurationRejectionReason())
            assertNull(insecure.urlRejectionReason("http://packages.example.com/mini/update.zip"))
        } else {
            // Release still prohibits insecure Mini archive transport.
            assertFalse(BuildConfig.DEBUG)
            assertNull(insecure.configurationRejectionReason())
            assertEquals("小程序下载仅支持 HTTPS", insecure.urlRejectionReason("http://packages.example.com/mini/update.zip"))
        }
    }

    @Test
    fun localPagesMustResolveToAnExistingFileInsideTheirVerifiedPackage() {
        val store = MiniPackageStore(context)
        val installed = installedPackage()

        assertEquals(
            "https://signal-mini.stmini.local/pages/detail.html",
            store.localPageUrl(installed, "/pages/detail.html")
        )
        assertNull(store.localPageUrl(installed, "../index.html"))
        assertNull(store.localPageUrl(installed, "/pages/../index.html"))
        assertNull(store.localPageUrl(installed, "pages\\detail.html"))
        assertNull(store.localPageUrl(installed, "missing.html"))
        assertEquals(
            "https://signal-mini.stmini.local/index.html?tab=trade#/login",
            store.localPageUrl(installed, "index.html?tab=trade#/login")
        )
        assertEquals(
            "https://signal-mini.stmini.local/index.html#/login",
            store.entryUrl(installed, "index.html#/login")
        )
        assertNull(store.entryUrl(installed, "missing.html"))

        assertEquals(
            File(packageDirectory, "pages/detail.html").canonicalFile,
            store.resolveLocalPage("signal-mini", "https://signal-mini.stmini.local/pages/detail.html")
        )
        assertNull(store.resolveLocalPage("signal-mini", "https://other.stmini.local/pages/detail.html"))
        assertNull(store.resolveLocalPage("signal-mini", "https://signal-mini.stmini.local/pages/../index.html"))
    }

    @Test
    fun installedPackageOnlyRequiresADeclaredNewerVersion() {
        val store = MiniPackageStore(context)
        val installed = installedPackage()

        assertFalse(store.requiresUpdate(installed, MiniLink.parse("mini://signal-mini?currentVersion=1.0.0")!!))
        assertTrue(store.requiresUpdate(installed, MiniLink.parse("mini://signal-mini?currentVersion=1.0.1")!!))
        assertTrue(store.requiresUpdate(installed, MiniLink.parse("mini://signal-mini?minSupportVersion=2.0.0")!!))
    }

    @Test
    fun installedPackageRevalidatesManifestAndNormalizesLegacyUpdateOwnership() {
        val store = MiniPackageStore(context)

        // A missing `updateself` is the documented legacy self-update default.
        assertEquals("1", store.installed("signal-mini")?.updateSelf)

        File(packageDirectory, ".st-mini-package.json").writeText(
            JSONObject(File(packageDirectory, ".st-mini-package.json").readText())
                .put("version", "9.9.9")
                .toString()
        )
        assertNull(store.installed("signal-mini"))

        File(packageDirectory, ".st-mini-package.json").writeText(
            JSONObject(File(packageDirectory, ".st-mini-package.json").readText())
                .put("version", "1.0.0")
                .toString()
        )
        File(packageDirectory, "mini-manifest.json").writeText(
            JSONObject(File(packageDirectory, "mini-manifest.json").readText())
                .put("miniId", "other-mini")
                .toString()
        )
        assertNull(store.installed("signal-mini"))
    }

    @Test
    fun installedPackageReadsLocalizedNameAndIconOnlyFromTheVerifiedManifest() {
        File(packageDirectory, "launch-icon.png").writeBytes(byteArrayOf(1, 2, 3))
        File(packageDirectory, "mini-manifest.json").writeText(
            JSONObject(File(packageDirectory, "mini-manifest.json").readText())
                .put("miniNameEn", "Signal Mini")
                .put("icon", "launch-icon.png")
                .toString()
        )
        val store = MiniPackageStore(context)

        val installed = store.installed("signal-mini")
        assertEquals("Signal Mini", installed?.miniNameEn)
        assertEquals(File(packageDirectory, "launch-icon.png").canonicalFile, store.installedIconFile(installed!!))
    }

    @Test
    fun homePolicyComesOnlyFromTheVerifiedManifestLiteralOne() {
        val store = MiniPackageStore(context)
        File(packageDirectory, "mini-manifest.json").writeText(
            JSONObject(File(packageDirectory, "mini-manifest.json").readText())
                .put("ishome", "1")
                .toString()
        )
        File(packageDirectory, ".st-mini-package.json").writeText(
            JSONObject(File(packageDirectory, ".st-mini-package.json").readText())
                .put("ishome", "0")
                .toString()
        )
        assertTrue(store.installed("signal-mini")!!.isHome)

        File(packageDirectory, "mini-manifest.json").writeText(
            JSONObject(File(packageDirectory, "mini-manifest.json").readText())
                .put("ishome", "true")
                .toString()
        )
        // The previously shipped strict manifest domain rejects nonliteral flags,
        // rather than silently accepting an invalid package as ordinary Mini.
        assertNull(store.installed("signal-mini"))
    }

    @Test
    fun eventEnvelopeKeepsTheIosCompatibleNameAndPayloadSchema() {
        var received: Map<String, Any?>? = null
        StminiRuntimeEvents.attach { received = it }

        StminiRuntimeEvents.emit(
            "mini_open_failed",
            mapOf("operationId" to "op-123", "code" to "invalid_mini_link", "retryable" to false)
        )
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals("mini_open_failed", received?.get("name"))
        @Suppress("UNCHECKED_CAST")
        val payload = received?.get("payload") as? Map<String, Any?>
        assertEquals("op-123", payload?.get("operationId"))
        assertEquals("invalid_mini_link", payload?.get("code"))
        assertEquals(false, payload?.get("retryable"))
    }

    private fun installedPackage() = MiniPackageStore.InstalledPackage(
        miniId = "signal-mini",
        miniName = "Signal Mini",
        iconUrl = "",
        launchLink = "mini://signal-mini",
        version = "1.0.0",
        entry = "index.html",
        updateSelf = "1"
    )
}
