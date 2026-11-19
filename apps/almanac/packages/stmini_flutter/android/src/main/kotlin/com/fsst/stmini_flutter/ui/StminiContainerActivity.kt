package com.fsst.stmini_flutter.ui

import com.fsst.stmini_flutter.web.BridgeDocumentLease

import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.app.Dialog
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebChromeClient
import android.webkit.WebViewClient
import android.webkit.RenderProcessGoneDetail
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import com.fsst.stmini_flutter.StminiDebugLog
import com.fsst.stmini_flutter.StminiRuntimeEvents
import com.fsst.stmini_flutter.bridge.MiniSelfManagedUpdateAuthority
import com.fsst.stmini_flutter.bridge.StminiWebBridge
import com.fsst.stmini_flutter.runtime.MiniLink
import com.fsst.stmini_flutter.runtime.MiniPackageStore
import com.fsst.stmini_flutter.runtime.StminiHostConfiguration
import com.fsst.stmini_flutter.runtime.StminiRuntimePool
import com.fsst.stmini_flutter.runtime.WebOrigin
import com.fsst.stmini_flutter.web.OnlineWebCore
import com.fsst.stmini_flutter.web.OnlineWebActivity
import com.fsst.stmini_flutter.web.OnlineWebOrigin
import com.fsst.stmini_flutter.web.OnlineWebSessionDelegate
import com.fsst.stmini_flutter.web.OnlineWebSessionRegistry
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.lang.ref.WeakReference
import java.util.UUID

/** Isolated full-screen Android container for either a verified Mini or H5. */
open class StminiContainerActivity : Activity(), StminiWebBridge.StminiBridgeActivity {
    companion object {
        const val EXTRA_MINI_LINK = "stmini.miniLink"
        const val EXTRA_WEB_URL = "stmini.webUrl"
        const val EXTRA_WEB_TITLE = "stmini.webTitle"
        const val EXTRA_SHOW_NAVIGATION = "stmini.showNavigation"
        const val EXTRA_PARENT_MINI_ID = "stmini.parentMiniId"
        const val EXTRA_OPERATION_ID = "stmini.operationId"
        private const val EXTRA_RUNTIME_SESSION_ID = "stmini.runtimeSessionId"
        private const val EXTRA_RESTORED_CHILD_INDEX = "stmini.restoredChildIndex"
        private const val EXTRA_ROUTE_CHILD = "stmini.routeChild"
        private const val ROOT_NAVIGATION_TOKEN = "__st_root_launch"
        private const val IMAGE_SAVE_PERMISSION_REQUEST = 20891

        /** Archive-byte completion is consumed by the native launch overlay only. */
        internal fun shouldForwardPackageEventToFlutter(name: String): Boolean = name != "mini_download_completed"

        @Volatile private var active: StminiContainerActivity? = null
        private val miniPages = mutableMapOf<String, MutableSet<StminiContainerActivity>>()
        /** A session is one root plus the package-owned pages it pushed. */
        private val sessionPages = mutableMapOf<String, MutableSet<StminiContainerActivity>>()
        private val snapshotContainers = mutableSetOf<WeakReference<StminiContainerActivity>>()
        init {
            MiniLaunchSnapshotStore.activeSnapshotReleaseObserver = ::releaseActiveLaunchSnapshots
        }
        /** Flutter's close method always owns the entire Mini session. */
        fun closeActive() { active?.closeMiniSessionOrFinish() }
        /** Test-visible receipt after a retained renderer loses its old Activity bridge. */
        @Volatile internal var retainedBridgeRemovalObserver: ((WebView) -> Unit)? = null
        /** Capture only a short-lived visible host surface for the next Mini launch. */
        fun rememberLaunchingHostSnapshot(host: Activity, miniId: String) =
            MiniLaunchSnapshotStore.remember(host, miniId)
        /**
         * Home Mini roots belong to the embedding application's task; ordinary
         * Mini roots retain the existing independent document-task behaviour.
         */
        internal fun rootLaunchIntent(
            context: Context,
            link: MiniLink,
            operationId: String?,
            isHome: Boolean
        ): Intent = Intent(
            context,
            if (isHome) StminiHomeActivity::class.java else StminiContainerActivity::class.java
        ).apply {
            if (isHome) {
                // Reopening Home must reveal the existing root rather than
                // stacking copies above the host Flutter activity.
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            } else {
                data = rootTaskIntentData(link.miniId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
            }
            putExtra(EXTRA_MINI_LINK, link.rawLink)
            operationId?.let { putExtra(EXTRA_OPERATION_ID, it) }
        }
        /** A stable document identity lets Android resume this Mini's existing task. */
        internal fun rootTaskIntentData(miniId: String): android.net.Uri = android.net.Uri.Builder()
            .scheme("stmini-flutter-runtime")
            .authority("root")
            .appendPath(miniId.trim().lowercase())
            .build()
        fun notifyMiniRootsLifecycle(name: String, payload: Map<String, Any?> = emptyMap()) {
            val targets = synchronized(miniPages) {
                miniPages.values.flatten().filter { it.isRootMini }.toList()
            }
            targets.forEach { it.notifyHostApplicationLifecycle(name, payload) }
            StminiRuntimePool.notifyHiddenRuntimes(name, payload)
        }
        fun notifyMiniSessionChanged(miniId: String, source: StminiContainerActivity, reason: String): Int {
            // A Mini id can be opened in more than one navigation session.
            // Session state must never cross those stacks: iOS limits this to
            // the source navigation controller, so use the Android runtime
            // session rather than every page registered under the Mini id.
            val targets = synchronized(sessionPages) {
                sessionPages[source.runtimeSessionId]?.filter { it !== source }?.toList() ?: emptyList()
            }
            StminiDebugLog.webRouter("session_changed_broadcast", mapOf(
                "miniId" to miniId,
                "reason" to reason,
                "targetCount" to targets.size
            ))
            targets.forEach { target ->
                // An online Mini `/web` page has its own browser storage. Keep
                // the iOS contract: an explicitly allow-listed origin receives
                // selected shared-session values, then reloads from that new
                // snapshot. Local Mini documents keep their own storage and
                // only receive the credential-free event below.
                target.mirrorSessionToLegacyWebStorageIfAllowed(reason)
                target.sendHostMessage("miniSessionChanged", mapOf("reason" to reason))
            }
            // Online `/web` pages no longer subclass this Activity. They are
            // still members of the same Mini session through the shared-owner
            // registry and receive the identical session signal.
            return targets.size + OnlineWebSessionRegistry.notifySessionChanged(source.runtimeSessionId, reason)
        }
        private fun rootForMini(miniId: String): StminiContainerActivity? = synchronized(miniPages) {
            miniPages[miniId]?.firstOrNull { it.isRootMini }
        }
        private fun rootForSession(sessionId: String): StminiContainerActivity? = synchronized(sessionPages) {
            sessionPages[sessionId]?.firstOrNull { it.isRootMini }
        }
        private fun pagesForSession(sessionId: String): List<StminiContainerActivity> = synchronized(sessionPages) {
            sessionPages[sessionId]?.toList().orEmpty()
        }
        private fun releaseActiveLaunchSnapshots() {
            val targets = synchronized(snapshotContainers) {
                snapshotContainers.mapNotNull { it.get() }.also {
                    snapshotContainers.removeAll { reference -> reference.get() == null }
                }
            }
            targets.forEach { activity -> activity.runOnUiThread(activity::releaseLaunchSnapshot) }
        }
    }

    private lateinit var webView: WebView
    private lateinit var webContent: FrameLayout
    private lateinit var bridge: StminiWebBridge
    /** Shared ordinary HTTPS Web core; Mini runtime state deliberately stays here. */
    private lateinit var onlineWebCore: OnlineWebCore
    private lateinit var launchOverlay: MiniLaunchOverlay
    private lateinit var launchSnapshot: ImageView
    private lateinit var navigationBar: FrameLayout
    private lateinit var navigationTitle: TextView
    private val store by lazy { MiniPackageStore(applicationContext) }
    private var miniId: String? = null
    private var firstContentReady = false
    private var isRootMini = false
    private var operationId: String? = null
    private var runtimeSessionId: String = ""
    private var isExternalMiniWebPage = false
    /** Last verified local document for a package-owned pushed child. */
    private var trustedChildUrl: String? = null
    private var secureBridgeInstalled = false
    /** Present only for host Web and Mini-owned `/web`, never local Mini documents. */
    private var onlineWebBridgeGate: OnlineWebCore.ExactMainFrameOriginGate? = null
    /** The only URL allowed to complete the root Mini launch presentation. */
    private var expectedRootDocumentUrl: String? = null
    /** Reject package callbacks that belong to an earlier open/update attempt. */
    private var launchGeneration = 0L
    private var rootNavigationGeneration = 0L
    private var rootIsHome = false
    private var rendererRecoveryInProgress = false
    private var retainedRuntime = false
    /**
     * A sibling login page can update this `/web` page while Android has
     * stopped it below the top Activity.  Reloading in that state starts a
     * navigation which some WebView providers promptly abort; defer it until
     * this exact page is visible again.
     */
    private var pendingLegacySessionReload = false
    /**
     * The first session event is sent while the old external document is
     * covered by the local login page.  Preserve it so the replacement
     * document receives the same signal after its reload commits.
     */
    private var pendingLegacySessionReason: String? = null
    private var pendingPageWillAppearAfterSessionReload = false
    /** True only while an exact-origin OnlineWebActivity delegate is dispatching. */
    private var onlineWebDelegateDispatchDepth = 0
    private var pageVisible = false
    /** A local route opened from an owned online `/web` page. */
    private var isMiniRouteChild = false
    private var launchSnapshotBitmap: android.graphics.Bitmap? = null
    private var launchSnapshotReleaseRunnable: Runnable? = null
    private var popupDialog: Dialog? = null
    private var popupWebView: WebView? = null
    private val networkHandler = Handler(Looper.getMainLooper())
    private var networkRetryCount = 0
    private var networkRetryRunnable: Runnable? = null
    private var waitingForNetworkRecovery = false
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private data class PendingImageSave(
        val bytes: ByteArray,
        val mimeType: String,
        val completed: (Boolean, String?) -> Unit,
        val documentGeneration: Long,
        val documentUrl: String?
    )
    private var pendingImageSave: PendingImageSave? = null
    private var boundPackageVersion: String? = null
    private var boundPackageEntry: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        active = this
        operationId = intent.getStringExtra(EXTRA_OPERATION_ID)
        runtimeSessionId = intent.getStringExtra(EXTRA_RUNTIME_SESSION_ID) ?: UUID.randomUUID().toString()
        miniId = intent.getStringExtra(EXTRA_PARENT_MINI_ID)
        miniId?.let {
            registerMiniPage(it)
            registerSessionPage()
        }
        val initialWebUrl = intent.getStringExtra(EXTRA_WEB_URL)
        isExternalMiniWebPage = miniId != null && initialWebUrl != null &&
            store.resolveLocalPage(miniId!!, initialWebUrl) == null
        isMiniRouteChild = intent.getBooleanExtra(EXTRA_ROUTE_CHILD, false) &&
            miniId != null && !isExternalMiniWebPage && initialWebUrl != null &&
            store.resolveLocalPage(miniId!!, initialWebUrl) != null
        if (miniId != null && !isExternalMiniWebPage && initialWebUrl != null) {
            // The Intent was already checked against the installed package.
            // Keep this value even before a WebView provider exposes getUrl().
            trustedChildUrl = initialWebUrl
        }
        renderContainer()
        val restoredChild = intent.getIntExtra(EXTRA_RESTORED_CHILD_INDEX, -1).takeIf { it >= 0 }?.let {
            StminiRuntimePool.takeRestoredChild(runtimeSessionId, it)
        }
        if (restoredChild != null) {
            // A child snapshot comes only from the root that just claimed the
            // version-bound runtime session. Revalidate it before restoring
            // its bridge in this fresh container.
            replaceWebView(restoredChild.webView)
            navigationBar.visibility = if (restoredChild.showNavigation) View.VISIBLE else View.GONE
            navigationTitle.text = restoredChild.title.orEmpty()
            if (miniId == null || store.resolveLocalPage(miniId!!, restoredChild.url) == null ||
                !installTrustedMessageBridge(miniId!!)) {
                // `takeRestoredChild` has already removed this child from the
                // pool and this Activity's onDestroy owns it. Tear down any
                // still-staged siblings rather than retaining old renderers
                // after a failed restore.
                StminiRuntimePool.discardStagedChildren(runtimeSessionId)
                finish()
                return
            }
            trustedChildUrl = restoredChild.url
            webView.onResume()
            return
        }
        // A child that renders a verified package page needs the Mini bridge
        // before it is loaded. An online `/web` child follows native STMini:
        // its ordinary bridge is limited to its exact HTTPS origin and it
        // inherits the verified root Mini identity for this session.
        if (miniId != null && !isExternalMiniWebPage && !installTrustedMessageBridge(miniId!!)) return
        if (isExternalMiniWebPage && !installMiniExternalWebMessageBridge(initialWebUrl)) return
        if (miniId == null && initialWebUrl != null && !installConfiguredWebMessageBridge(initialWebUrl)) return
        val miniLink = intent.getStringExtra(EXTRA_MINI_LINK)
        if (miniLink != null) openMini(miniLink) else openWeb(initialWebUrl)
    }

    /**
     * `documentLaunchMode=intoExisting` routes another open of this Mini to
     * the retained root. Preserve its WebView when possible, but transfer the
     * new operation id so Flutter can correlate the reused opening correctly.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = intent.getStringExtra(EXTRA_MINI_LINK)?.let(MiniLink::parse) ?: return
        if (!isRootMini || link.miniId != miniId) return
        intent.getStringExtra(EXTRA_OPERATION_ID)?.takeIf { it.isNotBlank() }?.let { operationId = it }
        val installed = store.installed(link.miniId)
        if (installed == null || !store.canRunInstalled(installed, link)) {
            openMini(link.rawLink)
            return
        }
        updateCompatiblePackageInBackground(installed, link)
        if (!link.path.isNullOrBlank()) {
            loadInstalled(installed, link.path, link.displayName, link.displayNameEn, link.iconUrl)
            return
        }
        if (firstContentReady) {
            StminiRuntimeEvents.emit("mini_first_content_ready", eventPayload(mapOf(
                "miniId" to link.miniId,
                "reused" to true
            )))
        }
        StminiDebugLog.webRouter("document_reused", mapOf(
            "miniId" to link.miniId,
            "documentReady" to firstContentReady
        ))
    }

    override fun onDestroy() {
        logTaskLifecycle("container_destroy")
        stopNetworkRecovery()
        popupDialog?.dismiss()
        popupDialog = null
        popupWebView?.destroy()
        popupWebView = null
        pendingImageSave?.completed?.invoke(false, "页面已关闭")
        pendingImageSave = null
        if (active === this) active = null
        miniId?.let(::unregisterMiniPage)
        unregisterSessionPage()
        if (isRootMini && isFinishing) {
            StminiRuntimeEvents.emit("mini_closed", eventPayload(mapOf("miniId" to miniId)))
        }
        if (!retainedRuntime) {
            webView.removeAllViews(); webView.destroy()
        }
        releaseLaunchSnapshot()
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        // A Mini internal /web child temporarily becomes active. When it
        // closes, the resumed root must reclaim the close/lifecycle target.
        active = this
        pageVisible = true
        if (reloadPendingLegacySessionIfNeeded()) {
            // A WebView reload tears down the current JavaScript context. Do
            // not send this lifecycle event into that old context; it will be
            // re-delivered after the new online document becomes visible.
            pendingPageWillAppearAfterSessionReload = true
            return
        }
        // Match the iOS STMini and ordinary Android Web-container contract:
        // every visible WebView gets a page-level resume notification. This
        // is deliberately separate from appShow, which only means the host
        // process returned from background.
        onlineWebCore.pageVisibilityMessage("pageWillAppear")
    }

    override fun onStop() {
        logTaskLifecycle("container_stop")
        super.onStop()
    }

    override fun onPause() {
        pageVisible = false
        super.onPause()
        // A child activity covering this WebView, system navigation, or the
        // host going to background all make this page no longer visible.
        // H5 may use this to suspend page-scoped work; appHide is still sent
        // separately for whole-application background handling.
        onlineWebCore.pageVisibilityMessage("pageWillDisAppear")
    }

    override fun closeStminiPage(count: Int?) {
        when {
            count == null -> if (isRootMini) closeMiniSessionOrFinish() else finish()
            miniId == null -> finish()
            count == 0 -> rootForSession(runtimeSessionId)?.popOwnedChildrenToRoot() ?: finish()
            else -> popOwnedPages(count)
        }
    }
    /** Kept for existing Android callers/tests that used the no-argument API. */
    fun closeStminiPage() = closeStminiPage(null)
    override fun setStminiLoading(visible: Boolean, message: String) {
        // A package route pushed from `/web` (for example login) is not a
        // Mini launch. Its own H5 UI owns loading feedback; never put the
        // native Mini startup overlay between the online page and this route.
        if (isMiniRouteChild) return
        if (visible) {
            launchOverlay.showProcessing()
        }
        else {
            // WebView may defer or omit `onPageCommitVisible` while the App is
            // backgrounded during a cold Mini launch. H5 emits hideLoading only
            // after its own two-frame first-content gate; accept it as a second
            // completion path, but still require this exact local root document.
            if (isRootMini && !firstContentReady) {
                completeRootMiniFirstContent(webView.url?.toString().orEmpty(), "h5_first_frame")
            }
            // A Mini page may request `hideLoading` after it starts its own work,
            // but that must never dismiss the native initial launch screen before
            // its first verified local document is actually visible.
            else if (!isRootMini || firstContentReady) launchOverlay.finishFirstDocument()
        }
    }
    @Suppress("DEPRECATION")
    override fun stminiStatusBarHeight(): Int = window.decorView.rootWindowInsets?.systemWindowInsetTop ?: 0
    override fun stminiLanguage(): String = StminiHostConfiguration.normalizedLanguage(this)
    override fun setStminiLanguage(language: String): String? = StminiHostConfiguration.setLanguage(this, language)
    override fun setStminiStatusBarTextColor(isDark: Boolean) {
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.decorView.systemUiVisibility = if (isDark) View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR else 0
        }
    }
    override fun showStminiMore() {
        if (isFinishing || isDestroyed) return
        AlertDialog.Builder(this)
            .setItems(arrayOf(if (stminiLanguage().startsWith("zh")) "关闭" else "Close")) { _, _ -> closeStminiPage() }
            .show()
    }
    override fun openStminiInternalWeb(url: String, title: String?, showNavigation: Boolean): Boolean {
        val owner = miniId ?: return false
        StminiDebugLog.webRouter("mini_web_intent", mapOf(
            "miniId" to owner,
            "url" to StminiDebugLog.redactedUrl(url),
            "navigationVisible" to showNavigation,
            "session" to runtimeSessionId.take(8)
        ))
        // `/web` uses the same Web-only display owner as Flutter `openWeb`.
        // Mini-only routes and generic Mini APIs stay behind a narrow session
        // delegate; OnlineWebActivity itself imports no Mini runtime class.
        val delegateKey = OnlineWebSessionRegistry.register(runtimeSessionId, onlineWebSessionDelegate())
        startActivity(OnlineWebActivity.intent(
            context = this,
            url = url,
            title = title,
            showNavigation = showNavigation,
            allowInsecureHttpNavigation = StminiHostConfiguration.allowInsecureHttpNavigation,
            sessionDelegate = delegateKey
        ))
        return true
    }

    private fun onlineWebSessionDelegate() = object : OnlineWebSessionDelegate {
        override fun handleMessage(
            raw: String,
            origin: String,
            webView: WebView,
            closePage: () -> Unit
        ): Boolean {
            val request = runCatching { org.json.JSONObject(raw) }.getOrNull() ?: return false
            // A Mini-pushed `/web` header/close leaves only this online child;
            // it must not dismiss the verified root Mini session underneath.
            if (request.optString("method") == "close") {
                closeOnlineWebPage(closeCount(request.optJSONObject("params")), closePage)
                return true
            }
            onlineWebDelegateDispatchDepth += 1
            try {
                StminiWebBridge(this@StminiContainerActivity, webView)
                    .postMessage(raw, allowsSensitiveHostBridge = true, onlineWebOrigin = origin)
            } finally {
                onlineWebDelegateDispatchDepth -= 1
            }
            return true
        }

        override fun leavePage(closePage: () -> Unit) = closePage()

        override fun sessionChanged(owner: OnlineWebActivity, webView: WebView, reason: String) {
            mirrorSessionToSharedOnlineWebIfAllowed(owner, webView, reason)
        }
    }

    private fun closeOnlineWebPage(count: Int?, closeCurrentPage: () -> Unit) {
        when (count) {
            null -> closeCurrentPage()
            0 -> {
                OnlineWebSessionRegistry.closeSession(runtimeSessionId)
                rootForSession(runtimeSessionId)?.popOwnedChildrenToRoot()
            }
            else -> OnlineWebSessionRegistry.closeCount(runtimeSessionId, count)
        }
    }

    private fun closeCount(params: org.json.JSONObject?): Int? {
        if (params == null || !params.has("count") || params.isNull("count")) return null
        return when (val raw = params.opt("count")) {
            is Number -> raw.toInt().takeIf { raw.toDouble() == it.toDouble() && it >= 0 }
            is String -> raw.trim().toIntOrNull()?.takeIf { it >= 0 }
            else -> null
        }
    }

    /**
     * User-authorized legacy session handoff for a declared, exact origin.
     * This copies only the host's explicit key allow-list into that same
     * origin's WebView localStorage. The shared owner reloads only after the
     * script succeeds and emits lifecycle messages from the new document.
     */
    private fun mirrorSessionToSharedOnlineWebIfAllowed(
        owner: OnlineWebActivity,
        targetWebView: WebView,
        sessionReason: String
    ) {
        val origin = WebOrigin.originOfHttpsUrl(targetWebView.url?.toString()) ?: run {
            owner.deliverSessionChangedWithoutReload(sessionReason)
            return
        }
        val policy = StminiHostConfiguration.bridgeContext["legacyWebStorageMirror"] as? Map<*, *> ?: run {
            owner.deliverSessionChangedWithoutReload(sessionReason)
            return
        }
        val keys = (policy["keys"] as? List<*>)
            ?.mapNotNull { (it as? String)?.trim()?.takeIf { key -> key.isNotEmpty() && key.length <= 128 } }
            ?.distinct()?.take(64).orEmpty()
            .filter { StminiHostConfiguration.allowsLegacyStorageMirror(origin, it) }
        if (keys.isEmpty()) {
            owner.deliverSessionChangedWithoutReload(sessionReason)
            return
        }
        val storageKey = ((policy["storageKey"] as? String)
            ?: (StminiHostConfiguration.bridgeContext["authStorageKey"] as? String))
            ?.trim()?.takeIf { it.isNotEmpty() && it.length <= 256 } ?: run {
            owner.deliverSessionChangedWithoutReload(sessionReason)
            return
        }
        val preferences = applicationContext.getSharedPreferences("stmini_flutter_storage", Context.MODE_PRIVATE)
        val authSnapshot = preferences.getString(storageKey, null)
            ?.let { raw -> runCatching { org.json.JSONObject(raw) }.getOrNull() } ?: run {
            owner.deliverSessionChangedWithoutReload(sessionReason)
            return
        }
        val values = org.json.JSONObject()
        keys.forEach { key ->
            values.put(key, if (authSnapshot.has(key) && !authSnapshot.isNull(key)) authSnapshot.opt(key) else org.json.JSONObject.NULL)
        }
        val cacheStorageKey = (policy["cacheStorageKey"] as? String)
            ?.trim()?.takeIf { it.isNotEmpty() && it.length <= 256 }
        val cacheSnapshot = cacheStorageKey?.let { key ->
            preferences.getString(key, null)?.let { raw -> runCatching { org.json.JSONObject(raw) }.getOrNull() }
        }
        val cacheKeys = (policy["cacheKeys"] as? List<*>)
            ?.mapNotNull { (it as? String)?.trim()?.takeIf { key -> key.isNotEmpty() && key.length <= 128 } }
            ?.distinct()?.take(64).orEmpty()
            .takeIf { StminiHostConfiguration.allowsLegacyStorageMirrorOrigin(origin) }.orEmpty()
        cacheSnapshot?.let { snapshot ->
            cacheKeys.forEach { key ->
                values.put(key, if (snapshot.has(key) && !snapshot.isNull(key)) snapshot.opt(key) else org.json.JSONObject.NULL)
            }
        }
        val script = """
            (() => {
              try {
                const values = ${values.toString().replace("</", "<\\/")};
                Object.keys(values).forEach((key) => {
                  const value = values[key];
                  if (value === null || value === undefined || value === '') window.localStorage.removeItem(key);
                  else window.localStorage.setItem(key, String(value));
                });
                return true;
              } catch (_) { return false; }
            })();
        """.trimIndent()
        owner.applySessionStorageMirror(
            script = script,
            reason = sessionReason,
            reloadOnChange = policy["reloadOnChange"] as? Boolean ?: true
        )
    }
    override fun openStminiInternalMini(link: MiniLink): Boolean {
        // A Mini-pushed HTTPS `/web` page keeps the verified root Mini's
        // identity, like native STMini. A regular host `/web` has no miniId
        // and never reaches this method.
        val info = currentMiniPackage() ?: return false
        if (!isRootMini && (!isExternalMiniWebPage || rootForSession(runtimeSessionId)?.miniId != info.miniId)) return false
        rememberLaunchingHostSnapshot(this, link.miniId)
        startActivity(rootLaunchIntent(
            context = this,
            link = link,
            operationId = operationId,
            isHome = store.installed(link.miniId)?.isHome == true
        ))
        return true
    }

    private fun logTaskLifecycle(event: String) {
        StminiDebugLog.webRouter(event, mapOf(
            "miniId" to miniId,
            "taskId" to taskId,
            "isTaskRoot" to isTaskRoot,
            "isFinishing" to isFinishing,
            "isChangingConfigurations" to isChangingConfigurations,
            "rootMini" to isRootMini,
            "documentReady" to firstContentReady,
            "retainedRuntime" to retainedRuntime
        ))
    }
    override fun currentMiniPackage(): MiniPackageStore.InstalledPackage? = miniId?.let(store::installed)?.takeIf {
        (boundPackageVersion == null || it.version == boundPackageVersion) && (boundPackageEntry == null || it.entry == boundPackageEntry)
    }
    override fun openStminiLocalPage(path: String, title: String?): Boolean {
        val info = currentMiniPackage() ?: return false
        val url = store.localPageUrl(info, path) ?: return false
        startActivity(Intent(this, StminiWebPageActivity::class.java).apply {
            putExtra(EXTRA_WEB_URL, url)
            putExtra(EXTRA_WEB_TITLE, title)
            putExtra(EXTRA_SHOW_NAVIGATION, true)
            putExtra(EXTRA_PARENT_MINI_ID, info.miniId)
            putExtra(EXTRA_RUNTIME_SESSION_ID, runtimeSessionId)
            operationId?.let { putExtra(EXTRA_OPERATION_ID, it) }
        })
        return true
    }
    override fun openStminiRouteChild(router: String, params: org.json.JSONObject): Boolean {
        // Match iOS `forwardMiniRouteOpenIfNeeded`: an online `/web` child
        // pushed by a verified Mini may open a package-owned route. The exact
        // WebMessage origin and the root-session match prevent an unrelated
        // host Web page from acquiring this path; ordinary host `/web` pages
        // never gain a Mini route capability.
        val info = currentMiniPackage() ?: return false
        // A root/local Mini must not gain this path merely because it shares
        // a package session. It is available only from the short-lived,
        // exact-origin OnlineWebActivity delegate currently dispatching.
        if ((!isExternalMiniWebPage && onlineWebDelegateDispatchDepth <= 0) ||
            rootForSession(runtimeSessionId)?.miniId != info.miniId) return false
        val routeParams = runCatching { org.json.JSONObject(params.toString()) }.getOrNull() ?: return false
        routeParams.remove("methodId")
        if (router == "/login" || router == "/mine/login") routeParams.put("isBack", "1")
        val encoded = android.util.Base64.encodeToString(
            routeParams.toString().toByteArray(Charsets.UTF_8),
            android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP
        )
        val url = store.localPageUrl(
            info,
            "${info.entry}#/?__mini_child=1&__mini_route_child=1&__mini_open_route=$encoded"
        ) ?: return false
        // Route children intentionally start as ordinary local H5 pages.
        // Do not capture the presenting `/web` page or show a Mini launch
        // screen here: iOS pushes this same child directly, and retaining a
        // bitmap on Android makes an authentication detour look frozen.
        startActivity(Intent(this, StminiWebPageActivity::class.java).apply {
            putExtra(EXTRA_WEB_URL, url)
            putExtra(EXTRA_SHOW_NAVIGATION, false)
            putExtra(EXTRA_PARENT_MINI_ID, info.miniId)
            putExtra(EXTRA_RUNTIME_SESSION_ID, runtimeSessionId)
            putExtra(EXTRA_ROUTE_CHILD, true)
            operationId?.let { putExtra(EXTRA_OPERATION_ID, it) }
        })
        return true
    }
    override fun legacyStorageOrigin(): String? {
        return null
    }

    /**
     * Mirrors the iOS Mini login/logout hand-off for an owned online `/web`
     * child. This is deliberately opt-in: both the target HTTPS origin and
     * every key must be declared in `legacyWebStorageMirror` by the host.
     */
    private fun mirrorSessionToLegacyWebStorageIfAllowed(sessionReason: String) {
        if (!::webView.isInitialized || !isExternalMiniWebPage || isFinishing || isDestroyed) return
        val origin = WebOrigin.originOfHttpsUrl(webView.url?.toString()) ?: return
        val policy = StminiHostConfiguration.bridgeContext["legacyWebStorageMirror"] as? Map<*, *> ?: return
        val keys = (policy["keys"] as? List<*>)
            ?.mapNotNull { (it as? String)?.trim()?.takeIf { key -> key.isNotEmpty() && key.length <= 128 } }
            ?.distinct()
            ?.take(64)
            .orEmpty()
            .filter { StminiHostConfiguration.allowsLegacyStorageMirror(origin, it) }
        if (keys.isEmpty()) return

        val storageKey = ((policy["storageKey"] as? String)
            ?: (StminiHostConfiguration.bridgeContext["authStorageKey"] as? String))
            ?.trim()
            ?.takeIf { it.isNotEmpty() && it.length <= 256 }
            ?: return
        val preferences = applicationContext.getSharedPreferences("stmini_flutter_storage", Context.MODE_PRIVATE)
        val authSnapshot = preferences.getString(storageKey, null)
            ?.let { raw -> runCatching { org.json.JSONObject(raw) }.getOrNull() }
            ?: return
        val values = org.json.JSONObject()
        keys.forEach { key ->
            values.put(key, if (authSnapshot.has(key) && !authSnapshot.isNull(key)) authSnapshot.opt(key) else org.json.JSONObject.NULL)
        }

        // Remote PWAs can restore a small, explicit cache before their
        // page-appearance hook runs. Keep the optional cache selection under
        // the same origin/key allow-list as the authentication snapshot.
        val cacheStorageKey = (policy["cacheStorageKey"] as? String)
            ?.trim()
            ?.takeIf { it.isNotEmpty() && it.length <= 256 }
        val cacheSnapshot = cacheStorageKey?.let { key ->
            preferences.getString(key, null)?.let { raw -> runCatching { org.json.JSONObject(raw) }.getOrNull() }
        }
        val cacheKeys = (policy["cacheKeys"] as? List<*>)
            ?.mapNotNull { (it as? String)?.trim()?.takeIf { key -> key.isNotEmpty() && key.length <= 128 } }
            ?.distinct()
            ?.take(64)
            .orEmpty()
            .takeIf { StminiHostConfiguration.allowsLegacyStorageMirrorOrigin(origin) }
            .orEmpty()
        if (cacheSnapshot != null) {
            cacheKeys.forEach { key ->
                values.put(key, if (cacheSnapshot.has(key) && !cacheSnapshot.isNull(key)) cacheSnapshot.opt(key) else org.json.JSONObject.NULL)
            }
        }

        val reloadOnChange = policy["reloadOnChange"] as? Boolean ?: true
        val script = """
            (() => {
              try {
                const values = ${values.toString().replace("</", "<\\/")};
                Object.keys(values).forEach((key) => {
                  const value = values[key];
                  if (value === null || value === undefined || value === '') window.localStorage.removeItem(key);
                  else window.localStorage.setItem(key, String(value));
                });
                return true;
              } catch (_) {
                return false;
              }
            })();
        """.trimIndent()
        webView.post {
            if (isFinishing || isDestroyed || !isExternalMiniWebPage) return@post
            webView.evaluateJavascript(script) { completed ->
                if (completed != "true") {
                    StminiDebugLog.webRouter("session_mirror_failed", mapOf("origin" to origin))
                    return@evaluateJavascript
                }
                StminiDebugLog.webRouter("session_mirror_applied", mapOf(
                    "origin" to origin,
                    "keyCount" to values.length(),
                    "reload" to reloadOnChange
                ))
                if (reloadOnChange && !isFinishing && !isDestroyed) {
                    // The immediate message below may land in an old document
                    // that is about to be reloaded. Only queue a replacement
                    // notification after this target really accepted the
                    // mirrored storage and will navigate.
                    pendingLegacySessionReason = sessionReason
                    pendingPageWillAppearAfterSessionReload = true
                    if (pageVisible) {
                        webView.reload()
                    } else {
                        pendingLegacySessionReload = true
                        StminiDebugLog.webRouter("session_mirror_reload_deferred", mapOf(
                            "origin" to origin
                        ))
                    }
                }
            }
        }
    }

    /** Reload a mirrored online page only after it has returned above its login child. */
    private fun reloadPendingLegacySessionIfNeeded(): Boolean {
        if (!pendingLegacySessionReload || !isExternalMiniWebPage || isFinishing || isDestroyed) return false
        pendingLegacySessionReload = false
        StminiDebugLog.webRouter("session_mirror_reload_on_resume", mapOf(
            "origin" to WebOrigin.originOfHttpsUrl(webView.url?.toString())
        ))
        webView.reload()
        return true
    }

    /**
     * `onPageCommitVisible` is the first point at which a reloaded WebView is
     * no longer its discarded pre-login document.  Wait briefly for the H5
     * bridge and retry a bounded number of times instead of losing the event
     * during entry-module parsing.
     */
    private fun deliverSessionReloadLifecycle(url: String) {
        if (!isExternalMiniWebPage || !pageVisible || isFinishing || isDestroyed) return
        val shouldDeliverAppear = pendingPageWillAppearAfterSessionReload
        val reason = pendingLegacySessionReason
        if (!shouldDeliverAppear && reason == null) return
        val expectedOrigin = WebOrigin.originOfHttpsUrl(url) ?: return
        pendingPageWillAppearAfterSessionReload = false
        pendingLegacySessionReason = null
        deliverHostMessagesWhenBridgeReady(
            expectedOrigin = expectedOrigin,
            messages = buildList {
                reason?.let { add("miniSessionChanged" to mapOf<String, Any?>("reason" to it)) }
                // `/web` is often an already-deployed, ordinary H5 page. It
                // may not know the Mini-specific event, but it does support
                // the long-standing host contract: re-read getUserInfo when
                // this signal arrives. iOS STWebH5Crl sends the same event.
                if (reason != null) add("updateUserInfo" to emptyMap<String, Any?>())
                if (shouldDeliverAppear) add("pageWillAppear" to emptyMap<String, Any?>())
            }
        )
    }

    private fun deliverHostMessagesWhenBridgeReady(
        expectedOrigin: String,
        messages: List<Pair<String, Map<String, Any?>>>,
        attempt: Int = 0
    ) {
        if (messages.isEmpty() || !pageVisible || isFinishing || isDestroyed ||
            WebOrigin.originOfHttpsUrl(webView.url?.toString()) != expectedOrigin) return
        val calls = org.json.JSONArray().apply {
            messages.forEach { (name, payload) ->
                put(org.json.JSONObject().apply {
                    put("method", name)
                    if (payload.isNotEmpty()) put("params", org.json.JSONObject(payload))
                })
            }
        }.toString().replace("</", "<\\/")
        webView.evaluateJavascript(
            """(() => { if (typeof window.CMSCallJsMessage !== 'function') return false; $calls.forEach((m) => window.CMSCallJsMessage(m)); return true; })();""",
        ) { completed ->
            if (completed == "true") {
                StminiDebugLog.webRouter("session_mirror_reload_lifecycle_delivered", mapOf(
                    "origin" to expectedOrigin,
                    "messageCount" to messages.size,
                    "attempt" to attempt
                ))
            } else if (attempt < 8 && pageVisible && !isFinishing && !isDestroyed) {
                networkHandler.postDelayed({
                    deliverHostMessagesWhenBridgeReady(expectedOrigin, messages, attempt + 1)
                }, 50L)
            } else {
                StminiDebugLog.webRouter("session_mirror_reload_lifecycle_not_ready", mapOf(
                    "origin" to expectedOrigin,
                    "messageCount" to messages.size,
                    "attempt" to attempt
                ))
            }
        }
    }

    override fun showStminiPopup(url: String, left: Int, right: Int, ratio: Float): Boolean {
        if (isFinishing || isDestroyed || popupDialog?.isShowing == true) return false
        val installed = currentMiniPackage()
        val localUrl = installed?.let { info ->
            store.resolveLocalPage(info.miniId, url, info.version, info.entry)?.let { url }
                ?: store.localPageUrl(info, url)
        }
        // A rejected reserved local URL is never an ordinary HTTPS target.
        if (isReservedMiniPopupUrl(url) && localUrl == null) return false
        val resolved = localUrl ?: url.takeIf { WebOrigin.originOfHttpsUrl(it) != null } ?: return false
        val localIdentity = installed?.takeIf { localUrl != null }
        val popupTarget = MiniPopupBridgePolicy.target(miniId, resolved) ?: return false
        // No JavascriptInterface fallback: without WebMessageListener the
        // verification popup cannot safely prove its origin or complete.
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) return false
        val popup = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW
            webViewClient = object : WebViewClient() {
                override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
                    BridgeDocumentLease.invalidate(view)
                }
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val target = request.url.toString()
                    if (isReservedMiniPopupUrl(target)) {
                        return localIdentity == null || store.resolveLocalPage(localIdentity.miniId, target, localIdentity.version, localIdentity.entry) == null
                    }
                    return WebOrigin.originOfHttpsUrl(target) == null
                }
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                    popupLocalResource(localIdentity, request)
            }
        }
        if (!installPopupVerificationBridge(popup, popupTarget, localIdentity)) {
            popup.destroy()
            return false
        }
        val maxMargin = (resources.displayMetrics.widthPixels / resources.displayMetrics.density).toInt().coerceAtLeast(120) - 120
        val safeLeft = left.coerceAtMost(maxMargin.coerceAtLeast(0))
        val safeRight = right.coerceAtMost((maxMargin - safeLeft).coerceAtLeast(0))
        val width = (resources.displayMetrics.widthPixels - ((safeLeft + safeRight) * resources.displayMetrics.density).toInt())
            .coerceAtLeast((120 * resources.displayMetrics.density).toInt())
        val height = (width / ratio.coerceIn(.2f, 3f)).toInt().coerceAtMost((resources.displayMetrics.heightPixels * .9f).toInt())
        popupDialog = Dialog(this).apply {
            setContentView(popup)
            window?.setLayout(width, height)
            setOnDismissListener {
                runCatching { WebViewCompat.removeWebMessageListener(popup, MiniPopupBridgePolicy.channelName) }
                BridgeDocumentLease.invalidate(popup)
                popup.destroy()
                if (popupWebView === popup) popupWebView = null
                if (popupDialog === this) popupDialog = null
            }
            show()
            window?.setLayout(width, height)
        }
        popupWebView = popup
        popup.loadUrl(resolved)
        return true
    }
    override fun completeStminiPopup(payload: org.json.JSONObject) {
        val safe = payload.toString().replace("</", "<\\/")
        popupWebView?.evaluateJavascript(
            "javascript:typeof window.CMSCallJsMessage==='function'&&window.CMSCallJsMessage({method:'codeVerifSucc',params:$safe})",
            null
        )
        // Matches iOS STWebPopView.complete: verification completes the
        // popup's own lifecycle, returning focus to the page that opened it.
        popupDialog?.dismiss()
    }

    private fun isReservedMiniPopupUrl(url: String): Boolean =
        android.net.Uri.parse(url).host.orEmpty().endsWith(".stmini.local", true)

    private fun popupLocalResource(identity: MiniPackageStore.InstalledPackage?, request: WebResourceRequest): WebResourceResponse? {
        if (!isReservedMiniPopupUrl(request.url.toString())) return null
        fun denied() = WebResourceResponse("text/plain", "utf-8", 403, "Rejected", emptyMap(), java.io.ByteArrayInputStream(ByteArray(0)))
        if (identity == null || request.method != "GET") return denied()
        val file = store.resolveLocalPage(identity.miniId, request.url.toString(), identity.version, identity.entry) ?: return denied()
        val mime = when (file.extension.lowercase()) {
            "html", "htm" -> "text/html"; "js" -> "application/javascript"; "css" -> "text/css"
            "json" -> "application/json"; "svg" -> "image/svg+xml"; "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"; "webp" -> "image/webp"; else -> "application/octet-stream"
        }
        return runCatching { WebResourceResponse(mime, "utf-8", FileInputStream(file)) }.getOrElse { denied() }
    }

    private fun queuePopupVerification(
        popup: WebView, target: MiniPopupBridgePolicy.Target, identity: MiniPackageStore.InstalledPackage?,
        raw: String, sourceOrigin: android.net.Uri, isMainFrame: Boolean
    ) {
        if (raw.toByteArray(Charsets.UTF_8).size > 65_536) return
        val request = runCatching { org.json.JSONObject(raw) }.getOrNull() ?: return
        if (!MiniPopupBridgePolicy.accepts(target, sourceOrigin, isMainFrame, request.optString("method"))) return
        val generation = BridgeDocumentLease.generation(popup)
        val document = popup.url ?: return
        fun currentDocument(): Boolean = BridgeDocumentLease.isCurrent(popup, generation, document) &&
            MiniPopupBridgePolicy.accepts(target, android.net.Uri.parse(document), true, request.optString("method")) &&
            (identity == null || store.resolveLocalPage(identity.miniId, document, identity.version, identity.entry) != null)
        if (!currentDocument()) return
        val params = request.optJSONObject("params") ?: org.json.JSONObject()
        popup.post {
            if (!isFinishing && !isDestroyed && popup === popupWebView && currentDocument()) completeStminiPopup(params)
        }
    }

    private fun installPopupVerificationBridge(popup: WebView, target: MiniPopupBridgePolicy.Target, identity: MiniPackageStore.InstalledPackage?): Boolean = runCatching {
        WebViewCompat.addWebMessageListener(
            popup,
            MiniPopupBridgePolicy.channelName,
            setOf(target.originRule),
            object : WebViewCompat.WebMessageListener {
                override fun onPostMessage(
                    view: WebView,
                    message: WebMessageCompat,
                    sourceOrigin: android.net.Uri,
                    isMainFrame: Boolean,
                    replyProxy: JavaScriptReplyProxy
                ) {
                    val raw = message.data ?: return
                    // Only native WebMessage metadata is authoritative. H5's
                    // payload origin/frame fields are deliberately ignored.
                    queuePopupVerification(popup, target, identity, raw, sourceOrigin, isMainFrame)
                }
            }
        )
        true
    }.getOrDefault(false)
    override fun shareStminiImage(bytes: ByteArray, mimeType: String): Boolean = runCatching {
        val extension = if (mimeType == "image/png") "png" else "jpg"
        val directory = File(cacheDir, "stmini-share").apply { mkdirs() }
        val image = File(directory, "share-${UUID.randomUUID()}.$extension")
        FileOutputStream(image).use { it.write(bytes) }
        val uri = FileProvider.getUriForFile(this, "$packageName.stmini_flutter.fileprovider", image)
        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, null))
        true
    }.getOrDefault(false)
    override fun saveStminiImage(bytes: ByteArray, mimeType: String, completed: (Boolean, String?) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            if (pendingImageSave != null) {
                completed(false, "图片保存请求进行中")
                return
            }
            pendingImageSave = PendingImageSave(bytes, mimeType, completed, BridgeDocumentLease.generation(webView), webView.url)
            requestPermissions(arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE), IMAGE_SAVE_PERMISSION_REQUEST)
            return
        }
        writeStminiImage(bytes, mimeType, completed)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != IMAGE_SAVE_PERMISSION_REQUEST) return
        val pending = pendingImageSave ?: return
        pendingImageSave = null
        if (isFinishing || isDestroyed || !BridgeDocumentLease.isCurrent(webView, pending.documentGeneration, pending.documentUrl) ||
            (miniId != null && currentMiniPackage() == null)) {
            pending.completed(false, "页面已失效")
        } else if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            pending.completed(false, "没有权限")
        } else {
            writeStminiImage(pending.bytes, pending.mimeType, pending.completed)
        }
    }
    private fun writeStminiImage(bytes: ByteArray, mimeType: String, completed: (Boolean, String?) -> Unit) {
        StminiMediaStoreWrite.write(object : StminiMediaStoreWrite.Sink {
            val extension = if (mimeType == "image/png") "png" else "jpg"
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "stmini-${System.currentTimeMillis()}.$extension")
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            override fun insert(): android.net.Uri? =
                contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            override fun write(uri: android.net.Uri, bytes: ByteArray) {
                contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: error("无法写入图片")
            }
            override fun publish(uri: android.net.Uri) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear(); values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                }
            }
            override fun delete(uri: android.net.Uri) { contentResolver.delete(uri, null, null) }
        }, bytes).onSuccess { completed(true, null) }.onFailure { completed(false, "保存出错") }
    }
    override fun notifyStminiSessionChanged(reason: String): Int {
        val id = miniId ?: return 0
        return notifyMiniSessionChanged(id, this, reason)
    }
    override fun continuousKeepAliveState(enabled: Boolean?): StminiWebBridge.ContinuousKeepAliveState? {
        // All Mini-owned pages in one navigation stack share the root package
        // identity, including HTTPS pages pushed through Mini `/web`.
        val info = currentMiniPackage() ?: return null
        return if (enabled == null) StminiRuntimePool.state(this, info.miniId)
        else StminiRuntimePool.setContinuousKeepAlive(this, info.miniId, enabled)
    }
    override fun canRequestSelfManagedUpdate(): Boolean = when (
        selfManagedUpdateRoute()
    ) {
        MiniSelfManagedUpdateAuthority.Route.root,
        MiniSelfManagedUpdateAuthority.Route.trustedChildDelegate -> true
        MiniSelfManagedUpdateAuthority.Route.reject -> false
    }
    override fun installStminiUpdate(
        downloadUrl: String,
        isForce: Boolean,
        completed: (Result<MiniPackageStore.InstalledPackage>) -> Unit
    ): Boolean {
        // A trusted internal child never performs package I/O or owns an
        // Overlay. It delegates to the matching root so operation events,
        // forced-update failure UI and retry/close all remain rooted there.
        if (!isRootMini) {
            val root = matchingRootForSelfManagedUpdate() ?: return false
            val accepted = root.installStminiUpdate(downloadUrl, isForce, completed)
            // Match iOS behaviour: a force update replaces the full runtime,
            // so retire the pushed child once its root accepted the request.
            if (accepted && isForce) finish()
            return accepted
        }
        val current = currentMiniPackage() ?: return false
        val presentRootUpdate = MiniRootUpdatePresentation.shouldBlockRoot(isRootMini, isForce)
        val launchToken = if (presentRootUpdate) beginRootMiniLaunch(
            current.miniId, current.miniName, current.miniNameEn, current.iconUrl, store.installedIconFile(current)
        ) else null
        // A non-forced update intentionally leaves an already-rendered root
        // visible, but its eventual result still cannot reload a newer Mini
        // open/update attempt in this same container.
        val updateGeneration = launchToken ?: launchGeneration
        store.installUpdateAsync(current, downloadUrl, isForce, { name, payload ->
            consumePackagePresentationEvent(name, payload, launchToken)
            // Archive completion is a native overlay transition, not a public
            // Flutter EventChannel event. The operation remains processing
            // while checksum/unpack/install/first document are pending.
            if (shouldForwardPackageEventToFlutter(name)) StminiRuntimeEvents.emit(name, eventPayload(payload))
        }) { result -> runOnUiThread {
            if (!isCurrentLaunch(updateGeneration)) {
                completed(result)
                return@runOnUiThread
            }
            result.onSuccess { updated ->
                emitActualPackageInstall(updated)
                val root = rootForMini(updated.miniId)
                when (MiniRootUpdatePresentation.applyTarget(
                    isForce = isForce,
                    hasActiveRoot = root != null,
                    activeRootIsCaller = root === this
                )) {
                    // A non-forced update is intentionally disk-only. Its
                    // package is selected on the next root cold launch, while
                    // the currently visible root keeps its current document
                    // and does not receive a new launch overlay.
                    MiniRootUpdatePresentation.ApplyTarget.none -> Unit
                    MiniRootUpdatePresentation.ApplyTarget.otherRoot -> {
                        root?.loadInstalled(updated, null)
                        finish()
                    }
                    MiniRootUpdatePresentation.ApplyTarget.caller -> loadInstalled(updated, null)
                }
            }.onFailure { error ->
                if (presentRootUpdate && launchToken != null && isCurrentLaunch(launchToken)) {
                    showRootUpdateFailure(downloadUrl, error)
                }
                StminiRuntimeEvents.emit("mini_update_failed", eventPayload(mapOf(
                    "miniId" to current.miniId,
                    "code" to if (error is SecurityException) "download_source_rejected" else "mini_update_failed",
                    "message" to (error.message ?: "小程序更新失败"),
                    "retryable" to (error !is SecurityException)
                )))
            }
            completed(result)
        } }
        return true
    }

    override fun onBackPressed() {
        goBackOrFinishCurrentPage()
    }

    /**
     * Mirrors native Android's `STMiniWebPageActivity.goBackOrFinish()` for a
     * pushed page.  A child Activity is a navigation level, not a request to
     * close the package-owned runtime session: after its WebView history is
     * exhausted it must reveal the root Mini that launched it.  The root
     * deliberately keeps its existing `ishome` and complete-session rules.
     */
    private fun goBackOrFinishCurrentPage() {
        if (onlineWebCore.goBackIfPossible()) return
        if (!isRootMini) {
            finish()
            return
        }
        if (rootIsHome) {
            // `ishome` only governs an installed root. Its in-document
            // history remains available, but Android system back must not
            // close it.
            return
        }
        closeMiniSessionOrFinish()
    }

    /**
     * The container affordance means "leave this pushed page", which is
     * deliberately different from Android system/gesture back for a trusted
     * `/web` child. OAuth and other external pages commonly retain redirect
     * history: consuming that history from the container button can bounce
     * straight back to the same page and make the button appear inert. iOS
     * `STWebH5Crl.back()` pops the native child in this case, so do the same
     * without touching the package-owned root/session.
     *
     * Local Mini children retain the normal WebView-history-first behaviour.
     */
    private fun onNavigationBackPressed() {
        if (isExternalMiniWebPage) {
            finish()
            return
        }
        goBackOrFinishCurrentPage()
    }

    private fun renderContainer() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
        }
        navigationBar = FrameLayout(this).apply {
            setBackgroundColor(Color.WHITE)
            elevation = dp(2).toFloat()
            visibility = View.GONE
        }
        navigationTitle = TextView(this).apply {
            gravity = Gravity.CENTER
            maxLines = 1
            textSize = 17f
            setTextColor(Color.rgb(24, 35, 58))
        }.also {
            navigationBar.addView(it, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))
        }
        ImageButton(this).apply {
            setImageResource(com.fsst.stmini_flutter.R.mipmap.stmini_icon_back)
            scaleType = ImageView.ScaleType.CENTER
            setPadding(dp(14), dp(14), dp(14), dp(14))
            background = null
            contentDescription = "返回"
            setOnClickListener { onNavigationBackPressed() }
        }.also {
            navigationBar.addView(it, FrameLayout.LayoutParams(
                dp(52),
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.START
            ))
        }
        root.addView(navigationBar, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)))
        webContent = FrameLayout(this)
        launchSnapshot = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            visibility = View.GONE
        }
        webView = WebView(this)
        launchOverlay = MiniLaunchOverlay(this).apply {
            visibility = View.GONE
            setHostLoadingImage(StminiHostConfiguration.loadingImage)
        }
        webContent.addView(launchSnapshot, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        webContent.addView(webView, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        webContent.addView(launchOverlay, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        root.addView(webContent, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)
        configureWebView()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + 0.5f).toInt()

    @SuppressLint("SetJavaScriptEnabled")
    private fun configureWebView() {
        onlineWebCore = OnlineWebCore(webView)
        onlineWebCore.configureWebView()
        onlineWebCore.onTitleChanged = { title ->
            if (navigationBar.visibility == View.VISIBLE) navigationTitle.text = title
        }
        bridge = StminiWebBridge(this, webView)
        webView.webChromeClient = object : WebChromeClient() {
            override fun onReceivedTitle(view: WebView, title: String?) {
                super.onReceivedTitle(view, title)
                onlineWebCore.receivedTitle(title)
            }
        }
        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
                BridgeDocumentLease.invalidate(view)
            }
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val url = request.url.toString()
                val id = miniId
                // Direct Flutter `openWeb` has no Mini bridge. HTTP requires
                // the host's explicit global opt-in; bridge authorization is
                // independently limited to exact configured origins.
                if (id == null) {
                    return OnlineWebCore.NavigationPolicy.blocks(
                        request, StminiHostConfiguration.allowInsecureHttpNavigation)
                }
                // A WebView JavaScript interface is visible to every frame.
                // Do not permit an untrusted iframe to inherit the enclosing
                // Mini's bridge. Mini pages may only navigate their own local
                // document in this WebView; external H5 must use `/web`.
                if (!request.isForMainFrame) return true
                // A deliberately-created `/web` child keeps Mini identity but
                // may complete host-authorized HTTP(S) redirects.
                if (isExternalMiniWebPage) return OnlineWebCore.NavigationPolicy.blocks(
                    request, StminiHostConfiguration.allowInsecureHttpNavigation)
                return store.resolveLocalPage(id, url) == null
            }

            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                val id = miniId ?: return null
                // Reserved local package hosts must never fall back to DNS or
                // networking when the identity/path no longer validates.
                if (!request.url.host.orEmpty().endsWith(".stmini.local", true)) return null
                val file = if (request.method == "GET") store.resolveLocalPage(id, request.url.toString(), boundPackageVersion, boundPackageEntry) else null
                if (file == null) return WebResourceResponse("text/plain", "utf-8", 403, "Rejected", emptyMap(), java.io.ByteArrayInputStream(ByteArray(0)))
                val mime = when (file.extension.lowercase()) {
                    "html", "htm" -> "text/html"; "js" -> "application/javascript"; "css" -> "text/css"
                    "json" -> "application/json"; "svg" -> "image/svg+xml"; "png" -> "image/png"
                    "jpg", "jpeg" -> "image/jpeg"; "webp" -> "image/webp"; else -> "application/octet-stream"
                }
                return WebResourceResponse(mime, "utf-8", FileInputStream(file))
            }

            override fun onPageCommitVisible(view: WebView, url: String) {
                super.onPageCommitVisible(view, url)
                stopNetworkRecovery()
                // An HTTPS redirect earns no inherited bridge access.  It is
                // made the one exact trusted origin only after it commits as
                // this WebView's main document.
                if (onlineWebBridgeGate != null) onlineWebCore.onTopLevelPageCommit(url)
                // Returning from a local login page reloads this online
                // document. Deliver the queued session/appearance messages
                // only into that replacement document, never its old DOM.
                deliverSessionReloadLifecycle(url)
                if (!isRootMini && !isExternalMiniWebPage && miniId?.let { store.resolveLocalPage(it, url) } != null) {
                    trustedChildUrl = url
                }
                // `onPageFinished` is too early and is also called for
                // redirects/children. The root launch presentation belongs to
                // one expected, verified local document only.
                completeRootMiniFirstContent(url, "page_commit")
            }

            override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                // Returning true is correct only after every reference to the
                // dead renderer has been retired. The recovery path below
                // recreates a Mini WebView exclusively from a verified local
                // package; arbitrary external `/web` pages never inherit it.
                onMiniRenderProcessGone(view)
                return true
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                super.onReceivedError(view, request, error)
                if (request.isForMainFrame && isRecoverableH5Navigation(request.url, error.errorCode)) {
                    scheduleNetworkRecovery("webview-${error.errorCode}")
                }
            }
        }
    }

    private fun isRecoverableH5Navigation(url: android.net.Uri, errorCode: Int): Boolean {
        if (isFinishing || isDestroyed || rendererRecoveryInProgress ||
            (!isExternalMiniWebPage && miniId != null) ||
            WebOrigin.originOfHttpsUrl(url.toString()) == null) return false
        return errorCode in setOf(
            WebViewClient.ERROR_TIMEOUT,
            WebViewClient.ERROR_HOST_LOOKUP,
            WebViewClient.ERROR_CONNECT,
            WebViewClient.ERROR_IO
        )
    }

    /** Android equivalent of iOS H5's 0.8/2/5s retry plus path recovery. */
    private fun scheduleNetworkRecovery(@Suppress("UNUSED_PARAMETER") reason: String) {
        if (networkRetryRunnable != null || isFinishing || isDestroyed) return
        waitingForNetworkRecovery = true
        startNetworkRecoveryMonitor()
        val delays = longArrayOf(800L, 2_000L, 5_000L)
        if (networkRetryCount >= delays.size) return
        val retry = Runnable {
            networkRetryRunnable = null
            if (!isFinishing && !isDestroyed && !rendererRecoveryInProgress &&
                (isExternalMiniWebPage || miniId == null) &&
                WebOrigin.originOfHttpsUrl(webView.url?.toString()) != null) webView.reload()
        }
        networkRetryRunnable = retry
        networkRetryCount += 1
        networkHandler.postDelayed(retry, delays[networkRetryCount - 1])
    }

    private fun startNetworkRecoveryMonitor() {
        if (networkCallback != null) return
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) return
                runOnUiThread {
                    if (!waitingForNetworkRecovery || isFinishing || isDestroyed || rendererRecoveryInProgress) return@runOnUiThread
                    networkRetryRunnable?.let(networkHandler::removeCallbacks)
                    networkRetryRunnable = null
                    networkRetryCount = 0
                    waitingForNetworkRecovery = false
                    webView.reload()
                }
            }
        }
        networkCallback = callback
        runCatching { manager.registerDefaultNetworkCallback(callback) }
            .onFailure { networkCallback = null }
    }

    private fun stopNetworkRecovery() {
        networkRetryRunnable?.let(networkHandler::removeCallbacks)
        networkRetryRunnable = null
        networkRetryCount = 0
        waitingForNetworkRecovery = false
        val callback = networkCallback ?: return
        networkCallback = null
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        runCatching { manager?.unregisterNetworkCallback(callback) }
    }

    private fun onMiniRenderProcessGone(deadWebView: WebView) {
        if (rendererRecoveryInProgress || isFinishing || isDestroyed) return
        rendererRecoveryInProgress = true
        stopNetworkRecovery()
        releaseLaunchSnapshot()
        val id = miniId
        val priorUrl = deadWebView.url
        id?.let { StminiRuntimePool.discard(it, deadWebView) }
        webContent.removeView(deadWebView)
        deadWebView.removeAllViews()
        deadWebView.destroy()
        val info = id?.let(store::installed)
        if (id == null || info == null || isExternalMiniWebPage) {
            fail("网页渲染进程已终止，请重新打开页面", "web_renderer_gone")
            return
        }
        webView = WebView(this)
        secureBridgeInstalled = false
        webContent.addView(
            webView,
            0,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        )
        configureWebView()
        if (!installTrustedMessageBridge(id)) return
        if (isRootMini) {
            loadInstalled(info, null)
        } else {
            // A package-owned child may recover only the same verified local
            // file. No external or cross-Mini URL is replayed after a crash.
            val localUrl = priorUrl?.takeIf { store.resolveLocalPage(id, it) != null }
            if (localUrl == null) fail("小程序页面恢复失败，请重新打开小程序", "mini_renderer_recovery_failed")
            else webView.loadUrl(localUrl)
        }
        rendererRecoveryInProgress = false
    }

    private fun openMini(rawLink: String) {
        val link = MiniLink.parse(rawLink) ?: return fail("Mini 链接无效")
        miniId = link.miniId
        isRootMini = true
        registerMiniPage(link.miniId)
        registerSessionPage()
        attachLaunchSnapshot(link.miniId)
        navigationBar.visibility = View.GONE
        val existing = store.installed(link.miniId)
        if (existing != null && store.canRunInstalled(existing, link)) {
            val retained = StminiRuntimePool.acquireSession(applicationContext, existing)
            if (retained != null) {
                replaceWebView(retained.rootWebView)
                rootIsHome = existing.isHome
                webView.onResume()
                if (!installTrustedMessageBridge(link.miniId)) {
                    StminiRuntimePool.discardDetachedChildren(retained.childPages)
                    return
                }
                firstContentReady = true
                launchOverlay.finishFirstDocument()
                webContent.post { finishLaunchSnapshotTransition() }
                restoreRetainedChildStack(retained.childPages)
                updateCompatiblePackageInBackground(existing, link)
                return
            }
        }
        if (!installTrustedMessageBridge(link.miniId)) return
        val launchToken = beginRootMiniLaunch(
            miniId = link.miniId,
            primaryName = link.displayName,
            englishName = link.displayNameEn,
            iconUrl = link.iconUrl,
            verifiedIcon = existing?.let(store::installedIconFile),
            installed = existing
        )
        if (existing != null && store.canRunInstalled(existing, link)) {
            loadInstalled(existing, link.path, link.displayName, link.displayNameEn, link.iconUrl)
            updateCompatiblePackageInBackground(existing, link)
            return
        }
        if (link.downloadUrl == null) return fail("本地没有可用 Mini 包")
        store.installAsync(link, { name, payload ->
            consumePackagePresentationEvent(name, payload, launchToken)
            if (shouldForwardPackageEventToFlutter(name)) StminiRuntimeEvents.emit(name, eventPayload(payload))
        }) { result -> runOnUiThread {
            if (!isCurrentLaunch(launchToken)) return@runOnUiThread
            result.onSuccess { info ->
                emitActualPackageInstall(info)
                loadInstalled(info, link.path, link.displayName, link.displayNameEn, link.iconUrl)
            }.onFailure { error -> fail(error.message ?: "小程序安装失败", if (error is SecurityException) "download_source_rejected" else "mini_install_failed") }
        } }
    }

    private fun emitActualPackageInstall(info: MiniPackageStore.InstalledPackage) {
        if (!info.installationChanged) return
        StminiRuntimeEvents.emit("mini_package_installed", eventPayload(mapOf("miniId" to info.miniId, "version" to info.version)))
        StminiRuntimeEvents.emit("installed_packages_changed", installedPackagesPayload(info))
    }

    /** Compatible roots remain visible: only the next cold launch adopts it. */
    private fun updateCompatiblePackageInBackground(info: MiniPackageStore.InstalledPackage, link: MiniLink) {
        if (!store.canRunInstalled(info, link) || !store.requiresUpdate(info, link) || link.downloadUrl == null) return
        val generation = launchGeneration
        store.installAsync(link, { name, payload ->
            if (shouldForwardPackageEventToFlutter(name)) StminiRuntimeEvents.emit(name, eventPayload(payload))
        }) { result -> runOnUiThread {
            if (!isCurrentLaunch(generation)) return@runOnUiThread
            result.onSuccess(::emitActualPackageInstall).onFailure { error ->
                StminiRuntimeEvents.emit("mini_update_failed", eventPayload(mapOf(
                    "miniId" to info.miniId, "code" to "mini_update_failed",
                    "message" to (error.message ?: "小程序更新失败"), "retryable" to (error !is SecurityException)
                )))
            }
        } }
    }

    private fun loadInstalled(
        info: MiniPackageStore.InstalledPackage,
        path: String?,
        primaryName: String? = null,
        englishName: String? = null,
        iconUrl: String? = null
    ) {
        if (isRootMini && info.isHome != (this is StminiHomeActivity) && handOffRootTask(link = intent.getStringExtra(EXTRA_MINI_LINK)?.let(MiniLink::parse), isHome = info.isHome)) {
            return
        }
        if (isRootMini) {
            rootIsHome = info.isHome
            firstContentReady = false
            expectedRootDocumentUrl = null
            launchOverlay.showProcessing()
            updateRootMiniIdentity(info, primaryName, englishName, iconUrl)
            // Cancel a prior document before declaring the next document as
            // the only candidate allowed to hide the new launch screen.
            webView.stopLoading()
        }
        boundPackageVersion = info.version
        boundPackageEntry = info.entry
        val url = store.entryUrl(info, path)
            ?: return fail("小程序本地页面无效", "mini_local_page_invalid")
        val rootDocumentUrl = if (isRootMini) bindRootDocumentNavigation(url) else url
        if (isRootMini) expectedRootDocumentUrl = rootDocumentUrl
        loadUrlPreservingLaunchSnapshot(rootDocumentUrl)
    }

    /**
     * A first install discovers `ishome` only after its manifest has been
     * verified. Move that root once into the correct Android task; the target
     * reloads the already-installed local package and no unverified link flag
     * can choose the Home container.
     */
    private fun handOffRootTask(link: MiniLink?, isHome: Boolean): Boolean {
        val target = link ?: return false
        rememberLaunchingHostSnapshot(this, target.miniId)
        val intent = rootLaunchIntent(this, target, operationId, isHome)
        if (isHome) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        finish()
        return true
    }

    /** Moves a verified retained Mini WebView into this fresh container. */
    private fun replaceWebView(retained: WebView) {
        if (::webView.isInitialized) {
            webContent.removeView(webView)
            webView.stopLoading()
            webView.removeAllViews()
            webView.destroy()
        }
        (retained.parent as? ViewGroup)?.removeView(retained)
        // A WebMessageListener closure is registered against the originating
        // Activity. Remove it before moving the WebView so this new container
        // can install a listener bound to its own bridge and no destroyed
        // Activity remains reachable through the retained renderer.
        runCatching { WebViewCompat.removeWebMessageListener(retained, "CMSScriptMessageChannel") }
        webView = retained
        if (launchSnapshotBitmap != null) webView.alpha = 0f
        secureBridgeInstalled = false
        webContent.addView(
            webView,
            0,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        )
        configureWebView()
    }

    /**
     * All close sources (Flutter, JS and system back without Web history) end
     * the same Mini session. Package-owned children are retained with their
     * root; external H5 children are finished and never enter the runtime
     * pool. This is the Flutter equivalent of native Android's complete task
     * restoration, without retaining host Activities or task identifiers.
     */
    private fun closeMiniSessionOrFinish() {
        val root = rootForSession(runtimeSessionId)
        if (root == null || !root.isRootMini) {
            finish()
            return
        }
        // Close all separate shared-owner `/web` Activities before the root
        // Mini session is retained/destroyed. This makes Flutter closeMini
        // equivalent to the former Activity-owned `/web` session close.
        OnlineWebSessionRegistry.closeSession(runtimeSessionId)
        root.closeOwnedSession()
    }

    /** Pop current Activity-backed Mini pages while preserving the root. */
    private fun popOwnedPages(count: Int) {
        val pages = pagesForSession(runtimeSessionId)
        val currentIndex = pages.indexOf(this)
        if (currentIndex <= 0 || count > currentIndex) {
            // Same as iOS: an out-of-range count closes the current page;
            // for a root that necessarily means closing its owned session.
            if (isRootMini) closeMiniSessionOrFinish() else finish()
            return
        }
        pages.subList(currentIndex - count + 1, currentIndex + 1).asReversed().forEach { it.finish() }
    }

    private fun popOwnedChildrenToRoot() {
        pagesForSession(runtimeSessionId).filter { it !== this }.asReversed().forEach { it.finish() }
    }

    private fun closeOwnedSession() {
        val info = currentMiniPackage()
        val pages = pagesForSession(runtimeSessionId)
        val retainableChildren = pages
            .filter { it !== this }
            .mapNotNull { it.retainedTrustedChildPage() }
        val canRetain = info != null && firstContentReady && !rendererRecoveryInProgress
        if (canRetain) {
            retainForRuntimeSession()
            retainableChildren.forEach { it.owner.retainForRuntimeSession() }
            retainedRuntime = StminiRuntimePool.retainSession(
                applicationContext,
                info!!,
                StminiRuntimePool.RetainedSession(
                    rootWebView = webView,
                    childPages = retainableChildren.map { it.page }
                )
            )
            if (!retainedRuntime) {
                // The pool rejected this session; normal destruction must own
                // every detached WebView instead of leaving an orphan alive.
                retainableChildren.forEach { it.owner.retainedRuntime = false }
            }
        }
        // Children are above the root in the Activity stack. Finish all of
        // them before the root so Android resumes the presenting Flutter host,
        // never an orphan page or the launcher.
        pages.filter { it !== this }.asReversed().forEach { it.finish() }
        finish()
    }

    private data class RetainableChild(
        val owner: StminiContainerActivity,
        val page: StminiRuntimePool.RetainedChildPage
    )

    private fun retainedTrustedChildPage(): RetainableChild? {
        if (isRootMini || isExternalMiniWebPage || rendererRecoveryInProgress || !secureBridgeInstalled) return null
        val id = miniId ?: return null
        val currentUrl = webView.url?.toString()
            ?.takeIf { store.resolveLocalPage(id, it) != null }
            ?: trustedChildUrl
            ?: return null
        if (store.resolveLocalPage(id, currentUrl) == null) return null
        return RetainableChild(
            owner = this,
            page = StminiRuntimePool.RetainedChildPage(
                webView = webView,
                url = currentUrl,
                title = intent.getStringExtra(EXTRA_WEB_TITLE),
                showNavigation = intent.getBooleanExtra(EXTRA_SHOW_NAVIGATION, true)
            )
        )
    }

    private fun retainForRuntimeSession() {
        webContent.removeView(webView)
        webView.onPause()
        // The listener captures this Activity through its bridge. It must be
        // removed before the Activity finishes, not only when a future
        // container happens to acquire the renderer from the pool.
        runCatching { WebViewCompat.removeWebMessageListener(webView, "CMSScriptMessageChannel") }
        secureBridgeInstalled = false
        retainedBridgeRemovalObserver?.invoke(webView)
        retainedRuntime = true
    }

    private fun restoreRetainedChildStack(children: List<StminiRuntimePool.RetainedChildPage>) {
        if (children.isEmpty()) return
        StminiRuntimePool.stageRestoredChildren(runtimeSessionId, children)
        runCatching {
            children.forEachIndexed { index, child ->
                startActivity(Intent(this, StminiWebPageActivity::class.java).apply {
                    putExtra(EXTRA_WEB_URL, child.url)
                    putExtra(EXTRA_WEB_TITLE, child.title)
                    putExtra(EXTRA_SHOW_NAVIGATION, child.showNavigation)
                    putExtra(EXTRA_PARENT_MINI_ID, miniId)
                    putExtra(EXTRA_RUNTIME_SESSION_ID, runtimeSessionId)
                    putExtra(EXTRA_RESTORED_CHILD_INDEX, index)
                    operationId?.let { putExtra(EXTRA_OPERATION_ID, it) }
                })
            }
        }.onFailure {
            StminiRuntimePool.discardStagedChildren(runtimeSessionId)
        }
    }

    private fun openWeb(url: String?) {
        if (url.isNullOrBlank()) return fail("网页地址无效")
        val showNavigation = intent.getBooleanExtra(EXTRA_SHOW_NAVIGATION, true)
        navigationBar.visibility = if (showNavigation) View.VISIBLE else View.GONE
        navigationTitle.text = intent.getStringExtra(EXTRA_WEB_TITLE) ?: ""
        StminiDebugLog.webRouter("web_load", mapOf(
            "miniId" to miniId,
            "pageType" to when {
                miniId == null -> "host_web"
                isExternalMiniWebPage -> "mini_web"
                else -> "mini_local"
            },
            "url" to StminiDebugLog.redactedUrl(url),
            "navigationRequested" to showNavigation,
            "navigationActual" to (navigationBar.visibility == View.VISIBLE),
            "titlePresent" to navigationTitle.text.isNotBlank()
        ))
        if (miniId != null && !isExternalMiniWebPage && store.resolveLocalPage(miniId!!, url) != null) {
            trustedChildUrl = url
        }
        loadUrlPreservingLaunchSnapshot(url)
        if (isMiniRouteChild) launchOverlay.finishFirstDocument()
    }

    /**
     * Some Android WebView providers reset a View's alpha as a navigation is
     * accepted. Reapply it after loading so a one-shot launch snapshot stays
     * above the new document until the verified first-content handoff.
     */
    private fun loadUrlPreservingLaunchSnapshot(url: String) {
        onlineWebCore.load(url)
        if (launchSnapshotBitmap != null) webView.alpha = 0f
    }

    /**
     * Bind the H5-compatible `CMSScriptMessageChannel.postMessage` object to
     * precisely one local Mini origin.  `WEB_MESSAGE_LISTENER` is a runtime
     * WebView capability, so merely compiling against AndroidX is not enough.
     * There is intentionally no `addJavascriptInterface` fallback: on an old
     * provider the safe behaviour is to leave the Mini closed.
     */
    private fun installTrustedMessageBridge(id: String): Boolean {
        return installMessageBridge(
            originRule = MiniBridgeOriginPolicy.originRule(id),
            accepts = { source, isMainFrame ->
                MiniBridgeOriginPolicy.accepts(source, id, isMainFrame)
            }
        )
    }

    /** A host `openWeb` uses the same top-level-document bridge contract as `/web`. */
    private fun installConfiguredWebMessageBridge(url: String?): Boolean {
        // Every allowed top-level online document may use the common Web
        // bridge. OnlineWebCore still rejects iframe and stale-document
        // messages, while HTTP remains an explicit host opt-in.
        return installOnlineWebMessageBridge(url, allowsSensitiveHostBridge = true)
    }

    /** A Mini-pushed `/web` is still ordinary HTTPS, never a Mini-origin bridge. */
    private fun installMiniExternalWebMessageBridge(url: String?): Boolean {
        return installOnlineWebMessageBridge(url, allowsSensitiveHostBridge = true)
    }

    /**
     * Shared Core bridge for both host `openWeb` and a Mini's `/web` child.
     * Its capability never depends on MiniPackageStore or the runtime pool.
     */
    private fun installOnlineWebMessageBridge(url: String?, allowsSensitiveHostBridge: Boolean): Boolean {
        if (secureBridgeInstalled) return true
        // Let `openWeb` retain its existing invalid-URL error instead of
        // turning a malformed input into a misleading bridge-capability one.
        if (OnlineWebOrigin.originOfBridgeUrl(
                url, StminiHostConfiguration.allowInsecureHttpNavigation
            ) == null) return true
        val gate = onlineWebCore.installExactOriginBridge(
            initialUrl = url,
            allowInsecureHttpBridge = StminiHostConfiguration.allowInsecureHttpNavigation,
            onMessage = { payload, origin ->
                bridge.postMessage(payload, allowsSensitiveHostBridge, onlineWebOrigin = origin)
            },
            onUnavailable = {
                fail("安全消息通道初始化失败，无法打开网页", "secure_message_bridge_unavailable")
            }
        ) ?: return false
        onlineWebBridgeGate = gate
        secureBridgeInstalled = true
        return true
    }

    private fun installMessageBridge(
        originRule: String,
        accepts: (android.net.Uri, Boolean) -> Boolean,
        allowsSensitiveHostBridge: (android.net.Uri) -> Boolean = { true }
    ): Boolean {
        if (secureBridgeInstalled) return true
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            fail("当前 WebView 不支持安全消息通道，无法打开小程序", "secure_message_bridge_unavailable")
            return false
        }
        return runCatching {
            WebViewCompat.addWebMessageListener(
                webView,
                "CMSScriptMessageChannel",
                setOf(originRule),
                object : WebViewCompat.WebMessageListener {
                    override fun onPostMessage(
                        view: WebView,
                        message: WebMessageCompat,
                        sourceOrigin: android.net.Uri,
                        isMainFrame: Boolean,
                        replyProxy: JavaScriptReplyProxy
                    ) {
                        // This path is only for an exact local Mini origin.
                        // The shared OnlineWebCore owns ordinary HTTPS rules.
                        if (!accepts(sourceOrigin, isMainFrame)) return
                        val payload = message.data ?: return
                        bridge.postMessage(payload, allowsSensitiveHostBridge(sourceOrigin))
                    }
                }
            )
            secureBridgeInstalled = true
            true
        }.getOrElse {
            fail("安全消息通道初始化失败，无法打开小程序", "secure_message_bridge_unavailable")
            false
        }
    }

    fun notifyHostApplicationLifecycle(name: String, payload: Map<String, Any?>) {
        if (miniId == null || (name != "appHide" && name != "appShow")) return
        sendHostMessage(name, payload)
    }

    fun sendHostMessage(name: String, payload: Map<String, Any?> = emptyMap()) {
        if (!::webView.isInitialized || isFinishing || isDestroyed) return
        val parameters = org.json.JSONObject(payload)
        val message = org.json.JSONObject().apply {
            put("method", name)
            if (parameters.length() > 0) put("params", parameters)
        }.toString()
        OnlineWebCore.CmsJsCallback.deliverHostMessage(webView, message)
    }

    private fun registerMiniPage(id: String) = synchronized(miniPages) {
        miniPages.getOrPut(id) { linkedSetOf() }.add(this)
    }

    private fun registerSessionPage() = synchronized(sessionPages) {
        if (runtimeSessionId.isNotBlank()) sessionPages.getOrPut(runtimeSessionId) { linkedSetOf() }.add(this)
    }

    private fun unregisterMiniPage(id: String) = synchronized(miniPages) {
        miniPages[id]?.remove(this)
        if (miniPages[id].isNullOrEmpty()) miniPages.remove(id)
    }

    private fun unregisterSessionPage() = synchronized(sessionPages) {
        if (runtimeSessionId.isBlank()) return@synchronized
        sessionPages[runtimeSessionId]?.remove(this)
        if (sessionPages[runtimeSessionId].isNullOrEmpty()) sessionPages.remove(runtimeSessionId)
    }

    private fun attachLaunchSnapshot(snapshotKey: String) {
        val bitmap = MiniLaunchSnapshotStore.take(snapshotKey) ?: return
        launchSnapshotBitmap?.let { if (!it.isRecycled) it.recycle() }
        launchSnapshotBitmap = bitmap
        launchSnapshot.setImageBitmap(bitmap)
        launchSnapshot.visibility = View.VISIBLE
        synchronized(snapshotContainers) { snapshotContainers.add(WeakReference(this)) }
        // Let the stored host frame remain visible while a reused or cold
        // root Mini surface is prepared; it is never written to disk.
        webView.alpha = 0f
    }

    private fun finishLaunchSnapshotTransition() {
        if (launchSnapshotBitmap == null) return
        launchSnapshotReleaseRunnable?.let(webContent::removeCallbacks)
        launchSnapshotReleaseRunnable = null
        webView.animate().cancel()
        webView.animate()
            .alpha(1f)
            .setDuration(220L)
            .withEndAction(::releaseLaunchSnapshot)
            .start()
    }

    private fun releaseLaunchSnapshot() {
        if (!::launchSnapshot.isInitialized) return
        launchSnapshotReleaseRunnable?.let(webContent::removeCallbacks)
        launchSnapshotReleaseRunnable = null
        launchSnapshot.animate().cancel()
        launchSnapshot.setImageDrawable(null)
        launchSnapshot.visibility = View.GONE
        launchSnapshotBitmap?.let { if (!it.isRecycled) it.recycle() }
        launchSnapshotBitmap = null
        synchronized(snapshotContainers) {
            snapshotContainers.removeAll { reference -> reference.get() == null || reference.get() === this }
        }
        if (::webView.isInitialized) webView.alpha = 1f
    }

    private fun fail(message: String, code: String = "mini_open_failed") {
        launchGeneration += 1
        expectedRootDocumentUrl = null
        releaseLaunchSnapshot()
        launchOverlay.showFailure(message, onClose = ::finish)
        StminiRuntimeEvents.emit("mini_open_failed", eventPayload(mapOf("code" to code, "message" to message, "retryable" to false)))
    }

    private fun beginRootMiniLaunch(
        miniId: String,
        primaryName: String?,
        englishName: String?,
        iconUrl: String?,
        verifiedIcon: java.io.File?,
        installed: MiniPackageStore.InstalledPackage? = null
    ): Long {
        launchGeneration += 1
        firstContentReady = false
        expectedRootDocumentUrl = null
        launchOverlay.showProcessing()
        val wantsEnglish = !resources.configuration.locales[0].language.equals("zh", true)
        val displayName = MiniLaunchIdentity.displayName(
            wantsEnglish = wantsEnglish,
            linkName = primaryName,
            linkEnglishName = englishName,
            installedName = installed?.miniName,
            installedEnglishName = installed?.miniNameEn
        )
        launchOverlay.updateIdentity(
            miniId = miniId,
            displayName = displayName,
            iconUrl = iconUrl?.takeIf { it.isNotBlank() } ?: installed?.iconUrl,
            verifiedIcon = verifiedIcon
        )
        return launchGeneration
    }

    private fun updateRootMiniIdentity(
        info: MiniPackageStore.InstalledPackage,
        primaryName: String? = null,
        englishName: String? = null,
        iconUrl: String? = null
    ) {
        if (!isRootMini) return
        beginRootMiniLaunch(
            miniId = info.miniId,
            primaryName = primaryName,
            englishName = englishName,
            iconUrl = iconUrl ?: info.iconUrl,
            verifiedIcon = store.installedIconFile(info),
            installed = info
        )
    }

    /** Reuse the package store's existing event payload; do not alter its Flutter EventChannel schema. */
    private fun consumePackagePresentationEvent(name: String, payload: Map<String, Any?>, launchToken: Long?) {
        if (!isRootMini || launchToken == null || !isCurrentLaunch(launchToken) ||
            payload["miniId"] != miniId || isFinishing || isDestroyed) return
        runOnUiThread {
            if (!isCurrentLaunch(launchToken)) return@runOnUiThread
            when (name) {
                "mini_download_started" -> launchOverlay.showProcessing()
                "mini_download_progress" -> launchOverlay.showDownloadProgress(
                    (payload["downloadedBytes"] as? Number)?.toLong() ?: 0L,
                    (payload["totalBytes"] as? Number)?.toLong() ?: 0L
                )
                // The same native short arc covers retry, validation,
                // unpacking and the eventual first local document render.
                "mini_download_retry", "mini_download_completed" -> launchOverlay.showProcessing()
            }
        }
    }

    private fun isCurrentLaunch(token: Long): Boolean = !isFinishing && !isDestroyed && token == launchGeneration

    private fun selfManagedUpdateRoute(): MiniSelfManagedUpdateAuthority.Route {
        val id = miniId
        val root = id?.let(::rootForMini)
        return MiniSelfManagedUpdateAuthority.route(
            isRootMini = isRootMini,
            isTrustedInternalChild = isTrustedInternalMiniChild(id),
            callerMiniId = id,
            rootMiniId = root?.miniId
        )
    }

    private fun matchingRootForSelfManagedUpdate(): StminiContainerActivity? {
        val id = miniId ?: return null
        val root = rootForMini(id) ?: return null
        return root.takeIf {
            selfManagedUpdateRoute() == MiniSelfManagedUpdateAuthority.Route.trustedChildDelegate &&
                it !== this && it.miniId == id && it.isRootMini
        }
    }

    /** Recheck that a child belongs to the active root Mini before delegating. */
    private fun isTrustedInternalMiniChild(id: String?): Boolean {
        val trustedMiniId: String = id ?: return false
        if (trustedMiniId.isBlank()) return false
        if (isRootMini) return false
        if (isExternalMiniWebPage) {
            return rootForSession(runtimeSessionId)?.miniId == trustedMiniId
        }
        val currentUrl = webView.url?.toString() ?: return false
        return store.resolveLocalPage(trustedMiniId, currentUrl) != null
    }

    private fun isExpectedRootMiniDocument(url: String): Boolean {
        val id = miniId ?: return false
        val expected = expectedRootDocumentUrl ?: return false
        val expectedNavigation = navigationTokenFrom(expected) ?: return false
        if (navigationTokenFrom(url) != expectedNavigation) return false
        // A committed URL may omit a hash fragment. Compare the verified local
        // file instead of raw text, while still rejecting every external URL.
        val expectedFile = store.resolveLocalPage(id, expected) ?: return false
        return store.resolveLocalPage(id, url) == expectedFile
    }

    /**
     * Complete the root launch only for the nonce-bound local entry document.
     * Native page-commit is normally first; the H5 first-frame signal is an
     * intentional fallback for a launch that was backgrounded mid-navigation.
     */
    private fun completeRootMiniFirstContent(url: String, source: String): Boolean {
        if (!isRootMini || firstContentReady || !isExpectedRootMiniDocument(url)) return false
        firstContentReady = true
        expectedRootDocumentUrl = null
        launchOverlay.finishFirstDocument()
        finishLaunchSnapshotTransition()
        StminiDebugLog.webRouter("mini_first_content_ready", mapOf(
            "miniId" to miniId,
            "source" to source
        ))
        StminiRuntimeEvents.emit("mini_first_content_ready", eventPayload(mapOf("miniId" to miniId!!)))
        return true
    }

    private fun bindRootDocumentNavigation(url: String): String {
        val token = "${launchGeneration}-${++rootNavigationGeneration}"
        return android.net.Uri.parse(url).buildUpon()
            .appendQueryParameter(ROOT_NAVIGATION_TOKEN, token)
            .build()
            .toString()
    }

    private fun navigationTokenFrom(url: String): String? = runCatching {
        android.net.Uri.parse(url).getQueryParameter(ROOT_NAVIGATION_TOKEN)
    }.getOrNull()

    private fun showRootUpdateFailure(downloadUrl: String, error: Throwable) {
        val message = error.message ?: "小程序更新失败"
        val canRetry = error !is SecurityException
        launchOverlay.showFailure(
            message = message,
            onRetry = if (canRetry) ({ installStminiUpdate(downloadUrl, true) {} }) else null,
            onClose = ::finish
        )
    }

    private fun eventPayload(payload: Map<String, Any?> = emptyMap()): Map<String, Any?> = buildMap {
        putAll(payload)
        operationId?.let { put("operationId", it) }
    }

    private fun installedPackagesPayload(installed: MiniPackageStore.InstalledPackage): Map<String, Any?> = eventPayload(mapOf(
        "miniId" to installed.miniId,
        "version" to installed.version,
        "packages" to store.installedPackages().map { info -> mapOf(
            "miniId" to info.miniId,
            "miniName" to info.miniName,
            "iconUrl" to info.iconUrl,
            "launchLink" to info.launchLink,
            "version" to info.version
        ) }
    ))
}
