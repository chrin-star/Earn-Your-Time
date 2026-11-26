package io.github.alunoadsnoite.focusfeed

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EarnTimeBlockPolicyTest {
    private val distracting = setOf("com.example.video", "com.example.social")

    @Test fun blocksSelectedDistractingAppOnlyWhenBalanceIsEmpty() {
        assertTrue(EarnTimeBlockPolicy.shouldBlock(
            "com.example.video", "io.github.alunoadsnoite.focusfeed",
            distracting, 0L, true
        ))
    }

    @Test fun doesNotBlockWhileBalanceRemains() {
        assertFalse(EarnTimeBlockPolicy.shouldBlock(
            "com.example.video", "io.github.alunoadsnoite.focusfeed",
            distracting, 1L, true
        ))
    }

    @Test fun doesNotBlockProductiveOrIgnoredApps() {
        assertFalse(EarnTimeBlockPolicy.shouldBlock(
            "com.example.productive", "io.github.alunoadsnoite.focusfeed",
            distracting, 0L, true
        ))
    }

    @Test fun doesNotBlockWhenDeviceIsLockedOrOwnAppIsForeground() {
        assertFalse(EarnTimeBlockPolicy.shouldBlock(
            "com.example.video", "io.github.alunoadsnoite.focusfeed",
            distracting, 0L, false
        ))
        assertFalse(EarnTimeBlockPolicy.shouldBlock(
            "io.github.alunoadsnoite.focusfeed", "io.github.alunoadsnoite.focusfeed",
            distracting, 0L, true
        ))
    }
}
