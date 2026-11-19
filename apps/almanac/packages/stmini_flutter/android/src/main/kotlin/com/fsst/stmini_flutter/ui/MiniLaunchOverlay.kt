package com.fsst.stmini_flutter.ui

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.net.Uri
import android.view.Gravity
import android.view.View
import android.view.animation.LinearInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Button
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Native launch presentation shared by every generic Mini host.  It deliberately
 * contains no product name, route, or business image: the caller supplies a
 * verified Mini identity and the host application icon is the safe fallback.
 *
 * The overlay has three visible phases: a rotating green processing arc while
 * opening/validating/unpacking/rendering, a byte-based determinate ring while
 * downloading, and a terminal error message.  It is only dismissed by the
 * owner after the first trusted Mini document becomes visible.
 */
internal enum class MiniLaunchPhase { PROCESSING, DOWNLOAD_PROGRESS, FAILURE, FINISHED }

internal class MiniLaunchOverlay(context: Context) : FrameLayout(context) {
    private val loadingRing = MiniLaunchRing(context)
    private val icon = ImageView(context).apply {
        scaleType = ImageView.ScaleType.CENTER_CROP
        clipToOutline = true
        elevation = dp(1).toFloat()
    }
    private val name = TextView(context).apply {
        gravity = Gravity.CENTER
        setTextColor(Color.rgb(43, 43, 43))
        setTypeface(typeface, Typeface.BOLD)
        textSize = 15f
        maxLines = 2
    }
    private val failure = TextView(context).apply {
        gravity = Gravity.CENTER
        setTextColor(Color.rgb(130, 35, 35))
        textSize = 14f
        maxLines = 3
        visibility = View.GONE
    }
    private val failureActions = LinearLayout(context).apply {
        gravity = Gravity.CENTER
        visibility = View.GONE
    }
    private val retryButton = Button(context)
    private val closeButton = Button(context)
    private var iconRequest = 0
    private var hostLoadingImageName: String? = null
    internal var phase: MiniLaunchPhase = MiniLaunchPhase.PROCESSING
        private set

    init {
        setBackgroundColor(Color.WHITE)
        isClickable = true
        isFocusable = true
        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            // Match the iOS/native Android loading identity placement: the
            // ring centre is a little above the visual centre and the name
            // sits below it instead of replacing the icon.
            translationY = -dp(17).toFloat()
            setPadding(dp(28), 0, dp(28), 0)
        }
        val ringBox = FrameLayout(context)
        ringBox.addView(loadingRing, FrameLayout.LayoutParams(dp(60), dp(60)))
        ringBox.addView(icon, FrameLayout.LayoutParams(dp(42), dp(42), Gravity.CENTER))
        content.addView(ringBox, LinearLayout.LayoutParams(dp(60), dp(60)).apply {
            bottomMargin = dp(12)
        })
        content.addView(name, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        content.addView(failure, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(10)
        })
        content.addView(failureActions, LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(8)
        })
        addView(content, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        showProcessing()
    }

    fun updateIdentity(miniId: String, displayName: String?, iconUrl: String?, verifiedIcon: File?) {
        val normalizedName = displayName?.trim().takeUnless { it.isNullOrEmpty() } ?: miniId
        name.text = normalizedName
        failure.visibility = View.GONE
        failureActions.visibility = View.GONE
        icon.setImageDrawable(hostLoadingImage() ?: hostApplicationIcon())
        verifiedIcon?.let(::decodeVerifiedIcon)?.let(icon::setImageBitmap)
        val request = ++iconRequest
        loadHttpsIcon(iconUrl) { bitmap ->
            if (request == iconRequest && bitmap != null) icon.setImageBitmap(bitmap)
        }
    }

    /**
     * Flutter mirrors iOS' `loadingImage` contract with a host resource name.
     * It is intentionally resolved only from the embedding application's
     * drawable/mipmap table; URLs, file paths and arbitrary package IDs never
     * become part of the launch presentation.
     */
    fun setHostLoadingImage(name: String?) {
        hostLoadingImageName = name?.trim()?.takeIf { it.isNotEmpty() && it.length <= 128 }
    }

    fun showProcessing() {
        phase = MiniLaunchPhase.PROCESSING
        visibility = View.VISIBLE
        failure.visibility = View.GONE
        failureActions.visibility = View.GONE
        loadingRing.showProcessing()
    }

    fun showDownloadProgress(downloadedBytes: Long, totalBytes: Long) {
        phase = if (totalBytes > 0L) MiniLaunchPhase.DOWNLOAD_PROGRESS else MiniLaunchPhase.PROCESSING
        visibility = View.VISIBLE
        failure.visibility = View.GONE
        if (totalBytes > 0L) loadingRing.showDownloadProgress(downloadedBytes.toFloat() / totalBytes.toFloat())
        else loadingRing.showProcessing()
    }

    fun showFailure(message: String, onRetry: (() -> Unit)? = null, onClose: (() -> Unit)? = null) {
        phase = MiniLaunchPhase.FAILURE
        visibility = View.VISIBLE
        loadingRing.stop()
        failure.text = message
        failure.visibility = View.VISIBLE
        failureActions.removeAllViews()
        if (onRetry != null) {
            retryButton.text = actionText(chinese = "重试", english = "Retry")
            retryButton.setOnClickListener { onRetry() }
            failureActions.addView(retryButton)
        }
        if (onClose != null) {
            closeButton.text = actionText(chinese = "关闭", english = "Close")
            closeButton.setOnClickListener { onClose() }
            failureActions.addView(closeButton)
        }
        failureActions.visibility = if (failureActions.childCount > 0) View.VISIBLE else View.GONE
    }

    fun finishFirstDocument() {
        phase = MiniLaunchPhase.FINISHED
        loadingRing.stop()
        visibility = View.GONE
    }

    private fun hostApplicationIcon(): Drawable? = runCatching {
        context.applicationInfo.loadIcon(context.packageManager)
    }.getOrNull()

    private fun hostLoadingImage(): Drawable? = runCatching {
        val name = hostLoadingImageName ?: return null
        val resources = context.resources
        val id = resources.getIdentifier(name, "drawable", context.packageName)
            .takeIf { it != 0 }
            ?: resources.getIdentifier(name, "mipmap", context.packageName).takeIf { it != 0 }
            ?: return null
        resources.getDrawable(id, context.theme)
    }.getOrNull()

    private fun actionText(chinese: String, english: String): String =
        if (resources.configuration.locales[0].language.equals("zh", true)) chinese else english

    /**
     * An icon is cosmetic and never grants bridge or package trust.  Still
     * require HTTPS, cap both response size and decoded pixels, and ignore
     * redirects that downgrade transport so a launch link cannot create an
     * insecure side channel through the presentation layer.
     */
    private fun loadHttpsIcon(rawUrl: String?, completed: (Bitmap?) -> Unit) {
        val uri = rawUrl?.trim()?.takeIf { it.isNotEmpty() }?.let(Uri::parse)
        if (uri?.scheme?.equals("https", true) != true || uri.host.isNullOrBlank()) return
        thread(name = "stmini-launch-icon", isDaemon = true) {
            val bitmap = runCatching { downloadIcon(uri.toString()) }.getOrNull()
            post { completed(bitmap) }
        }
    }

    private fun downloadIcon(initialUrl: String): Bitmap? {
        var current = URL(initialUrl)
        repeat(3) {
            val connection = (current.openConnection() as? HttpURLConnection) ?: return null
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 8_000
                connection.readTimeout = 8_000
                connection.requestMethod = "GET"
                when (val status = connection.responseCode) {
                    in 300..399 -> {
                        val next = connection.getHeaderField("Location") ?: return null
                        val candidate = URL(current, next)
                        if (!candidate.protocol.equals("https", true)) return null
                        current = candidate
                    }
                    in 200..299 -> {
                        if (connection.contentLengthLong > MAX_ICON_BYTES) return null
                        BufferedInputStream(connection.inputStream).use { input ->
                            return decodeIcon(input.readAtMost(MAX_ICON_BYTES))
                        }
                    }
                    else -> return null
                }
            } finally {
                connection.disconnect()
            }
        }
        return null
    }

    private fun decodeIcon(bytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0 ||
            bounds.outWidth.toLong() * bounds.outHeight.toLong() > MAX_ICON_PIXELS) return null
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    private fun BufferedInputStream.readAtMost(maxBytes: Long): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val count = read(buffer)
            if (count < 0) return output.toByteArray()
            if (output.size().toLong() + count > maxBytes) throw IllegalStateException("Mini 图标过大")
            output.write(buffer, 0, count)
        }
    }

    private fun decodeVerifiedIcon(file: File): Bitmap? = runCatching {
        if (file.length() !in 1..MAX_ICON_BYTES) return null
        val bytes = file.readBytes()
        decodeIcon(bytes)
    }.getOrNull()

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + 0.5f).toInt()

    private companion object {
        const val MAX_ICON_BYTES = 2L * 1024L * 1024L
        const val MAX_ICON_PIXELS = 4_000_000L
    }
}

/** 60dp iOS-equivalent ring: byte progress while downloading, short green arc otherwise. */
private class MiniLaunchRing(context: Context) : View(context) {
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        color = Color.argb(140, 43, 43, 43)
    }
    private val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        color = Color.rgb(10, 191, 90)
    }
    private var processing = true
    private var rotation = 0f
    private var progress = 0f
    private var animator: ValueAnimator? = null

    init { showProcessing() }

    fun showProcessing() {
        processing = true
        trackPaint.strokeWidth = dp(0.8f)
        arcPaint.strokeWidth = dp(4.5f)
        if (animator == null) {
            animator = ValueAnimator.ofFloat(0f, 360f).apply {
                duration = 1_200L
                interpolator = LinearInterpolator()
                repeatCount = ValueAnimator.INFINITE
                addUpdateListener { rotation = it.animatedValue as Float; invalidate() }
                start()
            }
        } else if (animator?.isStarted != true) animator?.start()
        invalidate()
    }

    fun showDownloadProgress(value: Float) {
        processing = false
        animator?.cancel()
        animator = null
        progress = value.coerceIn(0f, 1f)
        trackPaint.strokeWidth = dp(0.8f)
        arcPaint.strokeWidth = dp(4f)
        invalidate()
    }

    fun stop() {
        animator?.cancel()
        animator = null
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val inset = maxOf(arcPaint.strokeWidth, trackPaint.strokeWidth) / 2f
        val rect = RectF(inset, inset, width - inset, height - inset)
        canvas.drawArc(rect, -90f, 360f, false, trackPaint)
        if (processing) canvas.drawArc(rect, -90f + rotation, 15.12f, false, arcPaint)
        else canvas.drawArc(rect, -90f, 360f * progress, false, arcPaint)
    }

    override fun onDetachedFromWindow() {
        stop()
        super.onDetachedFromWindow()
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density
}
