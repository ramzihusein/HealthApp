import SwiftUI
import SwiftData
import Charts

struct DietPaneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @Query(sort: \DailyNutritionLog.dayDate) private var nutritionLogs: [DailyNutritionLog]
    @Query(sort: \DailyWeightEntry.dayDate) private var weights: [DailyWeightEntry]
    @Query private var profiles: [UserHealthProfile]

    @State private var selectedDate = CalendarDay.startOfDay(Date())
    @State private var caloriesText = ""
    @State private var weightText = ""
    @State private var notes = ""
    @State private var useImperialWeight: Bool = true

    private var profile: UserHealthProfile? { profiles.first }
    private var imperial: Bool { profile?.measurementSystemRaw == "imperial" }

    private var mealPlan: MealPlanDTO? {
        guard let p = plans.first else { return nil }
        return try? PlanCodec.decodeMeal(from: p.mealJSON)
    }

    private var goalCalories: Int { mealPlan?.targetDailyCalories ?? 2000 }

    private var todayKey: String { DayKey.string(for: selectedDate) }

    private var mealsForSelectedDay: [PlannedMealDTO] {
        guard let mp = mealPlan else { return [] }
        let idx = CalendarDay.planDayIndex(for: selectedDate)
        return mp.days.first(where: { $0.dayIndex == idx })?.meals ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    unitToggleCard

                    datePickerCard

                    mealPlanCard

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
                            HStack {
                                Text("Weight")
                                    .font(.headline)
                                    .foregroundStyle(FocusPalette.textPrimary)
                                Spacer()
                                Picker("", selection: $useImperialWeight) {
                                    Text("kg").tag(false)
                                    Text("lb").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 140)
                            }
                            TextField(useImperialWeight ? "Weight (lb)" : "Weight (kg)", text: $weightText)
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
            .onAppear {
                useImperialWeight = imperial
                loadFieldsForSelectedDay()
            }
            .onChange(of: selectedDate) { _, _ in loadFieldsForSelectedDay() }
            .onChange(of: imperial) { _, v in
                useImperialWeight = v
                loadFieldsForSelectedDay()
            }
            .onChange(of: useImperialWeight) { _, _ in loadFieldsForSelectedDay() }
        }
    }

    private var unitToggleCard: some View {
        FocusCard {
            Toggle("Use imperial units (lb, ft/in on forms)", isOn: Binding(
                get: { profile?.measurementSystemRaw == "imperial" },
                set: { newVal in
                    guard let p = profile else { return }
                    p.measurementSystemRaw = newVal ? "imperial" : "metric"
                    p.updatedAt = Date.now
                    useImperialWeight = newVal
                    try? modelContext.save()
                    loadFieldsForSelectedDay()
                }
            ))
            .tint(FocusPalette.accent)
            .foregroundStyle(FocusPalette.textPrimary)
        }
    }

    private var mealPlanCard: some View {
        FocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Planned meals (from your program)")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                if mealsForSelectedDay.isEmpty {
                    Text(mealPlan == nil ? "Generate a plan in onboarding to see meals here." : "No meals listed for this weekday in your plan.")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                } else {
                    ForEach(mealsForSelectedDay) { meal in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(meal.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FocusPalette.textPrimary)
                                if let c = meal.approxCalories {
                                    Text("~\(c) kcal")
                                        .font(.caption)
                                        .foregroundStyle(FocusPalette.accent)
                                }
                            }
                            Text(meal.description)
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
                            if let raw = meal.recipeURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                               let url = URL(string: raw),
                               ["http", "https"].contains(url.scheme?.lowercased()) {
                                Link(destination: url) {
                                    Label("Recipe ideas / search", systemImage: "link")
                                        .font(.caption.weight(.semibold))
                                }
                                .tint(FocusPalette.accent)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
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
        let last = nutritionLogs.suffix(14).filter { $0.caloriesIn > 0 }
        let distinctDays = MeasureConversion.distinctDaysWithCalories(Array(nutritionLogs))
        let pts = last.map { (day: $0.dayDate, cal: $0.caloriesIn) }
        return FocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calories vs goal (14 days)")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                Text(MeasureConversion.chartWaitMessage)
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary)
                if distinctDays < MeasureConversion.minDaysForChart {
                    Text("Logged days with calories: \(distinctDays) / \(MeasureConversion.minDaysForChart)")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                } else if pts.isEmpty {
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
        let last = weights.suffix(30).filter { $0.weightKg > 0 }
        let distinctDays = MeasureConversion.distinctDaysWithWeight(Array(weights))
        let useImp = imperial
        let pts: [(day: Date, w: Double)] = last.map {
            (day: $0.dayDate, w: useImp ? MeasureConversion.kgToLb($0.weightKg) : $0.weightKg)
        }
        let unitLabel = useImp ? "lb" : "kg"
        return FocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weight trend")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                Text(MeasureConversion.chartWaitMessage)
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary)
                if distinctDays < MeasureConversion.minDaysForChart {
                    Text("Logged days with weight: \(distinctDays) / \(MeasureConversion.minDaysForChart)")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                } else if pts.isEmpty {
                    Text("Enter weight to see the chart.")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                } else {
                    Chart {
                        ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                            LineMark(
                                x: .value("Day", p.day, unit: .day),
                                y: .value(unitLabel, p.w)
                            )
                            .foregroundStyle(FocusPalette.positive)
                            PointMark(
                                x: .value("Day", p.day, unit: .day),
                                y: .value(unitLabel, p.w)
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
            if useImperialWeight {
                weightText = String(format: "%.1f", MeasureConversion.kgToLb(w.weightKg))
            } else {
                weightText = String(format: "%.1f", w.weightKg)
            }
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
        let raw = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let kg: Double
        if useImperialWeight {
            kg = MeasureConversion.lbToKg(raw)
        } else {
            kg = raw
        }
        guard kg > 9, kg < 220 else { return }
        if let existing = weights.first(where: { $0.dayKey == k }) {
            existing.weightKg = kg
            existing.dayDate = selectedDate
        } else {
            let row = DailyWeightEntry(dayKey: k, dayDate: selectedDate, weightKg: kg)
            modelContext.insert(row)
        }
        try? modelContext.save()
        loadFieldsForSelectedDay()
    }
}
