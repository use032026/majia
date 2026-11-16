package com.fsst.stmini_flutter.runtime

import android.content.Context

/** In-process configuration explicitly supplied by the Flutter host. */
object StminiHostConfiguration {
    @Volatile var bridgeContext: Map<String, Any?> = emptyMap()
        private set

    @Volatile var security: MiniSecurity = MiniSecurity(null, false, emptySet())
        private set

    /** HTTP Web navigation and HTTP Bridge both require this explicit host opt-in. */
    @Volatile var allowInsecureHttpNavigation: Boolean = false
        private set

    /** Resource name supplied by the Flutter host; never treated as a URL. */
    @Volatile var loadingImage: String? = null
        private set

    private const val STORAGE_NAME = "stmini_flutter_storage"
    private const val RESET_STATE_NAME = "stmini_flutter_host_state"

    fun configure(context: Map<String, Any?>?) {
        bridgeContext = context ?: emptyMap()
        val rawSecurity = bridgeContext["miniSecurity"] as? Map<*, *> ?: emptyMap<Any?, Any?>()
        val keepAlive = (rawSecurity["continuousKeepAliveMiniIds"] as? List<*>)
            ?.mapNotNull { (it as? String)?.trim()?.lowercase()?.takeIf(String::isNotEmpty) }
            ?.toSet()
            ?: emptySet()
        security = MiniSecurity(
            trustedDownloadUrl = rawSecurity["downloadUrl"] as? String,
            allowInsecureHttpForDebug = rawSecurity["allowInsecureHTTPForDebug"] as? Boolean ?: false,
            continuousKeepAliveMiniIds = keepAlive
        )
        val rawWebSecurity = bridgeContext["webSecurity"] as? Map<*, *> ?: emptyMap<Any?, Any?>()
        allowInsecureHttpNavigation = rawWebSecurity["allowInsecureHTTP"] as? Boolean ?: false
    }

    /**
     * iOS applies this reset once per declared version.  Keep Android's copy
     * in the plugin-owned preference file: a reusable library must not scan
     * or mutate arbitrary host preferences.
     */
    fun configure(context: Map<String, Any?>?, applicationContext: Context, loadingImage: String?) {
        configure(context)
        loadingImage?.trim()?.takeIf { it.isNotEmpty() && it.length <= 128 }?.let { this.loadingImage = it }
        val reset = bridgeContext["storageReset"] as? Map<*, *> ?: return
        val version = (reset["version"] as? String)?.trim()?.takeIf { it.isNotEmpty() && it.length <= 128 } ?: return
        val keys = (reset["keys"] as? List<*>)
            ?.mapNotNull { (it as? String)?.takeIf { value -> value.isNotBlank() && value.length <= 256 } }
            ?.distinct()
            ?.take(64)
            .orEmpty()
        if (keys.isEmpty()) return
        val state = applicationContext.getSharedPreferences(RESET_STATE_NAME, Context.MODE_PRIVATE)
        val marker = "stmini.storage-reset.$version"
        if (state.getBoolean(marker, false)) return
        applicationContext.getSharedPreferences(STORAGE_NAME, Context.MODE_PRIVATE)
            .edit().apply { keys.forEach(::remove) }.apply()
        state.edit().putBoolean(marker, true).apply()
    }

    fun normalizedLanguage(context: Context): String {
        val persisted = context.getSharedPreferences(RESET_STATE_NAME, Context.MODE_PRIVATE)
            .getString("STLanguageCode", null)
        val raw = (persisted ?: java.util.Locale.getDefault().toLanguageTag()).trim()
        val value = raw.lowercase().replace('_', '-')
        return when {
            value.startsWith("zh-hant") || value.contains("hant") ||
                value.startsWith("zh-tw") || value.startsWith("zh-hk") -> "zh-Hant"
            value.startsWith("zh") -> "zh-Hans"
            value.startsWith("en") -> "en-US"
            else -> raw.ifBlank { "en-US" }
        }
    }

    fun setLanguage(context: Context, rawLanguage: String): String? {
        val language = rawLanguage.trim()
        if (language.isEmpty() || language.length > 64 ||
            language.any { !it.isLetterOrDigit() && it != '-' && it != '_' }) return null
        context.getSharedPreferences(RESET_STATE_NAME, Context.MODE_PRIVATE)
            .edit().putString("STLanguageCode", language).apply()
        return normalizedLanguage(context)
    }

    /** Exact-origin and explicit-key opt-in for a narrowly scoped legacy cache. */
    fun allowsLegacyStorageMirror(origin: String?, key: String): Boolean {
        val policy = bridgeContext["legacyWebStorageMirror"] as? Map<*, *> ?: return false
        if (!allowsLegacyStorageMirrorOrigin(origin)) return false
        val keys = (policy["keys"] as? List<*>)
            ?.mapNotNull { (it as? String)?.takeIf { value -> value.isNotBlank() && value.length <= 256 } }
            ?.toSet()
            .orEmpty()
        return key in keys
    }

    /** The optional legacy cache uses its own explicit key list, but the same origin allow-list. */
    fun allowsLegacyStorageMirrorOrigin(origin: String?): Boolean {
        val policy = bridgeContext["legacyWebStorageMirror"] as? Map<*, *> ?: return false
        val normalizedOrigin = origin?.let(WebOrigin::normalizeHttps) ?: return false
        val origins = (policy["origins"] as? List<*>)
            ?.mapNotNull { (it as? String)?.let(WebOrigin::normalizeHttps) }
            ?.toSet()
            .orEmpty()
        return normalizedOrigin in origins
    }
}
