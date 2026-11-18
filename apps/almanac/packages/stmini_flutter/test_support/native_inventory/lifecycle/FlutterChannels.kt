package io.flutter.plugin.common

/** Minimal signatures needed to invoke the production plugin directly on Android OS. */
interface BinaryMessenger
class MethodCall(val method: String, val arguments: Any?)
class MethodChannel(@Suppress("UNUSED_PARAMETER") messenger: BinaryMessenger,
                    @Suppress("UNUSED_PARAMETER") name: String) {
    interface MethodCallHandler { fun onMethodCall(call: MethodCall, result: Result) }
    interface Result {
        fun success(value: Any?)
        fun error(code: String, message: String?, details: Any?)
        fun notImplemented()
    }
    fun setMethodCallHandler(@Suppress("UNUSED_PARAMETER") handler: MethodCallHandler?) { }
}
class EventChannel(@Suppress("UNUSED_PARAMETER") messenger: BinaryMessenger,
                   @Suppress("UNUSED_PARAMETER") name: String) {
    interface EventSink { fun success(value: Any?) }
    interface StreamHandler {
        fun onListen(arguments: Any?, sink: EventSink)
        fun onCancel(arguments: Any?)
    }
    fun setStreamHandler(@Suppress("UNUSED_PARAMETER") handler: StreamHandler?) { }
}
