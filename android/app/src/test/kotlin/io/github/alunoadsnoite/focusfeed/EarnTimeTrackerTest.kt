package io.github.alunoadsnoite.focusfeed

import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

class EarnTimeTrackerTest {
    private fun tracker() = EarnTimeTracker(
        productivePackages = setOf("com.canva"),
        distractingPackages = setOf("com.youtube"),
    )

    @Test fun countsOnlySelectedForegroundApps() {
        val t = tracker()
        assertEquals(EarnTimeUsageDelta(), t.onForegroundChanged("com.canva", 1_000))
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 12), t.onForegroundChanged("com.youtube", 13_500))
        assertEquals(EarnTimeUsageDelta(distractingSeconds = 8), t.onForegroundChanged("com.android.launcher", 21_500))
        assertEquals(EarnTimeUsageDelta(), t.checkpoint(40_000))
    }

    @Test fun switchesBetweenProductiveAppsWithoutDoubleCounting() {
        val t = EarnTimeTracker(setOf("canva", "editor"), setOf("youtube"))
        t.onForegroundChanged("canva", 0)
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 5), t.onForegroundChanged("editor", 5_000))
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 7), t.checkpoint(12_000))
    }

    @Test fun preservesFractionalSecondsAcrossCheckpoints() {
        val t = tracker()
        t.onForegroundChanged("com.canva", 0)
        assertEquals(EarnTimeUsageDelta(), t.checkpoint(600))
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 1), t.checkpoint(1_200))
        assertEquals(EarnTimeUsageDelta(), t.checkpoint(1_800))
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 1), t.checkpoint(2_400))
    }

    @Test fun screenOffAndLockedPeriodsAreNotCounted() {
        val t = tracker()
        t.onForegroundChanged("com.canva", 0)
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 4), t.setDeviceUsable(false, 4_000))
        assertEquals(EarnTimeUsageDelta(), t.checkpoint(60_000))
        assertEquals(EarnTimeUsageDelta(), t.setDeviceUsable(true, 60_000))
        assertEquals(EarnTimeUsageDelta(productiveSeconds = 3), t.checkpoint(63_000))
    }

    @Test fun unselectedAndSystemPackagesAreIgnored() {
        val t = tracker()
        t.onForegroundChanged("com.android.settings", 0)
        assertEquals(EarnTimeUsageDelta(), t.onForegroundChanged("io.github.alunoadsnoite.focusfeed", 20_000))
        assertEquals(EarnTimeUsageDelta(), t.onForegroundChanged(null, 40_000))
    }

    @Test fun rejectsPackageSelectedInBothCategories() {
        try {
            EarnTimeTracker(setOf("same"), setOf("same"))
            fail("Overlapping categories must be rejected")
        } catch (_: IllegalArgumentException) {
            // Expected.
        }
    }

    @Test fun rejectsMonotonicClockMovingBackwards() {
        val t = tracker()
        t.onForegroundChanged("com.canva", 10_000)
        try {
            t.checkpoint(9_999)
            fail("A backwards monotonic timestamp must be rejected")
        } catch (_: IllegalArgumentException) {
            // Expected.
        }
    }
}
