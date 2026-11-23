package io.github.alunoadsnoite.focusfeed

import org.junit.Assert.assertEquals
import org.junit.Test

class EarnTimeUsageEventProcessorTest {
    private fun event(
        type: EarnTimeUsageEventProcessor.EventType,
        pkg: String,
        time: Long,
        activity: String = "Main",
    ) = EarnTimeUsageEventProcessor.ForegroundEvent(type, pkg, activity, time)

    @Test fun translatesWallClockEventsAndCountsForegroundTime() {
        val p = EarnTimeUsageEventProcessor(setOf("canva"), setOf("youtube"))
        // The batch is observed 10 seconds after its first event.
        val delta = p.process(
            listOf(event(EarnTimeUsageEventProcessor.EventType.RESUMED, "canva", 90_000)),
            nowWallTimeMillis = 100_000,
            nowElapsedRealtimeMillis = 50_000,
            deviceUsable = true,
        )
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 10), delta)
        assertEquals("canva", p.foregroundPackage())
    }

    @Test fun sortsEventsAndAccruesOnlyTheCorrectForegroundIntervals() {
        val p = EarnTimeUsageEventProcessor(setOf("canva"), setOf("youtube"))
        val delta = p.process(
            listOf(
                event(EarnTimeUsageEventProcessor.EventType.RESUMED, "youtube", 8_000),
                event(EarnTimeUsageEventProcessor.EventType.RESUMED, "canva", 3_000),
            ),
            nowWallTimeMillis = 10_000,
            nowElapsedRealtimeMillis = 20_000,
            deviceUsable = true,
        )
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 5, distractingSeconds = 2), delta)
        assertEquals("youtube", p.foregroundPackage())
    }

    @Test fun overlappingQueriesDoNotCountTheSameEventsTwice() {
        val p = EarnTimeUsageEventProcessor(setOf("canva"), emptySet())
        val resume = event(EarnTimeUsageEventProcessor.EventType.RESUMED, "canva", 1_000)
        p.process(listOf(resume), 2_000, 10_000, true)
        val second = p.process(listOf(resume), 4_000, 12_000, true)
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 2), second)
    }

    @Test fun pauseStopsCountingAndScreenOffPausesTheDevice() {
        val p = EarnTimeUsageEventProcessor(setOf("canva"), emptySet())
        p.process(
            listOf(event(EarnTimeUsageEventProcessor.EventType.RESUMED, "canva", 1_000)),
            1_000, 10_000, true,
        )
        val stopped = p.process(
            listOf(event(EarnTimeUsageEventProcessor.EventType.PAUSED, "canva", 4_000)),
            5_000, 14_000, true,
        )
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 3), stopped)
        val idle = p.process(emptyList(), 20_000, 29_000, false)
        assertEquals(EarnTimeUsageDelta(), idle)
        assertEquals(null, p.foregroundPackage())
    }

    @Test fun rejectsMonotonicClockMovingBackwardsBetweenBatches() {
        val p = EarnTimeUsageEventProcessor(emptySet(), emptySet())
        p.process(emptyList(), 10_000, 20_000, true)
        try {
            p.process(emptyList(), 11_000, 19_999, true)
            throw AssertionError("Expected backwards monotonic clock to be rejected")
        } catch (_: IllegalArgumentException) {
            // Expected.
        }
    }
}
