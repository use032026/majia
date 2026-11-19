package com.fsst.stmini_flutter.bridge

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.webkit.WebView
import android.widget.Toast
import com.fsst.stmini_flutter.StminiRuntimeEvents
import com.fsst.stmini_flutter.StminiDebugLog
import com.fsst.stmini_flutter.runtime.StminiHostConfiguration
import com.fsst.stmini_flutter.runtime.MiniPackageStore
import com.fsst.stmini_flutter.runtime.MiniLink
import com.fsst.stmini_flutter.web.BridgeDocumentLease
import com.fsst.stmini_flutter.web.ScopedWebStorage
import com.fsst.stmini_flutter.web.OnlineWebOrigin
import com.fsst.stmini_flutter.web.OnlineWebCore
import com.fsst.stmini_flutter.web.OnlineWebHostBridge
import org.json.JSONObject
import org.json.JSONTokener

/**
 * Keep self-managed package replacement bound to one Mini runtime. A trusted
 * internal page may delegate to its already-open root, but it never becomes
 * an update owner itself.
 */
internal object MiniSelfManagedUpdateAuthority {
    const val rootRequiredCode = "mini_update_root_delegate_unavailable"

    enum class Route { root, trustedChildDelegate, reject }

    fun route(
        isRootMini: Boolean,
        isTrustedInternalChild: Boolean,
        callerMiniId: String?,
        rootMiniId: String?
    ): Route = when {
        isRootMini -> Route.root
        isTrustedInternalChild && !callerMiniId.isNullOrBlank() && callerMiniId == rootMiniId -> Route.trustedChildDelegate
        else -> Route.reject
    }
}

/**
 * Small, framework-only counterpart of the iOS Flutter bridge. It intentionally
 * excludes account, trading, host router and privileged business APIs.
 */
class StminiWebBridge(
    private val activity: StminiBridgeActivity,
    private val webView: WebView,
    private val onlineWebRequestForwarder: (String, JSONObject, String, (JSONObject) -> Unit) -> Unit =
        OnlineWebHostBridge::forward
) {
    interface StminiBridgeActivity {
        fun closeStminiPage(count: Int? = null)
        fun setStminiLoading(visible: Boolean, message: String)
        fun stminiStatusBarHeight(): Int
        fun stminiLanguage(): String
        fun setStminiLanguage(language: String): String?
        fun showStminiMore()
        fun setStminiStatusBarTextColor(isDark: Boolean)
        fun showStminiPopup(url: String, left: Int, right: Int, ratio: Float): Boolean
        fun completeStminiPopup(payload: JSONObject)
        fun shareStminiImage(bytes: ByteArray, mimeType: String): Boolean
        fun saveStminiImage(bytes: ByteArray, mimeType: String, completed: (Boolean, String?) -> Unit)
        fun openStminiInternalWeb(url: String, title: String?, showNavigation: Boolean): Boolean
        /** Opens another verified Mini through the container, never a host Router. */
        fun openStminiInternalMini(link: MiniLink): Boolean
        fun currentMiniPackage(): MiniPackageStore.InstalledPackage?
        fun openStminiLocalPage(path: String, title: String?): Boolean
        /** An online `/web` page owned by the active Mini session can request this child. */
        fun openStminiRouteChild(router: String, params: JSONObject): Boolean
        /** Optional legacy storage mirror; currently unused by the container. */
        fun legacyStorageOrigin(): String?
        fun notifyStminiSessionChanged(reason: String): Int
        fun continuousKeepAliveState(enabled: Boolean? = null): ContinuousKeepAliveState?
        /** Only the owning root Mini may replace its own package runtime. */
        fun canRequestSelfManagedUpdate(): Boolean
        fun installStminiUpdate(downloadUrl: String, isForce: Boolean, completed: (Result<MiniPackageStore.InstalledPackage>) -> Unit): Boolean
    }

    data class ContinuousKeepAliveState(val supported: Boolean, val enabled: Boolean)

    companion object {
        private const val MAX_STORAGE_BYTES = 1_048_576
        // Do not let a compromised Mini document turn the bridge parser into
        // an unbounded allocation sink.  This also matches the storage limit.
        private const val MAX_MESSAGE_BYTES = 1_048_576
        private const val MAX_IMAGE_BASE64_BYTES = 6 * 1_048_576
        private const val MAX_IMAGE_BYTES = 4 * 1_048_576
        private const val MAX_IMAGE_PIXELS = 12_000_000L
        /** Mirrors iOS `nonSensitiveExternalHostMethods`. */
        private val nonSensitiveExternalHostMethods = setOf(
            "showToast",
            "showLoading",
            "hideLoading",
            "close",
            "more",
            "setStatusBarTextColor",
            "getStatusBarHeight",
            "applog",
            "logNetworkRequest"
        )
    }

    /**
     * Called exclusively by [androidx.webkit.WebMessageListener] after it has
     * verified the sender's Mini origin and main-frame status.  Deliberately
     * not annotated with `JavascriptInterface`: that API exposes this object
     * to every iframe in the WebView.
     */
    fun postMessage(
        raw: String,
        allowsSensitiveHostBridge: Boolean = true,
        onlineWebOrigin: String? = null
    ) {
        if (raw.toByteArray(Charsets.UTF_8).size > MAX_MESSAGE_BYTES) return
        val request = runCatching { JSONObject(raw) }.getOrNull() ?: return
        val method = request.optString("method")
        val params = request.optJSONObject("params") ?: JSONObject()
        if (params.has("methodId") && params.opt("methodId") !is String) return
        val generation = BridgeDocumentLease.generation(webView)
        val document = webView.url
        fun deliver(value: JSONObject) = OnlineWebCore.CmsJsCallback.deliver(webView, value.toString()) {
            BridgeDocumentLease.isCurrent(webView, generation, document)
        }
        val methodId = params.optString("methodId")
        val response = OnlineWebCore.CmsJsCallback.response(method, methodId)
        if (!allowsSensitiveHostBridge && method !in nonSensitiveExternalHostMethods) {
            fail(response, "当前页面未获宿主 Bridge 授权")
            deliver(response)
            return
        }
        var callbackImmediately = true
        when (method) {
            "showToast" -> runOnUi {
                Toast.makeText(activity as Context, params.optString("title", params.optString("msg")), Toast.LENGTH_SHORT).show()
            }
            "showLoading" -> runOnUi { activity.setStminiLoading(true, params.optString("title", params.optString("message"))) }
            "hideLoading" -> runOnUi { activity.setStminiLoading(false, "") }
            // WebMessageListener invokes this on the WebView/UI thread; call
            // through directly so close cannot be lost after the page has
            // already detached its own WebView from the message queue.
            "close" -> activity.closeStminiPage(optionalCloseCount(params))
            "setClipBoardData" -> runOnUi {
                val value = params.optString("text")
                val clipboard = (activity as Context).getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("STMini", value))
            }
            "jumpWeb" -> {
                val url = params.optString("url")
                if (!isHttpUrl(url)) fail(response, "url不合法") else runOnUi {
                    (activity as Context).startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                }
            }
            "systemShareText" -> runOnUi {
                val text = params.optString("text")
                (activity as Context).startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"; putExtra(Intent.EXTRA_TEXT, text)
                }, null))
            }
            "systemShareUrl" -> {
                val url = params.optString("urlStr")
                if (!isHttpUrl(url)) fail(response, "url不合法") else runOnUi {
                    (activity as Context).startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"; putExtra(Intent.EXTRA_TEXT, url)
                    }, null))
                }
            }
            "getPackageName" -> response.put("data", JSONObject().put("packageName", StminiHostConfiguration.bridgeContext["packageName"] as? String ?: ""))
            "getLanguage" -> response.put("data", JSONObject().put("language", activity.stminiLanguage()))
            "getStatusBarHeight" -> response.put("data", JSONObject().put("height", activity.stminiStatusBarHeight().toString()))
            "getConfig" -> response.put("data", JSONObject(StminiHostConfiguration.bridgeContext["config"] as? Map<*, *> ?: emptyMap<String, Any?>()))
            "getUserInfo" -> response.put("data", JSONObject(bridgeUserInfo()))
            "getToken" -> response.put("data", bridgeUserInfo()["token"] as? String ?: "")
            "setStorage" -> store(params, response, onlineWebOrigin)
            "getStorage" -> readStorage(params, response, onlineWebOrigin)
            "removeStorage" -> removeStorage(params, response, onlineWebOrigin)
            "open" -> {
                val router = params.optString("router")
                val url = params.optString("link")
                val navigation = params.optString("isNeedNavigationBar").lowercase() in setOf("1", "true", "yes")
                if (router == "/mini") {
                    val miniLink = parseInternalMiniLink(url)
                    if (miniLink == null) {
                        fail(response, "小程序链接无效")
                    } else if (!activity.openStminiInternalMini(miniLink)) {
                        // The Activity additionally proves that the caller is
                        // a live, trusted Mini root. A local child or a
                        // configured external page must not gain this route.
                        fail(response, "小程序导航容器不可用")
                    } else {
                        response.put("data", JSONObject().put("opened", true))
                    }
                } else if (router == "/web") {
                    val rawNavigation = params.opt("isNeedNavigationBar")
                    StminiDebugLog.webRouter("mini_web_request", mapOf(
                        "miniId" to activity.currentMiniPackage()?.miniId,
                        "url" to StminiDebugLog.redactedUrl(url),
                        "navigationRaw" to rawNavigation,
                        "navigationVisible" to navigation,
                        "titlePresent" to params.optString("title").isNotBlank()
                    ))
                    if (!isHttpsUrl(url)) {
                        StminiDebugLog.webRouter("mini_web_rejected", mapOf("reason" to "unsafe_url"))
                        fail(response, "仅支持安全的 HTTPS 小程序内网页")
                    } else if (!activity.openStminiInternalWeb(url, params.optString("title"), navigation)) {
                        StminiDebugLog.webRouter("mini_web_rejected", mapOf("reason" to "navigation_unavailable"))
                        fail(response, "小程序导航容器不可用")
                    } else response.put("data", JSONObject().put("opened", true))
                } else if (router.isNotBlank()) {
                    StminiDebugLog.webRouter("mini_route_request", mapOf(
                        "miniId" to activity.currentMiniPackage()?.miniId,
                        "router" to router.take(120)
                    ))
                    if (activity.openStminiRouteChild(router, params)) {
                        StminiDebugLog.webRouter("mini_route_accepted", mapOf(
                            "miniId" to activity.currentMiniPackage()?.miniId,
                            "router" to router.take(120)
                        ))
                        response.put("data", JSONObject().put("opened", true))
                    } else {
                        StminiDebugLog.webRouter("mini_route_rejected", mapOf(
                            "miniId" to activity.currentMiniPackage()?.miniId,
                            "router" to router.take(120),
                            "reason" to "navigation_unavailable"
                        ))
                        fail(response, "小程序路由页面无效")
                    }
                } else {
                    fail(response, "小程序路由页面无效")
                }
            }
            "mini_getMiniPackageInfo" -> {
                val info = activity.currentMiniPackage()
                if (info == null) fail(response, "小程序包校验失败") else response.put("data", JSONObject().apply {
                    put("miniId", info.miniId); put("version", info.version); put("updateself", info.updateSelf)
                })
            }
            "mini_checkMiniProgramUpdate" -> {
                val info = activity.currentMiniPackage()
                when {
                    info == null -> fail(response, "小程序包校验失败")
                    info.updateSelf != "0" -> fail(response, "当前小程序由自身检查更新")
                    else -> fail(response, "宿主检查更新尚未接入")
                }
            }
            "mini_downloadMiniProgramUpdate" -> {
                val info = activity.currentMiniPackage()
                val downloadUrl = params.optString("downloadUrl").trim()
                val isForce = boolParam(params, "isforce") ?: boolParam(params, "isForce")
                when {
                    // A pushed local child uses the same verified package, but
                    // it must never replace the parent runtime from beneath
                    // its own navigation/overlay. Reject before URL handling
                    // or the installer, so no download request can start.
                    !activity.canRequestSelfManagedUpdate() -> fail(
                        response,
                        "当前页面没有可用的根小程序更新上下文",
                        MiniSelfManagedUpdateAuthority.rootRequiredCode
                    )
                    info == null -> fail(response, "小程序包校验失败")
                    info.updateSelf != "1" -> fail(response, "当前小程序不支持自行更新")
                    downloadUrl.isEmpty() -> fail(response, "缺少更新地址")
                    isForce == null -> fail(response, "缺少 isforce")
                    !activity.installStminiUpdate(downloadUrl, isForce) { outcome ->
                        // The request was already acknowledged to H5. Install
                        // results are delivered through runtime events, so a
                        // forced update cannot destroy this page's callback.
                    } -> fail(response, "小程序更新容器不可用")
                    else -> response.put("data", JSONObject().apply {
                        put("accepted", true)
                        put("isforce", if (isForce) "1" else "0")
                    })
                }
            }
            "mini_navigateTo" -> {
                val path = params.optString("path")
                if (path.isBlank()) fail(response, "缺少 path")
                else if (!activity.openStminiLocalPage(path, params.optString("title"))) fail(response, "小程序本地页面无效")
                else response.put("data", JSONObject().put("opened", true))
            }
            "mini_notifySessionChanged" -> {
                val reason = params.optString("reason", "sessionChanged").take(64)
                val notified = activity.notifyStminiSessionChanged(reason)
                response.put("data", JSONObject().put("notified", notified))
            }
            "mini_getMiniProgramContinuousKeepAlive" -> {
                val state = activity.continuousKeepAliveState()
                if (state == null) fail(response, "仅小程序页面可设置持续保活")
                else response.put("data", JSONObject().apply {
                    put("enabled", state.enabled)
                    put("supported", state.supported)
                })
            }
            "mini_setMiniProgramContinuousKeepAlive" -> {
                val enabled = boolParam(params, "enabled")
                if (enabled == null) fail(response, "缺少 enabled")
                else {
                    val state = activity.continuousKeepAliveState(enabled)
                    if (state == null) fail(response, "仅小程序页面可设置持续保活")
                    else response.put("data", JSONObject().apply {
                        put("enabled", state.enabled)
                        put("supported", state.supported)
                    })
                }
            }
            "applog" -> StminiRuntimeEvents.emit("native_log", mapOf("message" to params.optString("msg", params.optString("message"))))
            "logNetworkRequest" -> StminiRuntimeEvents.emit("network_log", mapOf("method" to params.optString("method"), "url" to redactUrl(params.optString("url"))))
            "more" -> runOnUi { activity.showStminiMore() }
            "setStatusBarTextColor" -> runOnUi { activity.setStminiStatusBarTextColor(boolParam(params, "isDark") ?: true) }
            "setLanguage" -> {
                val language = params.optString("language", params.optString("languageCode"))
                val normalized = activity.setStminiLanguage(language)
                if (normalized == null) fail(response, if (language.isBlank()) "缺少 language" else "language 无效")
                else response.put("data", JSONObject().put("language", normalized))
            }
            "showPopWeb" -> {
                val url = params.optString("url").trim()
                if (url.isBlank()) fail(response, "url不合法")
                else if (!activity.showStminiPopup(url, boundedInt(params, "left", 50, 0, 160), boundedInt(params, "right", 50, 0, 160), boundedRatio(params))) fail(response, "url不合法")
            }
            "codeVerifSucc" -> runOnUi { activity.completeStminiPopup(params) }
            "systemShareImage" -> imageBytes(params, "分享图片数据有误")?.let { image ->
                if (!activity.shareStminiImage(image.first, image.second)) fail(response, "图片分享不可用")
            } ?: fail(response, imageInputError(params))
            "saveImageToPhotosAlbum" -> imageBytes(params, "图片数据有误")?.let { image ->
                callbackImmediately = false
                runOnUi {
                    activity.saveStminiImage(image.first, image.second) { saved, message ->
                        if (saved) deliver(response)
                        else { fail(response, message ?: "保存出错"); deliver(response) }
                    }
                }
            } ?: fail(response, imageInputError(params))
            else -> {
                // Only OnlineWebCore can provide an origin here. Local Mini
                // documents retain their existing fail-closed API surface;
                // no Mini method is forwarded into the embedding Flutter app.
                if (onlineWebOrigin == null) {
                    fail(response, "宿主未提供该 API")
                } else {
                    callbackImmediately = false
                    val requestParams = JSONObject(params.toString())
                    onlineWebRequestForwarder(method, requestParams, onlineWebOrigin) { hostResponse ->
                        response.put("code", hostResponse.optString("code", "0"))
                        response.put("data", hostResponse.opt("data") ?: JSONObject().put("msg", "宿主处理网页请求失败"))
                        deliver(response)
                    }
                }
            }
        }
        if (callbackImmediately) deliver(response)
    }

    private fun fail(response: JSONObject, message: String, errorCode: String? = null) {
        OnlineWebCore.CmsJsCallback.fail(response, message, errorCode)
    }

    private fun store(params: JSONObject, response: JSONObject, onlineOrigin: String?) {
        val subject = storageSubject(onlineOrigin) ?: return fail(response, "当前文档没有存储主体")
        val key = validStorageKey(params.optString("key")) ?: return fail(response, "缺少key")
        if (!params.has("data") || params.isNull("data")) return fail(response, "应当存储json字符串")
        val value = params.optString("data")
        if (value.toByteArray(Charsets.UTF_8).size > MAX_STORAGE_BYTES) return fail(response, "存储内容过大")
        if (runCatching { JSONTokener(value).nextValue() }.isFailure) return fail(response, "存储出错")
        val context = activity as Context
        ScopedWebStorage.preferences(context, subject).edit().putString(key, value).apply()
        legacyStoragePreferences(context, key)?.edit()?.putString(key, value)?.apply()
    }

    private fun readStorage(params: JSONObject, response: JSONObject, onlineOrigin: String?) {
        val subject = storageSubject(onlineOrigin) ?: return fail(response, "当前文档没有存储主体")
        val key = validStorageKey(params.optString("key")) ?: return fail(response, "缺少key")
        val context = activity as Context
        val value = ScopedWebStorage.preferences(context, subject).getString(key, null)
            ?: legacyStoragePreferences(context, key)?.getString(key, null)
            ?: return fail(response, "值不存在")
        response.put("data", runCatching { JSONTokener(value).nextValue() }.getOrElse { value })
    }

    private fun removeStorage(params: JSONObject, response: JSONObject, onlineOrigin: String?) {
        val subject = storageSubject(onlineOrigin) ?: return fail(response, "当前文档没有存储主体")
        val key = validStorageKey(params.optString("key")) ?: return fail(response, "缺少key")
        val context = activity as Context
        ScopedWebStorage.preferences(context, subject).edit().remove(key).apply()
        legacyStoragePreferences(context, key)?.edit()?.remove(key)?.apply()
    }

    private fun storageSubject(onlineOrigin: String?): String? {
        val origin = OnlineWebOrigin.originOfHttpsUrl(webView.url) ?: return null
        if (onlineOrigin != null && onlineOrigin != origin) return null
        val mini = activity.currentMiniPackage() ?: return null
        return "mini:${mini.miniId}|origin:$origin"
    }

    private fun validStorageKey(value: String): String? = value.takeIf { it.isNotBlank() && it.length <= 256 }

    private fun legacyStoragePreferences(context: Context, key: String) = activity.legacyStorageOrigin()
        ?.takeIf { StminiHostConfiguration.allowsLegacyStorageMirror(it, key) }
        ?.let { origin -> context.getSharedPreferences("stmini_flutter_legacy_${origin.hashCode()}", Context.MODE_PRIVATE) }

    /** Same explicit, JSON-only host cache contract as Flutter iOS. */
    private fun bridgeUserInfo(): Map<String, Any?> {
        val context = activity as Context
        val result = linkedMapOf<String, Any?>(
            "device_type" to "android",
            "dark_mode" to if ((context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES) "1" else "0",
            "language_code" to activity.stminiLanguage()
        )
        val authKey = StminiHostConfiguration.bridgeContext["authStorageKey"] as? String
        val auth = authKey?.takeIf { validStorageKey(it) != null }?.let {
            context.getSharedPreferences("stmini_flutter_storage", Context.MODE_PRIVATE).getString(it, null)
        }?.let(::jsonObject)
        auth?.let {
            result["token"] = it["token"] ?: it["access_token"]
            result["device_id"] = it["device_id"]
            result["user_id"] = it["user_id"]
        }
        val profileConfig = StminiHostConfiguration.bridgeContext["bridgeUserInfoStorage"] as? Map<*, *>
        val profile = profileConfig?.let { config ->
            val storageKey = config["storageKey"] as? String ?: return@let null
            val valueKey = config["valueKey"] as? String ?: return@let null
            val values = context.getSharedPreferences("stmini_flutter_storage", Context.MODE_PRIVATE)
                .getString(storageKey, null)?.let(::jsonObject) ?: return@let null
            val raw = values[valueKey]
            val selected = if (raw is String) jsonObject(raw) else raw as? Map<*, *>
            val nested = config["nestedKey"] as? String
            (if (nested.isNullOrBlank()) selected else selected?.get(nested) as? Map<*, *>)
                ?.entries?.associate { it.key.toString() to it.value }
        }
        profile?.let(result::putAll)
        (StminiHostConfiguration.bridgeContext["userInfo"] as? Map<*, *>)
            ?.entries?.forEach { (key, value) -> if (key is String) result[key] = value }
        return result.filterValues { it != null }
    }

    private fun jsonObject(value: String): Map<String, Any?>? = runCatching {
        val objectValue = JSONObject(value)
        objectValue.keys().asSequence().associateWith { key -> objectValue.opt(key) }
    }.getOrNull()

    private fun optionalCloseCount(params: JSONObject): Int? {
        if (!params.has("count") || params.isNull("count")) return null
        return when (val raw = params.opt("count")) {
            is Number -> raw.toInt().takeIf { raw.toDouble() == it.toDouble() && it >= 0 }
            is String -> raw.trim().toIntOrNull()?.takeIf { it >= 0 }
            else -> null
        }
    }

    private fun boundedInt(params: JSONObject, name: String, fallback: Int, low: Int, high: Int): Int =
        ((params.opt(name) as? Number)?.toInt() ?: params.optString(name).toIntOrNull() ?: fallback).coerceIn(low, high)

    private fun boundedRatio(params: JSONObject): Float =
        ((params.opt("ratio") as? Number)?.toFloat() ?: params.optString("ratio").toFloatOrNull() ?: 1f).coerceIn(.2f, 3f)

    private fun imageInputError(params: JSONObject): String = when {
        !params.has("imgFileStr") -> "缺少 imgFileStr"
        params.optString("imgFileStr").toByteArray(Charsets.UTF_8).size > MAX_IMAGE_BASE64_BYTES -> "图片数据过大"
        else -> "图片数据有误"
    }

    private fun imageBytes(params: JSONObject, @Suppress("UNUSED_PARAMETER") invalidMessage: String): Pair<ByteArray, String>? {
        val raw = params.optString("imgFileStr")
        if (raw.isBlank() || raw.toByteArray(Charsets.UTF_8).size > MAX_IMAGE_BASE64_BYTES) return null
        val payload = raw.substringAfter(',', raw)
        val bytes = runCatching { android.util.Base64.decode(payload, android.util.Base64.DEFAULT) }.getOrNull() ?: return null
        if (bytes.size > MAX_IMAGE_BYTES) return null
        val options = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
        android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        if (options.outWidth <= 0 || options.outHeight <= 0 || options.outWidth.toLong() * options.outHeight.toLong() > MAX_IMAGE_PIXELS) return null
        val mime = when {
            bytes.size >= 8 && bytes.copyOfRange(0, 8).contentEquals(byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10)) -> "image/png"
            bytes.size >= 3 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xD8.toByte() && bytes[2] == 0xFF.toByte() -> "image/jpeg"
            else -> return null
        }
        return bytes to mime
    }

    private fun boolParam(params: JSONObject, key: String): Boolean? {
        if (!params.has(key) || params.isNull(key)) return null
        return when (val raw = params.opt(key)) {
            is Boolean -> raw
            is Number -> raw.toInt() != 0
            is String -> when (raw.trim().lowercase()) {
                "1", "true", "yes", "on" -> true
                "0", "false", "no", "off" -> false
                else -> null
            }
            else -> null
        }
    }

    private fun callback(response: JSONObject) =
        OnlineWebCore.CmsJsCallback.deliver(webView, response.toString())

    private fun runOnUi(block: () -> Unit): Boolean {
        val generation = BridgeDocumentLease.generation(webView)
        val document = webView.url
        return webView.post { if (BridgeDocumentLease.isCurrent(webView, generation, document)) block() }
    }
    private fun isHttpUrl(value: String): Boolean = runCatching { Uri.parse(value) }.getOrNull()?.let {
        it.scheme.equals("https", true) || it.scheme.equals("http", true)
    } == true
    private fun isHttpsUrl(value: String): Boolean = runCatching { Uri.parse(value) }.getOrNull()?.let {
        it.scheme.equals("https", true) && !it.host.isNullOrBlank()
    } == true

    /** `/mini` is deliberately narrower than a host/QR Mini entry link. */
    private fun parseInternalMiniLink(value: String): MiniLink? {
        val raw = value.trim()
        val link = MiniLink.parse(raw) ?: return null
        val uri = runCatching { Uri.parse(raw) }.getOrNull() ?: return null
        val host = uri.host ?: return null
        if (!uri.scheme.equals("mini", true) || host.isBlank() ||
            !uri.path.isNullOrEmpty() || uri.userInfo != null || uri.port != -1 ||
            uri.fragment != null || host.lowercase() != link.miniId) return null
        return link
    }
    private fun redactUrl(value: String): String = runCatching { Uri.parse(value) }.getOrNull()?.let {
        "${it.scheme}://${it.host ?: ""}${it.path ?: ""}"
    } ?: ""
}
