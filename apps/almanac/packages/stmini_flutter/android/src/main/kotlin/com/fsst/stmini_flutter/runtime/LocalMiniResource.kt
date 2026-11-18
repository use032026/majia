package com.fsst.stmini_flutter.runtime

import android.net.Uri
import android.webkit.WebResourceResponse
import java.io.ByteArrayInputStream
import java.io.File
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.util.concurrent.Semaphore
import java.util.concurrent.atomic.AtomicBoolean

/** Derived local-origin/resource subset of pinned MiniPackageStore and Container.
 * Every request revalidates the installed identity. No network fallback or installer.
 */
class LocalMiniResource(private val inventory: LocalPackageInventory,
    val miniId: String, val version: String, val entry: String) {
    private val permits = Semaphore(4)
    private val active = mutableSetOf<BudgetStream>()
    private val closed = AtomicBoolean(false)
    val origin = "https://$miniId.stmini.local"
    val entryUrl: String get() = url(entry)

    fun url(path: String): String = Uri.Builder().scheme("https")
        .authority("$miniId.stmini.local").apply { path.split('/').forEach(::appendPath) }.build().toString()

    fun path(raw: String): String? = decodePath(raw, "https", "$miniId.stmini.local")
    fun html(raw: String): Boolean = path(raw)?.substringAfterLast('.', "")?.lowercase() in listOf("html", "htm")

    fun response(raw: String, method: String, identityInvalid: () -> Unit = {}, current: () -> Boolean): WebResourceResponse {
        val path = path(raw) ?: return rejected()
        if (method != "GET" || closed.get() || !permits.tryAcquire()) return rejected()
        var transferred = false
        try {
            val deadline = System.nanoTime() + 4_000_000_000L
            val check = {
                if (closed.get() || !current() || System.nanoTime() >= deadline) throw LocalPackageInventory.Unavailable()
            }
            val file = inventory.verifiedResource(miniId, version, entry, path, check)
            val size = file.length()
            if (size < 0 || size > 8L * 1024 * 1024) return rejected()
            val bytes = ByteArray(size.toInt())
            file.inputStream().use { input ->
                var offset = 0
                while (offset < bytes.size) {
                    check()
                    val count = input.read(bytes, offset, minOf(65536, bytes.size - offset))
                    if (count <= 0) throw LocalPackageInventory.Unavailable()
                    offset += count
                }
                check()
                if (input.read() != -1) throw LocalPackageInventory.Unavailable()
            }
            val after = inventory.verifiedResource(miniId, version, entry, path, check)
            if (after != file || after.length() != size) return rejected()
            check()
            val stream = BudgetStream(bytes)
            synchronized(active) {
                if (closed.get() || !current()) return rejected()
                active.add(stream)
                transferred = true
            }
            val mime = mime(path)
            return WebResourceResponse(mime, if (isText(mime)) "UTF-8" else null, 200, "OK",
                mapOf("Content-Security-Policy" to csp(), "X-Content-Type-Options" to "nosniff", "Cache-Control" to "no-store"), stream)
        } catch (_: LocalPackageInventory.IdentityInvalid) {
            if (!closed.get() && current()) identityInvalid()
            return rejected()
        } catch (_: Exception) { return rejected() }
        finally { if (!transferred) permits.release() }
    }

    fun close() {
        closed.set(true)
        val streams = synchronized(active) { active.toList() }
        streams.forEach { it.close() }
    }

    private inner class BudgetStream(bytes: ByteArray) : InputStream() {
        private var input: ByteArrayInputStream? = ByteArrayInputStream(bytes)
        @Synchronized override fun read(): Int {
            val value = input?.read() ?: -1
            if (value == -1) close()
            return value
        }
        @Synchronized override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            val value = input?.read(buffer, offset, length) ?: -1
            if (value == -1) close()
            return value
        }
        @Synchronized override fun close() {
            if (input == null) return
            input = null
            synchronized(active) { active.remove(this) }
            permits.release()
        }
    }

    companion object {
        fun decodePath(raw: String, scheme: String, host: String): String? = try {
            val uri = Uri.parse(raw)
            val encoded = uri.encodedPath ?: ""
            if (uri.scheme != scheme || uri.encodedAuthority != host || uri.encodedQuery != null ||
                !encoded.startsWith("/") || encoded.startsWith("//")) null else {
                val source = encoded.substring(1)
                val output = java.io.ByteArrayOutputStream()
                var index = 0
                while (index < source.length) {
                    val char = source[index]
                    if (char == '%') {
                        if (index + 2 >= source.length) throw IllegalArgumentException()
                        val value = source.substring(index + 1, index + 3).toInt(16)
                        if (value in listOf(0x2f, 0x5c, 0x25)) throw IllegalArgumentException()
                        output.write(value); index += 3
                    } else {
                        if (char.code > 127) throw IllegalArgumentException()
                        output.write(char.code); index++
                    }
                }
                val path = StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(output.toByteArray())).toString()
                path.takeIf { LocalPackageInventory.safePath(it) }
            }
        } catch (_: Exception) { null }
        // 'self' preserves the exact document origin even when the staged ID
        // contains '_', which Chromium rejects inside a CSP host-source token.
        fun csp() = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'none'; frame-src 'none'; child-src 'none'; worker-src 'none'; object-src 'none'; form-action 'none'; base-uri 'none'"
        fun mime(path: String) = when (path.substringAfterLast('.', "").lowercase()) {
            "html", "htm" -> "text/html"; "css" -> "text/css"; "js", "mjs" -> "application/javascript"
            "json" -> "application/json"; "svg" -> "image/svg+xml"; "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"; "gif" -> "image/gif"; "webp" -> "image/webp"; "ico" -> "image/x-icon"
            "woff" -> "font/woff"; "woff2" -> "font/woff2"; "ttf" -> "font/ttf"; "otf" -> "font/otf"
            else -> "application/octet-stream"
        }
        fun isText(mime: String) = mime.startsWith("text/") || mime in listOf("application/javascript", "application/json", "image/svg+xml")
        fun rejected() = WebResourceResponse("text/plain", "UTF-8", 403, "Forbidden",
            mapOf("Cache-Control" to "no-store", "Content-Security-Policy" to "default-src 'none'"), ByteArrayInputStream(ByteArray(0)))
    }
}
