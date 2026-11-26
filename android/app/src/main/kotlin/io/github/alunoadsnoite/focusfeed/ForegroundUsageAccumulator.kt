package io.github.alunoadsnoite.focusfeed

/**
 * Classifies foreground intervals using monotonic time.
 *
 * Call [sample] from the foreground-monitoring service. Each interval is
 * attributed to the package observed by the previous sample, never to both
 * the previous and current package. Screen-off, locked, unknown and self-app
 * intervals are ignored. Long polling gaps are discarded rather than guessed.
 */
internal class ForegroundUsageAccumulator(
    private val maxAccountableGapMs: Long = 2_000L,
) {
    init {
        require(maxAccountableGapMs > 0)
    }

    data class Delta(
        val productiveSeconds: Long = 0,
        val distractingSeconds: Long = 0,
    )

    private var lastElapsedMs: Long? = null
    private var lastKind: Kind? = null
    private var productiveRemainderMs = 0L
    private var distractingRemainderMs = 0L

    private enum class Kind { PRODUCTIVE, DISTRACTING }

    /**
     * Returns whole seconds completed since the previous sample.
     *
     * The current screen state gates the preceding interval as well. This is
     * intentionally conservative around screen-off/lock transitions so a
     * delayed poll cannot accidentally grant time while the device is locked.
     */
    fun sample(
        packageName: String?,
        elapsedRealtimeMs: Long,
        screenInteractive: Boolean,
        unlocked: Boolean,
        ownPackage: String,
        productiveApps: Set<String>,
        distractingApps: Set<String>,
    ): Delta {
        require(elapsedRealtimeMs >= 0)
        require(ownPackage.isNotBlank())

        var productiveSeconds = 0L
        var distractingSeconds = 0L
        val previous = lastElapsedMs
        val currentKind = classify(
            packageName,
            screenInteractive && unlocked,
            ownPackage,
            productiveApps,
            distractingApps,
        )

        if (previous != null) {
            val interval = elapsedRealtimeMs - previous
            if (interval < 0) {
                resetRemainders()
            } else if (
                interval in 1..maxAccountableGapMs &&
                screenInteractive &&
                unlocked
            ) {
                when (lastKind) {
                    Kind.PRODUCTIVE -> {
                        val total = productiveRemainderMs + interval
                        productiveSeconds = total / 1_000L
                        productiveRemainderMs = total % 1_000L
                    }
                    Kind.DISTRACTING -> {
                        val total = distractingRemainderMs + interval
                        distractingSeconds = total / 1_000L
                        distractingRemainderMs = total % 1_000L
                    }
                    null -> Unit
                }
            } else if (interval > maxAccountableGapMs) {
                // A stalled process must not retroactively mint or spend time.
                resetRemainders()
            }
        }

        lastElapsedMs = elapsedRealtimeMs
        lastKind = currentKind
        return Delta(productiveSeconds, distractingSeconds)
    }

    fun reset() {
        lastElapsedMs = null
        lastKind = null
        resetRemainders()
    }

    private fun classify(
        packageName: String?,
        eligible: Boolean,
        ownPackage: String,
        productiveApps: Set<String>,
        distractingApps: Set<String>,
    ): Kind? {
        if (!eligible || packageName.isNullOrBlank() || packageName == ownPackage) {
            return null
        }
        val productive = packageName in productiveApps
        val distracting = packageName in distractingApps
        return when {
            productive && !distracting -> Kind.PRODUCTIVE
            distracting && !productive -> Kind.DISTRACTING
            else -> null
        }
    }

    private fun resetRemainders() {
        productiveRemainderMs = 0
        distractingRemainderMs = 0
    }
}
