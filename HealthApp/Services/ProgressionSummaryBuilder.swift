import Foundation
import SwiftData

/// Builds text and maps for the next month’s LLM / mock plan from prior logs.
enum ProgressionSummaryBuilder {
    static func filterSessions(_ sessions: [WorkoutSessionLog], from start: Date, through end: Date) -> [WorkoutSessionLog] {
        let s = CalendarDay.startOfDay(start)
        let e = CalendarDay.startOfDay(end)
        return sessions.filter {
            let d = CalendarDay.startOfDay($0.dayDate)
            return d >= s && d <= e
        }
    }

    static func filterCardioLogs(_ logs: [CardioSessionLog], from start: Date, through end: Date) -> [CardioSessionLog] {
        let s = CalendarDay.startOfDay(start)
        let e = CalendarDay.startOfDay(end)
        return logs.filter {
            let d = CalendarDay.startOfDay($0.dayDate)
            return d >= s && d <= e
        }
    }

    /// Best logged load (kg) per exercise name among sets with reps > 0.
    static func maxLiftKgByExerciseName(sessions: [WorkoutSessionLog]) -> [String: Double] {
        var maxByName: [String: Double] = [:]
        for sess in sessions {
            let peak = sess.sets.filter { $0.reps > 0 }.map(\.weightKg).max() ?? 0
            guard peak > 0 else { continue }
            let name = sess.exerciseName
            maxByName[name] = max(maxByName[name] ?? 0, peak)
        }
        return maxByName
    }

    static func narrativeForLLM(
        sessions: [WorkoutSessionLog],
        priorWorkoutPlanJSON: String?,
        intervalStart: Date,
        intervalEnd: Date,
        cardioSessionsInInterval: [CardioSessionLog] = []
    ) -> String {
        var lines: [String] = []
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        lines.append("Prior training window: \(f.string(from: intervalStart)) – \(f.string(from: intervalEnd)).")
        let byName = maxLiftKgByExerciseName(sessions: sessions)
        if byName.isEmpty {
            lines.append("No barbell/dumbbell loads logged in this window (reps may be missing or weights zero).")
        } else {
            lines.append("Logged best working weight (kg) per exercise name (from sets with reps > 0):")
            for name in byName.keys.sorted() {
                guard let kg = byName[name] else { continue }
                lines.append("  - \(name): \(String(format: "%.1f", kg)) kg")
            }
        }
        if let json = priorWorkoutPlanJSON,
           let plan = try? PlanCodec.decodeWorkout(from: json),
           let week = plan.weeks.first {
            var cardioLines: [String] = []
            for d in week.days {
                for b in d.cardioBlocksResolved() {
                    cardioLines.append("  - \(d.name): \(b.title) \(b.durationMinutes) min, pace: \(b.targetPace ?? "n/a")")
                }
            }
            if !cardioLines.isEmpty {
                lines.append("Prior month prescribed cardio (progress from these targets if adherence was good):")
                lines.append(contentsOf: cardioLines)
            }
        }

        let cardioDone = cardioSessionsInInterval
            .filter { $0.completedMinutes > 0 }
            .sorted { $0.dayDate < $1.dayDate }
        if !cardioDone.isEmpty {
            lines.append("Logged cardio (what the user actually completed):")
            for c in cardioDone {
                let note = c.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " — \(c.notes)"
                lines.append("  - \(f.string(from: c.dayDate)) · \(c.blockTitle): \(c.completedMinutes) min done (plan \(c.targetDurationMinutes) min)\(note)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
