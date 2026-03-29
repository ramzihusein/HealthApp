import SwiftUI

enum PrivacyPolicyContent {
    /// Keep in sync with App Store Connect privacy answers. Host the same text on a public URL for the store listing if required.
    static let effectiveDate = "March 29, 2026"

    static var fullText: String { """
    Last updated: \(effectiveDate)

    This Privacy Policy describes how the HealthApp mobile application (“App”) handles information when you use it on your device.

    1. Summary
    The App is designed to help you plan training and nutrition. Most data stays on your device. If you use AI plan generation, portions of your profile and training-related text are sent over the internet to the language model provider you configure (by default an OpenAI-compatible service), as described below.

    2. Information stored on your device
    The App stores locally (using Apple’s SwiftData on your iPhone or iPad):
    • Health and fitness-related profile fields you enter (for example age, weight, height, goals, injuries or notes, equipment, training preferences).
    • Generated workout and meal plans (JSON).
    • Workout logs (strength sets, cardio completion, notes).
    • Nutrition and weight logs you enter.
    This on-device data is not transmitted to us (the developer) automatically. It remains on your device unless you use a feature that explicitly sends data to a third party (AI generation) or you export or share content yourself.

    3. AI plan generation and third-party providers
    When you generate or regenerate plans, the App may send a request to an OpenAI-compatible HTTPS API. The payload can include:
    • Profile and preference fields needed to build a plan.
    • A text summary derived from your prior workout logs (for continuation months).
    • A truncated copy of your previous workout plan JSON, when applicable.
    The remote service processes that input to return structured JSON plans. We do not control that provider’s servers; review their privacy policy (e.g. OpenAI at https://openai.com/policies/privacy-policy ) for how they handle API data.

    If no API key is configured and no built-in key is supplied in your build, the App may use offline template plans instead and avoid that network request.

    4. API keys and settings
    If you choose “Use my own API credentials,” your API key, base URL, and model id may be stored in UserDefaults on your device. They are used only to authenticate requests from the App to your chosen provider. Do not share your device or backups with untrusted parties if you store a key this way.

    5. Analytics and advertising
    The App does not include third-party analytics or advertising SDKs as part of this project. We do not sell your personal information.

    6. Children
    The App is not directed at children under 13. Do not use it for child-directed data collection.

    7. Medical disclaimer
    The App does not provide medical advice. Plans and suggestions are informational; consult a qualified professional for medical decisions.

    8. Changes
    We may update this policy. The “Last updated” date at the top will change when we do. Continued use after an update means you accept the revised policy.

    9. Contact
    For privacy questions about this App, use the support contact listed on the App Store product page (or your TestFlight invitation).
    """ }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text(PrivacyPolicyContent.fullText)
                .font(.body)
                .foregroundStyle(FocusPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(FocusScreenBackground())
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
