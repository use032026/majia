package com.fsst.stmini_flutter.inventorytest

import com.fsst.stmini_flutter.runtime.LocalPackageInventory
import java.io.File
import java.nio.file.Files
import org.json.JSONObject
import kotlin.system.exitProcess

/** Real filesystem cases for JVM/Android app_process; never an application entry point. */
object InventoryCases {
    private class Fixture(val container: File) {
        val base = File(container, "files").apply { mkdirs() }
        val root get() = File(base, "STMini")
        fun read(check: () -> Unit = {}): List<Map<String, String>> = LocalPackageInventory(base).read(check)
        fun pack(id: String = "alpha", manifestChanges: Map<String, Any?> = emptyMap(),
                 recordChanges: Map<String, Any?> = emptyMap()): File {
            val directory = File(root, id).apply { mkdirs() }
            File(directory, "pages").mkdirs()
            File(directory, "images").mkdirs()
            File(directory, "pages/index.html").writeText("local test entry")
            File(directory, "images/icon.png").writeText("local test icon")
            val manifest = mutableMapOf<String, Any?>("miniId" to id, "miniName" to "Local test",
                "version" to "1.2", "entry" to "pages/index.html", "icon" to "images/icon.png")
            val record = mutableMapOf<String, Any?>("miniId" to id, "version" to "1.2", "entry" to "pages/index.html")
            manifest.putAll(manifestChanges); record.putAll(recordChanges)
            File(directory, "mini-manifest.json").writeText(JSONObject(manifest).toString())
            File(directory, ".st-mini-package.json").writeText(JSONObject(record).toString())
            return directory
        }
    }

    private fun requireCount(fixture: Fixture, count: Int) {
        check(fixture.read().size == count) { "Unexpected validated count" }
    }
    private fun unavailable(action: () -> Unit) {
        try { action(); error("Expected unavailable") }
        catch (_: LocalPackageInventory.Unavailable) { }
    }
    private fun remove(file: File) {
        if (!Files.exists(file.toPath(), java.nio.file.LinkOption.NOFOLLOW_LINKS)) return
        Files.walk(file.toPath()).use { paths ->
            paths.sorted(Comparator.reverseOrder()).forEach { Files.delete(it) }
        }
    }
    private fun link(file: File, target: File) {
        remove(file); file.parentFile.mkdirs(); Files.createSymbolicLink(file.toPath(), target.toPath())
    }
    private fun tree(base: File): List<String> = Files.walk(base.toPath()).use { paths ->
        paths.map { path ->
            val relative = base.toPath().relativize(path).toString()
            if (Files.isSymbolicLink(path)) "link:$relative"
            else if (Files.isDirectory(path)) "dir:$relative"
            else "file:$relative:${File(path.toString()).readBytes().contentHashCode()}"
        }.sorted().toArray().map { it.toString() }
    }

    @JvmStatic fun main(args: Array<String>) {
        require(args.size == 1) { "One private temporary base is required" }
        val owner = File(args[0], "inventory-cases-${System.nanoTime()}").apply { check(mkdirs()) }
        val results = mutableListOf<Map<String, Any>>()
        var serial = 0
        fun run(name: String, body: (Fixture) -> Unit) {
            val container = File(owner, "case-${serial++}").apply { mkdirs() }
            try {
                body(Fixture(container))
                results.add(mapOf("name" to name, "passed" to true))
            } catch (error: Throwable) {
                results.add(mapOf("name" to name, "passed" to false, "failure" to error.javaClass.simpleName))
            } finally { remove(container) }
        }
        try {
            run("missing-root-read-does-not-create") { f ->
                val before = tree(f.base); requireCount(f, 0); check(before == tree(f.base)); check(!f.root.exists())
            }
            run("empty-root-read-does-not-write") { f ->
                f.root.mkdirs(); val before = tree(f.base); requireCount(f, 0); check(before == tree(f.base))
            }
            run("valid-sorted-five-field-metadata-no-writes") { f ->
                f.pack("zeta"); f.pack("alpha"); val before = tree(f.base)
                val records = f.read(); check(records.map { it["miniId"] } == listOf("alpha", "zeta"))
                check(records.all { it.keys == setOf("miniId", "miniName", "version", "entry", "icon") })
                check(records.all { it["version"] == "1.2" }); check(before == tree(f.base))
            }
            run("empty-name-and-icon") { f ->
                f.pack(manifestChanges = mapOf("miniName" to "", "icon" to ""))
                check(f.read().single()["miniName"] == "alpha"); check(f.read().single()["icon"] == "")
            }
            run("manifest-missing-optional-name-icon") { f ->
                val directory = f.pack(); val file = File(directory, "mini-manifest.json")
                val json = JSONObject(file.readText()); json.remove("miniName"); json.remove("icon"); file.writeText(json.toString())
                check(f.read().single()["miniName"] == "alpha"); check(f.read().single()["icon"] == "")
            }
            for ((field, value) in listOf("miniId" to "other", "version" to "1.3", "entry" to "other.html")) {
                run("record-mismatch-$field") { f -> f.pack(recordChanges = mapOf(field to value)); requireCount(f, 0) }
            }
            for (field in listOf("miniId", "version", "entry", "icon", "miniName", "channel", "updateself", "ishome")) {
                run("manifest-wrong-type-$field") { f -> f.pack(manifestChanges = mapOf(field to 7)); requireCount(f, 0) }
            }
            for (field in listOf("miniId", "version", "entry", "channel")) {
                run("record-wrong-type-$field") { f -> f.pack(recordChanges = mapOf(field to false)); requireCount(f, 0) }
            }
            for ((index, version) in listOf("", "1.", ".1", "1..2", "-1", "1e2", "1-beta", "1_2", "1\n", "1234567890", List(9) { "1" }.joinToString(".")).withIndex()) {
                run("invalid-version-$index") { f -> f.pack(manifestChanges = mapOf("version" to version), recordChanges = mapOf("version" to version)); requireCount(f, 0) }
            }
            run("maximum-version-and-leading-zero") { f ->
                val version = List(8) { "123456789" }.joinToString(".")
                f.pack(manifestChanges = mapOf("version" to version), recordChanges = mapOf("version" to version)); requireCount(f, 1)
                f.pack("zero", mapOf("version" to "000.01"), mapOf("version" to "000.01")); requireCount(f, 2)
            }
            for ((index, id) in listOf("Alpha", "_alpha", "a".repeat(65)).withIndex()) {
                run("invalid-id-$index") { f -> f.pack(id); requireCount(f, 0) }
            }
            run("utf16-name-boundary") { f -> f.pack(manifestChanges = mapOf("miniName" to "😀".repeat(128))); requireCount(f, 1) }
            run("utf16-name-overflow") { f -> f.pack(manifestChanges = mapOf("miniName" to "😀".repeat(129))); requireCount(f, 0) }
            for ((index, path) in listOf("", "/index.html", "a//b", "a/", ".", "..", "a/../b", "a\\b", "https:x", "a?b", "a#b", "a%b", "a\u0000b", "a\u001fb", "a\u007fb", "a\u0085b", "a".repeat(129), List(17) { "a" }.joinToString("/"), List(8) { "a".repeat(128) }.joinToString("/")).withIndex()) {
                run("invalid-entry-path-$index") { f -> f.pack(manifestChanges = mapOf("entry" to path), recordChanges = mapOf("entry" to path)); requireCount(f, 0) }
            }
            run("deep-safe-path") { f ->
                val path = List(16) { "a" }.joinToString("/")
                val directory = f.pack(manifestChanges = mapOf("entry" to path), recordChanges = mapOf("entry" to path))
                File(directory, path).apply { parentFile.mkdirs(); writeText("deep") }; requireCount(f, 1)
            }
            run("channel-mismatch") { f -> f.pack(manifestChanges = mapOf("channel" to "one"), recordChanges = mapOf("channel" to "two")); requireCount(f, 0) }
            run("channel-overflow") { f -> val value = "x".repeat(129); f.pack(manifestChanges = mapOf("channel" to value), recordChanges = mapOf("channel" to value)); requireCount(f, 0) }
            for (field in listOf("entry", "icon")) {
                run("missing-$field-file") { f -> val d = f.pack(); remove(File(d, if (field == "entry") "pages/index.html" else "images/icon.png")); requireCount(f, 0) }
                run("directory-as-$field-file") { f -> val d = f.pack(); val file = File(d, if (field == "entry") "pages/index.html" else "images/icon.png"); remove(file); file.mkdirs(); requireCount(f, 0) }
            }
            for (name in listOf("mini-manifest.json", ".st-mini-package.json")) {
                run("metadata-directory-$name") { f -> val d = f.pack(); val file = File(d, name); remove(file); file.mkdirs(); requireCount(f, 0) }
                run("metadata-too-large-$name") { f -> val d = f.pack(); File(d, name).writeText(" ".repeat(65537)); requireCount(f, 0) }
                run("metadata-malformed-$name") { f -> val d = f.pack(); File(d, name).writeText("{broken"); requireCount(f, 0) }
                run("metadata-invalid-utf8-$name") { f -> val d = f.pack(); File(d, name).writeBytes(byteArrayOf(0xc3.toByte(), 0x28)); requireCount(f, 0) }
            }
            for (name in listOf("mini-manifest.json", ".st-mini-package.json")) {
                for ((grammar, malformed) in listOf(
                    "single-quotes" to "{'miniId':'alpha','version':'1.2','entry':'pages/index.html'}",
                    "unquoted-name" to "{miniId: \"alpha\", \"version\": \"1.2\", \"entry\": \"pages/index.html\"}",
                    "trailing-comment" to "{\"miniId\":\"alpha\",\"version\":\"1.2\",\"entry\":\"pages/index.html\"}// comment",
                    "extra-root" to "{\"miniId\":\"alpha\",\"version\":\"1.2\",\"entry\":\"pages/index.html\"} {}"
                )) {
                    run("strict-json-$grammar-$name") { f ->
                        val d = f.pack(); File(d, name).writeText(malformed); requireCount(f, 0)
                    }
                }
            }
            run("same-version-deleted-entry-rechecked") { f -> val d = f.pack(); requireCount(f, 1); File(d, "pages/index.html").delete(); requireCount(f, 0) }
            run("same-version-mutated-manifest-rechecked") { f -> val d = f.pack(); requireCount(f, 1); File(d, "mini-manifest.json").writeText("{}"); requireCount(f, 0) }
            for (level in listOf("root", "package", "record", "manifest", "intermediate", "entry", "icon")) {
                for (location in listOf("inside", "outside", "broken")) {
                    run("symlink-$level-$location") { f ->
                        val d = f.pack()
                        val original = when (level) {
                            "root" -> f.root; "package" -> d
                            "record" -> File(d, ".st-mini-package.json"); "manifest" -> File(d, "mini-manifest.json")
                            "intermediate" -> File(d, "pages"); "entry" -> File(d, "pages/index.html")
                            else -> File(d, "images/icon.png")
                        }
                        val inside = when (level) {
                            "root" -> f.base; "package" -> f.root; else -> d
                        }
                        val target = File(if (location == "inside") inside else f.container, "target")
                        if (location != "broken") {
                            if (original.isDirectory) original.copyRecursively(target)
                            else original.copyTo(target)
                        }
                        link(original, target)
                        if (level == "root") unavailable { f.read() } else requireCount(f, 0)
                    }
                }
            }
            run("root-is-file") { f -> f.root.writeText("not directory"); unavailable { f.read() } }
            run("candidate-limit-refuses-truncation") { f -> f.root.mkdirs(); repeat(257) { File(f.root, "p$it").mkdirs() }; unavailable { f.read() } }
            run("hidden-staging-ignored") { f -> f.pack(".staging"); requireCount(f, 0) }
            run("cancel-before-read") { f -> unavailable { f.read { throw LocalPackageInventory.Unavailable() } } }
            run("deadline-after-base-read-does-not-fake-empty") { f ->
                var checks = 0
                unavailable { f.read { if (++checks == 2) throw LocalPackageInventory.Unavailable() } }
                check(checks == 2)
            }
            run("deadline-during-read") { f -> f.pack(); var checks = 0; unavailable { f.read { if (++checks == 5) throw LocalPackageInventory.Unavailable() } }; check(checks == 5) }
        } finally { remove(owner) }
        val passed = results.all { it["passed"] == true }
        println("STMINI_NATIVE_INVENTORY_RESULT " + JSONObject(mapOf("kind" to "real_filesystem_local_inventory", "passed" to passed, "caseCount" to results.size, "cases" to results)).toString())
        if (!passed) exitProcess(1)
    }
}
