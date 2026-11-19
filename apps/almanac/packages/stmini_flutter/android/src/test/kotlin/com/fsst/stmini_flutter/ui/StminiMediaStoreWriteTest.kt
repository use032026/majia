package com.fsst.stmini_flutter.ui

import android.net.Uri
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class StminiMediaStoreWriteTest {
    @Test fun failedWriteDeletesTheAlreadyInsertedPendingRow() {
        val sink = FakeSink(failWrite = true)
        val result = StminiMediaStoreWrite.write(sink, byteArrayOf(1))

        assertTrue(result.isFailure)
        assertTrue(sink.deleted)
        assertFalse(sink.published)
    }

    @Test fun successfulWritePublishesWithoutDeleting() {
        val sink = FakeSink()
        val result = StminiMediaStoreWrite.write(sink, byteArrayOf(1))

        assertTrue(result.isSuccess)
        assertTrue(sink.published)
        assertFalse(sink.deleted)
    }

    private class FakeSink(private val failWrite: Boolean = false) : StminiMediaStoreWrite.Sink {
        private val uri = Uri.parse("content://media/images/1")
        var published = false
        var deleted = false
        override fun insert(): Uri = uri
        override fun write(uri: Uri, bytes: ByteArray) { if (failWrite) error("disk full") }
        override fun publish(uri: Uri) { published = true }
        override fun delete(uri: Uri) { deleted = true }
    }
}
