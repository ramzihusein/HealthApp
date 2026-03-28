import Foundation
import SwiftData

enum WorkoutSessionBootstrapper {
    static func ensureSessionsForDay(
        date: Date,
        plan: WorkoutPlanDTO,
        context: ModelContext
    ) throws {
        let dayStart = CalendarDay.startOfDay(date)
        let dk = DayKey.string(for: dayStart)
        let idx = CalendarDay.planDayIndex(for: dayStart)
        guard let week = plan.weeks.first,
              let day = week.days.first(where: { $0.dayIndex == idx }),
              !day.exercises.isEmpty
        else { return }

        for (i, ex) in day.exercises.enumerated() {
            let exId = ex.id
            let fd = FetchDescriptor<WorkoutSessionLog>(
                predicate: #Predicate { $0.dayKey == dk && $0.exerciseId == exId }
            )
            if let existing = try context.fetch(fd).first {
                syncSetCount(session: existing, target: ex.sets, context: context)
                continue
            }
            let session = WorkoutSessionLog(
                dayKey: dk,
                dayDate: dayStart,
                exerciseId: exId,
                exerciseName: ex.name,
                sortOrder: i,
                targetSets: ex.sets,
                targetRepsHint: ex.reps
            )
            for s in 0..<ex.sets {
                let row = LoggedSetEntry(setIndex: s, reps: 0, weightKg: 0, session: session)
                session.sets.append(row)
            }
            context.insert(session)
        }
    }

    private static func syncSetCount(session: WorkoutSessionLog, target: Int, context: ModelContext) {
        let current = session.sets.sorted { $0.setIndex < $1.setIndex }
        if current.count == target { return }
        if current.count > target {
            let drop = Array(current.suffix(current.count - target))
            let ids = Set(drop.map(\.persistentModelID))
            session.sets.removeAll { ids.contains($0.persistentModelID) }
            drop.forEach { context.delete($0) }
            return
        }
        let start = current.count
        for s in start..<target {
            let row = LoggedSetEntry(setIndex: s, reps: 0, weightKg: 0, session: session)
            session.sets.append(row)
            context.insert(row)
        }
    }
}
