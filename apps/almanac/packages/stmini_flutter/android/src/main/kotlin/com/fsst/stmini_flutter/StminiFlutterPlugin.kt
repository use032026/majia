package com.fsst.stmini_flutter

import android.content.Context
import com.fsst.stmini_flutter.runtime.StminiHostConfiguration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Explicit foundation adapter. No container, WebView, installation or download module. */
class StminiFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var applicationContext: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var initialized = false
    private var language: String? = null
    private var eventSubscription: StminiRuntimeEvents.Subscription? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "stmini_flutter/methods")
        events = EventChannel(binding.binaryMessenger, "stmini_flutter/events")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
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
            "foundationState" -> result.success(state())
            else -> result.error("unsupported_capability", "This capability is not included in the foundation stage.", null)
        }
    }

    private fun state(): Map<String, Any?> = mapOf(
        "stage" to "foundation", "initialized" to initialized,
        "packageName" to StminiHostConfiguration.bridgeContext["packageName"],
        "language" to language,
        "capabilities" to listOf("host_configuration", "language_resolution", "runtime_events"),
        "miniLoadingAvailable" to false, "webLoadingAvailable" to false
    )

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
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        eventSubscription?.cancel()
        eventSubscription = null
    }
}
