import Foundation
import SwiftData

/// Inserts removable dummy strength + cardio logs in the **calendar month before** `relativeTo`,
/// matching the window used when regenerating plans (`Settings` / onboarding).
enum DebugProgressionSampleSeed {
    static let idPrefix = "__debug_seed__"

    /// Human-readable range for UI copy.
    static func priorMonthLabel(relativeTo date: Date = .now) -> String {
        let (start, _) = priorCalendarMonthBounds(relativeTo: date)
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: start)
    }

    /// Removes rows created by this seeder, then inserts fresh sample logs in the prior calendar month.
    static func replaceSampleLogsInPriorMonth(modelContext: ModelContext, relativeTo date: Date = .now) throws {
        #if DEBUG
        let (priorStart, _) = priorCalendarMonthBounds(relativeTo: date)
        try removeSeededLogs(modelContext: modelContext)

        let cal = CalendarDay.calendar
        func day(_ offset: Int) -> Date {
            let raw = cal.date(byAdding: .day, value: offset, to: priorStart) ?? priorStart
            return CalendarDay.startOfDay(raw)
        }

        // Spread across the prior month so the narrative shows multiple dates.
        let samples: [(offset: Int, name: String, idSuffix: String, sets: [(reps: Int, kg: Double)])] = [
            (9, "Barbell bench press", "bench", [(8, 62.5), (8, 60), (7, 60)]),
            (9, "Barbell back squat", "squat", [(5, 102.5), (5, 100), (5, 100)]),
            (14, "Conventional deadlift", "deadlift", [(5, 125), (5, 120), (4, 120)]),
            (19, "Overhead press", "ohp", [(8, 42.5), (8, 40), (6, 40)])
        ]

        for (i, spec) in samples.enumerated() {
            let d = day(spec.offset)
            let dk = DayKey.string(for: d)
            let exId = "\(idPrefix)\(spec.idSuffix)"
            let session = WorkoutSessionLog(
                dayKey: dk,
                dayDate: d,
                exerciseId: exId,
                exerciseName: spec.name,
                sortOrder: i,
                targetSets: spec.sets.count,
                targetRepsHint: "8–10"
            )
            for (si, st) in spec.sets.enumerated() {
                let row = LoggedSetEntry(setIndex: si, reps: st.reps, weightKg: st.kg, session: session)
                session.sets.append(row)
            }
            modelContext.insert(session)
        }

        let cardioDay = day(12)
        let cardioDK = DayKey.string(for: cardioDay)
        let cardio = CardioSessionLog(
            dayKey: cardioDK,
            dayDate: cardioDay,
            cardioBlockId: "\(idPrefix)cardio",
            blockTitle: "Easy conditioning",
            targetDurationMinutes: 30,
            completedMinutes: 28,
            notes: "Debug sample",
            sortOrder: 0
        )
        modelContext.insert(cardio)

        try modelContext.save()
        #else
        _ = modelContext
        _ = date
        #endif
    }

    private static func priorCalendarMonthBounds(relativeTo date: Date) -> (start: Date, end: Date) {
        let periodStart = CalendarDay.startOfMonth(containing: date)
        let priorAnchor = CalendarDay.calendar.date(byAdding: .month, value: -1, to: periodStart) ?? periodStart
        let priorStart = CalendarDay.startOfMonth(containing: priorAnchor)
        let priorEnd = CalendarDay.endOfMonth(containing: priorAnchor)
        return (priorStart, priorEnd)
    }

    #if DEBUG
    private static func removeSeededLogs(modelContext: ModelContext) throws {
        let sessions = try modelContext.fetch(FetchDescriptor<WorkoutSessionLog>())
        for s in sessions where s.exerciseId.hasPrefix(idPrefix) {
            modelContext.delete(s)
        }
        let cardio = try modelContext.fetch(FetchDescriptor<CardioSessionLog>())
        for c in cardio where c.cardioBlockId.hasPrefix(idPrefix) {
            modelContext.delete(c)
        }
    }
    #endif
}
