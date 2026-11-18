package com.fsst.stmini_flutter.runtime

import android.system.Os
import android.system.OsConstants
import android.system.ErrnoException
import android.util.JsonReader
import android.util.JsonToken
import java.io.StringReader
import org.json.JSONObject
import org.json.JSONTokener
import java.io.File
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/** Derived from pinned main MiniPackageStore's read-only record/manifest checks.
 * No downloader, installer, page router or positive validation cache is included.
 * The caller supplies its trusted, private filesDir; no Flutter argument can set it.
 */
class LocalPackageInventory(private val filesDirectory: File) {
    class Unavailable : Exception("Local inventory unavailable")
    class IdentityInvalid : Exception("Bound local package unavailable")
    private class Invalid : Exception()
    private data class PackageInfo(val miniId: String, val miniName: String,
        val version: String, val entry: String, val icon: String) {
        fun wire(): Map<String, String> = mapOf("miniId" to miniId, "miniName" to miniName,
            "version" to version, "entry" to entry, "icon" to icon)
    }

    /** Bounded user-space work; check is also the operation's cancellation/deadline gate. */
    fun read(check: () -> Unit): List<Map<String, String>> {
        check()
        val base = filesDirectory.canonicalFile
        check()
        val root = File(base, "STMini")
        // File.exists/canonicalFile cannot distinguish a missing directory
        // from a dangling symlink on Android. lstat never follows the link.
        try { Os.lstat(root.path) } catch (error: ErrnoException) {
            if (error.errno == OsConstants.ENOENT) { check(); return emptyList() }
            throw Unavailable()
        }
        check()
        if (!plainDirectory(root)) throw Unavailable()
        val children = root.listFiles() ?: throw Unavailable()
        check()
        if (children.count { !it.name.startsWith('.') } > 256) throw Unavailable()
        val result = children.filter { !it.name.startsWith('.') }.mapNotNull { directory ->
            check()
            try { readPackage(directory, check) } catch (_: Invalid) { null }
            catch (_: java.io.IOException) { null } catch (_: org.json.JSONException) { null }
            catch (_: IllegalStateException) { null } catch (_: SecurityException) { null }
        }.sortedBy { it.miniId }.map { it.wire() }
        check()
        return result
    }

    /** Renderer access shares every inventory validation; never accepts a caller-selected root. */
    fun verifiedPackage(miniId: String, version: String, entry: String? = null,
        check: () -> Unit): Map<String, String> {
        val item = read(check).firstOrNull { it["miniId"] == miniId && it["version"] == version }
            ?: throw Unavailable()
        if (entry != null && item["entry"] != entry) throw Unavailable()
        return item
    }

    fun verifiedResource(miniId: String, version: String, entry: String,
        path: String, check: () -> Unit): File {
        try { verifiedPackage(miniId, version, entry, check) }
        catch (_: Exception) {
            // Cancellation/deadline is not an identity change. Only a live
            // request can invalidate its bound renderer generation.
            check()
            throw IdentityInvalid()
        }
        val directory = File(File(filesDirectory.canonicalFile, "STMini"), miniId)
        if (!regularPath(directory, path, check)) throw Unavailable()
        check()
        return File(directory, path)
    }

    private fun readPackage(directory: File, check: () -> Unit): PackageInfo? {
        val id = directory.name
        if (!id.matches(Regex("^[a-z0-9][a-z0-9_-]{0,63}$")) || !plainDirectory(directory)) return null
        val record = jsonFile(directory, ".st-mini-package.json", check)
        val manifest = jsonFile(directory, "mini-manifest.json", check)
        if (string(record, "miniId") != id || string(manifest, "miniId") != id) throw Invalid()
        val version = string(manifest, "version")
        if (!version.matches(Regex("^[0-9]{1,9}(\\.[0-9]{1,9}){0,7}$")) ||
            version != string(record, "version")) throw Invalid()
        val entry = string(manifest, "entry")
        if (entry != string(record, "entry") || !regularPath(directory, entry, check)) throw Invalid()
        val icon = string(manifest, "icon", "")
        if (icon.isNotEmpty() && !regularPath(directory, icon, check)) throw Invalid()
        val channel = string(manifest, "channel", "")
        if (channel.length > 128 || channel != string(record, "channel", "")) throw Invalid()
        for (key in listOf("updateself", "ishome")) {
            if (string(manifest, key, "") !in listOf("", "0", "1")) throw Invalid()
        }
        val name = string(manifest, "miniName", "").ifEmpty { id }
        if (name.length > 256) throw Invalid()
        check()
        return PackageInfo(id, name, version, entry, icon)
    }

    private fun jsonFile(directory: File, name: String, check: () -> Unit): JSONObject {
        check()
        val file = File(directory, name)
        if (!plainFile(file) || file.length() > 65536L) throw Invalid()
        val bytes = file.inputStream().use { input ->
            val output = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(4096)
            while (true) {
                check()
                val count = input.read(buffer)
                if (count < 0) break
                output.write(buffer, 0, count)
                if (output.size() > 65536) throw Invalid()
            }
            output.toByteArray()
        }
        check()
        if (!plainFile(file)) throw Invalid()
        val text = StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString()
        // Android JSONTokener is intentionally lenient. A platform strict
        // grammar pass keeps malformed JSON acceptance aligned with iOS.
        JsonReader(StringReader(text)).use { reader ->
            reader.isLenient = false
            reader.beginObject()
            while (reader.hasNext()) { reader.nextName(); reader.skipValue() }
            reader.endObject()
            if (reader.peek() != JsonToken.END_DOCUMENT) throw Invalid()
        }
        val parser = JSONTokener(text)
        val value = parser.nextValue() as? JSONObject ?: throw Invalid()
        if (parser.nextClean() != '\u0000') throw Invalid()
        return value
    }

    private fun string(json: JSONObject, key: String, missing: String? = null): String {
        if (!json.has(key)) return missing ?: throw Invalid()
        return json.opt(key) as? String ?: throw Invalid()
    }

    private fun regularPath(directory: File, path: String, check: () -> Unit): Boolean {
        if (!safePath(path)) return false
        val parts = path.split('/')
        var current = directory
        parts.forEachIndexed { index, part ->
            check()
            current = File(current, part)
            if (index == parts.lastIndex) {
                if (!plainFile(current)) return false
            } else if (!plainDirectory(current)) return false
        }
        return current.canonicalPath.startsWith(directory.canonicalPath + File.separator)
    }

    private fun plainDirectory(file: File): Boolean = regularType(file, true) && file.canonicalFile == file.absoluteFile
    private fun plainFile(file: File): Boolean = regularType(file, false) && file.canonicalFile == file.absoluteFile
    private fun regularType(file: File, directory: Boolean): Boolean = try {
        val mode = Os.lstat(file.path).st_mode
        if (directory) OsConstants.S_ISDIR(mode) else OsConstants.S_ISREG(mode)
    } catch (_: ErrnoException) { false }

    companion object {
        fun safePath(path: String): Boolean {
            if (path.isEmpty() || path.length > 1024 || path.any {
                it.code < 32 || it.code in 127..159 || it in "\\:%?#"
            }) return false
            val parts = path.split('/')
            return parts.size <= 16 && parts.all { it.isNotEmpty() && it.length <= 128 && it != "." && it != ".." }
        }
    }
}
