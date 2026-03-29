import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserHealthProfile]

    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var modelId = ""
    @State private var useImperial = false
    @State private var currencyCode = "USD"
    @State private var savedNotice = false

    private var profile: UserHealthProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FocusCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LLM (OpenAI-compatible)")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("Key is stored in this app’s UserDefaults on device only—not in Git. For production, prefer Keychain.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
                            SecureField("API key", text: $apiKey)
                                .textContentType(.password)
                                .textFieldStyle(.roundedBorder)
                            TextField("Base URL (optional)", text: $baseURL)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            TextField("Model id (optional)", text: $modelId)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            Button("Save API settings") { saveAPISettings() }
                                .buttonStyle(FocusPrimaryButtonStyle())
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
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle("Settings")
            .onAppear { loadFromStorageAndProfile() }
            .onChange(of: useImperial) { _, _ in persistProfilePreferences() }
            .onChange(of: currencyCode) { _, _ in persistProfilePreferences() }
        }
    }

    private func loadFromStorageAndProfile() {
        let ud = UserDefaults.standard
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
        ud.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: AppConfig.openAIKeyUserDefaultsKey)
        let bu = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let mid = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        if bu.isEmpty { ud.removeObject(forKey: AppConfig.openAIBaseURLKey) } else { ud.set(bu, forKey: AppConfig.openAIBaseURLKey) }
        if mid.isEmpty { ud.removeObject(forKey: AppConfig.openAIModelKey) } else { ud.set(mid, forKey: AppConfig.openAIModelKey) }
        persistProfilePreferences()
        savedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedNotice = false }
    }

    private func persistProfilePreferences() {
        guard let p = profile else { return }
        p.measurementSystemRaw = useImperial ? "imperial" : "metric"
        p.currencyCode = currencyCode
        p.updatedAt = .now()
        try? modelContext.save()
    }
}
