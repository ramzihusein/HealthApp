import SwiftUI

/// Expandable help for users unsure where to obtain an API key for the selected provider.
struct LLMApiKeyHelpDisclosure: View {
    let provider: OnboardingLLMProvider
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(provider.apiKeyHelpBullets.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(FocusPalette.textSecondary)
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(FocusPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let url = provider.apiKeyPortalURL {
                    Link(destination: url) {
                        Label("Open keys page in browser", systemImage: "arrow.up.right.square")
                            .font(.footnote.weight(.semibold))
                    }
                    .tint(FocusPalette.accent)
                }

                Text("Never share your key or check it into Git. You can rotate keys anytime in the provider’s dashboard.")
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(FocusPalette.accent)
                Text("Where do I get an API key?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textPrimary)
            }
        }
        .tint(FocusPalette.accent)
    }
}
