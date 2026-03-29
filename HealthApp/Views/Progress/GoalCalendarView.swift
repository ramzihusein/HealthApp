import SwiftUI
import SwiftData

struct GoalCalendarView: View {
    @Query(sort: \DailyNutritionLog.dayDate) private var nutritionLogs: [DailyNutritionLog]
    @Query(sort: \DailyWeightEntry.dayDate) private var weights: [DailyWeightEntry]
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @Query private var sessions: [WorkoutSessionLog]
    @Query(sort: \CardioSessionLog.dayDate) private var allCardioSessionLogs: [CardioSessionLog]

    @State private var displayedMonth = Date()
    @State private var detailDay: Date?

    private var mealPlan: MealPlanDTO? {
        guard let p = plans.first else { return nil }
        return try? PlanCodec.decodeMeal(from: p.mealJSON)
    }

    private var workoutPlan: WorkoutPlanDTO? {
        guard let p = plans.first else { return nil }
        return try? PlanCodec.decodeWorkout(from: p.workoutJSON)
    }

    private var goalCalories: Int { mealPlan?.targetDailyCalories ?? 2000 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    monthHeader

                    legendRow

                    calendarGrid

                    Text("Past days use calories (~85–115% of goal) plus completed strength sets and cardio minutes (≥80% of each planned block) when those are scheduled. Rest days only use calories.")
                        .font(.caption2)
                        .foregroundStyle(FocusPalette.textSecondary)
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle("Goals calendar")
            .sheet(item: Binding(
                get: { detailDay.map { DayWrapper(id: $0) } },
                set: { detailDay = $0?.id }
            )) { wrap in
                DayProgressDetailSheet(
                    date: wrap.id,
                    goalCalories: goalCalories,
                    nutrition: nutrition(for: wrap.id),
                    weight: weight(for: wrap.id),
                    planDay: workoutDay(for: wrap.id),
                    sessions: sessions(on: wrap.id),
                    cardioLogs: cardioLogs(on: wrap.id)
                )
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(FocusPalette.accent)
            }
            Spacer()
            Text(monthTitle(displayedMonth))
                .font(.headline)
                .foregroundStyle(FocusPalette.textPrimary)
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(FocusPalette.accent)
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendDot(GoalDayTier.red.cellColor, "< 50%")
            legendDot(GoalDayTier.yellow.cellColor, "50–80%")
            legendDot(GoalDayTier.green.cellColor, "80–100%")
            legendDot(GoalDayTier.noData.cellColor, "No data")
        }
        .font(.caption2)
        .foregroundStyle(FocusPalette.textSecondary)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
        }
    }

    private var calendarGrid: some View {
        let start = CalendarDay.startOfMonth(containing: displayedMonth)
        let days = CalendarDay.daysInMonth(containing: start)
        let pad = leadingEmptyCells(for: start)
        let cols = 7
        let totalCells = pad + days.count
        let rows = (totalCells + cols - 1) / cols

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(FocusPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<cols, id: \.self) { col in
                        let i = row * cols + col
                        if i < pad {
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        } else if i - pad < days.count {
                            let d = days[i - pad]
                            dayCell(d)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let tier = GoalDayScore.tier(
            date: date,
            goalCalories: goalCalories,
            nutrition: nutrition(for: date),
            planDay: workoutDay(for: date),
            sessionsOnDay: sessions(on: date),
            cardioLogsOnDay: cardioLogs(on: date)
        )
        let dayNum = CalendarDay.calendar.component(.day, from: date)
        return Button {
            detailDay = CalendarDay.startOfDay(date)
        } label: {
            Text("\(dayNum)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tier == .future ? FocusPalette.textSecondary : FocusPalette.background)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tier.cellColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(FocusPalette.border.opacity(0.5), lineWidth: tier == .future ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .disabled(tier == .future)
    }

    private func shiftMonth(_ delta: Int) {
        guard let d = CalendarDay.calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = d
    }

    private func monthTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: d)
    }

    private func leadingEmptyCells(for monthStart: Date) -> Int {
        let wd = CalendarDay.calendar.component(.weekday, from: monthStart)
        return (wd + 5) % 7
    }

    private func nutrition(for date: Date) -> DailyNutritionLog? {
        let k = DayKey.string(for: CalendarDay.startOfDay(date))
        return nutritionLogs.first { $0.dayKey == k }
    }

    private func weight(for date: Date) -> DailyWeightEntry? {
        let k = DayKey.string(for: CalendarDay.startOfDay(date))
        return weights.first { $0.dayKey == k }
    }

    private func sessions(on date: Date) -> [WorkoutSessionLog] {
        let k = DayKey.string(for: CalendarDay.startOfDay(date))
        return sessions.filter { $0.dayKey == k }
    }

    private func cardioLogs(on date: Date) -> [CardioSessionLog] {
        let k = DayKey.string(for: CalendarDay.startOfDay(date))
        return allCardioSessionLogs.filter { $0.dayKey == k }
    }

    private func workoutDay(for date: Date) -> WorkoutDayDTO? {
        guard let plan = workoutPlan, let week = plan.weeks.first else { return nil }
        let idx = CalendarDay.planDayIndex(for: date)
        return week.days.first { $0.dayIndex == idx }
    }
}

private struct DayWrapper: Identifiable {
    let id: Date
}

private struct DayProgressDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let goalCalories: Int
    let nutrition: DailyNutritionLog?
    let weight: DailyWeightEntry?
    let planDay: WorkoutDayDTO?
    let sessions: [WorkoutSessionLog]
    let cardioLogs: [CardioSessionLog]

    @Query private var profiles: [UserHealthProfile]

    private var imperial: Bool { profiles.first?.measurementSystemRaw == "imperial" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let tier = GoalDayScore.tier(
                        date: date,
                        goalCalories: goalCalories,
                        nutrition: nutrition,
                        planDay: planDay,
                        sessionsOnDay: sessions,
                        cardioLogsOnDay: cardioLogs
                    )
                    Text("Status: \(tierLabel(tier))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FocusPalette.textPrimary)

                    if let frac = GoalDayScore.fractionMet(
                        date: date,
                        goalCalories: goalCalories,
                        nutrition: nutrition,
                        planDay: planDay,
                        sessionsOnDay: sessions,
                        cardioLogsOnDay: cardioLogs
                    ) {
                        Text("Goals met: \(Int((frac * 100).rounded()))% (calories \(calorieMet ? "✓" : "✗"); workout: \(workoutSubtitle))")
                            .font(.footnote)
                            .foregroundStyle(FocusPalette.textSecondary)
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nutrition")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("Logged: \(nutrition?.caloriesIn ?? 0) kcal · Goal: \(goalCalories) kcal")
                                .font(.subheadline)
                                .foregroundStyle(FocusPalette.textSecondary)
                            if let n = nutrition, !n.notes.isEmpty {
                                Text("Notes: \(n.notes)")
                                    .font(.caption)
                                    .foregroundStyle(FocusPalette.textSecondary)
                            }
                        }
                    }

                    if let w = weight {
                        FocusCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Weight")
                                    .font(.headline)
                                    .foregroundStyle(FocusPalette.textPrimary)
                                let disp = imperial ? MeasureConversion.kgToLb(w.weightKg) : w.weightKg
                                let u = imperial ? "lb" : "kg"
                                Text(String(format: "%.1f %@", disp, u))
                                    .font(.subheadline)
                                    .foregroundStyle(FocusPalette.textSecondary)
                            }
                        }
                    }

                    if let pd = planDay {
                        FocusCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Planned day: \(pd.name)")
                                    .font(.headline)
                                    .foregroundStyle(FocusPalette.textPrimary)
                                if !pd.liftingExercisesResolved().isEmpty {
                                    Text("Strength: \(pd.liftingExercisesResolved().map(\.name).joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(FocusPalette.textSecondary)
                                }
                                if !pd.cardioBlocksResolved().isEmpty {
                                    Text("Cardio: \(pd.cardioBlocksResolved().map(\.title).joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(FocusPalette.textSecondary)
                                }
                            }
                        }
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Logged lifting")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            if sessions.isEmpty {
                                Text("No sets logged.")
                                    .font(.caption)
                                    .foregroundStyle(FocusPalette.textSecondary)
                            } else {
                                ForEach(sessions.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { s in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(s.exerciseName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(FocusPalette.textPrimary)
                                        let sets = s.sets.sorted { $0.setIndex < $1.setIndex }
                                        Text(sets.map { setLine($0) }.joined(separator: " · "))
                                            .font(.caption2)
                                            .foregroundStyle(FocusPalette.textSecondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Logged cardio")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            if cardioLogs.isEmpty {
                                Text("Nothing logged for planned cardio blocks.")
                                    .font(.caption)
                                    .foregroundStyle(FocusPalette.textSecondary)
                            } else {
                                ForEach(cardioLogs.sorted { $0.sortOrder < $1.sortOrder }, id: \.logKey) { c in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(c.blockTitle)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color(red: 0.35, green: 0.82, blue: 0.88))
                                        Text("\(c.completedMinutes) min · target \(c.targetDurationMinutes) min")
                                            .font(.caption2)
                                            .foregroundStyle(FocusPalette.textSecondary)
                                        if !c.notes.isEmpty {
                                            Text(c.notes)
                                                .font(.caption2)
                                                .foregroundStyle(FocusPalette.textSecondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle(shortDate(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var calorieMet: Bool {
        guard let nutrition, nutrition.caloriesIn > 0, goalCalories > 0 else { return false }
        let r = Double(nutrition.caloriesIn) / Double(goalCalories)
        return r >= 0.85 && r <= 1.15
    }

    private var workoutSubtitle: String {
        guard let planDay else { return "n/a" }
        let lifts = planDay.liftingExercisesResolved()
        let cardioBlocks = planDay.cardioBlocksResolved()
        if lifts.isEmpty && cardioBlocks.isEmpty { return "n/a" }
        var parts: [String] = []
        if !lifts.isEmpty {
            let ok = lifts.allSatisfy { ex in
                guard let s = sessions.first(where: { $0.exerciseId == ex.id }) else { return false }
                !s.sets.isEmpty && !s.sets.contains { $0.reps <= 0 }
            }
            parts.append("strength \(ok ? "✓" : "✗")")
        }
        if !cardioBlocks.isEmpty {
            let ok = GoalDayScore.cardioGoalMet(blocks: cardioBlocks, logs: cardioLogs)
            parts.append("cardio \(ok ? "✓" : "✗")")
        }
        return parts.joined(separator: ", ")
    }

    private func setLine(_ set: LoggedSetEntry) -> String {
        let w = imperial ? MeasureConversion.kgToLb(set.weightKg) : set.weightKg
        let u = imperial ? "lb" : "kg"
        return "S\(set.setIndex + 1) \(String(format: "%.1f", w))\(u)×\(set.reps)"
    }

    private func tierLabel(_ t: GoalDayTier) -> String {
        switch t {
        case .future: return "Upcoming"
        case .noData: return "No data"
        case .red: return "Under 50%"
        case .yellow: return "50–80%"
        case .green: return "80–100%"
        }
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }
}
