package com.fsst.stmini_flutter.runtime

import android.content.Context

/** Test-only configuration glue, deliberately avoiding host preferences. */
object StminiHostConfiguration {
    var bridgeContext: Map<String, Any?> = emptyMap()
        private set
    fun configure(context: Map<String, Any?>) { bridgeContext = context.toMap() }
    fun normalizedLanguage(@Suppress("UNUSED_PARAMETER") context: Context): String = "en"
}
