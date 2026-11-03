package com.fsst.stmini_flutter

import android.app.Activity
import android.content.Context
import android.net.Uri
import android.os.SystemClock
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.fsst.stmini_flutter.web.OnlineWebActivity
import com.fsst.stmini_flutter.web.OnlineWebConfiguration
import com.fsst.stmini_flutter.web.OnlineWebEvents
import com.fsst.stmini_flutter.web.OnlineWebHostBridge
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Android adapter for the Web-only Flutter contract. */
class StminiFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {
    private lateinit var applicationContext: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var activity: Activity? = null
    private var backgroundStartedAtMs: Long? = null
    private val processLifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStop(owner: LifecycleOwner) {
            backgroundStartedAtMs = SystemClock.elapsedRealtime()
            OnlineWebActivity.notifyAppLifecycle("appHide")
        }

        override fun onStart(owner: LifecycleOwner) {
            val startedAt = backgroundStartedAtMs
            backgroundStartedAtMs = null
            val duration = if (startedAt == null) 0L else SystemClock.elapsedRealtime() - startedAt
            OnlineWebActivity.notifyAppLifecycle("appShow", mapOf("backgroundDurationMs" to duration))
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "stmini_flutter/methods")
        events = EventChannel(binding.binaryMessenger, "stmini_flutter/events")
        OnlineWebHostBridge.attach(methods)
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(processLifecycleObserver)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                OnlineWebConfiguration.configure(call.argument<Map<String, Any?>>("bridgeContext"))
                result.success(null)
            }
            "openWeb" -> openWeb(
                call.argument("url"),
                call.argument("title"),
                call.argument<Boolean>("showNavigationBar") ?: true,
                result
            )
            "closeWeb" -> {
                OnlineWebActivity.closeActive()
                result.success(null)
            }
            "notifyWebSessionChanged" -> {
                val reason = call.argument<String>("reason") ?: "sessionChanged"
                result.success(OnlineWebActivity.notifySessionChanged(reason))
            }
            "isAvailable" -> result.success(true)
            else -> result.notImplemented()
        }
    }

    private fun openWeb(url: String?, title: String?, showNavigationBar: Boolean, result: MethodChannel.Result) {
        val parsed = url?.let(Uri::parse)
        val valid = parsed?.host != null && (parsed.scheme.equals("https", true) ||
            (OnlineWebConfiguration.allowsInsecureHttpNavigation() && parsed.scheme.equals("http", true)))
        if (!valid) {
            result.error("invalid_web_url", "url must be an absolute HTTPS URL", null)
            return
        }
        val host = activity ?: run {
            result.error("no_presenting_controller", "No active Flutter Activity", null)
            return
        }
        val safeURL = url!!
        OnlineWebEvents.emit("web_open_requested", mapOf("url" to redact(safeURL)))
        host.startActivity(
            OnlineWebActivity.intent(
                context = host,
                url = safeURL,
                title = title,
                showNavigation = showNavigationBar,
                allowInsecureHttpNavigation = OnlineWebConfiguration.allowsInsecureHttpNavigation()
            )
        )
        OnlineWebEvents.emit("web_opened", mapOf("url" to redact(safeURL)))
        result.success(null)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) = OnlineWebEvents.attach(sink)
    override fun onCancel(arguments: Any?) = OnlineWebEvents.attach(null)

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ProcessLifecycleOwner.get().lifecycle.removeObserver(processLifecycleObserver)
        OnlineWebHostBridge.detach(methods)
        OnlineWebEvents.attach(null)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    private fun redact(raw: String): String = runCatching { Uri.parse(raw) }.getOrNull()?.let {
        "${it.scheme}://${it.host.orEmpty()}${it.path.orEmpty()}"
    }.orEmpty()
}
