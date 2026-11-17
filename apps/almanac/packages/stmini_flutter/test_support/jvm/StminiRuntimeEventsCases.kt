import android.os.Looper
import com.fsst.stmini_flutter.StminiRuntimeEvents

fun main() {
    var passed = 0
    fun scenario(name: String, body: () -> Unit) {
        body()
        Looper.drainForTest()
        passed += 1
        println("PASS $name")
    }
    scenario("current listener receives the original envelope") {
        val observed = mutableListOf<Map<String, Any?>>()
        val owner = StminiRuntimeEvents.attach { observed.add(it) }
        owner.emit("foundation_initialized", mapOf("initialized" to true))
        check(observed.isEmpty())
        Looper.drainForTest()
        check(observed == listOf(mapOf("name" to "foundation_initialized", "payload" to mapOf("initialized" to true))))
        owner.cancel()
    }
    scenario("queued old owner is not delivered to replacement") {
        val first = mutableListOf<Map<String, Any?>>()
        val second = mutableListOf<Map<String, Any?>>()
        val a = StminiRuntimeEvents.attach { first.add(it) }
        StminiRuntimeEvents.emit("old")
        a.cancel()
        val b = StminiRuntimeEvents.attach { second.add(it) }
        Looper.drainForTest()
        check(first.isEmpty() && second.isEmpty())
        b.cancel()
    }
    scenario("emit without a listener is not retained for a future listener") {
        StminiRuntimeEvents.emit("unowned")
        val seen = mutableListOf<Map<String, Any?>>()
        val owner = StminiRuntimeEvents.attach { seen.add(it) }
        Looper.drainForTest()
        check(seen.isEmpty())
        owner.cancel()
    }
    scenario("obsolete cancellation cannot clear current listener") {
        val a = StminiRuntimeEvents.attach { error("obsolete listener") }
        val seen = mutableListOf<Map<String, Any?>>()
        val b = StminiRuntimeEvents.attach { seen.add(it) }
        a.cancel()
        StminiRuntimeEvents.emit("current")
        Looper.drainForTest()
        check(seen.single()["name"] == "current")
        b.cancel()
    }
    scenario("old instance cannot emit into a new instance subscription") {
        val a = StminiRuntimeEvents.attach { error("obsolete listener") }
        val seen = mutableListOf<Map<String, Any?>>()
        val b = StminiRuntimeEvents.attach { seen.add(it) }
        a.emit("obsolete")
        b.emit("current")
        Looper.drainForTest()
        check(seen.size == 1 && seen.single()["name"] == "current")
        b.cancel()
    }
    scenario("payload is captured before yielding") {
        val seen = mutableListOf<Map<String, Any?>>()
        val owner = StminiRuntimeEvents.attach { seen.add(it) }
        val payload = mutableMapOf<String, Any?>("value" to "before")
        owner.emit("snapshot", payload)
        payload["value"] = "after"
        Looper.drainForTest()
        check((seen.single()["payload"] as Map<*, *>)["value"] == "before")
        owner.cancel()
    }
    scenario("detached sink exception is isolated and releases its subscription") {
        val broken = StminiRuntimeEvents.attach { throw IllegalStateException("detached test messenger") }
        broken.emit("first")
        broken.emit("late")
        Looper.drainForTest()
        val seen = mutableListOf<Map<String, Any?>>()
        val current = StminiRuntimeEvents.attach { seen.add(it) }
        broken.cancel()
        current.emit("recovered")
        Looper.drainForTest()
        check(seen.single()["name"] == "recovered")
        current.cancel()
    }
    scenario("a delivery can replace its own listener without deadlocking") {
        val seen = mutableListOf<Map<String, Any?>>()
        var b: StminiRuntimeEvents.Subscription? = null
        val a = StminiRuntimeEvents.attach {
            b = StminiRuntimeEvents.attach { event -> seen.add(event) }
            b!!.emit("replacement")
        }
        a.emit("first")
        Looper.drainForTest()
        check(seen.single()["name"] == "replacement")
        a.cancel()
        b!!.cancel()
    }
    println("$passed deterministic production-source scheduling cases passed; not Android OS execution")
}
