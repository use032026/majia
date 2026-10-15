package com.starburst.photoReport

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsetsController
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File
import kotlin.math.min

class PdfPreviewActivity : Activity() {
    private var descriptor: ParcelFileDescriptor? = null
    private var renderer: PdfRenderer? = null
    private var bitmap: Bitmap? = null
    private var pageIndex = 0
    private lateinit var image: ImageView
    private lateinit var counter: TextView
    private lateinit var previous: Button
    private lateinit var next: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(244, 247, 246)
        window.navigationBarColor = Color.rgb(244, 247, 246)
        try {
            val path = intent.getStringExtra(EXTRA_PATH) ?: error("Missing report path")
            val file = File(path).canonicalFile
            val appRoot = File(applicationInfo.dataDir).canonicalFile
            require(file.isFile && file.path.startsWith(appRoot.path + File.separator) && file.extension.equals("pdf", true)) {
                "Report file not found"
            }
            descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            renderer = PdfRenderer(descriptor!!)
            require(renderer!!.pageCount > 0) { "The PDF has no pages" }
            buildUi()
            showPage()
        } catch (error: Exception) {
            Toast.makeText(this, error.message ?: "Cannot preview PDF", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    private fun buildUi() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.rgb(244, 247, 246))
            setOnApplyWindowInsetsListener { view, insets ->
                view.setPadding(0, insets.systemWindowInsetTop, 0, insets.systemWindowInsetBottom)
                insets
            }
        }
        val toolbar = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), dp(4), dp(8), dp(4))
        }
        toolbar.addView(Button(this).apply {
            text = getString(R.string.close)
            setOnClickListener { finish() }
        })
        toolbar.addView(TextView(this).apply {
            text = getString(R.string.report_preview)
            textSize = 18f
            setTextColor(Color.rgb(23, 49, 46))
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        root.addView(toolbar)

        image = ImageView(this).apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.FIT_CENTER
            contentDescription = getString(R.string.report_preview)
        }
        val scroll = ScrollView(this).apply {
            setPadding(dp(12), dp(8), dp(12), dp(8))
            addView(image, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        root.addView(scroll, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        val navigation = LinearLayout(this).apply {
            gravity = Gravity.CENTER
            setPadding(dp(8), dp(4), dp(8), dp(8))
        }
        previous = Button(this).apply {
            text = getString(R.string.previous_page)
            setOnClickListener { pageIndex--; showPage(); scroll.scrollTo(0, 0) }
        }
        next = Button(this).apply {
            text = getString(R.string.next_page)
            setOnClickListener { pageIndex++; showPage(); scroll.scrollTo(0, 0) }
        }
        counter = TextView(this).apply {
            gravity = Gravity.CENTER
            textSize = 14f
            setTextColor(Color.rgb(23, 49, 46))
        }
        navigation.addView(previous)
        navigation.addView(counter, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        navigation.addView(next)
        root.addView(navigation)
        setContentView(root)
        root.post {
            if (Build.VERSION.SDK_INT >= 30) {
                val lightBars = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                root.windowInsetsController?.setSystemBarsAppearance(lightBars, lightBars)
            } else {
                val lightStatusBar = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                val lightNavigationBar = if (Build.VERSION.SDK_INT >= 26) View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR else 0
                window.decorView.systemUiVisibility = lightStatusBar or lightNavigationBar
            }
        }
    }

    private fun showPage() {
        val pdf = renderer ?: return
        pageIndex = pageIndex.coerceIn(0, pdf.pageCount - 1)
        pdf.openPage(pageIndex).use { page ->
            val available = resources.displayMetrics.widthPixels - dp(24)
            val width = min(1800, (available * 1.5f).toInt()).coerceAtLeast(1)
            val height = (width.toFloat() * page.height / page.width).toInt().coerceAtLeast(1)
            val rendered = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            rendered.eraseColor(Color.WHITE)
            page.render(rendered, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            image.setImageBitmap(null)
            bitmap?.recycle()
            bitmap = rendered
            image.setImageBitmap(rendered)
        }
        counter.text = "${pageIndex + 1} / ${pdf.pageCount}"
        previous.isEnabled = pageIndex > 0
        next.isEnabled = pageIndex < pdf.pageCount - 1
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        if (::image.isInitialized) image.setImageBitmap(null)
        bitmap?.recycle()
        renderer?.close()
        descriptor?.close()
        super.onDestroy()
    }

    companion object {
        const val EXTRA_PATH = "reportPath"
    }
}
