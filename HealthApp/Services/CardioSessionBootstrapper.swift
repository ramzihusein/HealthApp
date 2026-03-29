import Foundation
import SwiftData

enum CardioSessionBootstrapper {
    static func ensureForDay(date: Date, plan: WorkoutPlanDTO?, context: ModelContext) throws {
        guard let plan, let week = plan.weeks.first else { return }
        let dayStart = CalendarDay.startOfDay(date)
        let dk = DayKey.string(for: dayStart)
        let idx = CalendarDay.planDayIndex(for: dayStart)
        guard let day = week.days.first(where: { $0.dayIndex == idx }) else { return }

        let blocks = day.cardioBlocksResolved()
        let validIds = Set(blocks.map(\.id))

        let dayLogs = try context.fetch(
            FetchDescriptor<CardioSessionLog>(predicate: #Predicate { $0.dayKey == dk })
        )
        for row in dayLogs where !validIds.contains(row.cardioBlockId) {
            context.delete(row)
        }

        for (i, b) in blocks.enumerated() {
            let key = "\(dk)|\(b.id)"
            let fd = FetchDescriptor<CardioSessionLog>(predicate: #Predicate { $0.logKey == key })
            if let existing = try context.fetch(fd).first {
                if existing.targetDurationMinutes != b.durationMinutes {
                    existing.targetDurationMinutes = b.durationMinutes
                }
                if existing.blockTitle != b.title {
                    existing.blockTitle = b.title
                }
                existing.sortOrder = i
                continue
            }
            let row = CardioSessionLog(
                dayKey: dk,
                dayDate: dayStart,
                cardioBlockId: b.id,
                blockTitle: b.title,
                targetDurationMinutes: b.durationMinutes,
                completedMinutes: 0,
                notes: "",
                sortOrder: i
            )
            context.insert(row)
        }
    }
}
