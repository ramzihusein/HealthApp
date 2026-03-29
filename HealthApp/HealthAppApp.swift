import SwiftUI
import SwiftData

@main
struct HealthAppApp: App {
    private static let appSchema = Schema([
        UserHealthProfile.self,
        StoredGeneratedPlans.self,
        WorkoutSessionLog.self,
        LoggedSetEntry.self,
        DailyNutritionLog.self,
        DailyWeightEntry.self
    ])

    /// Creates the container; if the on-disk store is incompatible (e.g. after a model change), deletes it once and retries.
    private static func makeModelContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: appSchema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: appSchema, configurations: [config])
        } catch {
            NSLog("HealthApp: SwiftData failed to open store (\(error)). Clearing local database and retrying once.")
            Self.removeSwiftDataStoreFiles(for: config)
            do {
                return try ModelContainer(for: appSchema, configurations: [config])
            } catch {
                fatalError("HealthApp: SwiftData still failed after reset. Try deleting the app and reinstalling. Underlying error: \(error)")
            }
        }
    }

    private static func removeSwiftDataStoreFiles(for configuration: ModelConfiguration) {
        let fm = FileManager.default
        let root = configuration.url
        try? fm.removeItem(at: root)
        let basePath = root.path
        for suffix in ["-shm", "-wal"] {
            let path = basePath + suffix
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
    }

    var sharedModelContainer: ModelContainer = { HealthAppApp.makeModelContainer() }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
