package io.github.alunoadsnoite.focusfeed

/**
 * Pure foreground-time accountant. It never reads Android services or the
 * clock itself: callers supply monotonic elapsed-realtime timestamps.
 *
 * Only explicitly selected packages accrue time. System UI, the launcher,
 * this app, lock screen, and every unselected app are ignored by omission.
 */
internal enum class EarnTimeCategory { PRODUCTIVE, DISTRACTING, IGNORED }

internal data class EarnTimeUsageDelta(
    val productiveSeconds: Long = 0,
    val distractingSeconds: Long = 0,
) {
    operator fun plus(other: EarnTimeUsageDelta) = EarnTimeUsageDelta(
        productiveSeconds = Math.addExact(productiveSeconds, other.productiveSeconds),
        distractingSeconds = Math.addExact(distractingSeconds, other.distractingSeconds),
    )
}

internal class EarnTimeTracker(
    productivePackages: Set<String>,
    distractingPackages: Set<String>,
) {
    private val productive = productivePackages.toSet()
    private val distracting = distractingPackages.toSet()

    init {
        require(productive.none { it.isBlank() } && distracting.none { it.isBlank() })
        require(productive.intersect(distracting).isEmpty()) {
            "Una aplicación no puede ser productiva y distractora al mismo tiempo."
        }
    }

    private var foregroundPackage: String? = null
    private var deviceUsable = true
    private var intervalStartMillis: Long? = null
    private var productiveRemainderMillis = 0L
    private var distractingRemainderMillis = 0L

    private fun category(): EarnTimeCategory = when (foregroundPackage) {
        in productive -> EarnTimeCategory.PRODUCTIVE
        in distracting -> EarnTimeCategory.DISTRACTING
        else -> EarnTimeCategory.IGNORED
    }

    private fun accrueUntil(timestampMillis: Long): EarnTimeUsageDelta {
        val start = intervalStartMillis ?: run {
            intervalStartMillis = timestampMillis
            return EarnTimeUsageDelta()
        }
        require(timestampMillis >= start) { "Los tiempos monotónicos no pueden retroceder." }
        val elapsed = timestampMillis - start
        intervalStartMillis = timestampMillis
        if (!deviceUsable || elapsed == 0L) return EarnTimeUsageDelta()

        return when (category()) {
            EarnTimeCategory.PRODUCTIVE -> {
                val total = Math.addExact(productiveRemainderMillis, elapsed)
                val seconds = total / 1000
                productiveRemainderMillis = total % 1000
                EarnTimeUsageDelta(productiveSeconds = seconds)
            }
            EarnTimeCategory.DISTRACTING -> {
                val total = Math.addExact(distractingRemainderMillis, elapsed)
                val seconds = total / 1000
                distractingRemainderMillis = total % 1000
                EarnTimeUsageDelta(distractingSeconds = seconds)
            }
            EarnTimeCategory.IGNORED -> EarnTimeUsageDelta()
        }
    }

    /** Apply an ACTIVITY_RESUMED/PAUSED-derived foreground package change. */
    fun onForegroundChanged(packageName: String?, timestampMillis: Long): EarnTimeUsageDelta {
        val delta = accrueUntil(timestampMillis)
        foregroundPackage = packageName
        intervalStartMillis = timestampMillis
        return delta
    }

    /** Pause accounting while the display is off or the device is locked. */
    fun setDeviceUsable(usable: Boolean, timestampMillis: Long): EarnTimeUsageDelta {
        val delta = accrueUntil(timestampMillis)
        deviceUsable = usable
        intervalStartMillis = timestampMillis
        return delta
    }

    /** Flush whole seconds accumulated since the previous event/checkpoint. */
    fun checkpoint(timestampMillis: Long): EarnTimeUsageDelta =
        accrueUntil(timestampMillis)
}
