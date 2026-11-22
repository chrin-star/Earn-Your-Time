package io.github.alunoadsnoite.focusfeed

/**
 * User-configurable daily exchange rules.
 *
 * rewardNumerator / rewardDenominator is the number of entertainment seconds
 * earned per productive second. Example: 1:1 = 1/1, 2:1 = 2/1, 1:2 = 1/2.
 */
data class EarnTimeSettings(
    val dailyAllowanceSeconds: Long,
    val rewardNumerator: Long,
    val rewardDenominator: Long,
) {
    init {
        require(dailyAllowanceSeconds in 60..86_400) {
            "El límite diario debe estar entre 1 minuto y 24 horas."
        }
        require(rewardNumerator in 1..100 && rewardDenominator in 1..100) {
            "La proporción de recompensa no es válida."
        }
    }
}

/**
 * Local-day accounting. The caller supplies the device's current local date
 * as yyyy-MM-dd whenever it records usage. A date change starts a fresh day:
 * the configured allowance returns and all unused rewards expire.
 */
data class EarnTimeDay(
    var dayKey: String,
    var productiveSeconds: Long = 0,
    var earnedSeconds: Long = 0,
    var spentSeconds: Long = 0,
    var fractionalNumerator: Long = 0,
) {
    init {
        require(dayKey.matches(Regex("\\d{4}-\\d{2}-\\d{2}")))
        validate()
    }

    val remainingSeconds: Long
        get() = (earnedSeconds + spentAllowanceSeconds - spentSeconds).coerceAtLeast(0)

    // Kept as a derived value so the allowance is always the current setting.
    private var spentAllowanceSeconds: Long = 0

    fun validate() {
        require(productiveSeconds >= 0 && earnedSeconds >= 0 && spentSeconds >= 0)
        require(fractionalNumerator >= 0)
    }

    fun rollTo(today: String) {
        require(today.matches(Regex("\\d{4}-\\d{2}-\\d{2}")))
        if (today != dayKey) {
            dayKey = today
            productiveSeconds = 0
            earnedSeconds = 0
            spentSeconds = 0
            fractionalNumerator = 0
        }
    }

    fun recordProductive(seconds: Long, today: String, settings: EarnTimeSettings) {
        require(seconds >= 0)
        rollTo(today)
        productiveSeconds = Math.addExact(productiveSeconds, seconds)
        val scaled = Math.addExact(
            Math.multiplyExact(seconds, settings.rewardNumerator),
            fractionalNumerator,
        )
        val newlyEarned = scaled / settings.rewardDenominator
        fractionalNumerator = scaled % settings.rewardDenominator
        earnedSeconds = Math.addExact(earnedSeconds, newlyEarned)
    }

    fun recordDistracting(seconds: Long, today: String, settings: EarnTimeSettings) {
        require(seconds >= 0)
        rollTo(today)
        spentSeconds = Math.addExact(spentSeconds, seconds)
    }

    fun remaining(settings: EarnTimeSettings): Long =
        (settings.dailyAllowanceSeconds + earnedSeconds - spentSeconds).coerceAtLeast(0)

    fun canUseDistractingApps(settings: EarnTimeSettings): Boolean =
        remaining(settings) > 0

    fun reset(today: String) {
        rollTo(today)
    }
}
