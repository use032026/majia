package com.fsst.stmini_flutter.runtime

import android.content.Context
import android.net.Uri
import android.os.SystemClock
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeoutException
import java.util.zip.ZipInputStream

/**
 * Generic, private Mini package store. ZIP archives are always installed to a
 * staging directory, validated, then renamed into place; WebView never opens
 * an archive or a `file://` URL directly.
 */
class MiniPackageStore(private val context: Context) {
    data class InstalledPackage(
        val miniId: String,
        val miniName: String,
        val iconUrl: String,
        val launchLink: String,
        val version: String,
        val entry: String,
        val updateSelf: String,
        /** Optional English label and local icon from the verified manifest. */
        val miniNameEn: String = "",
        val icon: String = "",
        /** Root-only presentation/close policy, trusted only from the manifest. */
        val isHome: Boolean = false,
        /** Transient install receipt; never persisted as package metadata. */
        val installationChanged: Boolean = false
    )

    companion object {
        private const val MAX_ARCHIVE_BYTES = 80L * 1024L * 1024L
        private const val MAX_UNPACKED_BYTES = 160L * 1024L * 1024L
        private const val DOWNLOAD_ATTEMPT_TIMEOUT_MS = 60_000L
        private const val DOWNLOAD_TOTAL_TIMEOUT_MS = 180_000L
        private const val DOWNLOAD_RETRY_DELAY_MS = 600L
        private const val MANIFEST_FILE = "mini-manifest.json"
        private const val RECORD_FILE = ".st-mini-package.json"
        private const val LOCAL_HOST_SUFFIX = ".stmini.local"
        private val executor = Executors.newSingleThreadExecutor { task ->
            Thread(task, "stmini-package-install").apply { isDaemon = true }
        }
    }

    fun installedPackages(): List<InstalledPackage> = packageRoot().listFiles()
        ?.mapNotNull { directory -> readInstalled(directory.name) }
        ?.sortedBy(InstalledPackage::miniId)
        ?: emptyList()

    fun installed(miniId: String): InstalledPackage? = readInstalled(miniId)

    /** True only when the link requires replacing the verified local package. */
    fun requiresUpdate(installed: InstalledPackage, link: MiniLink): Boolean {
        val minimum = link.minSupportVersion
        if (minimum != null && compareVersion(installed.version, minimum) < 0) return true
        val current = link.currentVersion
        return current != null && compareVersion(installed.version, current) < 0
    }

    /** minSupport is the runtime floor; current is the floor only without it. */
    fun canRunInstalled(installed: InstalledPackage, link: MiniLink): Boolean {
        val floor = link.minSupportVersion ?: link.currentVersion ?: return true
        return compareVersion(installed.version, floor) >= 0
    }

    fun resolveLocalPage(miniId: String, rawUrl: String, expectedVersion: String? = null, expectedEntry: String? = null): File? {
        val uri = runCatching { Uri.parse(rawUrl) }.getOrNull() ?: return null
        if (!uri.scheme.equals("https", true) || uri.userInfo != null || uri.port != -1 ||
            !uri.host.equals("${miniId.lowercase()}$LOCAL_HOST_SUFFIX", true)) return null
        // Full runtime routes may retain a query/fragment, but only the
        // strictly decoded local path chooses a file. Neither can select a root.
        val plain = uri.buildUpon().scheme("https").encodedAuthority("${miniId.lowercase()}$LOCAL_HOST_SUFFIX")
            .clearQuery().fragment(null).build().toString()
        val relative = LocalMiniResource.decodePath(plain, "https", "${miniId.lowercase()}$LOCAL_HOST_SUFFIX") ?: return null
        val current = installed(miniId) ?: return null
        if ((expectedVersion != null && current.version != expectedVersion) ||
            (expectedEntry != null && current.entry != expectedEntry)) return null
        return packageFile(miniId, relative)
    }

    fun entryUrl(info: InstalledPackage, route: String?): String? {
        val selected = if (route.isNullOrBlank()) LocalRoute(info.entry, null, null) else parseLocalRoute(route)
        val routeParts = selected ?: return null
        if (packageFile(info.miniId, routeParts.relative) == null) return null
        return localUrl(info.miniId, routeParts)
    }

    fun localPageUrl(info: InstalledPackage, path: String): String? {
        val route = parseLocalRoute(path) ?: return null
        if (packageFile(info.miniId, route.relative) == null) return null
        return localUrl(info.miniId, route)
    }

    private data class LocalRoute(val relative: String, val encodedQuery: String?, val encodedFragment: String?)

    private fun parseLocalRoute(raw: String): LocalRoute? {
        val uri = runCatching { Uri.parse(raw.trim()) }.getOrNull() ?: return null
        if (uri.isAbsolute || uri.authority != null || uri.userInfo != null) return null
        val relative = uri.path?.trimStart('/')?.takeIf(::safeRelativePath) ?: return null
        return LocalRoute(relative, uri.encodedQuery, uri.encodedFragment)
    }

    private fun localUrl(miniId: String, route: LocalRoute): String = Uri.Builder()
            .scheme("https")
            .authority("${miniId}$LOCAL_HOST_SUFFIX")
            .apply {
                route.relative.split('/').forEach(::appendPath)
                route.encodedQuery?.let(::encodedQuery)
                route.encodedFragment?.let(::encodedFragment)
            }
            .build().toString()

    fun installUpdateAsync(
        installed: InstalledPackage,
        downloadUrl: String,
        emit: (String, Map<String, Any?>) -> Unit,
        completed: (Result<InstalledPackage>) -> Unit
    ) = installUpdateAsync(installed, downloadUrl, false, emit, completed)

    fun installUpdateAsync(
        installed: InstalledPackage,
        downloadUrl: String,
        requiresNewerVersion: Boolean,
        emit: (String, Map<String, Any?>) -> Unit,
        completed: (Result<InstalledPackage>) -> Unit
    ) = enqueueInstall(
        MiniLink(
            miniId = installed.miniId,
            rawLink = "mini://${installed.miniId}?downloadUrl=${Uri.encode(downloadUrl)}",
            downloadUrl = downloadUrl,
            currentVersion = null,
            minSupportVersion = null,
            displayName = installed.miniName,
            displayNameEn = installed.miniNameEn,
            iconUrl = installed.iconUrl,
            path = null
        ),
        emit,
        completed,
        requiresNewerVersion
    )

    fun installAsync(
        link: MiniLink,
        emit: (String, Map<String, Any?>) -> Unit,
        completed: (Result<InstalledPackage>) -> Unit
    ) = enqueueInstall(link, emit, completed, false)

    private fun enqueueInstall(
        link: MiniLink,
        emit: (String, Map<String, Any?>) -> Unit,
        completed: (Result<InstalledPackage>) -> Unit,
        requiresNewerVersion: Boolean
    ) {
        executor.execute {
            completed(runCatching { install(link, emit, requiresNewerVersion) })
        }
    }

    private fun install(link: MiniLink, emit: (String, Map<String, Any?>) -> Unit, requiresNewerVersion: Boolean): InstalledPackage {
        val downloadUrl = link.downloadUrl ?: throw IllegalArgumentException("首次安装缺少 downloadUrl")
        StminiHostConfiguration.security.urlRejectionReason(downloadUrl)?.let { throw SecurityException(it) }
        LocalPackageInventory(context.filesDir).read { }
        val root = packageRoot()
        root.mkdirs()
        val staging = File(root, ".${link.miniId}.${UUID.randomUUID()}.staging")
        val archive = File(root, ".${link.miniId}.${UUID.randomUUID()}.zip")
        try {
            emit("mini_download_started", mapOf("miniId" to link.miniId))
            download(downloadUrl, archive, link.miniId, emit) { downloaded, total ->
                // Keep Android's established `downloadedBytes`, and add the
                // iOS-compatible aliases so Flutter consumers can share one
                // progress reader without a platform branch.
                emit("mini_download_progress", mapOf(
                    "miniId" to link.miniId,
                    "downloadedBytes" to downloaded,
                    "receivedBytes" to downloaded,
                    "totalBytes" to total,
                    "percent" to if (total > 0L) ((downloaded * 100L / total).toInt() / 10) * 10 else null
                ))
            }
            // The archive's final byte is not the end of the user-visible
            // launch. The host now validates, unpacks and atomically installs
            // it, so consumers must leave determinate 100% immediately.
            emit("mini_download_completed", mapOf("miniId" to link.miniId))
            unzipSafely(archive, staging)
            val manifest = readManifest(staging)
            require(manifest.miniId == link.miniId) { "Mini 包标识与链接不一致" }
            if (link.currentVersion != null && compareVersion(manifest.version, link.currentVersion) < 0) {
                throw IllegalStateException("Mini 包版本低于链接声明版本")
            }
            if (link.minSupportVersion != null && compareVersion(manifest.version, link.minSupportVersion) < 0) {
                throw IllegalStateException("Mini 包版本低于最低支持版本")
            }
            // The shared serial installer owns commits. Re-read verified disk
            // now, never trust an earlier caller's installed snapshot.
            val currentInstalled = readInstalled(link.miniId)
            if (currentInstalled != null && compareVersion(manifest.version, currentInstalled.version) <= 0) {
                if (requiresNewerVersion && compareVersion(manifest.version, currentInstalled.version) < 0) {
                    throw IllegalStateException("下载的小程序版本低于本地版本")
                }
                return currentInstalled.copy(installationChanged = false)
            }
            val record = JSONObject().apply {
                put("miniId", manifest.miniId)
                put("miniName", link.displayName ?: manifest.name)
                put("miniNameEn", link.displayNameEn ?: manifest.nameEn)
                put("iconUrl", link.iconUrl ?: "")
                put("launchLink", link.rawLink)
                put("channel", JSONObject(File(staging, MANIFEST_FILE).readText(StandardCharsets.UTF_8)).optString("channel", ""))
                put("version", manifest.version)
                put("entry", manifest.entry)
                put("updateself", manifest.updateSelf)
                put("icon", manifest.icon)
                put("ishome", if (manifest.isHome) "1" else "0")
            }
            File(staging, RECORD_FILE).writeText(record.toString(), StandardCharsets.UTF_8)
            val target = packageDirectory(link.miniId)
            val backup = File(root, ".${link.miniId}.${UUID.randomUUID()}.backup")
            backup.deleteRecursively()
            if (target.exists() && !target.renameTo(backup)) throw IllegalStateException("无法备份旧 Mini 包")
            if (!staging.renameTo(target)) {
                if (backup.exists()) backup.renameTo(target)
                throw IllegalStateException("无法安装 Mini 包")
            }
            val verified = readInstalled(link.miniId) ?: run {
                target.deleteRecursively()
                if (backup.exists()) backup.renameTo(target)
                throw IllegalStateException("已安装 Mini 包校验失败")
            }
            backup.deleteRecursively()
            return verified.copy(installationChanged = true)
        } finally {
            archive.delete()
            staging.deleteRecursively()
        }
    }

    private data class Manifest(
        val miniId: String,
        val name: String,
        val nameEn: String,
        val version: String,
        val entry: String,
        val updateSelf: String,
        val icon: String,
        val isHome: Boolean
    )

    private fun readManifest(directory: File): Manifest {
        val file = File(directory, MANIFEST_FILE)
        require(file.isFile) { "Mini 包缺少 $MANIFEST_FILE" }
        val json = JSONObject(file.readText(StandardCharsets.UTF_8))
        val miniId = json.optString("miniId").trim().lowercase()
        val version = json.optString("version").trim()
        val entry = json.optString("entry", "index.html").trim().trimStart('/')
        require(miniId.isNotEmpty() && version.isNotEmpty() && safeRelativePath(entry)) { "Mini 清单无效" }
        require(File(directory, entry).isFile) { "Mini 入口文件不存在" }
        val declaredUpdateSelf = json.optString("updateself", "").trim()
        require(declaredUpdateSelf.isEmpty() || declaredUpdateSelf == "0" || declaredUpdateSelf == "1") {
            "Mini 清单更新策略无效"
        }
        // Legacy manifests default to self-managed updates, matching iOS.
        val updateSelf = if (declaredUpdateSelf == "0") "0" else "1"
        val icon = json.optString("icon", "").trim().trimStart('/')
        require(icon.isEmpty() || (safeRelativePath(icon) && File(directory, icon).isFile)) {
            "Mini 清单图标无效"
        }
        return Manifest(
            miniId = miniId,
            name = json.optString("miniName", miniId),
            nameEn = json.optString("miniNameEn", ""),
            version = version,
            entry = entry,
            updateSelf = updateSelf,
            icon = icon,
            // Do not accept truthy aliases here. The package contract uses
            // the literal string `"1"`; anything else is an ordinary Mini.
            isHome = json.optString("ishome", "").trim() == "1"
        )
    }

    private fun readInstalled(miniId: String): InstalledPackage? = runCatching {
        val strict = LocalPackageInventory(context.filesDir).read { }.firstOrNull { it["miniId"] == miniId }
            ?: return@runCatching null
        val directory = packageDirectory(miniId)
        val record = JSONObject(File(directory, RECORD_FILE).readText(StandardCharsets.UTF_8))
        val recorded = InstalledPackage(
            miniId = record.getString("miniId").lowercase(),
            miniName = record.optString("miniName"),
            iconUrl = record.optString("iconUrl"),
            launchLink = record.optString("launchLink"),
            version = record.getString("version"),
            entry = record.getString("entry"),
            updateSelf = record.optString("updateself", ""),
            miniNameEn = record.optString("miniNameEn", ""),
            icon = record.optString("icon", ""),
            isHome = record.optString("ishome", "") == "1"
        )
        val manifest = readManifest(directory)
        if (
            recorded.miniId != miniId.lowercase() ||
            manifest.miniId != miniId.lowercase() ||
            recorded.version != manifest.version ||
            recorded.entry != manifest.entry ||
            !safeRelativePath(recorded.entry) ||
            strict["entry"] != recorded.entry || strict["version"] != recorded.version
        ) null else recorded.copy(
            updateSelf = manifest.updateSelf,
            // A verified manifest is the final local source of identity. The
            // record retains optional link presentation only for old packages.
            miniName = recorded.miniName.ifBlank { manifest.name },
            miniNameEn = recorded.miniNameEn.ifBlank { manifest.nameEn },
            icon = manifest.icon,
            // The record is only an atomic-install marker. A later read must
            // always re-derive root policy from the verified package manifest.
            isHome = manifest.isHome
        )
    }.getOrNull()

    /** The manifest was verified during [installed], so this local icon is safe to render. */
    fun installedIconFile(info: InstalledPackage): File? = info.icon.takeIf(::safeRelativePath)
        ?.let { packageFile(info.miniId, it) }

    private fun packageRoot() = File(context.filesDir, "STMini")
    private fun packageDirectory(miniId: String) = File(packageRoot(), miniId.lowercase())
    private fun packageFile(miniId: String, relative: String): File? = runCatching {
        if (!safeRelativePath(relative)) return@runCatching null
        val info = readInstalled(miniId) ?: return@runCatching null
        LocalPackageInventory(context.filesDir).verifiedResource(miniId, info.version, info.entry, relative) { }
    }.getOrNull()

    private fun download(
        url: String,
        target: File,
        miniId: String,
        emit: (String, Map<String, Any?>) -> Unit,
        progress: (Long, Long) -> Unit
    ) {
        val deadline = SystemClock.elapsedRealtime() + DOWNLOAD_TOTAL_TIMEOUT_MS
        var lastError: Exception? = null
        repeat(2) { attempt ->
            target.delete()
            try {
                downloadOnce(url, target, deadline, progress)
                return
            } catch (error: Exception) {
                if (error is SecurityException || SystemClock.elapsedRealtime() >= deadline || attempt == 1) throw error
                lastError = error
                emit("mini_download_retry", mapOf("miniId" to miniId, "attempt" to (attempt + 2), "delayMs" to DOWNLOAD_RETRY_DELAY_MS))
                Thread.sleep(minOf(DOWNLOAD_RETRY_DELAY_MS, (deadline - SystemClock.elapsedRealtime()).coerceAtLeast(0L)))
            }
        }
        throw lastError ?: TimeoutException("小程序下载超时")
    }

    private fun downloadOnce(url: String, target: File, deadline: Long, progress: (Long, Long) -> Unit) {
        var currentUrl = URL(url)
        repeat(4) {
            val remaining = deadline - SystemClock.elapsedRealtime()
            if (remaining <= 0) throw TimeoutException("小程序下载超时")
            val connection = (currentUrl.openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = false
                connectTimeout = minOf(30_000L, remaining).toInt()
                readTimeout = minOf(DOWNLOAD_ATTEMPT_TIMEOUT_MS, remaining).toInt()
                requestMethod = "GET"
            }
            try {
                val status = connection.responseCode
                if (status in 300..399) {
                    val location = connection.getHeaderField("Location") ?: throw IllegalStateException("下载重定向缺少地址")
                    val next = URL(currentUrl, location)
                    StminiHostConfiguration.security.urlRejectionReason(next.toString())?.let { throw SecurityException(it) }
                    currentUrl = next
                    return@repeat
                }
                if (status !in 200..299) throw IllegalStateException("Mini 下载失败 HTTP $status")
                val length = connection.contentLengthLong
                if (length > MAX_ARCHIVE_BYTES) throw IllegalStateException("Mini 包过大")
                var total = 0L
                BufferedInputStream(connection.inputStream).use { input ->
                    FileOutputStream(target).use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            if (SystemClock.elapsedRealtime() >= deadline) throw TimeoutException("小程序下载超时")
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            if (total > MAX_ARCHIVE_BYTES) throw IllegalStateException("Mini 包过大")
                            output.write(buffer, 0, count)
                            progress(total, length)
                        }
                    }
                }
                return
            } finally {
                connection.disconnect()
            }
        }
        throw IllegalStateException("Mini 下载重定向过多")
    }

    private fun unzipSafely(archive: File, target: File) {
        target.mkdirs()
        var unpacked = 0L
        ZipInputStream(BufferedInputStream(FileInputStream(archive))).use { input ->
            while (true) {
                val entry = input.nextEntry ?: break
                val name = entry.name.replace('\\', '/')
                val safeName = name.trimEnd('/')
                require(safeRelativePath(safeName)) { "Mini 包含非法文件路径" }
                val output = File(target, safeName).canonicalFile
                require(output.path.startsWith(target.canonicalPath + File.separator)) { "Mini 包路径越界" }
                if (entry.isDirectory) {
                    output.mkdirs()
                    input.closeEntry()
                    continue
                }
                output.parentFile?.mkdirs()
                FileOutputStream(output).use { stream ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        unpacked += count
                        if (unpacked > MAX_UNPACKED_BYTES) throw IllegalStateException("Mini 解压后过大")
                        stream.write(buffer, 0, count)
                    }
                }
                input.closeEntry()
            }
        }
    }

    private fun safeRelativePath(path: String): Boolean = path.isNotBlank() &&
        !path.startsWith('/') && !path.contains("\\") &&
        path.split('/').none { it.isEmpty() || it == "." || it == ".." }

    private fun compareVersion(left: String, right: String): Int {
        val a = left.split('.', '-', '_').map { it.toIntOrNull() ?: 0 }
        val b = right.split('.', '-', '_').map { it.toIntOrNull() ?: 0 }
        val length = maxOf(a.size, b.size)
        for (index in 0 until length) {
            val result = (a.getOrElse(index) { 0 }).compareTo(b.getOrElse(index) { 0 })
            if (result != 0) return result
        }
        return 0
    }
}
