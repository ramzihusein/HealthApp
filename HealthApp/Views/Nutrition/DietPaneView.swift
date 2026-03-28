import SwiftUI
import SwiftData
import Charts

struct DietPaneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @Query(sort: \DailyNutritionLog.dayDate) private var nutritionLogs: [DailyNutritionLog]
    @Query(sort: \DailyWeightEntry.dayDate) private var weights: [DailyWeightEntry]

    @State private var selectedDate = CalendarDay.startOfDay(Date())
    @State private var caloriesText = ""
    @State private var weightText = ""
    @State private var notes = ""

    private var mealPlan: MealPlanDTO? {
        guard let p = plans.first else { return nil }
        return try? PlanCodec.decodeMeal(from: p.mealJSON)
    }

    private var goalCalories: Int { mealPlan?.targetDailyCalories ?? 2000 }

    private var todayKey: String { DayKey.string(for: selectedDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    datePickerCard

                    FocusCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calories in")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            TextField("kcal for day", text: $caloriesText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Text("Goal: \(goalCalories) kcal")
                                    .font(.caption)
                                    .foregroundStyle(FocusPalette.textSecondary)
                                Spacer()
                                Button("Save") { saveNutrition() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(FocusPalette.accent)
                            }
                        }
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Weight")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            TextField("kg", text: $weightText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            Button("Save weight") { saveWeight() }
                                .buttonStyle(.borderedProminent)
                                .tint(FocusPalette.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    caloriesChartCard
                    weightChartCard
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle("Nutrition")
            .onAppear { loadFieldsForSelectedDay() }
            .onChange(of: selectedDate) { _, _ in loadFieldsForSelectedDay() }
        }
    }

    private var datePickerCard: some View {
        FocusCard {
            DatePicker(
                "Day",
                selection: Binding(
                    get: { selectedDate },
                    set: { selectedDate = CalendarDay.startOfDay($0) }
                ),
                displayedComponents: .date
            )
            .tint(FocusPalette.accent)
            .foregroundStyle(FocusPalette.textPrimary)
        }
    }

    private var caloriesChartCard: some View {
        let last = nutritionLogs.suffix(14)
        let pts = last.map { (day: $0.dayDate, cal: $0.caloriesIn) }
        return FocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calories vs goal (14 days)")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                if pts.isEmpty {
                    Text("Log calories to see the chart.")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                } else {
                    Chart {
                        ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                            BarMark(
                                x: .value("Day", p.day, unit: .day),
                                y: .value("kcal", p.cal)
                            )
                            .foregroundStyle(FocusPalette.accent.opacity(0.85))
                        }
                        RuleMark(y: .value("Goal", goalCalories))
                            .foregroundStyle(FocusPalette.textSecondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FocusPalette.border)
                            AxisValueLabel(format: .dateTime.month().day())
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FocusPalette.border)
                            AxisValueLabel()
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var weightChartCard: some View {
        let last = weights.suffix(30)
        let pts = last.map { (day: $0.dayDate, w: $0.weightKg) }
        return FocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weight trend")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                if pts.count < 2 {
                    Text("Enter weight on a few days to see a line.")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                } else {
                    Chart {
                        ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                            LineMark(
                                x: .value("Day", p.day, unit: .day),
                                y: .value("kg", p.w)
                            )
                            .foregroundStyle(FocusPalette.positive)
                            PointMark(
                                x: .value("Day", p.day, unit: .day),
                                y: .value("kg", p.w)
                            )
                            .foregroundStyle(FocusPalette.positive)
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FocusPalette.border)
                            AxisValueLabel(format: .dateTime.month().day())
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(FocusPalette.border)
                            AxisValueLabel()
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func loadFieldsForSelectedDay() {
        let k = todayKey
        if let n = nutritionLogs.first(where: { $0.dayKey == k }) {
            caloriesText = n.caloriesIn > 0 ? "\(n.caloriesIn)" : ""
            notes = n.notes
        } else {
            caloriesText = ""
            notes = ""
        }
        if let w = weights.first(where: { $0.dayKey == k }) {
            weightText = String(format: "%.1f", w.weightKg)
        } else {
            weightText = ""
        }
    }

    private func saveNutrition() {
        let k = todayKey
        let digits = caloriesText.filter { $0.isNumber }
        let v = Int(digits) ?? 0
        if let existing = nutritionLogs.first(where: { $0.dayKey == k }) {
            existing.caloriesIn = v
            existing.notes = notes
            existing.dayDate = selectedDate
        } else {
            let row = DailyNutritionLog(dayKey: k, dayDate: selectedDate, caloriesIn: v, notes: notes)
            modelContext.insert(row)
        }
        try? modelContext.save()
    }

    private func saveWeight() {
        let k = todayKey
        let v = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard v > 20, v < 400 else { return }
        if let existing = weights.first(where: { $0.dayKey == k }) {
            existing.weightKg = v
            existing.dayDate = selectedDate
        } else {
            let row = DailyWeightEntry(dayKey: k, dayDate: selectedDate, weightKg: v)
            modelContext.insert(row)
        }
        try? modelContext.save()
        loadFieldsForSelectedDay()
    }
}
