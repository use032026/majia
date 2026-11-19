package com.fsst.stmini_flutter.ui

import android.graphics.Bitmap
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class MiniLaunchSnapshotStoreTest {
    @Before fun setUp() = MiniLaunchSnapshotStore.clearForMemoryPressure()
    @After fun tearDown() = MiniLaunchSnapshotStore.clearForMemoryPressure()

    @Test fun replacementRecyclesOldSnapshotAndConsumesTheNewOneOnce() {
        val first = Bitmap.createBitmap(4, 4, Bitmap.Config.RGB_565)
        val second = Bitmap.createBitmap(4, 4, Bitmap.Config.RGB_565)

        MiniLaunchSnapshotStore.rememberForTest(RuntimeEnvironment.getApplication(), "mini", first)
        MiniLaunchSnapshotStore.rememberForTest(RuntimeEnvironment.getApplication(), "MINI", second)

        assertTrue(first.isRecycled)
        assertSame(second, MiniLaunchSnapshotStore.take("mini"))
        assertEquals(0, MiniLaunchSnapshotStore.pendingCountForTest())
        second.recycle()
    }

    @Test fun memoryPressureClearsAndRecyclesPendingSnapshots() {
        val snapshot = Bitmap.createBitmap(4, 4, Bitmap.Config.RGB_565)
        MiniLaunchSnapshotStore.rememberForTest(RuntimeEnvironment.getApplication(), "mini", snapshot)

        MiniLaunchSnapshotStore.clearForMemoryPressure()

        assertTrue(snapshot.isRecycled)
        assertEquals(0, MiniLaunchSnapshotStore.pendingCountForTest())
    }
}
