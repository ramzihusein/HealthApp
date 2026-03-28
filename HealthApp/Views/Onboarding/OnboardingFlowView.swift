import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    var existingProfile: UserHealthProfile?

    @State private var step = 0
    @State private var age = 30
    @State private var weightKg = 75.0
    @State private var heightCm = 175.0
    @State private var gender = "prefer_not_say"
    @State private var activity = "moderate"
    @State private var selectedGoals: Set<String> = []
    @State private var injuries = ""
    @State private var cookMins = 45
    @State private var budget = 120.0
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private let goalOptions = [
        "Lose weight",
        "Gain muscle",
        "Increase flexibility",
        "Improve endurance",
        "General health",
        "Rehab / return to activity"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(headerTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(FocusPalette.textPrimary)

                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(FocusPalette.textSecondary)

                    stepsContent

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(FocusPalette.danger)
                    }

                    navigationRow
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if let p = existingProfile {
                age = p.age
                weightKg = p.weightKg
                heightCm = p.heightCm
                gender = p.genderRaw
                activity = p.activityLevelRaw
                selectedGoals = Set(p.goals)
                injuries = p.injuriesNotes
                cookMins = p.dailyCookingMinutes
                budget = p.weeklyMealBudget
            }
        }
    }

    private var headerTitle: String {
        switch step {
        case 0: return "Your baseline"
        case 1: return "Goals & safety"
        case 2: return "Kitchen & budget"
        default: return "Build your plans"
        }
    }

    private var headerSubtitle: String {
        switch step {
        case 0: return "We use this to size training and nutrition — not to judge."
        case 1: return "Pick what matters now. You can change this later."
        case 2: return "Helps the planner respect real life."
        default: return "We generate a structured workout and meal plan. Add an API key in Info for live LLM output."
        }
    }

    @ViewBuilder
    private var stepsContent: some View {
        switch step {
        case 0:
            stepBaseline
        case 1:
            stepGoals
        case 2:
            stepKitchen
        default:
            stepFinish
        }
    }

    private var stepBaseline: some View {
        VStack(alignment: .leading, spacing: 16) {
            FocusCard {
                VStack(alignment: .leading, spacing: 12) {
                    labeledStepper("Age", value: $age, range: 14...90)
                    labeledSlider("Weight (kg)", value: $weightKg, range: 35...200)
                    labeledSlider("Height (cm)", value: $heightCm, range: 120...220)
                    pickerRow("Gender", selection: $gender, options: [
                        ("prefer_not_say", "Prefer not to say"),
                        ("female", "Female"),
                        ("male", "Male"),
                        ("non_binary", "Non-binary")
                    ])
                    pickerRow("Activity", selection: $activity, options: [
                        ("sedentary", "Mostly seated"),
                        ("light", "Light — walks, 1–2 sessions/wk"),
                        ("moderate", "Moderate — 3–4 sessions/wk"),
                        ("active", "Active — 5+ sessions/wk"),
                        ("very_active", "Very active — physical job + training")
                    ])
                }
            }
        }
    }

    private var stepGoals: some View {
        VStack(alignment: .leading, spacing: 16) {
            FocusCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Goals")
                        .font(.headline)
                        .foregroundStyle(FocusPalette.textPrimary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(goalOptions, id: \.self) { g in
                            goalChip(g)
                        }
                    }
                }
            }
            FocusCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Injuries or movements to avoid")
                        .font(.headline)
                        .foregroundStyle(FocusPalette.textPrimary)
                    TextField("e.g. mild shoulder impingement — no overhead pressing", text: $injuries, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(FocusPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(FocusPalette.textPrimary)
                }
            }
        }
    }

    private var stepKitchen: some View {
        FocusCard {
            VStack(alignment: .leading, spacing: 16) {
                labeledStepper("Avg. cooking time / day (min)", value: $cookMins, range: 10...180)
                labeledSlider("Weekly meal budget (USD)", value: $budget, range: 20...500)
            }
        }
    }

    private var stepFinish: some View {
        FocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ready")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                Text("Plans are saved on this device. When you add a backend (e.g. Supabase), the same profile id can sync to the web app.")
                    .font(.footnote)
                    .foregroundStyle(FocusPalette.textSecondary)
                if isGenerating {
                    ProgressView()
                        .tint(FocusPalette.accent)
                        .padding(.top, 8)
                }
            }
        }
    }

    private var navigationRow: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(FocusSecondaryButtonStyle())
            }
            Spacer(minLength: 0)
            if step < 3 {
                Button("Continue") { step += 1 }
                    .buttonStyle(FocusPrimaryButtonStyle())
            } else {
                Button(action: completeOnboarding) {
                    Text(isGenerating ? "Working…" : "Generate plans")
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .disabled(isGenerating)
            }
        }
    }

    private func goalChip(_ g: String) -> some View {
        let on = selectedGoals.contains(g)
        return Button {
            if on { selectedGoals.remove(g) } else { selectedGoals.insert(g) }
        } label: {
            Text(g)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(on ? FocusPalette.background : FocusPalette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(on ? FocusPalette.accent : FocusPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(on ? Color.clear : FocusPalette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func labeledStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .foregroundStyle(FocusPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textSecondary)
                Spacer()
                Text(String(format: "%.0f", value.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(FocusPalette.textPrimary)
            }
            Slider(value: value, in: range)
                .tint(FocusPalette.accent)
        }
    }

    private func pickerRow(_ title: String, selection: Binding<String>, options: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
            Menu {
                ForEach(options, id: \.0) { opt in
                    Button(opt.1) { selection.wrappedValue = opt.0 }
                }
            } label: {
                HStack {
                    Text(options.first { $0.0 == selection.wrappedValue }?.1 ?? selection.wrappedValue)
                        .foregroundStyle(FocusPalette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FocusPalette.textSecondary)
                }
                .padding(12)
                .background(FocusPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func completeOnboarding() {
        guard let p = existingProfile ?? profilesFetchFirst() else { return }
        errorMessage = nil
        isGenerating = true
        p.age = age
        p.weightKg = weightKg
        p.heightCm = heightCm
        p.genderRaw = gender
        p.activityLevelRaw = activity
        p.goalsCSV = selectedGoals.sorted().joined(separator: ",")
        p.injuriesNotes = injuries
        p.dailyCookingMinutes = cookMins
        p.weeklyMealBudget = budget
        p.updatedAt = .now

        Task {
            do {
                let result = try await PlanGenerationService.generatePlans(for: p)
                await MainActor.run {
                    let existing = try? modelContext.fetch(FetchDescriptor<StoredGeneratedPlans>())
                    existing?.forEach { modelContext.delete($0) }
                    let stored = StoredGeneratedPlans(
                        workoutJSON: result.workoutJSON,
                        mealJSON: result.mealJSON,
                        llmModelUsed: result.model
                    )
                    modelContext.insert(stored)
                    p.onboardingComplete = true
                    try? modelContext.save()
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func profilesFetchFirst() -> UserHealthProfile? {
        let d = FetchDescriptor<UserHealthProfile>()
        return try? modelContext.fetch(d).first
    }
}
