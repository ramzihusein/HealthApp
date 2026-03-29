import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserHealthProfile]

    @State private var useCustomLLM = false
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var modelId = ""
    @State private var useImperial = true
    @State private var currencyCode = "USD"
    @State private var savedNotice = false
    @State private var isRegeneratingPlans = false
    @State private var regenError: String?
    @State private var regenSuccess = false
    #if DEBUG
    @State private var showDebugResetConfirm = false
    @State private var debugResetError: String?
    @State private var debugSeedSuccess = false
    @State private var debugSeedError: String?
    #endif

    private var profile: UserHealthProfile? { profiles.first }

    /// Tutorial content tracks base URL when set; otherwise last onboarding provider from UserDefaults.
    private var tutorialProvider: OnboardingLLMProvider {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return OnboardingLLMProvider.fromStoredBaseURL(trimmed)
        }
        if let raw = UserDefaults.standard.string(forKey: AppConfig.llmProviderRawKey),
           let p = OnboardingLLMProvider(rawValue: raw) {
            return p
        }
        return .openAI
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FocusCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI plan generation")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("By default the app uses the built-in connection. Turn on the option below only if you want to bill your own OpenAI (or compatible) account.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)

                            Toggle("Use my own API credentials", isOn: $useCustomLLM)
                                .tint(FocusPalette.accent)
                                .foregroundStyle(FocusPalette.textPrimary)

                            if useCustomLLM {
                                Text("Key and endpoint are stored in UserDefaults on this device only. Prefer Keychain for production apps.")
                                    .font(.caption2)
                                    .foregroundStyle(FocusPalette.textSecondary)
                                APIKeyField(text: $apiKey, placeholder: "Your API key")

                                LLMApiKeyHelpDisclosure(provider: tutorialProvider)

                                TextField("Base URL (optional)", text: $baseURL)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                TextField("Model id (optional)", text: $modelId)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            }

                            Button("Save API settings") { saveAPISettings() }
                                .buttonStyle(FocusPrimaryButtonStyle())
                        }
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Regenerate plans")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("Uses your current profile and (from month 2 onward) last month’s workout logs for suggested loads. Plans are scoped to the current calendar month—regenerate when a month ends or anytime you want a refresh. If no API key is available, the app uses offline mock templates.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
                            Button(action: regeneratePlans) {
                                HStack {
                                    if isRegeneratingPlans {
                                        ProgressView()
                                            .tint(FocusPalette.background)
                                    }
                                    Text(isRegeneratingPlans ? "Generating…" : "Regenerate workout & meal plans")
                                }
                            }
                            .buttonStyle(FocusPrimaryButtonStyle())
                            .disabled(profile == nil || isRegeneratingPlans)
                        }
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Units")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Toggle("Use imperial (lb, ft/in)", isOn: $useImperial)
                                .tint(FocusPalette.accent)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("Applies to baseline, Fuel weight, and default workout weight entry.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Budget currency")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Picker("Currency", selection: $currencyCode) {
                                ForEach(CurrencyOption.allCases) { c in
                                    Text(c.label).tag(c.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(FocusPalette.accent)
                        }
                    }

                    if savedNotice {
                        Text("Saved.")
                            .font(.footnote)
                            .foregroundStyle(FocusPalette.positive)
                    }

                    #if DEBUG
                    FocusCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Debug")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("Insert removable sample strength + cardio logs in the last calendar month (same window plan regeneration uses for month 2+). Then tap Regenerate above to test progression text and suggested loads. Removes any previous debug seed rows first.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
                            Button("Insert sample logs for prior month") {
                                insertDebugProgressionSample()
                            }
                            .buttonStyle(.bordered)
                            .tint(FocusPalette.accent)

                            Text("Erase all SwiftData (profile, plans, logs, nutrition, weight), clear LLM-related UserDefaults and the stable user id, then insert a fresh profile. You will return to onboarding.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
                                .padding(.top, 8)
                            Button("Reset local data (fresh install)") {
                                showDebugResetConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FocusPalette.danger)
                        }
                    }
                    #endif
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle("Settings")
            .onAppear { loadFromStorageAndProfile() }
            .onChange(of: useImperial) { _, _ in persistProfilePreferences() }
            .onChange(of: currencyCode) { _, _ in persistProfilePreferences() }
            .alert("Regeneration failed", isPresented: Binding(
                get: { regenError != nil },
                set: { if !$0 { regenError = nil } }
            )) {
                Button("OK") { regenError = nil }
            } message: {
                Text(regenError ?? "")
            }
            .alert("Plans updated", isPresented: $regenSuccess) {
                Button("OK") {}
            } message: {
                Text("New workout and meal plans are saved. Review the Train and Fuel tabs.")
            }
            #if DEBUG
            .alert("Reset all local data?", isPresented: $showDebugResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { performDebugReset() }
            } message: {
                Text("This cannot be undone. Use only on simulator or test devices.")
            }
            .alert("Reset failed", isPresented: Binding(
                get: { debugResetError != nil },
                set: { if !$0 { debugResetError = nil } }
            )) {
                Button("OK") { debugResetError = nil }
            } message: {
                Text(debugResetError ?? "")
            }
            .alert("Sample logs inserted", isPresented: $debugSeedSuccess) {
                Button("OK") {}
            } message: {
                Text("Prior month (\(DebugProgressionSampleSeed.priorMonthLabel())) has debug bench, squat, deadlift, OHP, and one cardio log. Regenerate workout & meal plans to run month 2+ with that data.")
            }
            .alert("Sample seed failed", isPresented: Binding(
                get: { debugSeedError != nil },
                set: { if !$0 { debugSeedError = nil } }
            )) {
                Button("OK") { debugSeedError = nil }
            } message: {
                Text(debugSeedError ?? "")
            }
            #endif
        }
    }

    private func loadFromStorageAndProfile() {
        let ud = UserDefaults.standard
        useCustomLLM = LLMCredentialStore.isUsingCustomCredentials
        apiKey = ud.string(forKey: AppConfig.openAIKeyUserDefaultsKey) ?? ""
        baseURL = ud.string(forKey: AppConfig.openAIBaseURLKey) ?? ""
        modelId = ud.string(forKey: AppConfig.openAIModelKey) ?? ""
        if let p = profile {
            useImperial = p.measurementSystemRaw == "imperial"
            currencyCode = CurrencyOption(rawValue: p.currencyCode) != nil ? p.currencyCode : "USD"
        }
    }

    private func saveAPISettings() {
        let ud = UserDefaults.standard
        LLMCredentialStore.setUsesCustomCredentials(useCustomLLM)
        if useCustomLLM {
            let k = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if k.isEmpty {
                ud.removeObject(forKey: AppConfig.openAIKeyUserDefaultsKey)
            } else {
                ud.set(k, forKey: AppConfig.openAIKeyUserDefaultsKey)
            }
            let bu = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let mid = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
            if bu.isEmpty { ud.removeObject(forKey: AppConfig.openAIBaseURLKey) } else { ud.set(bu, forKey: AppConfig.openAIBaseURLKey) }
            if mid.isEmpty { ud.removeObject(forKey: AppConfig.openAIModelKey) } else { ud.set(mid, forKey: AppConfig.openAIModelKey) }
        } else {
            ud.removeObject(forKey: AppConfig.openAIKeyUserDefaultsKey)
            ud.removeObject(forKey: AppConfig.openAIBaseURLKey)
            ud.removeObject(forKey: AppConfig.openAIModelKey)
        }
        persistProfilePreferences()
        savedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNotice = false }
    }

    private func persistProfilePreferences() {
        guard let p = profile else { return }
        p.measurementSystemRaw = useImperial ? "imperial" : "metric"
        p.currencyCode = currencyCode
        p.updatedAt = Date.now
        try? modelContext.save()
    }

    private func regeneratePlans() {
        guard let p = profile else { return }
        regenError = nil
        isRegeneratingPlans = true
        Task { @MainActor in
            do {
                let existing = (try? modelContext.fetch(FetchDescriptor<StoredGeneratedPlans>())) ?? []
                let old = existing.first
                let nextSeq = (old?.planMonthSequence ?? 0) + 1
                let periodStart = CalendarDay.startOfMonth(containing: Date())
                let periodEnd = CalendarDay.endOfMonth(containing: Date())
                let priorAnchor = CalendarDay.calendar.date(byAdding: .month, value: -1, to: periodStart) ?? periodStart
                let priorStart = CalendarDay.startOfMonth(containing: priorAnchor)
                let priorEnd = CalendarDay.endOfMonth(containing: priorAnchor)
                let allSessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSessionLog>())) ?? []
                let filtered = ProgressionSummaryBuilder.filterSessions(allSessions, from: priorStart, through: priorEnd)
                let allCardio = (try? modelContext.fetch(FetchDescriptor<CardioSessionLog>())) ?? []
                let filteredCardio = ProgressionSummaryBuilder.filterCardioLogs(allCardio, from: priorStart, through: priorEnd)
                let narrative = nextSeq > 1
                    ? ProgressionSummaryBuilder.narrativeForLLM(
                        sessions: filtered,
                        priorWorkoutPlanJSON: old?.workoutJSON,
                        intervalStart: priorStart,
                        intervalEnd: priorEnd,
                        cardioSessionsInInterval: filteredCardio
                    )
                    : ""
                let liftHints = nextSeq > 1 ? ProgressionSummaryBuilder.maxLiftKgByExerciseName(sessions: filtered) : [:]

                let result = try await PlanGenerationService.generatePlans(
                    for: p,
                    planMonthSequence: nextSeq,
                    priorMonthSummaryForLLM: narrative,
                    priorLiftMaxKgByExerciseName: liftHints,
                    priorWorkoutPlanJSON: nextSeq > 1 ? old?.workoutJSON : nil
                )
                existing.forEach { modelContext.delete($0) }
                let stored = StoredGeneratedPlans(
                    workoutJSON: result.workoutJSON,
                    mealJSON: result.mealJSON,
                    llmModelUsed: result.model,
                    planPeriodStart: periodStart,
                    planPeriodEnd: periodEnd,
                    planMonthSequence: nextSeq
                )
                modelContext.insert(stored)
                p.updatedAt = Date.now
                try? modelContext.save()
                isRegeneratingPlans = false
                regenSuccess = true
            } catch {
                isRegeneratingPlans = false
                regenError = error.localizedDescription
            }
        }
    }

    #if DEBUG
    private func insertDebugProgressionSample() {
        debugSeedError = nil
        do {
            try DebugProgressionSampleSeed.replaceSampleLogsInPriorMonth(modelContext: modelContext)
            debugSeedSuccess = true
        } catch {
            debugSeedError = error.localizedDescription
        }
    }

    private func performDebugReset() {
        debugResetError = nil
        do {
            try DebugLocalDataReset.wipeAllLocalData(modelContext: modelContext)
            useCustomLLM = false
            apiKey = ""
            baseURL = ""
            modelId = ""
            loadFromStorageAndProfile()
        } catch {
            debugResetError = error.localizedDescription
        }
    }
    #endif
}
