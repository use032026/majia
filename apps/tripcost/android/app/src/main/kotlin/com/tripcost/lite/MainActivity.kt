package com.tripcost.lite

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermission: String? = null
    private var pendingBackupPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        VisionOcrApi.setUp(messenger, AndroidVisionOcrApi(this))
        CloudSyncApi.setUp(messenger, AndroidCloudSyncApi())
        SharedSnapshotApi.setUp(messenger, AndroidSharedSnapshotApi())
        WidgetControlApi.setUp(messenger, AndroidWidgetControlApi())

        MethodChannel(messenger, PERMISSION_CHANNEL)
            .setMethodCallHandler(::handlePermissionCall)
        MethodChannel(messenger, PHOTO_CHANNEL)
            .setMethodCallHandler(::handlePhotoCall)
        MethodChannel(messenger, DOCUMENT_CHANNEL)
            .setMethodCallHandler(::handleDocumentCall)
    }

    private fun handlePermissionCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "openSettings") {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            )
            result.success(runCatching { startActivity(intent) }.isSuccess)
            return
        }

        val permission = call.argument<String>("permission")
        when (call.method) {
            "status" -> result.success(permissionStatus(permission))
            "request" -> requestPermission(permission, result)
            else -> result.notImplemented()
        }
    }

    private fun permissionStatus(permission: String?): String {
        if (permission == "photoLibrary" && Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
            // Image Picker uses Android's scoped system picker on modern
            // releases, so no broad photo-library permission is needed.
            return "granted"
        }
        val androidPermission = androidPermission(permission) ?: return "unavailable"
        if (ContextCompat.checkSelfPermission(this, androidPermission) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return "granted"
        }
        val prompted = getSharedPreferences(PERMISSION_PREFERENCES, MODE_PRIVATE)
            .getBoolean("prompted_$permission", false)
        return if (prompted) "denied" else "notDetermined"
    }

    private fun androidPermission(permission: String?): String? = when (permission) {
        "camera" -> Manifest.permission.CAMERA
        "photoLibrary" -> if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        } else {
            null
        }
        else -> null
    }

    private fun requestPermission(permission: String?, result: MethodChannel.Result) {
        if (permission == "photoLibrary" && Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
            result.success("granted")
            return
        }
        val androidPermission = androidPermission(permission)
        if (androidPermission == null || pendingPermissionResult != null) {
            result.success("unavailable")
            return
        }
        if (permissionStatus(permission) == "granted") {
            result.success("granted")
            return
        }
        getSharedPreferences(PERMISSION_PREFERENCES, MODE_PRIVATE)
            .edit()
            .putBoolean("prompted_$permission", true)
            .apply()
        pendingPermissionResult = result
        pendingPermission = permission
        ActivityCompat.requestPermissions(
            this,
            arrayOf(androidPermission),
            PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        pendingPermissionResult?.success(permissionStatus(pendingPermission))
        pendingPermissionResult = null
        pendingPermission = null
    }

    private fun handlePhotoCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "savePng") {
            result.notImplemented()
            return
        }
        val bytes = call.arguments as? ByteArray
        if (bytes == null || bytes.isEmpty()) {
            result.error("invalid-image", "A PNG image is required.", null)
            return
        }
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            permissionStatus("photoLibrary") != "granted"
        ) {
            result.error(
                "photo-permission-denied",
                "Permission to add photos was not granted.",
                null,
            )
            return
        }
        Thread {
            runCatching { savePng(bytes) }
                .onSuccess { runOnUiThread { result.success(null) } }
                .onFailure { error ->
                    runOnUiThread {
                        result.error("photo-save-failed", error.localizedMessage, null)
                    }
                }
        }.start()
    }

    private fun savePng(bytes: ByteArray) {
        val values = ContentValues().apply {
            put(
                MediaStore.Images.Media.DISPLAY_NAME,
                "roamsum-trip-summary-${System.currentTimeMillis()}.png",
            )
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/RoamSum",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val resolver = contentResolver
        val uri = checkNotNull(
            resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values),
        ) { "Could not create a photo-library item." }
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: error("Could not open the photo-library output stream.")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun handleDocumentCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "generatePdf" -> {
                @Suppress("UNCHECKED_CAST")
                val document = call.arguments as? Map<String, Any?>
                if (document == null) {
                    result.error("invalid-document", "Missing PDF document.", null)
                    return
                }
                Thread {
                    runCatching { ExpensePdfRenderer.render(cacheDir, document) }
                        .onSuccess { file -> runOnUiThread { result.success(file.path) } }
                        .onFailure { error ->
                            runOnUiThread {
                                result.error("pdf-failed", error.localizedMessage, null)
                            }
                        }
                }.start()
            }
            "shareFiles" -> shareFiles(call, result)
            "pickBackupFile" -> pickBackupFile(result)
            else -> result.notImplemented()
        }
    }

    private fun shareFiles(call: MethodCall, result: MethodChannel.Result) {
        val paths = call.argument<List<String>>("paths").orEmpty()
        val files = paths.map(::File)
        if (files.isEmpty() || files.any { !it.isFile }) {
            result.error("share-unavailable", "A file is unavailable.", null)
            return
        }
        val uris = ArrayList(files.map { file ->
            FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        })
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = if (files.all { it.extension.lowercase(Locale.ROOT) == "pdf" }) {
                "application/pdf"
            } else {
                "application/octet-stream"
            }
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        runCatching {
            startActivity(Intent.createChooser(intent, null))
        }.onSuccess {
            result.success(null)
        }.onFailure { error ->
            result.error("share-unavailable", error.localizedMessage, null)
        }
    }

    private fun pickBackupFile(result: MethodChannel.Result) {
        if (pendingBackupPickerResult != null) {
            result.error("picker-unavailable", "A file picker is already open.", null)
            return
        }
        pendingBackupPickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
        }
        runCatching { startActivityForResult(intent, BACKUP_PICKER_REQUEST) }
            .onFailure { error ->
                pendingBackupPickerResult = null
                result.error("picker-unavailable", error.localizedMessage, null)
            }
    }

    @Deprecated("Deprecated in Android SDK, retained for FlutterActivity compatibility.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != BACKUP_PICKER_REQUEST) return
        val result = pendingBackupPickerResult
        pendingBackupPickerResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return
        }
        val uri = data.data!!
        runCatching {
            val destination = File(cacheDir, "roamsum-restore-${System.currentTimeMillis()}.json")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destination).use(input::copyTo)
            } ?: error("Could not read the selected backup.")
            destination.path
        }.onSuccess { path -> result?.success(path) }.onFailure { error ->
            result?.error("picker-unavailable", error.localizedMessage, null)
        }
    }

    companion object {
        private const val PERMISSION_CHANNEL = "trip_cost/permissions"
        private const val PHOTO_CHANNEL = "trip_cost/photos"
        private const val DOCUMENT_CHANNEL = "trip_cost/documents"
        private const val PERMISSION_PREFERENCES = "tripcost-permissions"
        private const val PERMISSION_REQUEST = 4101
        private const val BACKUP_PICKER_REQUEST = 4102
    }
}

private class AndroidVisionOcrApi(private val activity: Activity) : VisionOcrApi {
    override fun supportedRecognitionLanguages(): List<String> =
        listOf("en", "zh-Hans", "zh-Hant")

    override fun recognizeImage(request: OcrRequest, callback: (Result<OcrResult>) -> Unit) {
        if (request.contractVersion != CONTRACT_VERSION) {
            callback(
                Result.failure(
                    FlutterError("unsupported-contract", "Unsupported OCR contract version."),
                ),
            )
            return
        }
        val file = File(request.imagePath)
        if (!file.isFile) {
            callback(Result.failure(FlutterError("image-not-found", "Image was not found.")))
            return
        }
        val image = runCatching { InputImage.fromFilePath(activity, Uri.fromFile(file)) }
            .getOrElse { error ->
                callback(Result.failure(FlutterError("invalid-image", error.localizedMessage)))
                return
            }
        val recognizesChinese = request.preferredLanguages.any {
            it.lowercase(Locale.ROOT).startsWith("zh")
        }
        val recognizer = if (recognizesChinese) {
            TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
        } else {
            TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        }
        recognizer.process(image)
            .addOnSuccessListener { text ->
                val candidates = text.textBlocks.flatMap { block ->
                    block.lines.map { line ->
                        // ML Kit does not expose stable per-line confidence across
                        // every script. Suppress coordinate overlays until the two
                        // platform coordinate systems can be normalized exactly.
                        OcrCandidate(
                            text = line.text,
                            confidence = 0.85,
                            x = 0.0,
                            y = 0.0,
                            width = 0.0,
                            height = 0.0,
                        )
                    }
                }
                callback(Result.success(OcrResult(CONTRACT_VERSION, candidates)))
                recognizer.close()
            }
            .addOnFailureListener { error ->
                callback(
                    Result.failure(
                        FlutterError("recognition-failed", error.localizedMessage),
                    ),
                )
                recognizer.close()
            }

    }

    companion object {
        private const val CONTRACT_VERSION = 1L
    }
}

private class AndroidCloudSyncApi : CloudSyncApi {
    override fun accountStatus(callback: (Result<CloudAccountState>) -> Unit) {
        callback(Result.success(CloudAccountState.RESTRICTED))
    }

    override fun pushChanges(
        records: List<SyncRecord>,
        cursor: String?,
        callback: (Result<SyncPushResult>) -> Unit,
    ) {
        callback(Result.failure(unsupportedCloudSync()))
    }

    override fun pullChanges(
        cursor: String?,
        callback: (Result<SyncPullResult>) -> Unit,
    ) {
        callback(Result.failure(unsupportedCloudSync()))
    }

    private fun unsupportedCloudSync() = FlutterError(
        "unsupported-platform",
        "iCloud sync is only available on Apple platforms.",
    )
}

private class AndroidSharedSnapshotApi : SharedSnapshotApi {
    override fun writeWidgetSnapshot(
        snapshot: SharedSnapshot,
        callback: (Result<Unit>) -> Unit,
    ) = callback(Result.success(Unit))

    override fun clearWidgetSnapshot(callback: (Result<Unit>) -> Unit) =
        callback(Result.success(Unit))
}

private class AndroidWidgetControlApi : WidgetControlApi {
    override fun reloadTimelines() = Unit
}

private object ExpensePdfRenderer {
    private const val PAGE_WIDTH = 595
    private const val PAGE_HEIGHT = 842
    private const val MARGIN = 40f

    fun render(cacheDirectory: File, document: Map<String, Any?>): File {
        val rows = document["rows"] as? List<*> ?: error("Expense rows are missing.")
        require(rows.isNotEmpty()) { "Expense rows are empty." }
        val outputDirectory = File(cacheDirectory, "roamsum-exports").apply { mkdirs() }
        val requestedName = document["filename"]?.toString().orEmpty()
        val safeName = requestedName
            .replace(Regex("[^A-Za-z0-9._-]"), "-")
            .takeIf { it.endsWith(".pdf", ignoreCase = true) }
            ?: "roamsum-expenses.pdf"
        val destination = File(outputDirectory, safeName)
        val pdf = PdfDocument()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK
            textSize = 11f
        }
        var pageNumber = 0
        var page: PdfDocument.Page? = null
        var y = MARGIN

        fun beginPage() {
            page?.let(pdf::finishPage)
            pageNumber += 1
            page = pdf.startPage(
                PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, pageNumber).create(),
            )
            y = MARGIN
        }

        fun drawLine(value: String, size: Float = 11f) {
            if (y > PAGE_HEIGHT - MARGIN) beginPage()
            paint.textSize = size
            page!!.canvas.drawText(value.take(100), MARGIN, y, paint)
            y += size + 7f
        }

        beginPage()
        paint.isFakeBoldText = true
        drawLine(document["title"]?.toString() ?: "RoamSum expenses", 20f)
        paint.isFakeBoldText = false
        drawLine(document["generatedAt"]?.toString().orEmpty(), 10f)
        y += 8f
        for (rawRow in rows) {
            val row = rawRow as? Map<*, *> ?: continue
            paint.isFakeBoldText = true
            drawLine(row["title"]?.toString().orEmpty(), 13f)
            paint.isFakeBoldText = false
            drawLine(row["occurredAt"]?.toString().orEmpty(), 9f)
            drawLine(
                "${row["transactionAmount"].orEmpty()} ${row["transactionCurrency"].orEmpty()}  " +
                    "→ ${row["estimatedAmount"].orEmpty()} ${row["homeCurrency"].orEmpty()}",
            )
            drawLine(
                "Rate ${row["rate"].orEmpty()} · ${row["rateDate"].orEmpty()} · " +
                    row["rateSource"].orEmpty(),
                9f,
            )
            y += 9f
        }
        val disclaimer = document["disclaimer"]?.toString().orEmpty()
        if (disclaimer.isNotBlank()) {
            y += 6f
            drawLine(disclaimer, 8f)
        }
        page?.let(pdf::finishPage)
        FileOutputStream(destination).use(pdf::writeTo)
        pdf.close()
        return destination
    }

    private fun Any?.orEmpty(): String = this?.toString().orEmpty()
}
