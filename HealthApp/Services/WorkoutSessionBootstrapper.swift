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
              let day = week.days.first(where: { $0.dayIndex == idx })
        else { return }

        let lifts = day.liftingExercisesResolved()
        guard !lifts.isEmpty else { return }

        for (i, ex) in lifts.enumerated() {
            let exId = ex.id
            let fd = FetchDescriptor<WorkoutSessionLog>(
                predicate: #Predicate { $0.dayKey == dk && $0.exerciseId == exId }
            )
            if let existing = try context.fetch(fd).first {
                syncSetCount(session: existing, target: ex.sets, template: ex, context: context)
                continue
            }
            let seed = seedWeightKg(for: ex)
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
                let row = LoggedSetEntry(setIndex: s, reps: 0, weightKg: seed, session: session)
                session.sets.append(row)
            }
            context.insert(session)
        }
    }

    private static func seedWeightKg(for ex: ExerciseTemplateDTO) -> Double {
        guard let s = ex.suggestedWeightKg, s > 0 else { return 0 }
        return s
    }

    private static func syncSetCount(session: WorkoutSessionLog, target: Int, template: ExerciseTemplateDTO, context: ModelContext) {
        let current = session.sets.sorted { $0.setIndex < $1.setIndex }
        if current.count == target { return }
        if current.count > target {
            let drop = Array(current.suffix(current.count - target))
            let ids = Set(drop.map(\.persistentModelID))
            session.sets.removeAll { ids.contains($0.persistentModelID) }
            drop.forEach { context.delete($0) }
            return
        }
        let seed = seedWeightKg(for: template)
        let start = current.count
        for s in start..<target {
            let row = LoggedSetEntry(setIndex: s, reps: 0, weightKg: seed, session: session)
            session.sets.append(row)
            context.insert(row)
        }
    }
}
