import SwiftUI
import SwiftData

@main
struct HealthAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserHealthProfile.self,
            StoredGeneratedPlans.self,
            WorkoutSessionLog.self,
            LoggedSetEntry.self,
            DailyNutritionLog.self,
            DailyWeightEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
