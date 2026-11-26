package io.github.alunoadsnoite.focusfeed

/** Pure decision rule for the Earn Your Time zero-balance soft blocker. */
internal object EarnTimeBlockPolicy {
    fun shouldBlock(
        foregroundPackage: String?,
        ownPackage: String,
        distractingPackages: Set<String>,
        remainingSeconds: Long,
        deviceUsable: Boolean,
    ): Boolean {
        if (!deviceUsable || remainingSeconds > 0) return false
        if (foregroundPackage.isNullOrBlank() || foregroundPackage == ownPackage) return false
        return foregroundPackage in distractingPackages
    }
}
