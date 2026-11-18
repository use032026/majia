package com.almanac.lite.renderer

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import android.webkit.WebView
import android.view.View
import android.view.ViewGroup
import com.fsst.stmini_flutter.ui.LocalMiniView
import com.fsst.stmini_flutter.runtime.LocalMiniResource
import com.fsst.stmini_flutter.runtime.LocalPackageInventory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.json.JSONObject
import java.io.File
import java.net.ServerSocket
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/** Test-only APK instrumentation. Real production WebView/renderer + Android UI;
 * messenger recording is explicit glue, separate from the FlutterEngine target.
 */
class RendererInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    private class Messenger : BinaryMessenger {
        val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()
        override fun send(channel: String, message: ByteBuffer?) {}
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) { callback?.reply(null) }
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            if (handler == null) handlers.remove(channel) else handlers[channel] = handler
        }
    }
    private fun <T> ui(block: () -> T): T {
        val value = AtomicReference<T>(); val error = AtomicReference<Throwable>()
        runOnMainSync { try { value.set(block()) } catch (failure: Throwable) { error.set(failure) } }
        error.get()?.let { throw it }; return value.get()
    }
    private fun until(seconds: Int = 12, condition: () -> Boolean) {
        val deadline = System.nanoTime() + seconds * 1_000_000_000L
        while (System.nanoTime() < deadline) { if (condition()) return; Thread.sleep(50) }
        error("renderer-condition-timeout")
    }
    private fun js(view: WebView, source: String): String {
        val latch = CountDownLatch(1); val value = AtomicReference<String>()
        ui { view.evaluateJavascript(source) { value.set(it); latch.countDown() } }
        check(latch.await(5, TimeUnit.SECONDS)) { "DOM-evaluate-timeout" }; return value.get()
    }
    private fun web(view: View): WebView? {
        if (view is WebView) return view
        if (view is ViewGroup) for (index in 0 until view.childCount) web(view.getChildAt(index))?.let { return it }
        return null
    }
    private fun command(messenger: Messenger, method: String): Any? = ui {
        var answer: Any? = null; var called = false
        val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, null))
        message.flip() // The engine normally hands native a readable buffer.
        messenger.handlers.getValue("stmini_flutter/local_view/908").onMessage(message) { data ->
            data?.flip()
            answer = if (data == null) null else StandardMethodCodec.INSTANCE.decodeEnvelope(data); called = true
        }
        check(called); answer
    }
    override fun onStart() {
        val report = JSONObject().put("kind", "real_android_instrumentation_production_local_webview")
        var activity: Activity? = null; var renderer: LocalMiniView? = null; var server: ServerSocket? = null
        val root = File(targetContext.filesDir, "STMini")
        val pack = File(root, "renderer_fixture")
        try {
            check(!root.exists()) { "task-native-root-must-start-absent" }
            check(pack.mkdirs())
            for ((name, bytes) in RendererFixture.files) File(pack, name).writeBytes(bytes)
            val count = AtomicInteger(0)
            val listener = ServerSocket(0, 10, java.net.InetAddress.getByName("127.0.0.1")); server = listener
            val accept = Thread {
                while (!listener.isClosed) {
                    try {
                        listener.accept().use { socket ->
                            count.incrementAndGet()
                            val body = "window.__rendererProbe.remoteCodeExecuted=true"
                            val response = "HTTP/1.1 200 OK\r\nContent-Type: application/javascript\r\nContent-Length: ${body.length}\r\nConnection: close\r\n\r\n$body"
                            socket.getOutputStream().write(response.toByteArray())
                        }
                    } catch (_: Exception) { if (!listener.isClosed) throw IllegalStateException("loopback-listener") }
                }
            }.apply { isDaemon = true; start() }
            Socket("127.0.0.1", listener.localPort).use { it.getInputStream().read() }
            until { count.get() == 1 }; count.set(0)
            report.put("positiveControlConnections", 1)
            activity = startActivitySync(Intent().setClassName("com.almanac.lite", "com.almanac.lite.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            val messenger = Messenger()
            renderer = ui { LocalMiniView(activity!!, messenger, 908,
                mapOf("miniId" to "renderer_fixture", "version" to "1.0"), { true }, {}).also { activity!!.addContentView(it.getView(), ViewGroup.LayoutParams(-1, -1)) } }
            fun state() = command(messenger, "state") as Map<*, *>
            fun currentWeb() = ui { web(renderer!!.getView()) } ?: error("no-real-WebView")
            until { state()["phase"] == "ready" }
            var view = currentWeb()
            report.put("initialDocument", js(view, "JSON.stringify({url:location.href,ready:document.readyState,script:typeof window.__rendererProbe,body:document.body&&document.body.innerText})"))
            until { js(view, "document.readyState==='complete' && window.__rendererProbe && window.__rendererProbe.ran") == "true" }
            val dom = JSONObject(org.json.JSONTokener(js(view, "JSON.stringify({text:document.getElementById('content').textContent,color:getComputedStyle(document.getElementById('content')).color,width:document.getElementById('pixel').naturalWidth,bridge:typeof window.CMSScriptMessageChannel})")).nextValue() as String)
            check(dom.getString("text") == "Verified local Mini DOM from probe.js")
            check(dom.getString("color") == "rgb(13, 47, 83)"); check(dom.getInt("width") == 1); check(dom.getString("bridge") == "undefined")
            check(js(view, "document.getElementById('action').click(); window.__rendererProbe.clicked") == "true")
            report.put("dom", dom).put("localJS", true).put("interaction", true)
            js(view, "window.__permissionProbe='pending'; if(!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia){window.__permissionProbe='unavailable'}else{navigator.mediaDevices.getUserMedia({video:true,audio:true}).then(function(stream){stream.getTracks().forEach(function(track){track.stop()});window.__permissionProbe='granted'},function(){window.__permissionProbe='rejected'})}; true")
            until { js(view, "window.__permissionProbe!=='pending'") == "true" }
            val permission = js(view, "window.__permissionProbe")
            check(permission in listOf("\"rejected\"", "\"unavailable\""))
            report.put("realPageMediaPermission", permission)
            Thread.sleep(600); waitForIdleSync()
            ui {
                report.put("webViewViewport", JSONObject().put("width", view.width).put("height", view.height)
                    .put("attached", view.isAttachedToWindow).put("shown", view.isShown))
                val bitmap = android.graphics.Bitmap.createBitmap(view.width, view.height, android.graphics.Bitmap.Config.ARGB_8888)
                view.draw(android.graphics.Canvas(bitmap))
                File(targetContext.cacheDir, "renderer-native-webview.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
                bitmap.recycle()
            }
            uiAutomation.takeScreenshot()?.let { bitmap -> File(targetContext.cacheDir, "renderer-native.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }; bitmap.recycle() }
            js(view, "window.runNetworkProbe(${listener.localPort}); true")
            until { js(view, "window.__rendererProbe.done===true") == "true" }
            val network = JSONObject(org.json.JSONTokener(js(view, "JSON.stringify(window.__rendererProbe)")).nextValue() as String)
            val attempts = network.getJSONObject("attempts")
            check(attempts.length() == 12); check(!network.getBoolean("remoteCodeExecuted")); check(count.get() == 0)
            for (name in attempts.keys()) check(attempts.getString(name) !in listOf("attempted", "open", "opened", "resolved"))
            for (name in listOf("remoteScript", "dataScript", "blobScript")) check(attempts.getString(name) != "load")
            report.put("networkAttempts", attempts).put("loopbackConnections", count.get())
            js(view, "location.href='http://127.0.0.1:${listener.localPort}/main'; true")
            Thread.sleep(300); check(ui { view.url?.contains("renderer_fixture.stmini.local") } == true); check(count.get() == 0)
            js(view, "document.getElementById('second').click(); true")
            until { state()["phase"] == "ready" && state()["canGoBack"] == true }
            view = currentWeb(); check(js(view, "document.getElementById('second-content').textContent") == "\"Verified second local document\"")
            check(command(messenger, "goBack") == true)
            until { state()["phase"] == "ready" && state()["canGoBack"] == false }
            view = currentWeb(); until { js(view, "window.__rendererProbe && window.__rendererProbe.ran") == "true" }
            js(view, "location.hash='fixture-anchor'; true"); Thread.sleep(8300)
            check(state()["phase"] == "ready")
            for (index in 0 until 12) command(messenger, "reload")
            until { state()["phase"] == "ready" }
            view = currentWeb(); until { js(view, "window.__rendererProbe && window.__rendererProbe.ran") == "true" }
            report.put("backReloadAnchor", true)
            val beforeBackground = currentWeb()
            ui { activity!!.moveTaskToBack(true) }
            until { !ui { renderer!!.getView().hasWindowFocus() } }
            ui { targetContext.startActivity(Intent().setClassName("com.almanac.lite", "com.almanac.lite.MainActivity")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)) }
            until { ui { renderer!!.getView().hasWindowFocus() } }
            check(currentWeb() === beforeBackground)
            check(state()["phase"] == "ready")
            check(js(currentWeb(), "window.__rendererProbe.ran") == "true")
            report.put("actualActivityBackgroundForeground", true)
            val lost = currentWeb()
            ui { lost.webViewClient.onRenderProcessGone(lost, object : android.webkit.RenderProcessGoneDetail() {
                override fun didCrash() = false
                override fun rendererPriorityAtExit() = WebView.RENDERER_PRIORITY_BOUND
            }) }
            check(state()["phase"] == "failed" && state()["errorCode"] == "renderer_terminated")
            command(messenger, "reload"); until { state()["phase"] == "ready" }
            report.put("controlledProductionRendererLossCallbackAndReload", true)
            // Test-only scheduler control; the production eight-second timer
            // actually runs. No native or Flutter product test hook is added.
            val field = renderer!!.javaClass.getDeclaredField("worker").apply { isAccessible = true }
            val worker = field.get(renderer) as java.util.concurrent.ThreadPoolExecutor
            val entered = CountDownLatch(1); val release = CountDownLatch(1)
            worker.submit { entered.countDown(); release.await(15, TimeUnit.SECONDS) }
            check(entered.await(2, TimeUnit.SECONDS))
            val watchdogStart = System.nanoTime()
            try {
                command(messenger, "reload")
                until(10) { state()["phase"] == "failed" }
                check(System.nanoTime() - watchdogStart >= 7_800_000_000L)
                check(state()["errorCode"] == "render_timeout")
            } finally { release.countDown() }
            Thread.sleep(400)
            check(state()["errorCode"] == "render_timeout")
            check(ui { web(renderer!!.getView()) } == null)
            command(messenger, "reload"); until { state()["phase"] == "ready" }
            report.put("actualEightSecondWatchdogWithControlledIdentityWorker", true).put("lateIdentityIgnoredAndReloadRecovers", true)
            val resources = LocalMiniResource(LocalPackageInventory(targetContext.filesDir), "renderer_fixture", "1.0", "index.html")
            for (raw in listOf("https://other.stmini.local/index.html", "https://renderer_fixture.stmini.local:80/index.html",
                "https://user@renderer_fixture.stmini.local/index.html", "https://renderer_fixture.stmini.local/%2e%2e/index.html",
                "https://renderer_fixture.stmini.local/%252e%252e/index.html", "https://renderer_fixture.stmini.local/a%2fb",
                "https://renderer_fixture.stmini.local/a//b", "https://renderer_fixture.stmini.local/%C3%28",
                "https://renderer_fixture.stmini.local/index.html?x=1", "file:///etc/passwd")) check(resources.path(raw) == null) { raw }
            check(resources.path("https://renderer_fixture.stmini.local/index.html#anchor") == "index.html")
            val held = (0 until 4).map { resources.response(resources.url("probe.js"), "GET") { true } }
            check(held.all { it.statusCode == 200 })
            check(resources.response(resources.url("probe.js"), "GET") { true }.statusCode == 403)
            held[0].data.close()
            val replacement = resources.response(resources.url("probe.js"), "GET") { true }
            check(replacement.statusCode == 200); replacement.data.close()
            held.drop(1).forEach { it.data.close() }
            java.io.RandomAccessFile(File(pack, "large.bin"), "rw").use { it.setLength(8L * 1024 * 1024 + 1) }
            check(resources.response(resources.url("large.bin"), "GET") { true }.statusCode == 403)
            check(resources.response(resources.url("probe.js"), "POST") { true }.statusCode == 403)
            check(resources.response(resources.url("probe.js"), "GET") { false }.statusCode == 403)
            report.put("resourceBoundsAndCancellation", true)
            resources.close()
            command(messenger, "close"); command(messenger, "close")
            check(state()["phase"] == "closed"); report.put("closed", true)
            for (field in listOf("version", "entry")) {
                ui { (renderer!!.getView().parent as? ViewGroup)?.removeView(renderer!!.getView()); renderer!!.dispose() }
                for (name in listOf("mini-manifest.json", ".st-mini-package.json")) File(pack, name).writeBytes(RendererFixture.files.getValue(name))
                File(pack, "pixel.png").copyTo(File(pack, "identity-probe.png"), overwrite = true)
                renderer = ui { LocalMiniView(activity!!, messenger, 908,
                    mapOf("miniId" to "renderer_fixture", "version" to "1.0"), { true }, {}).also { activity!!.addContentView(it.getView(), ViewGroup.LayoutParams(-1, -1)) } }
                until { state()["phase"] == "ready" }
                view = currentWeb()
                until { js(view, "document.readyState==='complete' && window.__rendererProbe && window.__rendererProbe.ran") == "true" }
                js(view, "window.__missingDone=false; var missing=new Image(); missing.onerror=function(){window.__missingDone=true}; missing.src='missing.png'; document.body.appendChild(missing); true")
                until { js(view, "window.__missingDone===true") == "true" }
                check(state()["phase"] == "ready")
                for (name in listOf("mini-manifest.json", ".st-mini-package.json")) {
                    val changed = JSONObject(File(pack, name).readText()).put(field, if (field == "version") "2.0" else "second.html")
                    File(pack, name).writeText(changed.toString())
                }
                js(view, "var changed=new Image(); changed.src='identity-probe.png'; document.body.appendChild(changed); true")
                until { state()["phase"] == "failed" }; check(state()["errorCode"] == "package_unavailable")
                command(messenger, "reload")
                until { state()["phase"] == "failed" }; check(state()["errorCode"] == "package_unavailable")
                ui { (renderer!!.getView().parent as? ViewGroup)?.removeView(renderer!!.getView()); renderer!!.dispose() }
                renderer = ui { LocalMiniView(activity!!, messenger, 908,
                    mapOf("miniId" to "renderer_fixture", "version" to if (field == "version") "2.0" else "1.0"), { true }, {}).also { activity!!.addContentView(it.getView(), ViewGroup.LayoutParams(-1, -1)) } }
                until { state()["phase"] == "ready" }
                val reopened = currentWeb()
                check(ui { reopened.url?.substringAfterLast('/') } == if (field == "entry") "second.html" else "index.html")
                command(messenger, "close")
            }
            report.put("readyIdentityMutationFailsAndReopenRecovers", true).put("missingImageKeepsReady", true)
            for (name in listOf("mini-manifest.json", ".st-mini-package.json")) File(pack, name).writeBytes(RendererFixture.files.getValue(name))
            val manifest = JSONObject(File(pack, "mini-manifest.json").readText())
            val record = JSONObject(File(pack, ".st-mini-package.json").readText())
            val nfc = "caf\u00e9.html"; val nfd = "cafe\u0301.html"
            File(pack, "index.html").copyTo(File(pack, nfc))
            fun writeWire() {
                File(pack, "mini-manifest.json").writeText(manifest.toString())
                File(pack, ".st-mini-package.json").writeText(record.toString())
            }
            val inventory = LocalPackageInventory(targetContext.filesDir)
            manifest.put("entry", nfc); record.put("entry", nfd); writeWire(); check(inventory.read {}.isEmpty())
            record.put("entry", nfc); manifest.put("channel", "\u00e9"); record.put("channel", "e\u0301")
            writeWire(); check(inventory.read {}.isEmpty())
            manifest.put("channel", ""); record.put("channel", ""); writeWire(); check(inventory.read {}.size == 1)
            check(runCatching { inventory.verifiedPackage("renderer_fixture", "1.0", nfd) {} }.isFailure)
            report.put("unicodeExactWire", true).put("passed", true)
            report.put("uncovered", org.json.JSONArray(listOf("WebRTC", "UDP", "DNS", "physical device")))
        } catch (failure: Throwable) {
            report.put("passed", false).put("failure", failure.toString()).put("trace", failure.stackTrace.take(8).joinToString("\n"))
        } finally {
            renderer?.let { ui { (it.getView().parent as? ViewGroup)?.removeView(it.getView()); it.dispose() } }; server?.close(); activity?.let { ui { it.finish() } }
            pack.deleteRecursively(); if (root.exists() && root.list()?.isEmpty() == true) root.delete()
            report.put("rootAbsentAfterCleanup", !root.exists())
            File(targetContext.cacheDir, "renderer-native-result.json").writeText(report.toString())
            val results = Bundle(); results.putString("stream", "STMINI_LOCAL_ANDROID_DOM_RESULT $report\n")
            finish(if (report.optBoolean("passed")) Activity.RESULT_OK else Activity.RESULT_CANCELED, results)
        }
    }
}

private object RendererFixture {
    val files = mapOf(
        ".st-mini-package.json" to android.util.Base64.decode("eyJtaW5pSWQiOiAicmVuZGVyZXJfZml4dHVyZSIsICJtaW5pTmFtZSI6ICJMb2NhbCByZW5kZXJlciBmaXh0dXJlIiwgInZlcnNpb24iOiAiMS4wIiwgImVudHJ5IjogImluZGV4Lmh0bWwiLCAiaWNvbiI6ICJwaXhlbC5wbmciLCAiY2hhbm5lbCI6ICJmaXh0dXJlIn0K", android.util.Base64.DEFAULT),
        "index.html" to android.util.Base64.decode("PCFkb2N0eXBlIGh0bWw+PGh0bWw+PGhlYWQ+PG1ldGEgY2hhcnNldD0idXRmLTgiPjx0aXRsZT5Mb2NhbCBNaW5pIGZpeHR1cmU8L3RpdGxlPjxsaW5rIHJlbD0ic3R5bGVzaGVldCIgaHJlZj0ic3R5bGUuY3NzIj48c2NyaXB0IGRlZmVyIHNyYz0icHJvYmUuanMiPjwvc2NyaXB0PjwvaGVhZD48Ym9keT48aDEgaWQ9ImNvbnRlbnQiPldhaXRpbmcgZm9yIGxvY2FsIHNjcmlwdDwvaDE+PGltZyBpZD0icGl4ZWwiIHNyYz0icGl4ZWwucG5nIiBhbHQ9IkxvY2FsIHBpeGVsIj48YnV0dG9uIGlkPSJhY3Rpb24iPlRhcCBmaXh0dXJlPC9idXR0b24+PGEgaWQ9InNlY29uZCIgaHJlZj0ic2Vjb25kLmh0bWwiPlNlY29uZCBsb2NhbCBwYWdlPC9hPjxkaXYgaWQ9InJlc3VsdCI+PC9kaXY+PC9ib2R5PjwvaHRtbD4K", android.util.Base64.DEFAULT),
        "mini-manifest.json" to android.util.Base64.decode("eyJtaW5pSWQiOiAicmVuZGVyZXJfZml4dHVyZSIsICJtaW5pTmFtZSI6ICJMb2NhbCByZW5kZXJlciBmaXh0dXJlIiwgInZlcnNpb24iOiAiMS4wIiwgImVudHJ5IjogImluZGV4Lmh0bWwiLCAiaWNvbiI6ICJwaXhlbC5wbmciLCAiY2hhbm5lbCI6ICJmaXh0dXJlIn0K", android.util.Base64.DEFAULT),
        "pixel.png" to android.util.Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jr1sAAAAASUVORK5CYII=", android.util.Base64.DEFAULT),
        "probe.js" to android.util.Base64.decode("J3VzZSBzdHJpY3QnOwp3aW5kb3cuX19yZW5kZXJlclByb2JlID0geyByYW46IHRydWUsIGNsaWNrZWQ6IGZhbHNlLCByZW1vdGVDb2RlRXhlY3V0ZWQ6IGZhbHNlLCBhdHRlbXB0czoge30gfTsKZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2NvbnRlbnQnKS50ZXh0Q29udGVudCA9ICdWZXJpZmllZCBsb2NhbCBNaW5pIERPTSBmcm9tIHByb2JlLmpzJzsKZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2FjdGlvbicpLmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJywgZnVuY3Rpb24gKCkgewogIHdpbmRvdy5fX3JlbmRlcmVyUHJvYmUuY2xpY2tlZCA9IHRydWU7CiAgZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3Jlc3VsdCcpLnRleHRDb250ZW50ID0gJ0xvY2FsIGludGVyYWN0aW9uIGNvbXBsZXRlZCc7Cn0pOwp3aW5kb3cucnVuTmV0d29ya1Byb2JlID0gYXN5bmMgZnVuY3Rpb24gKHBvcnQpIHsKICBjb25zdCBwcm9iZSA9IHdpbmRvdy5fX3JlbmRlcmVyUHJvYmU7CiAgY29uc3QgYmFzZSA9ICdodHRwOi8vMTI3LjAuMC4xOicgKyBwb3J0ICsgJy8nOwogIGNvbnN0IGpvYnMgPSBbXTsKICBmdW5jdGlvbiByZXNvdXJjZShuYW1lLCBlbGVtZW50LCB1cmwpIHsKICAgIGpvYnMucHVzaChuZXcgUHJvbWlzZShmdW5jdGlvbiAocmVzb2x2ZSkgewogICAgICBsZXQgZW5kZWQgPSBmYWxzZTsKICAgICAgZnVuY3Rpb24gZW5kKHZhbHVlKSB7IGlmIChlbmRlZCkgcmV0dXJuOyBlbmRlZCA9IHRydWU7IHByb2JlLmF0dGVtcHRzW25hbWVdID0gdmFsdWU7IGVsZW1lbnQucmVtb3ZlKCk7IHJlc29sdmUoKTsgfQogICAgICBlbGVtZW50Lm9ubG9hZCA9IGZ1bmN0aW9uICgpIHsgZW5kKCdsb2FkJyk7IH07CiAgICAgIGVsZW1lbnQub25lcnJvciA9IGZ1bmN0aW9uICgpIHsgZW5kKCdlcnJvcicpOyB9OwogICAgICBwcm9iZS5hdHRlbXB0c1tuYW1lXSA9ICdhdHRlbXB0ZWQnOwogICAgICBlbGVtZW50LnNyYyA9IHVybDsKICAgICAgZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChlbGVtZW50KTsKICAgICAgc2V0VGltZW91dChmdW5jdGlvbiAoKSB7IGVuZCgndGltZW91dCcpOyB9LCAxMjAwKTsKICAgIH0pKTsKICB9CiAgcmVzb3VyY2UoJ2ltYWdlJywgbmV3IEltYWdlKCksIGJhc2UgKyAnaW1hZ2UnKTsKICByZXNvdXJjZSgncmVtb3RlU2NyaXB0JywgZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnc2NyaXB0JyksIGJhc2UgKyAnc2NyaXB0Jyk7CiAgcmVzb3VyY2UoJ2lmcmFtZScsIGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2lmcmFtZScpLCBiYXNlICsgJ2ZyYW1lJyk7CiAgcmVzb3VyY2UoJ2ZpbGUnLCBuZXcgSW1hZ2UoKSwgJ2ZpbGU6Ly8vZXRjL3Bhc3N3ZCcpOwogIHJlc291cmNlKCdjb250ZW50JywgbmV3IEltYWdlKCksICdjb250ZW50Oi8vc3RtaW5pLmludmFsaWQvcHJpdmF0ZScpOwogIHJlc291cmNlKCdkYXRhU2NyaXB0JywgZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnc2NyaXB0JyksICdkYXRhOnRleHQvamF2YXNjcmlwdCx3aW5kb3cuX19yZW5kZXJlclByb2JlLnJlbW90ZUNvZGVFeGVjdXRlZD10cnVlJyk7CiAgY29uc3QgYmxvYiA9IFVSTC5jcmVhdGVPYmplY3RVUkwobmV3IEJsb2IoWyd3aW5kb3cuX19yZW5kZXJlclByb2JlLnJlbW90ZUNvZGVFeGVjdXRlZD10cnVlJ10sIHsgdHlwZTogJ2FwcGxpY2F0aW9uL2phdmFzY3JpcHQnIH0pKTsKICByZXNvdXJjZSgnYmxvYlNjcmlwdCcsIGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3NjcmlwdCcpLCBibG9iKTsKICBwcm9iZS5hdHRlbXB0cy5mZXRjaCA9ICdhdHRlbXB0ZWQnOwogIGpvYnMucHVzaChmZXRjaChiYXNlICsgJ2ZldGNoJykudGhlbihmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLmZldGNoID0gJ3Jlc29sdmVkJzsgfSwgZnVuY3Rpb24gKCkgeyBwcm9iZS5hdHRlbXB0cy5mZXRjaCA9ICdyZWplY3RlZCc7IH0pKTsKICBqb2JzLnB1c2gobmV3IFByb21pc2UoZnVuY3Rpb24gKHJlc29sdmUpIHsKICAgIGNvbnN0IHhociA9IG5ldyBYTUxIdHRwUmVxdWVzdCgpOyBwcm9iZS5hdHRlbXB0cy54aHIgPSAnYXR0ZW1wdGVkJzsKICAgIHhoci5vbmxvYWQgPSBmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLnhociA9ICdsb2FkJzsgcmVzb2x2ZSgpOyB9OwogICAgeGhyLm9uZXJyb3IgPSBmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLnhociA9ICdlcnJvcic7IHJlc29sdmUoKTsgfTsKICAgIHhoci5vbnRpbWVvdXQgPSBmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLnhociA9ICd0aW1lb3V0JzsgcmVzb2x2ZSgpOyB9OwogICAgdHJ5IHsgeGhyLm9wZW4oJ0dFVCcsIGJhc2UgKyAneGhyJyk7IHhoci50aW1lb3V0ID0gMTIwMDsgeGhyLnNlbmQoKTsgfQogICAgY2F0Y2ggKF8pIHsgcHJvYmUuYXR0ZW1wdHMueGhyID0gJ3JlamVjdGVkJzsgcmVzb2x2ZSgpOyB9CiAgfSkpOwogIGpvYnMucHVzaChuZXcgUHJvbWlzZShmdW5jdGlvbiAocmVzb2x2ZSkgewogICAgcHJvYmUuYXR0ZW1wdHMud2Vic29ja2V0ID0gJ2F0dGVtcHRlZCc7IGxldCBzb2NrZXQ7CiAgICB0cnkgewogICAgICBzb2NrZXQgPSBuZXcgV2ViU29ja2V0KCd3czovLzEyNy4wLjAuMTonICsgcG9ydCArICcvc29ja2V0Jyk7CiAgICAgIHNvY2tldC5vbmVycm9yID0gZnVuY3Rpb24gKCkgeyBwcm9iZS5hdHRlbXB0cy53ZWJzb2NrZXQgPSAnZXJyb3InOyByZXNvbHZlKCk7IH07CiAgICAgIHNvY2tldC5vbm9wZW4gPSBmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLndlYnNvY2tldCA9ICdvcGVuJzsgc29ja2V0LmNsb3NlKCk7IHJlc29sdmUoKTsgfTsKICAgICAgc2V0VGltZW91dChmdW5jdGlvbiAoKSB7IGlmIChwcm9iZS5hdHRlbXB0cy53ZWJzb2NrZXQgPT09ICdhdHRlbXB0ZWQnKSB7IHByb2JlLmF0dGVtcHRzLndlYnNvY2tldCA9ICd0aW1lb3V0Jzsgc29ja2V0LmNsb3NlKCk7IHJlc29sdmUoKTsgfSB9LCAxMjAwKTsKICAgIH0gY2F0Y2ggKF8pIHsgcHJvYmUuYXR0ZW1wdHMud2Vic29ja2V0ID0gJ3JlamVjdGVkJzsgcmVzb2x2ZSgpOyB9CiAgfSkpOwogIHByb2JlLmF0dGVtcHRzLnBvcHVwID0gd2luZG93Lm9wZW4oYmFzZSArICdwb3B1cCcsICdfYmxhbmsnKSA9PT0gbnVsbCA/ICdyZWplY3RlZCcgOiAnb3BlbmVkJzsKICBjb25zdCBmb3JtID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZm9ybScpOyBmb3JtLmFjdGlvbiA9IGJhc2UgKyAnZm9ybSc7IGZvcm0ubWV0aG9kID0gJ1BPU1QnOwogIHByb2JlLmF0dGVtcHRzLmZvcm0gPSAnYXR0ZW1wdGVkJzsgZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChmb3JtKTsgZm9ybS5zdWJtaXQoKTsgZm9ybS5yZW1vdmUoKTsKICBqb2JzLnB1c2gobmV3IFByb21pc2UoZnVuY3Rpb24gKHJlc29sdmUpIHsgc2V0VGltZW91dChmdW5jdGlvbiAoKSB7IHByb2JlLmF0dGVtcHRzLmZvcm0gPSAnc2V0dGxlZF93aXRob3V0X25hdmlnYXRpb24nOyByZXNvbHZlKCk7IH0sIDEyMDApOyB9KSk7CiAgYXdhaXQgUHJvbWlzZS5hbGwoam9icyk7IFVSTC5yZXZva2VPYmplY3RVUkwoYmxvYik7IHByb2JlLmRvbmUgPSB0cnVlOwogIHJldHVybiBwcm9iZTsKfTsK", android.util.Base64.DEFAULT),
        "second.html" to android.util.Base64.decode("PCFkb2N0eXBlIGh0bWw+PGh0bWw+PGhlYWQ+PG1ldGEgY2hhcnNldD0idXRmLTgiPjx0aXRsZT5TZWNvbmQgbG9jYWwgTWluaTwvdGl0bGU+PGxpbmsgcmVsPSJzdHlsZXNoZWV0IiBocmVmPSJzdHlsZS5jc3MiPjwvaGVhZD48Ym9keT48aDEgaWQ9InNlY29uZC1jb250ZW50Ij5WZXJpZmllZCBzZWNvbmQgbG9jYWwgZG9jdW1lbnQ8L2gxPjxhIGhyZWY9ImluZGV4Lmh0bWwiPkZpcnN0IGxvY2FsIHBhZ2U8L2E+PC9ib2R5PjwvaHRtbD4K", android.util.Base64.DEFAULT),
        "style.css" to android.util.Base64.decode("Ym9keSB7IGJhY2tncm91bmQ6IHJnYigyNDUsIDI0OCwgMjUyKTsgY29sb3I6IHJnYigxMywgNDcsIDgzKTsgZm9udC1mYW1pbHk6IHNhbnMtc2VyaWY7IH0gI2NvbnRlbnQgeyBjb2xvcjogcmdiKDEzLCA0NywgODMpOyB9IGJ1dHRvbiB7IG1pbi1oZWlnaHQ6IDQ4cHg7IH0K", android.util.Base64.DEFAULT),
    )
}
