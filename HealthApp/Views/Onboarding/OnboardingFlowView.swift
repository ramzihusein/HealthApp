import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    var existingProfile: UserHealthProfile?

    @State private var step = 0
    @State private var llmProvider: OnboardingLLMProvider = .openAI
    @State private var customBaseURL = ""
    @State private var customModel = ""
    @State private var age = 30
    @State private var weightKg = 75.0
    @State private var heightCm = 175.0
    @State private var gender = "prefer_not_say"
    @State private var activity = "moderate"
    @State private var selectedGoals: Set<String> = []
    @State private var injuries = ""
    @State private var cookMins = 45
    @State private var budget = 120.0
    @State private var useImperial = true
    @State private var currencyCode = "USD"
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var workoutSessionMinutes = 45
    @State private var liftDaysPerWeek = 4
    @State private var cardioDaysPerWeek = 3
    @State private var equipmentSelected: Set<String> = []

    private let goalOptions = [
        "Lose weight",
        "Gain muscle",
        "Increase flexibility",
        "Improve endurance",
        "General health",
        "Rehab / return to activity"
    ]

    private let equipmentOptions: [(id: String, label: String)] = [
        ("dumbbells", "Dumbbells"),
        ("barbell", "Barbell & rack"),
        ("machines", "Weight machines"),
        ("cables", "Cable station"),
        ("kettlebells", "Kettlebells"),
        ("resistance_bands", "Resistance bands"),
        ("pullup_bar", "Pull-up bar"),
        ("treadmill", "Treadmill"),
        ("stationary_bike", "Exercise bike"),
        ("elliptical", "Elliptical"),
        ("rowing_erg", "Rowing machine"),
        ("running_paths", "Outdoor running / paths"),
        ("swim_access", "Pool / swim"),
        ("no_gym_equipment", "No gym equipment")
    ]

    private var weightLbBinding: Binding<Double> {
        Binding(
            get: { MeasureConversion.kgToLb(weightKg) },
            set: { weightKg = MeasureConversion.lbToKg($0) }
        )
    }

    private var heightFeet: Int {
        let totalIn = heightCm / 2.54
        return min(7, max(4, Int(totalIn / 12.0)))
    }

    private var heightInchesRemainder: Int {
        let totalIn = heightCm / 2.54
        let ft = Int(totalIn / 12.0)
        return min(11, max(0, Int(round(totalIn - Double(ft * 12)))))
    }

    private var heightFeetBinding: Binding<Int> {
        Binding(
            get: { heightFeet },
            set: { newFt in
                let inch = heightInchesRemainder
                heightCm = Double(max(4, min(7, newFt)) * 12 + inch) * 2.54
            }
        )
    }

    private var heightInchesBinding: Binding<Int> {
        Binding(
            get: { heightInchesRemainder },
            set: { newIn in
                let ft = heightFeet
                heightCm = Double(ft * 12 + min(11, max(0, newIn))) * 2.54
            }
        )
    }

    private var heightImperialRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Height")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
            HStack(spacing: 12) {
                Stepper("Feet: \(heightFeet)", value: heightFeetBinding, in: 4...7)
                    .foregroundStyle(FocusPalette.textPrimary)
                Stepper("In: \(heightInchesRemainder)", value: heightInchesBinding, in: 0...11)
                    .foregroundStyle(FocusPalette.textPrimary)
            }
        }
    }

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
            loadLLMFieldsFromStorage()
            if let p = existingProfile {
                age = p.age
                weightKg = p.weightKg
                heightCm = p.heightCm
                gender = p.genderRaw == "non_binary" ? "prefer_not_say" : p.genderRaw
                activity = p.activityLevelRaw
                selectedGoals = Set(p.goals)
                injuries = p.injuriesNotes
                cookMins = p.dailyCookingMinutes
                budget = p.weeklyMealBudget
                useImperial = p.measurementSystemRaw == "imperial"
                currencyCode = CurrencyOption(rawValue: p.currencyCode) != nil ? p.currencyCode : "USD"
                workoutSessionMinutes = p.workoutSessionMinutes
                liftDaysPerWeek = p.liftDaysPerWeek
                cardioDaysPerWeek = p.cardioDaysPerWeek
                let eqParts = p.equipmentCSV.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                equipmentSelected = Set(eqParts.map { $0 == "bodyweight_only" ? "no_gym_equipment" : $0 })
            }
        }
        .onChange(of: llmProvider) { old, p in
            if p == .custom, old != .custom {
                customBaseURL = ""
                customModel = ""
            } else if p != .custom {
                customBaseURL = p.defaultBaseURL
                customModel = p.defaultModel
            }
        }
    }

    private var headerTitle: String {
        switch step {
        case 0: return "Plan generation"
        case 1: return "Your baseline"
        case 2: return "Training & equipment"
        case 3: return "Goals & safety"
        case 4: return "Kitchen & budget"
        default: return "Build your plans"
        }
    }

    private var headerSubtitle: String {
        switch step {
        case 0: return "Plans use the built-in AI connection. You can switch to your own key and model in Settings anytime."
        case 1: return "We use this to size training and nutrition — not to judge."
        case 2: return "Time, weekly frequency, and gear so strength and cardio stay realistic."
        case 3: return "Pick what matters now. You can change this later."
        case 4: return "Helps the planner respect real life."
        default: return "We’ll build your workout and meal plan from your answers."
        }
    }

    @ViewBuilder
    private var stepsContent: some View {
        switch step {
        case 0:
            stepLLMSetup
        case 1:
            stepBaseline
        case 2:
            stepTraining
        case 3:
            stepGoals
        case 4:
            stepKitchen
        default:
            stepFinish
        }
    }

    private var canProceedFromLLMStep: Bool {
        if llmProvider != .custom { return true }
        return !customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var stepLLMSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            FocusCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("AI-powered plans")
                        .font(.headline)
                        .foregroundStyle(FocusPalette.textPrimary)
                    Text("Workout and meal plans are generated with an OpenAI-compatible chat API. No API key is required here — advanced users can use their own key under Settings.")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)

                    llmProviderMenu

                    if llmProvider == .custom {
                        TextField("Base URL (e.g. https://api.example.com/v1)", text: $customBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("Model id", text: $customModel)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !canProceedFromLLMStep {
                            Text("Enter a base URL to continue, or choose another provider.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.warning)
                        }
                        Text("Custom endpoints require enabling “Use my own API credentials” in Settings and saving your key there.")
                            .font(.caption2)
                            .foregroundStyle(FocusPalette.textSecondary)
                    }

                    LLMApiKeyHelpDisclosure(provider: llmProvider)
                }
            }

            FocusCard {
                VStack(alignment: .leading, spacing: 10) {
                    disclaimerRow(
                        title: "Not professional medical or coaching advice",
                        body: "This app is not a substitute for a licensed dietitian, physician, or certified personal trainer. For medical conditions or injuries, consult a qualified professional."
                    )
                }
            }
        }
    }

    private func disclaimerRow(title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FocusPalette.warning)
                .font(.body)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FocusPalette.textPrimary)
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(FocusPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var llmProviderMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Provider")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
            Menu {
                ForEach(OnboardingLLMProvider.allCases) { p in
                    Button(p.menuLabel) { llmProvider = p }
                }
            } label: {
                HStack {
                    Text(llmProvider.menuLabel)
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

    private var stepBaseline: some View {
        VStack(alignment: .leading, spacing: 16) {
            FocusCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Units")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FocusPalette.textSecondary)
                        Spacer()
                        Picker("", selection: $useImperial) {
                            Text("Metric").tag(false)
                            Text("Imperial").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }
                    labeledStepper("Age", value: $age, range: 14...90)
                    if useImperial {
                        labeledSlider("Weight (lb)", value: weightLbBinding, range: 77...440)
                        heightImperialRow
                    } else {
                        labeledSlider("Weight (kg)", value: $weightKg, range: 35...200)
                        labeledSlider("Height (cm)", value: $heightCm, range: 120...220)
                    }
                    pickerRow("Gender", selection: $gender, options: [
                        ("prefer_not_say", "Prefer not to say"),
                        ("female", "Female"),
                        ("male", "Male")
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

    private var stepTraining: some View {
        FocusCard {
            VStack(alignment: .leading, spacing: 16) {
                labeledStepper("Typical workout time (minutes)", value: $workoutSessionMinutes, range: 20...120)
                labeledStepper("Strength / lifting days per week", value: $liftDaysPerWeek, range: 2...6)
                labeledStepper("Cardio sessions per week", value: $cardioDaysPerWeek, range: 0...7)
                Text("Equipment available")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                Text("Select everything you can use. Plans avoid gear you do not have.")
                    .font(.caption)
                    .foregroundStyle(FocusPalette.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(equipmentOptions, id: \.id) { opt in
                        equipmentChip(opt)
                    }
                }
            }
        }
    }

    private func equipmentChip(_ opt: (id: String, label: String)) -> some View {
        let on = equipmentSelected.contains(opt.id)
        return Button {
            if on { equipmentSelected.remove(opt.id) } else { equipmentSelected.insert(opt.id) }
        } label: {
            Text(opt.label)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(on ? FocusPalette.background : FocusPalette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .background(on ? FocusPalette.accent : FocusPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(on ? Color.clear : FocusPalette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weekly grocery budget")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FocusPalette.textSecondary)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(CurrencyOption.allCases) { c in
                            Text(c.label).tag(c.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(FocusPalette.accent)
                    .foregroundStyle(FocusPalette.textPrimary)
                }
                labeledSlider(
                    "Amount (\(CurrencyOption(rawValue: currencyCode)?.symbol ?? currencyCode))",
                    value: $budget,
                    range: 20...500
                )
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
            if step < 5 {
                Button("Continue") {
                    if step == 0 { persistLLMSettingsFromOnboarding() }
                    step += 1
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .disabled(step == 0 && !canProceedFromLLMStep)
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
        p.measurementSystemRaw = useImperial ? "imperial" : "metric"
        p.currencyCode = currencyCode
        p.workoutSessionMinutes = workoutSessionMinutes
        p.liftDaysPerWeek = liftDaysPerWeek
        p.cardioDaysPerWeek = cardioDaysPerWeek
        p.equipmentCSV = equipmentSelected
            .map { $0 == "bodyweight_only" ? "no_gym_equipment" : $0 }
            .sorted()
            .joined(separator: ",")
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

    private func loadLLMFieldsFromStorage() {
        let ud = UserDefaults.standard
        let base = ud.string(forKey: AppConfig.openAIBaseURLKey)
        let model = ud.string(forKey: AppConfig.openAIModelKey) ?? ""
        if let raw = ud.string(forKey: AppConfig.llmProviderRawKey),
           let p = OnboardingLLMProvider(rawValue: raw) {
            llmProvider = p
        } else {
            llmProvider = OnboardingLLMProvider.fromStoredBaseURL(base)
        }
        if llmProvider == .custom {
            customBaseURL = base ?? ""
            customModel = model
        } else {
            customBaseURL = llmProvider.defaultBaseURL
            customModel = model.isEmpty ? llmProvider.defaultModel : model
        }
    }

    private func persistLLMSettingsFromOnboarding() {
        let ud = UserDefaults.standard
        if llmProvider == .custom {
            LLMCredentialStore.setUsesCustomCredentials(true)
            let base = customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
            ud.set(base, forKey: AppConfig.openAIBaseURLKey)
            if model.isEmpty {
                ud.removeObject(forKey: AppConfig.openAIModelKey)
            } else {
                ud.set(model, forKey: AppConfig.openAIModelKey)
            }
        } else {
            LLMCredentialStore.setUsesCustomCredentials(false)
            ud.removeObject(forKey: AppConfig.openAIBaseURLKey)
            ud.removeObject(forKey: AppConfig.openAIModelKey)
        }
        ud.set(llmProvider.rawValue, forKey: AppConfig.llmProviderRawKey)
    }
}
