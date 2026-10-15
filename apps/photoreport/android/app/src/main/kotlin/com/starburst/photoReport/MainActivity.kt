package com.starburst.photoReport

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var pendingPickerResult: MethodChannel.Result? = null
    private val preferences by lazy { getSharedPreferences("PhotoReportPreferences", MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                handleCall(call, result)
            } catch (error: Exception) {
                result.error("native_error", error.message ?: "Android operation failed", null)
            }
        }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPreferredLanguage" -> result.success(preferences.getString("preferredLanguage", null))
            "clearPreferredLanguage" -> {
                preferences.edit().remove("preferredLanguage").apply()
                result.success(null)
            }
            "setPreferredLanguage" -> {
                val language = call.argument<String>("languageCode")
                if (language !in listOf("zh", "en")) {
                    result.error("invalid_language", "Invalid language setting", null)
                } else {
                    preferences.edit().putString("preferredLanguage", language).apply()
                    result.success(null)
                }
            }
            "getOnboardingComplete" -> result.success(preferences.getBoolean("onboardingComplete", false))
            "setOnboardingComplete" -> {
                val complete = call.argument<Boolean>("isComplete")
                if (complete == null) {
                    result.error("invalid_onboarding_state", "Invalid onboarding state", null)
                } else {
                    preferences.edit().putBoolean("onboardingComplete", complete).apply()
                    result.success(null)
                }
            }
            "generateReport" -> {
                val project = call.argument<Map<*, *>>("project")
                val issues = call.argument<List<*>>("issues")
                val options = call.argument<Map<*, *>>("options")
                if (project == null || issues == null || options == null) {
                    result.error("invalid_payload", "Invalid report data", null)
                    return
                }
                val language = call.argument<String>("languageCode") ?: "zh"
                worker.execute {
                    try {
                        val file = ReportPdfRenderer(applicationContext).generate(project, issues, options, language)
                        runOnUiThread { result.success(file.absolutePath) }
                    } catch (error: Exception) {
                        Log.e("PhotoReport", "PDF generation failed", error)
                        runOnUiThread {
                            result.error("pdf_generation_failed", error.message ?: "PDF generation failed", null)
                        }
                    }
                }
            }
            "previewReport" -> {
                val file = requirePrivateFile(call.argument("path"))
                if (file == null) {
                    result.error("missing_file", "Report file not found", null)
                    return
                }
                startActivity(Intent(this, PdfPreviewActivity::class.java).putExtra(PdfPreviewActivity.EXTRA_PATH, file.path))
                result.success(null)
            }
            "shareReport" -> {
                val file = requirePrivateFile(call.argument("path"))
                if (file == null) {
                    result.error("missing_file", "File not found", null)
                    return
                }
                worker.execute {
                    try {
                        val intent = prepareShareIntent(file)
                        runOnUiThread {
                            try {
                                startActivity(Intent.createChooser(intent, null))
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("share_failed", error.message ?: "Cannot share file", null)
                            }
                        }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("share_failed", error.message ?: "Cannot share file", null) }
                    }
                }
            }
            "pickBackup" -> {
                if (pendingPickerResult != null) {
                    result.error("picker_busy", "The file picker is already in use", null)
                    return
                }
                pendingPickerResult = result
                try {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivityForResult(intent, PICK_BACKUP_REQUEST)
                } catch (error: Exception) {
                    pendingPickerResult = null
                    result.error("picker_unavailable", error.message ?: "File picker unavailable", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    @Deprecated("Used to support the Android document picker on the Flutter activity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_BACKUP_REQUEST) return
        val pending = pendingPickerResult ?: return
        pendingPickerResult = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            pending.success(null)
            return
        }
        worker.execute {
            try {
                val incoming = File(cacheDir, "incoming").apply { mkdirs() }
                val destination = File(incoming, "${UUID.randomUUID()}.prbackup")
                contentResolver.openInputStream(uri)?.use { input ->
                    destination.outputStream().use { output -> input.copyTo(output) }
                } ?: error("Selected backup cannot be read")
                runOnUiThread { pending.success(destination.absolutePath) }
            } catch (error: Exception) {
                runOnUiThread { pending.error("backup_import_failed", error.message, null) }
            }
        }
    }

    private fun requirePrivateFile(path: String?): File? {
        if (path.isNullOrBlank()) return null
        val file = File(path).canonicalFile
        val appData = File(applicationInfo.dataDir).canonicalFile
        return file.takeIf { it.isFile && it.path.startsWith(appData.path + File.separator) }
    }

    private fun prepareShareIntent(source: File): Intent {
        val directory = File(cacheDir, "shared/${UUID.randomUUID()}").apply { mkdirs() }
        val copy = File(directory, source.name)
        source.copyTo(copy)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", copy)
        val mimeType = if (source.extension.equals("pdf", ignoreCase = true)) "application/pdf" else "application/octet-stream"
        return Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(source.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "com.starburst.photo_report/report"
        private const val PICK_BACKUP_REQUEST = 4001
    }
}
