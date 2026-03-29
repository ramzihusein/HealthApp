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
                            Text("Uses your current profile. If no API key is available (built-in or your own), the app uses offline mock templates.")
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
                            Text("Erase all SwiftData (profile, plans, logs, nutrition, weight), clear LLM-related UserDefaults and the stable user id, then insert a fresh profile. You will return to onboarding.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
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
        Task {
            do {
                let result = try await PlanGenerationService.generatePlans(for: p)
                await MainActor.run {
                    let existing = (try? modelContext.fetch(FetchDescriptor<StoredGeneratedPlans>())) ?? []
                    existing.forEach { modelContext.delete($0) }
                    let stored = StoredGeneratedPlans(
                        workoutJSON: result.workoutJSON,
                        mealJSON: result.mealJSON,
                        llmModelUsed: result.model
                    )
                    modelContext.insert(stored)
                    p.updatedAt = Date.now
                    try? modelContext.save()
                    isRegeneratingPlans = false
                    regenSuccess = true
                }
            } catch {
                await MainActor.run {
                    isRegeneratingPlans = false
                    regenError = error.localizedDescription
                }
            }
        }
    }

    #if DEBUG
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
