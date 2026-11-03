package com.fsst.stmini_flutter.web

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * The only Android-to-Flutter hand-off for an explicitly authorized ordinary
 * Web page.  It is intentionally in the Web Core: no Mini package, runtime,
 * session or Activity state can be smuggled into a host request.
 */
internal object OnlineWebHostBridge {
    private const val methodName = "webBridgeRequest"
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var channel: MethodChannel? = null

    fun attach(methodChannel: MethodChannel) {
        channel = methodChannel
    }

    fun detach(methodChannel: MethodChannel) {
        if (channel === methodChannel) channel = null
    }

    fun forward(
        method: String,
        params: JSONObject,
        origin: String,
        completed: (JSONObject) -> Unit
    ) {
        val activeChannel = channel
        if (activeChannel == null) {
            completed(failure("宿主未处理该网页请求"))
            return
        }
        val request = mapOf(
            "method" to method,
            "params" to flutterValue(params),
            // Origin comes from OnlineWebCore's exact, committed-frame gate.
            // It is never copied from the page payload or host response.
            "origin" to origin
        )
        mainHandler.post {
            // The plugin may detach between the caller's initial lookup and
            // this UI turn. Fail closed rather than delivering through a stale
            // messenger from a prior Flutter engine.
            if (channel !== activeChannel) {
                completed(failure("宿主未处理该网页请求"))
                return@post
            }
            activeChannel.invokeMethod(methodName, request, object : MethodChannel.Result {
                override fun success(result: Any?) = completed(normalizeResponse(result))
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    completed(failure(errorMessage?.takeIf { it.isNotBlank() } ?: "宿主处理网页请求失败"))
                }
                override fun notImplemented() = completed(failure("宿主未处理该网页请求"))
            })
        }
    }

    /** Only `code` and `data` cross back into the H5 response envelope. */
    private fun normalizeResponse(result: Any?): JSONObject {
        val map = result as? Map<*, *> ?: return failure("宿主未处理该网页请求")
        val code = when (val raw = map["code"]) {
            is Number -> if (raw.toInt() == 0) "0" else "1"
            is String -> if (raw.trim() == "0") "0" else "1"
            else -> "1"
        }
        val data = map["data"]
        return if (code == "0") {
            val safeData = jsonValue(data) as? JSONObject
            val message = safeData?.optString("msg")?.takeIf { it.isNotBlank() }
                ?: "宿主处理网页请求失败"
            JSONObject().apply {
                put("code", "0")
                put("data", (safeData ?: JSONObject()).apply { if (!has("msg")) put("msg", message) })
            }
        } else {
            JSONObject().apply {
                put("code", "1")
                put("data", jsonValue(data) ?: JSONObject())
            }
        }
    }

    private fun failure(message: String): JSONObject = JSONObject().apply {
        put("code", "0")
        put("data", JSONObject().put("msg", message))
    }

    private fun flutterValue(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> value.keys().asSequence().associateWith { key -> flutterValue(value.opt(key)) }
        is JSONArray -> List(value.length()) { index -> flutterValue(value.opt(index)) }
        else -> value
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        null -> null
        is Map<*, *> -> JSONObject().apply {
            value.forEach { (key, item) -> if (key is String) put(key, jsonValue(item)) }
        }
        is Iterable<*> -> JSONArray().apply { value.forEach { put(jsonValue(it)) } }
        is Array<*> -> JSONArray().apply { value.forEach { put(jsonValue(it)) } }
        is Boolean, is Number, is String -> value
        else -> value.toString()
    }
}
