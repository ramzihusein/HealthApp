import Foundation
import SwiftData
import SwiftUI

/// Color tier for calendar cells: share of daily goals met (calories + lifting when scheduled).
enum GoalDayTier: Equatable {
    case future
    case noData
    case red
    case yellow
    case green

    var cellColor: Color {
        switch self {
        case .future: return FocusPalette.surface
        case .noData: return FocusPalette.surfaceElevated.opacity(0.85)
        case .red: return Color(red: 0.55, green: 0.18, blue: 0.2)
        case .yellow: return Color(red: 0.65, green: 0.5, blue: 0.12)
        case .green: return Color(red: 0.12, green: 0.45, blue: 0.28)
        }
    }
}

enum GoalDayScore {
    /// Fraction in 0...1 of applicable goals met; `nil` if the day is in the future.
    static func fractionMet(
        date: Date,
        goalCalories: Int,
        nutrition: DailyNutritionLog?,
        planDay: WorkoutDayDTO?,
        sessionsOnDay: [WorkoutSessionLog],
        cardioLogsOnDay: [CardioSessionLog],
        relativeToToday: Date = .now
    ) -> Double? {
        let day = CalendarDay.startOfDay(date)
        let today = CalendarDay.startOfDay(relativeToToday)
        if day > today { return nil }

        let calorieOK = calorieGoalMet(log: nutrition, goal: goalCalories)
        guard let planDay else {
            return calorieOK ? 1 : 0
        }

        let lifts = planDay.liftingExercisesResolved()
        let cardioBlocks = planDay.cardioBlocksResolved()
        let workoutScheduled = !lifts.isEmpty || !cardioBlocks.isEmpty

        if !workoutScheduled {
            return calorieOK ? 1 : 0
        }

        let liftOK = lifts.isEmpty ? true : liftingAllSetsLogged(planDay: planDay, sessions: sessionsOnDay)
        let cardioOK = cardioBlocks.isEmpty ? true : cardioGoalMet(blocks: cardioBlocks, logs: cardioLogsOnDay)
        let workoutOK = liftOK && cardioOK

        return ((calorieOK ? 1.0 : 0.0) + (workoutOK ? 1.0 : 0.0)) / 2.0
    }

    static func tier(
        date: Date,
        goalCalories: Int,
        nutrition: DailyNutritionLog?,
        planDay: WorkoutDayDTO?,
        sessionsOnDay: [WorkoutSessionLog],
        cardioLogsOnDay: [CardioSessionLog],
        relativeToToday: Date = .now
    ) -> GoalDayTier {
        let day = CalendarDay.startOfDay(date)
        let today = CalendarDay.startOfDay(relativeToToday)
        if day > today { return .future }

        guard let frac = fractionMet(
            date: date,
            goalCalories: goalCalories,
            nutrition: nutrition,
            planDay: planDay,
            sessionsOnDay: sessionsOnDay,
            cardioLogsOnDay: cardioLogsOnDay,
            relativeToToday: relativeToToday
        ) else { return .future }

        let lifts = planDay?.liftingExercisesResolved() ?? []
        let cardioBlocks = planDay?.cardioBlocksResolved() ?? []
        let hasAnySignal = (nutrition?.caloriesIn ?? 0) > 0
            || !sessionsOnDay.isEmpty
            || !lifts.isEmpty
            || cardioLogsOnDay.contains { $0.completedMinutes > 0 || !$0.notes.isEmpty }
        if !hasAnySignal && frac == 0 { return .noData }

        if frac < 0.5 { return .red }
        if frac < 0.8 { return .yellow }
        return .green
    }

    private static func calorieGoalMet(log: DailyNutritionLog?, goal: Int) -> Bool {
        guard let log, log.caloriesIn > 0, goal > 0 else { return false }
        let r = Double(log.caloriesIn) / Double(goal)
        return r >= 0.85 && r <= 1.15
    }

    private static func liftingAllSetsLogged(planDay: WorkoutDayDTO, sessions: [WorkoutSessionLog]) -> Bool {
        let lifts = planDay.liftingExercisesResolved()
        for ex in lifts {
            guard let s = sessions.first(where: { $0.exerciseId == ex.id }) else { return false }
            let sorted = s.sets.sorted { $0.setIndex < $1.setIndex }
            guard !sorted.isEmpty else { return false }
            if sorted.contains(where: { $0.reps <= 0 }) { return false }
        }
        return true
    }

    /// Met when each planned block has a log at ≥80% of prescribed minutes (or any minutes if plan says 0).
    static func cardioGoalMet(blocks: [CardioBlockDTO], logs: [CardioSessionLog]) -> Bool {
        for b in blocks {
            guard let log = logs.first(where: { $0.cardioBlockId == b.id }) else { return false }
            let target = max(1, b.durationMinutes)
            let threshold = max(1, Int((Double(target) * 0.8).rounded(.down)))
            if log.completedMinutes < threshold { return false }
        }
        return true
    }
}
