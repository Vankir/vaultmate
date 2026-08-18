package com.scanworks.obsi

import java.time.DayOfWeek
import java.time.LocalDate

/**
 * Kotlin port of [RecurrentTask.calculateNextOccurrence] (lib/src/core/tasks/reccurent_task.dart)
 * so the home-screen widget can compute the next occurrence of a recurring task without
 * round-tripping through the Dart isolate. Keep in sync with the Dart implementation.
 */
object RecurrenceCalculator {
    private val weekdayNames = mapOf(
        "monday" to DayOfWeek.MONDAY,
        "tuesday" to DayOfWeek.TUESDAY,
        "wednesday" to DayOfWeek.WEDNESDAY,
        "thursday" to DayOfWeek.THURSDAY,
        "friday" to DayOfWeek.FRIDAY,
        "saturday" to DayOfWeek.SATURDAY,
        "sunday" to DayOfWeek.SUNDAY
    )

    fun calculateNextOccurrence(lastDate: LocalDate, recurrenceRule: String): LocalDate {
        val ruleParts = recurrenceRule.trim().split(Regex("\\s+"))
        if (ruleParts.size < 2 || ruleParts[0].lowercase() != "every") {
            throw IllegalArgumentException("Invalid recurrence rule format.")
        }

        val frequency = ruleParts[1].lowercase()
        val interval = if (ruleParts.size == 3) ruleParts[2].toIntOrNull() ?: 1 else 1

        return when (frequency) {
            "day", "days" -> lastDate.plusDays(interval.toLong())
            "week", "weeks" -> lastDate.plusWeeks(interval.toLong())
            "month", "months" -> lastDate.plusMonths(interval.toLong())
            "year", "years" -> lastDate.plusYears(interval.toLong())
            "weekday", "weekdays" -> {
                var nextDate = lastDate
                repeat(interval) {
                    nextDate = nextDate.plusDays(1)
                    while (nextDate.dayOfWeek == DayOfWeek.SATURDAY ||
                        nextDate.dayOfWeek == DayOfWeek.SUNDAY
                    ) {
                        nextDate = nextDate.plusDays(1)
                    }
                }
                nextDate
            }
            else -> {
                val weekday = weekdayNames[frequency]
                    ?: throw IllegalArgumentException("Unsupported recurrence frequency.")
                var nextDate = lastDate.plusDays(1)
                while (nextDate.dayOfWeek != weekday) {
                    nextDate = nextDate.plusDays(1)
                }
                nextDate
            }
        }
    }
}
