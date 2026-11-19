package com.fsst.stmini_flutter.ui

/** Presentation-only localization order shared by the Android launch screen. */
internal object MiniLaunchIdentity {
    fun displayName(
        wantsEnglish: Boolean,
        linkName: String?,
        linkEnglishName: String?,
        installedName: String?,
        installedEnglishName: String?
    ): String? = if (wantsEnglish) {
        linkEnglishName.nonBlank()
            ?: installedEnglishName.nonBlank()
            ?: linkName.nonBlank()
            ?: installedName.nonBlank()
    } else {
        linkName.nonBlank()
            ?: installedName.nonBlank()
            ?: linkEnglishName.nonBlank()
            ?: installedEnglishName.nonBlank()
    }

    private fun String?.nonBlank(): String? = takeIf { !it.isNullOrBlank() }
}

/** A background update must never block an already usable root Mini. */
internal object MiniRootUpdatePresentation {
    fun shouldBlockRoot(isRootMini: Boolean, isForce: Boolean): Boolean = isRootMini && isForce

    /**
     * Package installation and visible navigation deliberately have different
     * lifecycles. A silent update is persisted for a later cold launch; it
     * must not restart a Mini the user is already using. Forced updates keep
     * the existing blocking behaviour and apply at the active root when one
     * exists.
     */
    fun applyTarget(
        isForce: Boolean,
        hasActiveRoot: Boolean,
        activeRootIsCaller: Boolean
    ): ApplyTarget = when {
        !isForce -> ApplyTarget.none
        hasActiveRoot && !activeRootIsCaller -> ApplyTarget.otherRoot
        else -> ApplyTarget.caller
    }

    enum class ApplyTarget { none, caller, otherRoot }
}
