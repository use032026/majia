package com.fsst.stmini_flutter.web

import android.content.Context
import android.content.SharedPreferences
import java.security.MessageDigest

/** The verified native dispatcher supplies this subject; page parameters cannot select a domain. */
internal object ScopedWebStorage {
    fun preferences(context: Context, subject: String): SharedPreferences {
        require(subject.isNotEmpty() && subject.toByteArray(Charsets.UTF_8).size <= 1024)
        val encoded = MessageDigest.getInstance("SHA-256").digest(subject.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it.toInt() and 255) }
        return context.getSharedPreferences("stmini_scoped_v1_$encoded", Context.MODE_PRIVATE)
    }
}
