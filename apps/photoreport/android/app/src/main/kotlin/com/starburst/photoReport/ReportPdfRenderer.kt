package com.starburst.photoReport

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.media.ExifInterface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import io.flutter.util.PathUtils
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

class ReportPdfRenderer(private val context: Context) {
    private val brand = Color.rgb(11, 107, 99)
    private val ink = Color.rgb(23, 49, 46)
    private val muted = Color.rgb(95, 113, 109)
    private val canvasColor = Color.rgb(244, 247, 246)
    private val soft = Color.rgb(231, 240, 238)
    private val pending = Color.rgb(173, 84, 23)
    private val progress = Color.rgb(36, 101, 168)
    private val completed = Color.rgb(31, 118, 80)
    private val risk = Color.rgb(183, 53, 61)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val pageWidth = 595f
    private val pageHeight = 842f

    fun generate(project: Map<*, *>, rawIssues: List<*>, options: Map<*, *>, languageCode: String): File {
        val issues = rawIssues.map { it as? Map<*, *> ?: error("Invalid issue data") }
        val copy = Copy(languageCode)
        val reports = File(PathUtils.getDataDirectory(context), "PhotoReport/Reports").apply { mkdirs() }
        val projectName = project.string("name", copy.text("现场报告"))
        val safeName = projectName.replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "-").take(80)
        val stamp = SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.US).format(Date())
        val destination = File(reports, "$safeName-$stamp.pdf")
        val document = PdfDocument()
        var pageNumber = 0
        try {
            fun page(draw: (Canvas) -> Unit) {
                pageNumber += 1
                val info = PdfDocument.PageInfo.Builder(pageWidth.toInt(), pageHeight.toInt(), pageNumber).create()
                val page = document.startPage(info)
                page.canvas.drawColor(Color.WHITE)
                draw(page.canvas)
                drawText(page.canvas, copy.footer(pageNumber), 42f, 808f, 511f, 22f, 7.4f, muted, center = true)
                document.finishPage(page)
            }

            val concise = options.string("layout") == "concise"
            if (!concise || issues.isEmpty()) page { drawCover(it, project, issues, options, copy) }
            for (issue in issues) {
                val photos = (issue["photos"] as? List<*>)?.map {
                    it as? Map<*, *> ?: error("Invalid photo data")
                } ?: emptyList()
                if (photos.isEmpty()) {
                    page { drawIssuePage(it, issue, emptyList(), false, options, copy) }
                } else {
                    photos.chunked(4).forEachIndexed { index, chunk ->
                        page { drawIssuePage(it, issue, chunk, index > 0, options, copy) }
                    }
                }
            }
            if (!concise && options.bool("includeNotes")) page { drawNotesPage(it, project, issues, copy) }
            destination.outputStream().use { document.writeTo(it) }
            return destination
        } catch (error: Exception) {
            destination.delete()
            throw error
        } finally {
            document.close()
        }
    }

    private fun drawCover(canvas: Canvas, project: Map<*, *>, issues: List<Map<*, *>>, options: Map<*, *>, copy: Copy) {
        rectangle(canvas, 0f, 0f, pageWidth, 17f, brand)
        val company = if (options.bool("includeProjectDetails")) project.string("companyName", copy.text("现场情况记录")) else copy.text("现场情况记录")
        drawText(canvas, company, 42f, 48f, 511f, 24f, 13f, brand, bold = true)
        drawText(canvas, copy.text("现场照片沟通记录"), 42f, 132f, 511f, 54f, if (copy.english) 30f else 34f, ink, bold = true)
        drawText(canvas, "FIELD PHOTO NOTES", 44f, 190f, 511f, 22f, 11f, muted, bold = true)
        rounded(canvas, 42f, 254f, 511f, 190f, 14f, soft)
        drawText(canvas, project.string("name"), 64f, 278f, 467f, 30f, 20f, ink, bold = true)
        if (options.bool("includeProjectDetails")) {
            val labelWidth = if (copy.english) 104f else 74f
            infoRow(canvas, copy.text("记录地点"), project.string("address"), 324f, labelWidth)
            infoRow(canvas, copy.text("记录日期"), project.string("inspectionDate"), 356f, labelWidth)
            infoRow(canvas, copy.text("记录人员"), project.string("inspectorName", copy.text("未填写")), 388f, labelWidth)
        }
        val metrics = mutableListOf(Triple(copy.text("记录总数"), issues.size, ink))
        if (options.bool("includeStatus")) {
            metrics += Triple(copy.text("待处理"), issues.count { it.string("status") == "待处理" }, pending)
            metrics += Triple(copy.text("处理中"), issues.count { it.string("status") == "处理中" }, progress)
            metrics += Triple(copy.text("已完成"), issues.count { it.string("status") == "已完成" }, completed)
        }
        if (options.bool("includeSeverity")) metrics += Triple(copy.text("高优先级"), issues.count { it.string("severity") == "高" }, risk)
        val metricWidth = min(120f, (511f - (metrics.size - 1) * 10f) / metrics.size)
        metrics.forEachIndexed { index, metric ->
            val x = 42f + index * (metricWidth + 10f)
            rounded(canvas, x, 482f, metricWidth, 88f, 12f, alpha(metric.third, 0.09f))
            drawText(canvas, metric.second.toString(), x + 13f, 497f, metricWidth - 26f, 30f, 23f, metric.third, bold = true)
            drawText(canvas, metric.first, x + 13f, 535f, metricWidth - 26f, 18f, 9f, muted)
        }
        if (options.bool("includePosition")) {
            val rooms = issues.map { it.string("room") }.filter { it.isNotEmpty() }.distinct().sorted()
            drawText(canvas, copy.text("记录范围"), 42f, 618f, 511f, 24f, 15f, ink, bold = true)
            drawText(canvas, if (rooms.isEmpty()) copy.text("尚未记录区域") else rooms.joinToString("  ·  "), 42f, 650f, 511f, 64f, 12f, muted)
        }
        drawText(canvas, copy.text(DISCLAIMER), 42f, 756f, 511f, 28f, 9f, muted)
    }

    private fun drawIssuePage(canvas: Canvas, issue: Map<*, *>, photos: List<Map<*, *>>, continuation: Boolean, options: Map<*, *>, copy: Copy) {
        rounded(canvas, 42f, 38f, 76f, 29f, 7f, brand)
        drawText(canvas, issue.string("code"), 42f, 45f, 76f, 16f, 11f, Color.WHITE, bold = true, center = true)
        drawText(canvas, if (continuation) copy.text("补充照片") else issue.string("category"), 130f, 40f, 423f, 26f, 19f, ink, bold = true)
        val pills = mutableListOf<Pair<String, Int>>()
        val severity = issue.string("severity")
        if (options.bool("includeSeverity") && severity != "未设置") {
            pills += copy.severityPriority(severity) to when (severity) { "高" -> risk; "中" -> pending; else -> muted }
        }
        val status = issue.string("status")
        if (options.bool("includeStatus") && status != "未设置") {
            pills += copy.text(status) to when (status) { "已完成" -> completed; "处理中" -> progress; else -> pending }
        }
        if (pills.isNotEmpty()) {
            var x = 553f - (pills.size * 98f + (pills.size - 1) * 8f)
            for ((label, color) in pills) {
                rounded(canvas, x, 74f, 98f, 24f, 12f, alpha(color, 0.1f))
                drawText(canvas, label, x, 80f, 98f, 13f, 8.5f, color, bold = true, center = true)
                x += 106f
            }
        }
        val detailY = if (pills.isEmpty()) 92f else 110f
        var photosY = if (pills.isEmpty()) 104f else 116f
        if (!continuation) {
            val concise = options.string("layout") == "concise"
            val detailHeight = if (concise) (if (options.bool("includePosition")) 132f else 112f) else 151f
            rounded(canvas, 42f, detailY, 511f, detailHeight, 12f, soft)
            var descriptionY = detailY + 19f
            if (options.bool("includePosition")) {
                val room = issue.string("room")
                val location = issue.string("location")
                detailPair(canvas, copy.text("位置"), if (location.isEmpty()) room else "$room / $location", 58f, detailY + 15f, 292f)
                descriptionY = detailY + 59f
            }
            if (!concise && options.bool("includeAssignee")) {
                detailPair(canvas, copy.text("负责人"), issue.string("assignee", copy.text("未填写")), 365f, detailY + 15f, 168f)
            }
            if (!concise && options.bool("includeDueDate")) {
                detailPair(canvas, copy.text("处理期限"), issue.string("dueDate", copy.text("未设置")), 365f, detailY + 58f, 168f)
            }
            drawText(canvas, copy.text("照片说明"), 58f, descriptionY, if (copy.english) 118f else 72f, 17f, 9f, muted)
            drawText(canvas, issue.string("description"), 58f, descriptionY + 20f, if (concise) 475f else 292f, if (concise) 43f else 50f, 10.5f, ink)
            photosY = detailY + detailHeight + 22f
        }
        if (photos.isEmpty()) {
            rounded(canvas, 42f, photosY, 511f, 250f, 12f, canvasColor)
            drawText(canvas, copy.text("此记录未附现场照片"), 42f, photosY + 112f, 511f, 24f, 12f, muted, center = true)
            return
        }
        photos.forEachIndexed { index, photo ->
            val x = 42f + (index % 2) * 263f
            val y = photosY + (index / 2) * 252f
            drawPhoto(canvas, photo, copy, RectF(x, y, x + 248f, y + 238f))
        }
    }

    private fun drawPhoto(canvas: Canvas, photo: Map<*, *>, copy: Copy, cell: RectF) {
        rounded(canvas, cell.left, cell.top, cell.width(), cell.height(), 10f, canvasColor)
        drawText(canvas, copy.text(photo.string("phase")), cell.left + 9f, cell.top + 7f, cell.width() - 18f, 16f, 9f, muted, bold = true)
        val frame = RectF(cell.left + 7f, cell.top + 28f, cell.right - 7f, cell.bottom - 7f)
        val image = loadPhoto(photo.string("path"), 800)
        if (image == null) {
            drawText(canvas, copy.text("照片文件不可用"), frame.left, frame.top + 70f, frame.width(), 26f, 10f, muted, center = true)
            return
        }
        try {
            rectangle(canvas, frame.left, frame.top, frame.width(), frame.height(), Color.rgb(23, 31, 31))
            val scale = min(frame.width() / image.width, frame.height() / image.height)
            val width = image.width * scale
            val height = image.height * scale
            val imageRect = RectF(frame.centerX() - width / 2f, frame.centerY() - height / 2f, frame.centerX() + width / 2f, frame.centerY() + height / 2f)
            paint.color = Color.WHITE
            canvas.drawBitmap(image, null, imageRect, paint)
            (photo["annotations"] as? List<*>)?.forEach { raw ->
                (raw as? Map<*, *>)?.let { drawAnnotation(canvas, it, imageRect) }
            }
        } finally {
            image.recycle()
        }
    }

    private fun drawAnnotation(canvas: Canvas, annotation: Map<*, *>, rect: RectF) {
        val startX = rect.left + annotation.number("x1") * rect.width()
        val startY = rect.top + annotation.number("y1") * rect.height()
        val endX = rect.left + annotation.number("x2") * rect.width()
        val endY = rect.top + annotation.number("y2") * rect.height()
        val color = (annotation["color"] as? Number)?.toInt()?.let { Color.rgb((it shr 16) and 255, (it shr 8) and 255, it and 255) } ?: Color.RED
        paint.color = color
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2.4f
        when (annotation.string("kind")) {
            "rectangle" -> canvas.drawRect(minOf(startX, endX), minOf(startY, endY), maxOf(startX, endX), maxOf(startY, endY), paint)
            "arrow" -> {
                canvas.drawLine(startX, startY, endX, endY, paint)
                val angle = atan2(endY - startY, endX - startX)
                for (offset in listOf(-0.58, 0.58)) {
                    canvas.drawLine(endX, endY, (endX - cos(angle + offset) * 12f).toFloat(), (endY - sin(angle + offset) * 12f).toFloat(), paint)
                }
            }
            "text" -> {
                val width = min(130f, rect.right - startX).coerceAtLeast(0f)
                if (width > 10f) {
                    rounded(canvas, startX, startY, width, 32f, 4f, alpha(color, 0.88f))
                    val luminance = Color.red(color) * 0.299 + Color.green(color) * 0.587 + Color.blue(color) * 0.114
                    drawText(canvas, annotation.string("text"), startX + 5f, startY + 6f, width - 10f, 20f, 8f, if (luminance > 127) Color.BLACK else Color.WHITE, bold = true)
                }
            }
        }
        paint.style = Paint.Style.FILL
    }

    private fun drawNotesPage(canvas: Canvas, project: Map<*, *>, issues: List<Map<*, *>>, copy: Copy) {
        rectangle(canvas, 0f, 0f, pageWidth, 17f, brand)
        drawText(canvas, copy.text("补充说明"), 42f, 58f, 511f, 38f, 26f, ink, bold = true)
        drawText(canvas, copy.projectLine(project.string("name")), 42f, 108f, 511f, 22f, 11f, muted, bold = true)
        rounded(canvas, 42f, 164f, 511f, 210f, 12f, soft)
        drawText(canvas, copy.text("补充说明"), 60f, 184f, 180f, 22f, 13f, brand, bold = true)
        drawText(canvas, project.string("notes", copy.text("无")), 60f, 219f, 475f, 132f, 11f, ink)
        val unfinished = issues.count { it.string("status") in listOf("待处理", "处理中") }
        drawText(canvas, copy.summary(issues.size, unfinished), 42f, 411f, 511f, 52f, 10f, muted)
        drawText(canvas, copy.text(DISCLAIMER), 42f, 530f, 511f, 50f, 10f, muted, center = true)
    }

    private fun loadPhoto(path: String, targetSize: Int): Bitmap? {
        val file = File(path)
        if (!file.isFile) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / sample > targetSize * 2 || bounds.outHeight / sample > targetSize * 2) sample *= 2
        val bitmap = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        val rotation = try {
            when (ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } catch (_: Exception) { 0f }
        if (rotation == 0f) return bitmap
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, Matrix().apply { postRotate(rotation) }, true)
        bitmap.recycle()
        return rotated
    }

    private fun infoRow(canvas: Canvas, label: String, value: String, y: Float, labelWidth: Float) {
        drawText(canvas, label, 64f, y, labelWidth, 22f, 10f, muted)
        val valueX = 64f + labelWidth + 7f
        drawText(canvas, value, valueX, y, 531f - valueX, 22f, 11f, ink)
    }

    private fun detailPair(canvas: Canvas, label: String, value: String, x: Float, y: Float, width: Float) {
        drawText(canvas, label, x, y, width, 16f, 9f, muted)
        drawText(canvas, value, x, y + 18f, width, 20f, 10.5f, ink, bold = true)
    }

    private fun rectangle(canvas: Canvas, x: Float, y: Float, width: Float, height: Float, color: Int) {
        paint.color = color
        paint.style = Paint.Style.FILL
        canvas.drawRect(x, y, x + width, y + height, paint)
    }

    private fun rounded(canvas: Canvas, x: Float, y: Float, width: Float, height: Float, radius: Float, color: Int) {
        paint.color = color
        paint.style = Paint.Style.FILL
        canvas.drawRoundRect(x, y, x + width, y + height, radius, radius, paint)
    }

    private fun drawText(canvas: Canvas, text: String, x: Float, y: Float, width: Float, height: Float, size: Float, color: Int, bold: Boolean = false, center: Boolean = false) {
        if (text.isEmpty() || width <= 0f || height <= 0f) return
        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            textSize = size
            typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        }
        val maxLines = ((height / (size * 1.25f)).toInt()).coerceAtLeast(1)
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, textPaint, width.toInt().coerceAtLeast(1))
            .setAlignment(if (center) Layout.Alignment.ALIGN_CENTER else Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setLineSpacing(2f, 1f)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()
        canvas.save()
        canvas.translate(x, y)
        canvas.clipRect(0f, 0f, width, height)
        layout.draw(canvas)
        canvas.restore()
    }

    private fun alpha(color: Int, opacity: Float) = Color.argb((opacity * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

    private fun Map<*, *>.string(key: String, fallback: String = ""): String = (this[key] as? String)?.takeIf { it.isNotEmpty() } ?: fallback
    private fun Map<*, *>.bool(key: String): Boolean = this[key] as? Boolean ?: false
    private fun Map<*, *>.number(key: String): Float = (this[key] as? Number)?.toFloat() ?: 0f

    private class Copy(languageCode: String) {
        val english = languageCode.lowercase(Locale.ROOT).startsWith("en")
        fun text(chinese: String): String = if (english) translations[chinese] ?: chinese else chinese
        fun footer(page: Int) = if (english) "For site communication and documentation only; not a professional assessment, acceptance decision, or legal opinion  ·  Page $page" else "仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见  ·  第 $page 页"
        fun severityPriority(severity: String) = if (english) "${text(severity)} priority" else "${severity}优先级"
        fun projectLine(name: String) = if (english) "Project: $name" else "项目：$name"
        fun summary(total: Int, unfinished: Int) = if (english) "At generation time, $total records were organized and $unfinished were marked unfinished. Generate again to reflect the latest content." else "截至生成时，共整理 $total 条记录，其中 $unfinished 条标记为尚未完成处理。再次生成时会反映最新内容。"

        companion object {
            private val translations = mapOf(
                "现场报告" to "Site report", "现场情况记录" to "Site condition records",
                "现场照片沟通记录" to "On-site Photo Communication Record", "记录地点" to "Location",
                "记录日期" to "Record date", "记录人员" to "Recorder", "未填写" to "Not provided",
                "记录总数" to "Total records", "待处理" to "Pending", "处理中" to "In progress",
                "已完成" to "Completed", "高优先级" to "High priority", "记录范围" to "Recorded areas",
                "尚未记录区域" to "No areas recorded", "补充照片" to "Additional photos",
                "未设置" to "Not set", "低" to "Low", "中" to "Medium", "高" to "High",
                "位置" to "Location", "负责人" to "Assignee", "处理期限" to "Due date",
                "照片说明" to "Photo description", "此记录未附现场照片" to "No site photos attached to this record",
                "处理前" to "Before", "处理后" to "After", "照片文件不可用" to "Photo file unavailable",
                "补充说明" to "Additional notes", "无" to "None",
                DISCLAIMER to "For site communication and documentation only. This is not a professional assessment, acceptance decision, or legal opinion."
            )
        }
    }

    companion object {
        private const val DISCLAIMER = "内容仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见。"
    }
}
