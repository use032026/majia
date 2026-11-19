package com.fsst.stmini_flutter

import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import com.fsst.stmini_flutter.runtime.LocalPackageInventory
import com.fsst.stmini_flutter.ui.LocalMiniViewFactory
import android.app.Activity
import android.content.Context
import android.os.SystemClock
import java.util.UUID
import com.fsst.stmini_flutter.runtime.MiniLink
import com.fsst.stmini_flutter.runtime.MiniPackageStore
import com.fsst.stmini_flutter.runtime.StminiHostConfiguration
import com.fsst.stmini_flutter.ui.StminiContainerActivity
import com.fsst.stmini_flutter.web.OnlineWebHostBridge
import com.fsst.stmini_flutter.web.OnlineWebActivity
import com.fsst.stmini_flutter.web.OnlineWebConfiguration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner

/** Android implementation of the public Flutter/iOS STMini method contract. */
class StminiFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {
    private lateinit var applicationContext: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private val main = Handler(Looper.getMainLooper())
    private lateinit var inventoryExecutor: ExecutorService
    private var attached = false
    private var inventoryQuery: InventoryQuery? = null
    private class InventoryQuery(var result: MethodChannel.Result?) {
        val cancelled = AtomicBoolean(false)
        var future: Future<*>? = null
    }
    private var localViews: LocalMiniViewFactory? = null
    private var initialized = false
    private var language: String? = null
    private var eventSubscription: StminiRuntimeEvents.Subscription? = null

    private var activity: Activity? = null
    private var backgroundAtElapsedMs: Long? = null
    private val processLifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStop(owner: LifecycleOwner) {
            backgroundAtElapsedMs = SystemClock.elapsedRealtime()
            StminiContainerActivity.notifyMiniRootsLifecycle("appHide")
            OnlineWebActivity.notifyAppLifecycle("appHide")
        }

        override fun onStart(owner: LifecycleOwner) {
            val startedAt = backgroundAtElapsedMs ?: return
            backgroundAtElapsedMs = null
            val durationMs = (SystemClock.elapsedRealtime() - startedAt).coerceAtLeast(0L)
            StminiContainerActivity.notifyMiniRootsLifecycle("appShow", mapOf(
                "backgroundDurationMs" to durationMs,
                "recoveryMode" to "visible_resume"
            ))
            OnlineWebActivity.notifyAppLifecycle("appShow", mapOf(
                "backgroundDurationMs" to durationMs,
                "recoveryMode" to "visible_resume"
            ))
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        attached = true
        initialized = false
        inventoryExecutor = Executors.newSingleThreadExecutor { task -> Thread(task, "stmini-local-inventory").apply { isDaemon = true } }
        localViews = LocalMiniViewFactory(binding.binaryMessenger) { attached && initialized }.also {
            binding.platformViewRegistry.registerViewFactory("stmini_flutter/local_view", it)
        }
        methods = MethodChannel(binding.binaryMessenger, "stmini_flutter/methods")
        OnlineWebHostBridge.attach(methods)
        events = EventChannel(binding.binaryMessenger, "stmini_flutter/events")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(processLifecycleObserver)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val args = call.arguments as? Map<*, *>
                val context = args?.get("bridgeContext") as? Map<*, *>
                if (args == null || args.keys.any { it !in setOf("bridgeContext", "loadingImage") } ||
                    context == null || context.keys.any { it != "packageName" } ||
                    context["packageName"] != applicationContext.packageName || applicationContext.packageName != "com.almanac.lite" ||
                    (args["loadingImage"] != null && args["loadingImage"] !is String)) {
                    return result.error("unsupported_host_configuration", "Only the Deynu host identity is configured.", null)
                }
                @Suppress("UNCHECKED_CAST")
                val hostContext = context as Map<String, Any?>
                StminiHostConfiguration.configure(hostContext, applicationContext, call.argument<String>("loadingImage"))
                OnlineWebConfiguration.configure(hostContext)
                language = StminiHostConfiguration.normalizedLanguage(applicationContext)
                initialized = true
                eventSubscription?.emit("runtime_initialized", state())
                result.success(null)
            }
            "openMini" -> openMini(call.argument<String>("link"), result)
            "openWeb" -> openWeb(
                call.argument<String>("url"), call.argument<String>("title"),
                call.argument<Boolean>("showNavigationBar") ?: true, result
            )
            // Keep the historical method name for compatibility: it closes a
            // Mini session when present and also the standalone host Web
            // owner opened through the same plugin API.
            "closeMini" -> {
                OnlineWebActivity.closeActive()
                StminiContainerActivity.closeActive()
                result.success(null)
            }
            "closeWeb" -> { OnlineWebActivity.closeActive(); result.success(null) }
            "notifyWebSessionChanged" -> {
                val reason = call.argument<String>("reason")
                if (reason.isNullOrBlank() || reason.length > 128) result.error("invalid_reason", "A bounded reason is required.", null)
                else result.success(OnlineWebActivity.notifyHostSessionChanged(reason))
            }
            "foundationState" -> result.success(state())
            "installedPackages" -> readInventory(call.arguments, result)
            "isAvailable" -> result.success(true)
            else -> result.notImplemented()
        }
    }

    private fun state(): Map<String, Any?> = mapOf(
        "stage" to "mini", "runtimeMode" to "mini", "initialized" to initialized,
        "packageName" to if (initialized) StminiHostConfiguration.bridgeContext["packageName"] else null,
        "language" to language,
        "capabilities" to listOf("host_configuration", "language_resolution", "runtime_events", "local_inventory", "local_renderer", "mini_runtime", "online_web", "framework_bridge", "isolated_storage"),
        "localRendererAvailable" to true,
        "miniLoadingAvailable" to true, "webLoadingAvailable" to true
    )

    private fun readInventory(arguments: Any?, result: MethodChannel.Result) {
        if (arguments != null) return result.error("invalid_inventory_arguments", "Inventory accepts no arguments.", null)
        if (!initialized || !attached) return result.error("not_initialized", "Initialize the foundation first.", null)
        if (inventoryQuery != null) return result.error("inventory_busy", "Inventory query already in progress.", null)
        val query = InventoryQuery(result)
        inventoryQuery = query
        val base = applicationContext.filesDir
        val deadline = System.nanoTime() + 4_000_000_000L
        query.future = inventoryExecutor.submit {
            val outcome = runCatching {
                LocalPackageInventory(base).read {
                    if (query.cancelled.get() || Thread.currentThread().isInterrupted || System.nanoTime() >= deadline) {
                        throw LocalPackageInventory.Unavailable()
                    }
                }
            }
            main.post {
                if (!attached || inventoryQuery !== query || query.cancelled.get()) return@post
                inventoryQuery = null
                val completion = query.result
                query.result = null
                query.future = null
                outcome.fold({ completion?.success(it) }, {
                    completion?.error("inventory_unavailable", "Local inventory could not be read.", null)
                })
            }
        }
    }

    private fun openMini(link: String?, result: MethodChannel.Result) {
        if (!attached || !initialized) return result.error("not_initialized", "Initialize the Mini runtime first.", null)
        val operationId = UUID.randomUUID().toString()
        val parsed = link?.let(MiniLink::parse)
        if (parsed == null) {
            StminiRuntimeEvents.emit("mini_open_failed", mapOf("operationId" to operationId, "code" to "invalid_mini_link", "retryable" to false))
            return result.error("invalid_mini_link", "link must start with mini://", null)
        }
        parsed.downloadUrl?.let { source ->
            StminiHostConfiguration.security.urlRejectionReason(source)?.let { reason ->
                StminiRuntimeEvents.emit("mini_open_failed", mapOf("operationId" to operationId, "code" to "download_source_rejected", "retryable" to false))
                return result.error("mini_download_source_rejected", reason, null)
            }
        }
        val host = activity ?: run {
            StminiRuntimeEvents.emit("mini_open_failed", mapOf("operationId" to operationId, "code" to "no_presenting_controller", "retryable" to true))
            return result.error("no_presenting_controller", "No active Flutter Activity", null)
        }
        StminiRuntimeEvents.emit("open_requested", mapOf("link" to "mini://${parsed.miniId}"))
        StminiRuntimeEvents.emit("mini_opening", mapOf("operationId" to operationId, "link" to "mini://${parsed.miniId}"))
        StminiContainerActivity.rememberLaunchingHostSnapshot(host, parsed.miniId)
        host.startActivity(StminiContainerActivity.rootLaunchIntent(
            context = host,
            link = parsed,
            operationId = operationId,
            // This is derived only from the previously verified local package.
            // A first install starts in document mode and will move itself into
            // the host task after verifying an `ishome: "1"` manifest.
            isHome = MiniPackageStore(applicationContext).installed(parsed.miniId)?.isHome == true
        ))
        result.success(null)
    }

    private fun openWeb(url: String?, title: String?, showNavigationBar: Boolean, result: MethodChannel.Result) {
        if (!attached || !initialized) return result.error("not_initialized", "Initialize the Mini runtime first.", null)
        val valid = url?.let { android.net.Uri.parse(it) }?.let { uri ->
            uri.host != null && (uri.scheme.equals("https", true) ||
                (StminiHostConfiguration.allowInsecureHttpNavigation && uri.scheme.equals("http", true)))
        } == true
        if (!valid) return result.error("invalid_web_url", "url must be an absolute HTTPS URL", null)
        val host = activity ?: return result.error("no_presenting_controller", "No active Flutter Activity", null)
        StminiRuntimeEvents.emit("web_open_requested", mapOf("url" to redact(url!!)))
        host.startActivity(OnlineWebActivity.intent(
            context = host,
            url = url,
            title = title,
            showNavigation = showNavigationBar,
            allowInsecureHttpNavigation = StminiHostConfiguration.allowInsecureHttpNavigation
        ))
        StminiRuntimeEvents.emit("web_opened", mapOf("url" to redact(url)))
        result.success(null)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSubscription?.cancel()
        eventSubscription = StminiRuntimeEvents.attach { sink.success(it) }
        if (initialized) eventSubscription?.emit("runtime_initialized", state())
    }
    override fun onCancel(arguments: Any?) { eventSubscription?.cancel(); eventSubscription = null }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        initialized = false
        localViews?.detach(); localViews = null
        inventoryQuery?.let { query ->
            inventoryQuery = null; query.cancelled.set(true); query.future?.cancel(true)
            val completion = query.result; query.result = null; query.future = null
            completion?.error("inventory_cancelled", "Inventory query cancelled.", null)
        }
        inventoryExecutor.shutdownNow()
        ProcessLifecycleOwner.get().lifecycle.removeObserver(processLifecycleObserver)
        OnlineWebHostBridge.detach(methods)
        methods.setMethodCallHandler(null); events.setStreamHandler(null)
        eventSubscription?.cancel(); eventSubscription = null
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    private fun redact(raw: String): String = runCatching { android.net.Uri.parse(raw) }.getOrNull()?.let {
        "${it.scheme}://${it.host ?: ""}${it.path ?: ""}"
    } ?: ""
}
