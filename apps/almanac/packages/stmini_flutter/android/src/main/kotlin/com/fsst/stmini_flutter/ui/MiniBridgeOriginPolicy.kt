package com.fsst.stmini_flutter.ui

import android.net.Uri
import com.fsst.stmini_flutter.runtime.WebOrigin
import java.util.Locale

/**
 * The bridge has a stronger boundary than ordinary navigation: only the
 * verified Mini's top-level local document may send native requests.  Keep
 * the origin comparison in one small, executable policy so the WebKit origin
 * rule and the listener's defence-in-depth check cannot drift apart.
 */
internal object MiniBridgeOriginPolicy {
    fun originRule(miniId: String): String =
        "https://${miniId.lowercase(Locale.US)}.stmini.local"

    fun accepts(sourceOrigin: Uri, miniId: String, isMainFrame: Boolean): Boolean {
        return isMainFrame && WebOrigin.matchesHttps(sourceOrigin, originRule(miniId))
    }

    fun acceptsConfiguredWeb(sourceOrigin: Uri, expectedOrigin: String, isMainFrame: Boolean): Boolean =
        isMainFrame && WebOrigin.matchesHttps(sourceOrigin, expectedOrigin)
}
