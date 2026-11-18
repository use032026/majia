package com.fsst.stmini_flutter.inventorytest

import android.content.ContextWrapper
import android.os.Handler
import android.os.Looper
import com.fsst.stmini_flutter.StminiFlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import kotlin.system.exitProcess

/** Real Android Handler/Looper/Filesystem + production plugin sources.
 * Flutter channel/embedding and preference configuration are explicit test glue;
 * this is not proof of running a FlutterEngine. No production hook is added.
 */
object LifecycleCases {
    private class TestContext(private val directory: File) : ContextWrapper(null) {
        override fun getPackageName(): String = "com.almanac.lite"
        override fun getFilesDir(): File = directory
    }
    /** Simulates an OS read that returns after cancellation. Only the worker waits. */
    private class ReadGateFile(private val real: File, private val entered: () -> Unit) : File(real.path) {
        val release = CountDownLatch(1)
        override fun getCanonicalFile(): File {
            entered()
            var interrupted = false
            while (true) {
                try {
                    check(release.await(8, TimeUnit.SECONDS)) { "worker-gate-timeout" }
                    break
                } catch (_: InterruptedException) { interrupted = true }
            }
            if (interrupted) Thread.currentThread().interrupt()
            return real.canonicalFile
        }
    }

    @JvmStatic fun main(args: Array<String>) {
        require(args.size == 1) { "One task-owned temporary parent is required" }
        Looper.prepareMainLooper()
        val main = Handler(Looper.getMainLooper())
        val owner = File(args[0], "inventory-lifecycle-${System.nanoTime()}").apply { check(mkdirs()) }
        val oldFiles = File(owner, "old-files").apply { mkdirs() }
        val newFiles = File(owner, "new-files").apply { mkdirs() }
        val plugin = StminiFlutterPlugin()
        val cases = mutableListOf<Map<String, Any>>()
        var finished = false
        var attachedBinding: FlutterPlugin.FlutterPluginBinding? = null
        var oldGate: ReadGateFile? = null
        var newGate: ReadGateFile? = null
        val messenger = object : BinaryMessenger { }

        fun finish(passed: Boolean, failure: String? = null) {
            if (finished) return
            finished = true
            oldGate?.release?.countDown(); newGate?.release?.countDown()
            attachedBinding?.let { try { plugin.onDetachedFromEngine(it) } catch (_: Throwable) { } }
            // Cleanup is restricted to the fixture created above; no symlink traversal.
            Files.walk(owner.toPath()).use { paths ->
                paths.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) }
            }
            val result = mutableMapOf<String, Any>(
                "kind" to "real_android_os_plugin_lifecycle_with_flutter_glue_stubs",
                "passed" to passed, "caseCount" to cases.size, "cases" to cases,
                "flutterEngineExecuted" to false,
                "productionSources" to listOf("StminiFlutterPlugin", "LocalPackageInventory", "StminiRuntimeEvents"))
            if (failure != null) result["failure"] = failure
            println("STMINI_NATIVE_LIFECYCLE_RESULT " + JSONObject(result).toString())
            exitProcess(if (passed) 0 else 1)
        }
        fun guarded(body: () -> Unit) {
            if (finished) return
            try { body() } catch (error: Throwable) { finish(false, error.javaClass.simpleName + ":" + (error.message ?: "case-failed")) }
        }
        fun expect(name: String, condition: Boolean) {
            cases.add(mapOf("name" to name, "passed" to condition))
            check(condition) { name }
        }
        class Reply(private val label: String, private val action: (Any?, String?) -> Unit) : MethodChannel.Result {
            var count = 0
            private fun complete(value: Any?, error: String?) = guarded {
                count += 1
                expect("$label-main-thread", Looper.myLooper() === Looper.getMainLooper())
                expect("$label-once", count == 1)
                action(value, error)
            }
            override fun success(value: Any?) = complete(value, null)
            override fun error(code: String, message: String?, details: Any?) = complete(null, code)
            override fun notImplemented() = complete(null, "not_implemented")
        }
        fun call(method: String, reply: Reply, arguments: Any? = null) {
            plugin.onMethodCall(MethodCall(method, arguments), reply)
        }
        fun initialize(label: String) {
            val reply = Reply(label) { value, error -> expect("$label-success", value == null && error == null) }
            call("initialize", reply, mapOf("bridgeContext" to mapOf("packageName" to "com.almanac.lite")))
            expect("$label-completed", reply.count == 1)
        }

        main.postDelayed({ guarded { expect("watchdog", false) } }, 12_000)
        guarded {
            lateinit var oldReply: Reply
            lateinit var newReply: Reply
            lateinit var executor: ExecutorService
            lateinit var oldBinding: FlutterPlugin.FlutterPluginBinding
            oldGate = ReadGateFile(oldFiles) {
                main.post { guarded {
                    expect("old-worker-entered-before-detach", oldReply.count == 0)
                    plugin.onDetachedFromEngine(oldBinding)
                    attachedBinding = null
                    expect("detach-cancels-original-once", oldReply.count == 1)
                    // A fresh attach must reset initialized identity/language independently.
                    newGate = ReadGateFile(newFiles) {
                        main.post { guarded {
                            expect("new-query-stays-pending", newReply.count == 0)
                            oldGate!!.release.countDown()
                            // Await on a helper thread, never block Android's main message queue.
                            Thread {
                                val terminated = executor.awaitTermination(5, TimeUnit.SECONDS)
                                main.post { guarded {
                                    expect("old-worker-terminated-after-posting-late-callback", terminated)
                                    expect("late-old-callback-not-delivered-twice", oldReply.count == 1)
                                    expect("late-old-callback-cannot-finish-new-query", newReply.count == 0)
                                    call("installedPackages", Reply("new-still-busy") { _, error ->
                                        expect("new-query-ownership-preserved", error == "inventory_busy")
                                    })
                                    newGate!!.release.countDown()
                                } }
                            }.apply { isDaemon = true; start() }
                        } }
                    }
                    val binding = FlutterPlugin.FlutterPluginBinding(TestContext(newGate!!), messenger)
                    plugin.onAttachedToEngine(binding)
                    attachedBinding = binding
                    call("foundationState", Reply("reattach-state") { value, error ->
                        val state = value as? Map<*, *>
                        expect("reattach-clears-initialized-and-identity", error == null && state != null && state["initialized"] == false && state["packageName"] == null && state["language"] == null)
                    })
                    call("installedPackages", Reply("reattach-uninitialized") { _, error -> expect("reattach-requires-initialize", error == "not_initialized") })
                    initialize("new-initialize")
                    newReply = Reply("new-inventory") { value, error ->
                        expect("new-query-empty-real-root", error == null && value is List<*> && value.isEmpty())
                        expect("no-root-created-old-or-new", !File(oldFiles, "STMini").exists() && !File(newFiles, "STMini").exists())
                        expect("original-cancel-terminal-preserved", oldReply.count == 1)
                        // Keep pumping the real OS queue after success to catch duplicate results.
                        main.postDelayed({ guarded {
                            expect("new-result-once-after-late-window", newReply.count == 1)
                            expect("old-result-once-after-late-window", oldReply.count == 1)
                            finish(true)
                        } }, 100)
                    }
                    call("installedPackages", newReply)
                    call("installedPackages", Reply("new-busy") { _, error -> expect("new-single-flight-busy", error == "inventory_busy") })
                } }
            }
            oldBinding = FlutterPlugin.FlutterPluginBinding(TestContext(oldGate!!), messenger)
            plugin.onAttachedToEngine(oldBinding)
            attachedBinding = oldBinding
            call("installedPackages", Reply("old-uninitialized") { _, error -> expect("initial-read-requires-initialize", error == "not_initialized") })
            initialize("old-initialize")
            oldReply = Reply("old-inventory") { _, error -> expect("old-cancel-code", error == "inventory_cancelled") }
            call("installedPackages", oldReply)
            // Reflection observes the real executor only; it does not change production state.
            val executorField = StminiFlutterPlugin::class.java.getDeclaredField("inventoryExecutor").apply { isAccessible = true }
            executor = executorField.get(plugin) as ExecutorService
            call("installedPackages", Reply("old-busy") { _, error -> expect("old-single-flight-busy", error == "inventory_busy") })
        }
        Looper.loop()
    }
}
