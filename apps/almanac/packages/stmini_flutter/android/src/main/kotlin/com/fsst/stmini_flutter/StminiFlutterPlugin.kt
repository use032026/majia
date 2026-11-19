package com.fsst.stmini_flutter

import com.fsst.stmini_flutter.ui.LocalMiniViewFactory
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.fsst.stmini_flutter.runtime.LocalPackageInventory
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import com.fsst.stmini_flutter.runtime.StminiHostConfiguration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Foundation initialization plus an explicit local-only PlatformView; no full link loader/install/download/Bridge. */
class StminiFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
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

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        initialized = false
        language = null
        attached = true
        inventoryExecutor = Executors.newSingleThreadExecutor { task ->
            Thread(task, "stmini-local-inventory").apply { isDaemon = true }
        }
        methods = MethodChannel(binding.binaryMessenger, "stmini_flutter/methods")
        events = EventChannel(binding.binaryMessenger, "stmini_flutter/events")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        localViews = LocalMiniViewFactory(binding.binaryMessenger) { attached && initialized }.also {
            binding.platformViewRegistry.registerViewFactory("stmini_flutter/local_view", it)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val args = call.arguments as? Map<*, *>
                val context = args?.get("bridgeContext") as? Map<*, *>
                if (args == null || args.keys.any { it != "bridgeContext" } ||
                    context == null || context.keys.any { it != "packageName" } ||
                    context["packageName"] != applicationContext.packageName ||
                    applicationContext.packageName != "com.almanac.lite") {
                    result.error("unsupported_foundation_configuration", "Stage one supports only the Deynu packageName.", null)
                    return
                }
                // Execute main's real configuration and language-resolution types.
                StminiHostConfiguration.configure(mapOf("packageName" to applicationContext.packageName))
                language = StminiHostConfiguration.normalizedLanguage(applicationContext)
                initialized = true
                eventSubscription?.emit("foundation_initialized", state())
                result.success(null)
            }
            "openMini", "openWeb", "closeMini", "closeWeb", "notifyWebSessionChanged" -> result.error("unsupported_capability", "Full Mini and standalone Web are not integrated on Android.", null)
            "foundationState" -> result.success(state())
            "installedPackages" -> readInventory(call.arguments, result)
            else -> result.error("unsupported_capability", "This capability is not included in the foundation stage.", null)
        }
    }

    private fun state(): Map<String, Any?> = mapOf(
        "stage" to "foundation", "initialized" to initialized,
        "packageName" to if (initialized) StminiHostConfiguration.bridgeContext["packageName"] else null,
        "language" to language,
        "capabilities" to listOf("host_configuration", "language_resolution", "runtime_events", "local_inventory", "local_renderer"),
        "localRendererAvailable" to true,
        "miniLoadingAvailable" to false, "webLoadingAvailable" to false,
        "miniPackageDownloadAvailable" to false, "miniPackageInstallAvailable" to false, "miniPackageUpdateAvailable" to false,
        "miniChildWebAvailable" to false, "closedMiniCacheAvailable" to false
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

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSubscription?.cancel()
        eventSubscription = StminiRuntimeEvents.attach { sink.success(it) }
        // EventChannel listen and initialize use different control channels.
        // Replay current truth when listen arrives after initialization.
        if (initialized) eventSubscription?.emit("foundation_initialized", state())
    }
    override fun onCancel(arguments: Any?) {
        eventSubscription?.cancel()
        eventSubscription = null
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        localViews?.detach(); localViews = null
        initialized = false
        language = null
        inventoryQuery?.let { query ->
            inventoryQuery = null
            query.cancelled.set(true)
            query.future?.cancel(true)
            val completion = query.result
            query.result = null
            query.future = null
            completion?.error("inventory_cancelled", "Inventory query cancelled.", null)
        }
        inventoryExecutor.shutdownNow()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        eventSubscription?.cancel()
        eventSubscription = null
    }
}
