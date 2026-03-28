import SwiftUI
import SwiftData
import Charts

struct ProgressOverviewView: View {
    @Query(sort: \DailyWeightEntry.dayDate) private var weights: [DailyWeightEntry]
    @Query(sort: \DailyNutritionLog.dayDate) private var nutrition: [DailyNutritionLog]
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @Query private var sessions: [WorkoutSessionLog]

    private var goalCalories: Int {
        guard let p = plans.first, let m = try? PlanCodec.decodeMeal(from: p.mealJSON) else { return 2000 }
        return m.targetDailyCalories
    }

    private var workoutDaysThisWeekCount: Int {
        let days = CalendarDay.daysInWeek(containing: Date())
        let keys = Set(days.map { DayKey.string(for: $0) })
        return Set(sessions.filter { keys.contains($0.dayKey) }.map(\.dayKey)).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FocusCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This week")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("\(workoutDaysThisWeekCount) days with logged lifts")
                                .font(.subheadline)
                                .foregroundStyle(FocusPalette.textSecondary)
                            Text("Small, consistent sessions beat sporadic extremes.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary.opacity(0.9))
                        }
                    }

                    weightSparkCard
                    adherenceCard
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle("Overview")
        }
    }

    private var weightSparkCard: some View {
        let pts = weights.suffix(14).map { (d: $0.dayDate, w: $0.weightKg) }
        return FocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weight (14d)")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                if pts.count < 2 {
                    Text("Log weight in Fuel to chart progress.")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                } else {
                    Chart {
                        ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                            LineMark(
                                x: .value("Day", p.d, unit: .day),
                                y: .value("kg", p.w)
                            )
                            .foregroundStyle(FocusPalette.accent)
                        }
                    }
                    .frame(height: 160)
                }
            }
        }
    }

    private var adherenceCard: some View {
        let last7 = nutrition.suffix(7)
        let pts = last7.map { (d: $0.dayDate, c: $0.caloriesIn, g: goalCalories) }
        return FocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calorie adherence")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                if pts.isEmpty {
                    Text("No nutrition logs in the last stretch.")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                } else {
                    Chart {
                        ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                            BarMark(
                                x: .value("Day", p.d, unit: .day),
                                y: .value("kcal", p.c)
                            )
                            .foregroundStyle(barColor(cal: p.c, goal: p.g))
                        }
                        RuleMark(y: .value("Goal", goalCalories))
                            .foregroundStyle(FocusPalette.textSecondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .frame(height: 180)
                }
            }
        }
    }

    private func barColor(cal: Int, goal: Int) -> Color {
        let r = Double(cal) / Double(max(goal, 1))
        if r < 0.75 { return FocusPalette.warning }
        if r > 1.15 { return FocusPalette.danger.opacity(0.85) }
        return FocusPalette.positive.opacity(0.9)
    }
}
