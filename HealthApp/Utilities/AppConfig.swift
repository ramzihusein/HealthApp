import Foundation

enum AppConfig {
    static let openAIKeyUserDefaultsKey = "HealthAppOpenAIKey"
    static let openAIBaseURLKey = "HealthAppOpenAIBaseURL"
    static let openAIModelKey = "HealthAppOpenAIModel"
    static let llmProviderRawKey = "HealthAppLLMProviderRaw"
    /// When true, UserDefaults key / base URL / model override the built-in (Info.plist / xcconfig) values.
    static let useCustomOpenAILLMKey = "HealthAppUseCustomOpenAILLM"
}

// MARK: - LLM resolution (built-in vs Settings override)

enum LLMCredentialStore {
    /// After the first read, persisted bool wins. First launch: custom only if a user API key was already stored (legacy installs).
    private static var usesCustomOpenAILLM: Bool {
        let ud = UserDefaults.standard
        if ud.object(forKey: AppConfig.useCustomOpenAILLMKey) == nil {
            let hadKey = !(ud.string(forKey: AppConfig.openAIKeyUserDefaultsKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ud.set(hadKey, forKey: AppConfig.useCustomOpenAILLMKey)
        }
        return ud.bool(forKey: AppConfig.useCustomOpenAILLMKey)
    }

    private static func plistString(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if t.contains("$(") && t.contains(")") { return nil }
        return t
    }

    private static var embeddedOpenAIKey: String? {
        plistString("HealthAppOpenAIKey")
    }

    private static var embeddedBaseURL: String {
        plistString("HealthAppOpenAIBaseURL") ?? "https://api.openai.com/v1"
    }

    private static var embeddedModel: String {
        plistString("HealthAppOpenAIModel") ?? "gpt-4o-mini"
    }

    static func resolvedOpenAIKey() -> String? {
        let ud = UserDefaults.standard
        if usesCustomOpenAILLM {
            let k = ud.string(forKey: AppConfig.openAIKeyUserDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !k.isEmpty { return k }
        }
        if let k = embeddedOpenAIKey, !k.isEmpty { return k }
        let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return env.isEmpty ? nil : env
    }

    static func resolvedBaseURL() -> String {
        let ud = UserDefaults.standard
        if usesCustomOpenAILLM {
            let s = ud.string(forKey: AppConfig.openAIBaseURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !s.isEmpty { return s }
        }
        return embeddedBaseURL
    }

    static func resolvedModel() -> String {
        let ud = UserDefaults.standard
        if usesCustomOpenAILLM {
            let s = ud.string(forKey: AppConfig.openAIModelKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !s.isEmpty { return s }
        }
        return embeddedModel
    }

    static var isUsingCustomCredentials: Bool { usesCustomOpenAILLM }

    static func setUsesCustomCredentials(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: AppConfig.useCustomOpenAILLMKey)
    }
}
