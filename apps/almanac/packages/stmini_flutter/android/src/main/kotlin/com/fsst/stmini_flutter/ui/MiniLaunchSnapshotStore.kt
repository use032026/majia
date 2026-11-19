package com.fsst.stmini_flutter.ui

import android.content.ComponentCallbacks2
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.WindowManager

/**
 * Short-lived, in-memory handoff of a presenting host's visible surface.
 *
 * This is deliberately not a task snapshot: it is keyed only by the target
 * Mini id, never persisted, and is consumed exactly once by its container.
 * Secure host windows are excluded. Replacing, memory pressure and explicit
 * discard recycle the old bitmap immediately.
 */
internal object MiniLaunchSnapshotStore {
    private const val MAX_WIDTH = 540
    private val snapshots = mutableMapOf<String, Bitmap>()
    private var callbacksRegistered = false
    @Volatile internal var activeSnapshotReleaseObserver: (() -> Unit)? = null

    @Synchronized
    fun remember(host: android.app.Activity, miniId: String) {
        if (miniId.isBlank() ||
            host.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0) return
        val source = host.window.decorView ?: return
        if (source.width <= 0 || source.height <= 0) return
        val scale = minOf(1f, MAX_WIDTH.toFloat() / source.width.toFloat())
        val width = (source.width * scale).toInt().coerceAtLeast(1)
        val height = (source.height * scale).toInt().coerceAtLeast(1)
        val snapshot = runCatching {
            Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565).also { bitmap ->
                Canvas(bitmap).apply {
                    scale(scale, scale)
                    source.draw(this)
                }
            }
        }.getOrNull() ?: return
        rememberBitmap(host.applicationContext, miniId, snapshot)
    }

    @Synchronized
    fun take(miniId: String): Bitmap? = snapshots.remove(miniId.lowercase())

    @Synchronized
    fun discard(miniId: String) {
        snapshots.remove(miniId.lowercase())?.recycleSafely()
    }

    @Synchronized
    fun clearForMemoryPressure() {
        snapshots.values.forEach { it.recycleSafely() }
        snapshots.clear()
        activeSnapshotReleaseObserver?.invoke()
    }

    /** Test seam: production capture always goes through [remember]. */
    @Synchronized
    internal fun rememberForTest(context: Context, miniId: String, bitmap: Bitmap) =
        rememberBitmap(context.applicationContext, miniId, bitmap)

    @Synchronized
    internal fun pendingCountForTest(): Int = snapshots.size

    private fun rememberBitmap(context: Context, miniId: String, bitmap: Bitmap) {
        if (miniId.isBlank()) {
            bitmap.recycleSafely()
            return
        }
        ensureCallbacks(context)
        snapshots.put(miniId.lowercase(), bitmap)?.recycleSafely()
    }

    private fun ensureCallbacks(context: Context) {
        if (callbacksRegistered) return
        context.registerComponentCallbacks(object : ComponentCallbacks2 {
            override fun onConfigurationChanged(newConfig: Configuration) = Unit
            override fun onLowMemory() = clearForMemoryPressure()
            override fun onTrimMemory(level: Int) {
                if (level >= ComponentCallbacks2.TRIM_MEMORY_BACKGROUND ||
                    level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW ||
                    level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL) clearForMemoryPressure()
            }
        })
        callbacksRegistered = true
    }

    private fun Bitmap.recycleSafely() {
        if (!isRecycled) recycle()
    }
}
