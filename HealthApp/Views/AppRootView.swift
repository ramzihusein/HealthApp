import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserHealthProfile]

    private var profile: UserHealthProfile? { profiles.first }

    var body: some View {
        ZStack {
            FocusScreenBackground()
            Group {
                if let p = profile, p.onboardingComplete {
                    MainTabView()
                } else {
                    OnboardingFlowView(existingProfile: profile)
                }
            }
        }
        .tint(FocusPalette.accent)
        .onAppear {
            if profiles.isEmpty {
                let p = UserHealthProfile()
                modelContext.insert(p)
                try? modelContext.save()
            }
        }
    }
}
