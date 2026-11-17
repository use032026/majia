package android.os

// Deterministic scheduling stand-in only. This is not an Android OS test.
class Looper private constructor() {
    private val queue = ArrayDeque<Runnable>()
    companion object {
        private val main = Looper()
        @JvmStatic fun getMainLooper(): Looper = main
        fun drainForTest() { while (main.queue.isNotEmpty()) main.queue.removeFirst().run() }
    }
    internal fun enqueue(runnable: Runnable) { queue.addLast(runnable) }
}
class Handler(private val looper: Looper) {
    fun post(runnable: Runnable): Boolean { looper.enqueue(runnable); return true }
}
