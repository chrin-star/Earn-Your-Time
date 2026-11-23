package io.github.alunoadsnoite.focusfeed

/**
 * Converts Android UsageEvents into monotonic foreground transitions.
 *
 * Android UsageEvents use wall-clock timestamps, while EarnTimeTracker must
 * receive elapsed-realtime timestamps. Each batch is therefore translated
 * relative to its wall-clock/elapsed-realtime observation pair. The caller
 * must query a bounded overlapping window and provide events in any order;
 * this processor sorts and de-duplicates them.
 *
 * Create a new instance after process/device restart. No Android service is
 * accessed here, which keeps the event logic deterministic and testable.
 */
internal class EarnTimeUsageEventProcessor(
    productivePackages: Set<String>,
    distractingPackages: Set<String>,
) {
    enum class EventType { RESUMED, PAUSED }

    data class ForegroundEvent(
        val type: EventType,
        val packageName: String,
        val activityName: String?,
        val wallTimeMillis: Long,
    )

    private val activity = ForegroundActivityTracker()
    private val accountant = EarnTimeTracker(productivePackages, distractingPackages)
    private var lastEventWallTime = Long.MIN_VALUE
    private var lastAppliedPackage: String? = null
    private var lastMonotonicTime = Long.MIN_VALUE

    /**
     * Process one UsageEvents batch.
     *
     * @param nowWallTimeMillis System.currentTimeMillis() at query time.
     * @param nowElapsedRealtimeMillis SystemClock.elapsedRealtime() at query time.
     * @param deviceUsable false while screen is off or keyguard is showing.
     */
    fun process(
        events: List<ForegroundEvent>,
        nowWallTimeMillis: Long,
        nowElapsedRealtimeMillis: Long,
        deviceUsable: Boolean,
    ): EarnTimeUsageDelta {
        require(nowWallTimeMillis >= 0L)
        require(nowElapsedRealtimeMillis >= 0L)
        require(lastMonotonicTime == Long.MIN_VALUE ||
            nowElapsedRealtimeMillis >= lastMonotonicTime) {
            "El reloj monotónico no puede retroceder."
        }

        var total = EarnTimeUsageDelta()
        val ordered = events.sortedBy { it.wallTimeMillis }
        for (event in ordered) {
            require(event.packageName.isNotBlank())
            if (event.wallTimeMillis <= lastEventWallTime) continue

            // Translate relative to this batch, not with a permanently stored
            // wall-clock offset, so ordinary manual/NTP clock corrections do
            // not directly become elapsed-time jumps.
            val age = (nowWallTimeMillis - event.wallTimeMillis).coerceAtLeast(0L)
            val eventElapsed = (nowElapsedRealtimeMillis - age).coerceAtLeast(0L)
            val safeElapsed = maxOf(eventElapsed, lastMonotonicTime.takeIf {
                it != Long.MIN_VALUE
            } ?: eventElapsed)

            when (event.type) {
                EventType.RESUMED -> activity.resume(
                    event.packageName, event.activityName, safeElapsed
                )
                EventType.PAUSED -> activity.pause(
                    event.packageName, event.activityName, safeElapsed
                )
            }

            val newPackage = activity.packageName
            if (newPackage != lastAppliedPackage) {
                total += accountant.onForegroundChanged(newPackage, safeElapsed)
                lastAppliedPackage = newPackage
            }
            lastEventWallTime = event.wallTimeMillis
            lastMonotonicTime = safeElapsed
        }

        val foreground = activity.packageName
        if (foreground != lastAppliedPackage) {
            total += accountant.onForegroundChanged(foreground, nowElapsedRealtimeMillis)
            lastAppliedPackage = foreground
        }
        total += accountant.setDeviceUsable(deviceUsable, nowElapsedRealtimeMillis)
        total += accountant.checkpoint(nowElapsedRealtimeMillis)
        lastMonotonicTime = nowElapsedRealtimeMillis
        return total
    }

    /** Current package after the latest processed event batch, if any. */
    fun foregroundPackage(): String? = activity.packageName
}
