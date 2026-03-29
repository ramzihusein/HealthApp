import Foundation

/// Providers that expose an OpenAI-compatible `POST /v1/chat/completions` API (same request shape as OpenAI).
enum OnboardingLLMProvider: String, CaseIterable, Identifiable {
    case openAI
    case groq
    case togetherAI
    case openRouter
    case custom

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .openAI: return "OpenAI"
        case .groq: return "Groq"
        case .togetherAI: return "Together AI"
        case .openRouter: return "OpenRouter"
        case .custom: return "Custom (OpenAI-compatible URL)"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .togetherAI: return "https://api.together.xyz/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .groq: return "llama-3.1-8b-instant"
        case .togetherAI: return "meta-llama/Llama-3-8b-chat-hf"
        case .openRouter: return "openai/gpt-4o-mini"
        case .custom: return "gpt-4o-mini"
        }
    }

    static func fromStoredBaseURL(_ url: String?) -> OnboardingLLMProvider {
        guard let url, !url.isEmpty else { return .openAI }
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if u.contains("api.openai.com") { return .openAI }
        if u.contains("groq.com") { return .groq }
        if u.contains("together.xyz") { return .togetherAI }
        if u.contains("openrouter.ai") { return .openRouter }
        return .custom
    }

    /// Dashboard URL where users typically create API keys.
    var apiKeyPortalURL: URL? {
        switch self {
        case .openAI: return URL(string: "https://platform.openai.com/api-keys")
        case .groq: return URL(string: "https://console.groq.com/keys")
        case .togetherAI: return URL(string: "https://api.together.xyz/settings/api-keys")
        case .openRouter: return URL(string: "https://openrouter.ai/keys")
        case .custom: return nil
        }
    }

    var apiKeyHelpBullets: [String] {
        switch self {
        case .openAI:
            return [
                "Sign in or create an account at OpenAI.",
                "Open the API keys page and choose Create new secret key.",
                "Copy the key immediately (it may not be shown again). Usage may require a payment method on file."
            ]
        case .groq:
            return [
                "Sign in at Groq Console with your account.",
                "Go to API Keys and create a new key.",
                "Copy the key and paste it here."
            ]
        case .togetherAI:
            return [
                "Sign in to Together AI.",
                "Open your account settings and find API keys.",
                "Generate a key and copy it into this app."
            ]
        case .openRouter:
            return [
                "Sign in to OpenRouter.",
                "Open the Keys section and create an API key.",
                "Add credits if your account requires them for the models you use."
            ]
        case .custom:
            return [
                "Open your provider’s website or developer documentation.",
                "Look for API keys, tokens, or credentials—often under Account, Developer, or Settings.",
                "Ensure the provider supports OpenAI-compatible chat completions at the base URL you entered.",
                "Create a key with access to the model id you configured."
            ]
        }
    }
}
