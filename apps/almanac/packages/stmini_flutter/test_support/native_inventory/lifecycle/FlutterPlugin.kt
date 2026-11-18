package io.flutter.embedding.engine.plugins

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger

/** Test glue only. This is not a FlutterEngine or Flutter embedding implementation. */
interface FlutterPlugin {
    class FlutterPluginBinding(val applicationContext: Context, val binaryMessenger: BinaryMessenger) {
        val platformViewRegistry = TestPlatformViewRegistry()
    }
    class TestPlatformViewRegistry {
        fun registerViewFactory(name: String, factory: Any): Boolean = true
    }
    fun onAttachedToEngine(binding: FlutterPluginBinding)
    fun onDetachedFromEngine(binding: FlutterPluginBinding)
}
