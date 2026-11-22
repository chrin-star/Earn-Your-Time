package io.github.alunoadsnoite.focusfeed

import org.junit.Assert.assertEquals
import org.junit.Test

class ForegroundUsageAccumulatorTest {
    private val productive = setOf("com.example.editor")
    private val distracting = setOf("com.example.video")

    private fun sample(
        tracker: ForegroundUsageAccumulator,
        pkg: String?,
        time: Long,
        screen: Boolean = true,
        unlocked: Boolean = true,
        productiveApps: Set<String> = productive,
        distractingApps: Set<String> = distracting,
    ) = tracker.sample(
        packageName = pkg,
        elapsedRealtimeMs = time,
        screenInteractive = screen,
        unlocked = unlocked,
        ownPackage = "io.github.alunoadsnoite.focusfeed",
        productiveApps = productiveApps,
        distractingApps = distractingApps,
    )

    @Test fun firstSampleOnlyEstablishesTheForegroundAnchor() {
        val tracker = ForegroundUsageAccumulator()
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(tracker, "com.example.editor", 10_000),
        )
    }

    @Test fun appSwitchCreditsThePreviousPackageExactlyOnce() {
        val tracker = ForegroundUsageAccumulator()
        sample(tracker, "com.example.editor", 0)
        val first = sample(tracker, "com.example.editor", 1_000)
        val switched = sample(tracker, "com.example.video", 2_000)
        val next = sample(tracker, "com.example.video", 3_000)

        assertEquals(1L, first.productiveSeconds)
        assertEquals(1L, switched.productiveSeconds)
        assertEquals(0L, switched.distractingSeconds)
        assertEquals(1L, next.distractingSeconds)
    }

    @Test fun subsecondIntervalsAccumulateWithoutLosingFractions() {
        val tracker = ForegroundUsageAccumulator()
        sample(tracker, "com.example.editor", 0)
        assertEquals(0L, sample(tracker, "com.example.editor", 400).productiveSeconds)
        assertEquals(0L, sample(tracker, "com.example.editor", 800).productiveSeconds)
        assertEquals(1L, sample(tracker, "com.example.editor", 1_200).productiveSeconds)
    }

    @Test fun screenOffAndLockedIntervalsAreNotCreditedOrSpent() {
        val tracker = ForegroundUsageAccumulator()
        sample(tracker, "com.example.editor", 0)
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(tracker, "com.example.editor", 1_000, screen = false),
        )
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(tracker, "com.example.video", 2_000, unlocked = false),
        )
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(tracker, "com.example.video", 3_000),
        )
        assertEquals(
            1L,
            sample(tracker, "com.example.video", 4_000).distractingSeconds,
        )
    }

    @Test fun ownUnknownAndAmbiguouslySelectedAppsAreIgnored() {
        val tracker = ForegroundUsageAccumulator()
        sample(tracker, "io.github.alunoadsnoite.focusfeed", 0)
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(tracker, "io.github.alunoadsnoite.focusfeed", 1_000),
        )
        sample(tracker, "com.example.unknown", 2_000)
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(tracker, "com.example.unknown", 3_000),
        )
        sample(
            tracker,
            "com.example.editor",
            4_000,
            productiveApps = setOf("com.example.editor"),
            distractingApps = setOf("com.example.editor"),
        )
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(
                tracker,
                "com.example.editor",
                5_000,
                productiveApps = setOf("com.example.editor"),
                distractingApps = setOf("com.example.editor"),
            ),
        )
    }

    @Test fun longPollingGapIsDiscardedAndStartsANewAnchor() {
        val tracker = ForegroundUsageAccumulator()
        sample(tracker, "com.example.editor", 0)
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(tracker, "com.example.editor", 10_000),
        )
        assertEquals(
            1L,
            sample(tracker, "com.example.editor", 11_000).productiveSeconds,
        )
    }

    @Test fun resetDiscardsPreviousForegroundStateAndFractions() {
        val tracker = ForegroundUsageAccumulator()
        sample(tracker, "com.example.editor", 0)
        sample(tracker, "com.example.editor", 500)
        tracker.reset()
        assertEquals(
            ForegroundUsageAccumulator.Delta(),
            sample(tracker, "com.example.editor", 1_000),
        )
        assertEquals(
            1L,
            sample(tracker, "com.example.editor", 2_000).productiveSeconds,
        )
    }
}
