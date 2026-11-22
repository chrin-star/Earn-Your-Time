package io.github.alunoadsnoite.focusfeed

import org.junit.Assert.*
import org.junit.Test

class EarnTimeDayTest {
    private val oneToOne = EarnTimeSettings(
        dailyAllowanceSeconds = 2 * 60 * 60,
        rewardNumerator = 1,
        rewardDenominator = 1,
    )

    @Test fun productiveTimeEarnsOneToOneAutomatically() {
        val day = EarnTimeDay("2026-11-22")
        day.recordProductive(3600, "2026-11-22", oneToOne)
        assertEquals(3600L, day.earnedSeconds)
        assertEquals(3 * 60 * 60L, day.remaining(oneToOne))
    }

    @Test fun customRatioCanDoubleReward() {
        val settings = oneToOne.copy(rewardNumerator = 2, rewardDenominator = 1)
        val day = EarnTimeDay("2026-11-22")
        day.recordProductive(1800, "2026-11-22", settings)
        assertEquals(3600L, day.earnedSeconds)
    }

    @Test fun fractionalRatioCarriesRemainderWithinTheSameDay() {
        val settings = oneToOne.copy(rewardNumerator = 1, rewardDenominator = 2)
        val day = EarnTimeDay("2026-11-22")
        day.recordProductive(1, "2026-11-22", settings)
        day.recordProductive(1, "2026-11-22", settings)
        assertEquals(1L, day.earnedSeconds)
        assertEquals(0L, day.fractionalNumerator)
    }

    @Test fun distractingTimeConsumesDailyAllowanceAndEarnedTime() {
        val day = EarnTimeDay("2026-11-22")
        day.recordProductive(1800, "2026-11-22", oneToOne)
        day.recordDistracting(5400, "2026-11-22", oneToOne)
        assertEquals(60 * 60L, day.remaining(oneToOne))
        day.recordDistracting(2 * 60 * 60L, "2026-11-22", oneToOne)
        assertEquals(0L, day.remaining(oneToOne))
        assertFalse(day.canUseDistractingApps(oneToOne))
    }

    @Test fun newLocalDayResetsAllowanceAccountingAndExpiresUnusedRewards() {
        val day = EarnTimeDay("2026-11-22")
        day.recordProductive(3600, "2026-11-22", oneToOne)
        day.recordDistracting(600, "2026-11-22", oneToOne)
        day.rollTo("2026-11-23")
        assertEquals(0L, day.productiveSeconds)
        assertEquals(0L, day.earnedSeconds)
        assertEquals(0L, day.spentSeconds)
        assertEquals(0L, day.fractionalNumerator)
        assertEquals(2 * 60 * 60L, day.remaining(oneToOne))
    }

    @Test fun usageRecordedAfterMidnightBelongsOnlyToNewDay() {
        val day = EarnTimeDay("2026-11-22")
        day.recordProductive(3599, "2026-11-22", oneToOne)
        day.recordProductive(1, "2026-11-23", oneToOne)
        assertEquals("2026-11-23", day.dayKey)
        assertEquals(1L, day.productiveSeconds)
        assertEquals(1L, day.earnedSeconds)
    }

    @Test fun zeroOrNegativeIntervalsAreRejected() {
        val day = EarnTimeDay("2026-11-22")
        try {
            day.recordProductive(-1, "2026-11-22", oneToOne)
            fail("Negative usage must be rejected")
        } catch (_: IllegalArgumentException) {
            // Expected.
        }
    }

    @Test fun invalidSettingsAreRejected() {
        try {
            EarnTimeSettings(0, 1, 1)
            fail("A zero daily allowance must be rejected")
        } catch (_: IllegalArgumentException) {
            // Expected.
        }
        try {
            EarnTimeSettings(60, 1, 0)
            fail("A zero denominator must be rejected")
        } catch (_: IllegalArgumentException) {
            // Expected.
        }
    }
}
