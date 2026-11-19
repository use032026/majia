package com.fsst.stmini_flutter.ui

import android.net.Uri
import com.fsst.stmini_flutter.runtime.WebOrigin

/**
 * A popup must not inherit the root Mini bridge.  This policy grants exactly
 * one callback, `codeVerifSucc`, to the initial verified local page or the
 * initial exact HTTPS origin. Redirects, iframes and every other message are
 * rejected by design.
 */
internal object MiniPopupBridgePolicy {
    const val channelName = "CMSScriptMessageChannel"
    const val codeVerifiedMethod = "codeVerifSucc"

    data class Target(val originRule: String, val localMiniId: String?)

    fun target(miniId: String?, url: String): Target? {
        val localId = miniId?.takeIf {
            MiniBridgeOriginPolicy.accepts(Uri.parse(url), it, true)
        }
        if (localId != null) return Target(MiniBridgeOriginPolicy.originRule(localId), localId)
        return WebOrigin.originOfHttpsUrl(url)?.let { Target(it, null) }
    }

    fun accepts(target: Target, source: Uri, isMainFrame: Boolean, method: String): Boolean {
        if (!isMainFrame || method != codeVerifiedMethod) return false
        return target.localMiniId?.let { MiniBridgeOriginPolicy.accepts(source, it, true) }
            ?: MiniBridgeOriginPolicy.acceptsConfiguredWeb(source, target.originRule, true)
    }
}
