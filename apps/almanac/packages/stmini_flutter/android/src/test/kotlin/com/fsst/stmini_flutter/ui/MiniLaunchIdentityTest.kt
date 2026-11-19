package com.fsst.stmini_flutter.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class MiniLaunchIdentityTest {
    @Test
    fun onlyAForcedRootUpdateMayBlockTheAlreadyRenderedMini() {
        assertEquals(true, MiniRootUpdatePresentation.shouldBlockRoot(isRootMini = true, isForce = true))
        assertEquals(false, MiniRootUpdatePresentation.shouldBlockRoot(isRootMini = true, isForce = false))
        assertEquals(false, MiniRootUpdatePresentation.shouldBlockRoot(isRootMini = false, isForce = true))
    }

    @Test
    fun silentUpdatesNeverReloadEitherTheCurrentOrAnotherRoot() {
        assertEquals(
            MiniRootUpdatePresentation.ApplyTarget.none,
            MiniRootUpdatePresentation.applyTarget(
                isForce = false,
                hasActiveRoot = true,
                activeRootIsCaller = true
            )
        )
        assertEquals(
            MiniRootUpdatePresentation.ApplyTarget.none,
            MiniRootUpdatePresentation.applyTarget(
                isForce = false,
                hasActiveRoot = true,
                activeRootIsCaller = false
            )
        )
    }

    @Test
    fun forcedUpdatesApplyAtTheCurrentRootOrTheKnownOtherRoot() {
        assertEquals(
            MiniRootUpdatePresentation.ApplyTarget.caller,
            MiniRootUpdatePresentation.applyTarget(
                isForce = true,
                hasActiveRoot = true,
                activeRootIsCaller = true
            )
        )
        assertEquals(
            MiniRootUpdatePresentation.ApplyTarget.otherRoot,
            MiniRootUpdatePresentation.applyTarget(
                isForce = true,
                hasActiveRoot = true,
                activeRootIsCaller = false
            )
        )
        assertEquals(
            MiniRootUpdatePresentation.ApplyTarget.caller,
            MiniRootUpdatePresentation.applyTarget(
                isForce = true,
                hasActiveRoot = false,
                activeRootIsCaller = false
            )
        )
    }

    @Test
    fun englishUsesVerifiedManifestEnglishBeforeAChineseOnlyLinkLabel() {
        assertEquals(
            "Signal Mini",
            MiniLaunchIdentity.displayName(
                wantsEnglish = true,
                linkName = "信号小程序",
                linkEnglishName = null,
                installedName = "信号小程序",
                installedEnglishName = "Signal Mini"
            )
        )
    }

    @Test
    fun chineseUsesTheLinkChineseLabelBeforeInstalledPresentation() {
        assertEquals(
            "信号小程序",
            MiniLaunchIdentity.displayName(
                wantsEnglish = false,
                linkName = "信号小程序",
                linkEnglishName = "Signal Mini",
                installedName = "旧名称",
                installedEnglishName = "Old Mini"
            )
        )
    }
}
