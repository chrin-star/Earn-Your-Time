package io.github.alunoadsnoite.focusfeed

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Separate local storage for Earn Your Time; never touches legacy Pomodoro data. */
internal object EarnTimeStore {
    private const val PREFS = "earn_time_data"
    private const val KEY_DAY = "day"
    private const val KEY_PRODUCTIVE = "productive_packages"
    private const val KEY_DISTRACTING = "distracting_packages"
    private const val KEY_ALLOWANCE = "daily_allowance_seconds"
    private const val KEY_NUMERATOR = "reward_numerator"
    private const val KEY_DENOMINATOR = "reward_denominator"
    @Volatile private var cachedDay: EarnTimeDay? = null

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun configure(context: Context, productive: Set<String>, distracting: Set<String>) {
        require(productive.none { it.isBlank() } && distracting.none { it.isBlank() })
        require(productive.intersect(distracting).isEmpty()) {
            "Una aplicación no puede estar en ambas categorías."
        }
        require((productive + distracting).none { it == context.packageName }) {
            "Earn Your Time no puede seleccionarse a sí misma."
        }
        prefs(context).edit()
            .putStringSet(KEY_PRODUCTIVE, productive)
            .putStringSet(KEY_DISTRACTING, distracting)
            .apply()
    }

    fun categories(context: Context): Pair<Set<String>, Set<String>> {
        val p = prefs(context)
        return (p.getStringSet(KEY_PRODUCTIVE, emptySet()) ?: emptySet()).toSet() to
            (p.getStringSet(KEY_DISTRACTING, emptySet()) ?: emptySet()).toSet()
    }

    fun settings(context: Context) = EarnTimeSettings(
        prefs(context).getLong(KEY_ALLOWANCE, 30 * 60L),
        prefs(context).getLong(KEY_NUMERATOR, 1L),
        prefs(context).getLong(KEY_DENOMINATOR, 1L),
    )

    fun saveSettings(context: Context, settings: EarnTimeSettings) {
        prefs(context).edit()
            .putLong(KEY_ALLOWANCE, settings.dailyAllowanceSeconds)
            .putLong(KEY_NUMERATOR, settings.rewardNumerator)
            .putLong(KEY_DENOMINATOR, settings.rewardDenominator)
            .apply()
    }

    @Synchronized
    fun record(context: Context, delta: EarnTimeUsageDelta) {
        if (delta == EarnTimeUsageDelta()) return
        val p = prefs(context)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(Date())
        val day = cachedDay ?: p.getString(KEY_DAY, null)?.let(::decodeDay) ?: EarnTimeDay(today)
        val settings = settings(context)
        day.recordProductive(delta.productiveSeconds, today, settings)
        day.recordDistracting(delta.distractingSeconds, today, settings)
        cachedDay = day
    }

    @Synchronized
    fun flush(context: Context) {
        val day = cachedDay ?: return
        check(prefs(context).edit().putString(KEY_DAY, encodeDay(day)).commit()) {
            "No se pudo guardar el progreso de Earn Your Time."
        }
    }

    @Synchronized
    fun snapshot(context: Context): Map<String, Any> {
        val p = prefs(context)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(Date())
        val day = cachedDay ?: p.getString(KEY_DAY, null)?.let(::decodeDay) ?: EarnTimeDay(today)
        val settings = settings(context)
        day.rollTo(today)
        cachedDay = day
        return mapOf(
            "productiveSeconds" to day.productiveSeconds,
            "earnedSeconds" to day.earnedSeconds,
            "distractingSeconds" to day.spentSeconds,
            "remainingSeconds" to day.remaining(settings),
            "dailyAllowanceSeconds" to settings.dailyAllowanceSeconds,
            "rewardNumerator" to settings.rewardNumerator,
            "rewardDenominator" to settings.rewardDenominator,
            "productivePackages" to categories(context).first.toList(),
            "distractingPackages" to categories(context).second.toList(),
        )
    }

    private fun encodeDay(day: EarnTimeDay) = JSONObject()
        .put("dayKey", day.dayKey)
        .put("productiveSeconds", day.productiveSeconds)
        .put("earnedSeconds", day.earnedSeconds)
        .put("spentSeconds", day.spentSeconds)
        .put("fractionalNumerator", day.fractionalNumerator)
        .toString()

    private fun decodeDay(raw: String): EarnTimeDay {
        val j = JSONObject(raw)
        return EarnTimeDay(
            j.getString("dayKey"),
            j.getLong("productiveSeconds"),
            j.getLong("earnedSeconds"),
            j.getLong("spentSeconds"),
            j.getLong("fractionalNumerator"),
        )
    }
}
