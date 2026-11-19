package com.fsst.stmini_flutter.ui

import android.net.Uri

/** Keeps pending MediaStore rows transactional even when output fails. */
internal object StminiMediaStoreWrite {
    interface Sink {
        fun insert(): Uri?
        fun write(uri: Uri, bytes: ByteArray)
        fun publish(uri: Uri)
        fun delete(uri: Uri)
    }

    fun write(sink: Sink, bytes: ByteArray): Result<Unit> = runCatching {
        var uri: Uri? = null
        try {
            uri = sink.insert() ?: error("无法创建图片")
            sink.write(uri, bytes)
            sink.publish(uri)
        } catch (error: Throwable) {
            uri?.let { runCatching { sink.delete(it) } }
            throw error
        }
    }
}
