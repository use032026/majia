package com.fsst.stmini_flutter.web

import android.content.Context
import android.content.res.Configuration
import org.json.JSONObject
import org.json.JSONTokener
import java.util.Locale

/**
 * The ordinary Web session subset of the historical JS Bridge.
 *
 * This is intentionally independent of Mini packages and routes. An
 * explicitly authorized online H5 can exchange only its configured session
 * snapshot and package identity; navigation and other host actions remain
 * delegated to the embedding Flutter app.
 */
internal object OnlineWebSessionBridge {
    private const val STORAGE_NAME = "stmini_flutter_storage"
    private const val MAX_STORAGE_BYTES = 1_048_576

    fun handle(context: Context, method: String, params: JSONObject): JSONObject? = when (method) {
        "getPackageName" -> success(JSONObject().put("packageName", configuration()["packageName"] as? String ?: ""))
        "getUserInfo" -> success(userInfo(context))
        "getToken" -> success(userInfo(context).optString("token"))
        "setStorage" -> store(context, params)
        "getStorage" -> read(context, params)
        "removeStorage" -> remove(context, params)
        else -> null
    }

    private fun configuration(): Map<String, Any?> = OnlineWebConfiguration.context()

    private fun userInfo(context: Context): JSONObject {
        val values = JSONObject().apply {
            put("device_type", "android")
            put("dark_mode", if (isDark(context)) "1" else "0")
            put("language_code", languageCode())
        }
        val authKey = configuration()["authStorageKey"] as? String
        authKey?.takeIf(::validKey)?.let { key ->
            storedJson(context, key)?.let { auth ->
                values.put("token", auth.opt("token") ?: auth.opt("access_token"))
                values.put("device_id", auth.opt("device_id"))
                values.put("user_id", auth.opt("user_id"))
            }
        }
        val profileConfig = configuration()["bridgeUserInfoStorage"] as? Map<*, *>
        profileConfig?.let { config ->
            val storageKey = config["storageKey"] as? String ?: return@let
            val valueKey = config["valueKey"] as? String ?: return@let
            val selected = storedJson(context, storageKey)?.opt(valueKey) ?: return@let
            val profile = when (selected) {
                is JSONObject -> selected
                is String -> jsonObject(selected)
                else -> null
            } ?: return@let
            val nested = config["nestedKey"] as? String
            val result = if (nested.isNullOrBlank()) profile else profile.optJSONObject(nested)
            result?.keys()?.forEach { key -> values.put(key, result.opt(key)) }
        }
        (configuration()["userInfo"] as? Map<*, *>)?.forEach { (key, value) ->
            if (key is String) values.put(key, value)
        }
        return values
    }

    private fun store(context: Context, params: JSONObject): JSONObject {
        val key = params.optString("key").takeIf(::validKey) ?: return failure("缺少key")
        if (!params.has("data") || params.isNull("data")) return failure("应当存储json字符串")
        val value = params.optString("data")
        if (value.toByteArray(Charsets.UTF_8).size > MAX_STORAGE_BYTES) return failure("存储内容过大")
        if (jsonValue(value) == null) return failure("存储出错")
        context.getSharedPreferences(STORAGE_NAME, Context.MODE_PRIVATE).edit().putString(key, value).apply()
        return success()
    }

    private fun read(context: Context, params: JSONObject): JSONObject {
        val key = params.optString("key").takeIf(::validKey) ?: return failure("缺少key")
        val value = context.getSharedPreferences(STORAGE_NAME, Context.MODE_PRIVATE).getString(key, null)
            ?: return failure("值不存在")
        return success(jsonValue(value) ?: value)
    }

    private fun remove(context: Context, params: JSONObject): JSONObject {
        val key = params.optString("key").takeIf(::validKey) ?: return failure("缺少key")
        context.getSharedPreferences(STORAGE_NAME, Context.MODE_PRIVATE).edit().remove(key).apply()
        return success()
    }

    private fun storedJson(context: Context, key: String): JSONObject? =
        key.takeIf(::validKey)
            ?.let { context.getSharedPreferences(STORAGE_NAME, Context.MODE_PRIVATE).getString(it, null) }
            ?.let(::jsonObject)

    private fun validKey(value: String): Boolean = value.isNotBlank() && value.length <= 256
    private fun jsonObject(value: String): JSONObject? = runCatching { JSONObject(value) }.getOrNull()
    private fun jsonValue(value: String): Any? = runCatching { JSONTokener(value).nextValue() }.getOrNull()
    private fun success(data: Any = JSONObject()): JSONObject = JSONObject().put("code", "1").put("data", data)
    private fun failure(message: String): JSONObject = JSONObject().put("code", "0").put("data", JSONObject().put("msg", message))

    private fun isDark(context: Context): Boolean =
        context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

    private fun languageCode(): String {
        val language = Locale.getDefault().toLanguageTag()
        return when {
            language.startsWith("zh-Hant", true) || language.startsWith("zh-TW", true) || language.startsWith("zh-HK", true) -> "zh-Hant"
            language.startsWith("zh", true) -> "zh-Hans"
            language.startsWith("en", true) -> "en-US"
            else -> language
        }
    }
}
