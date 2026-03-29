import Foundation
import SwiftData

/// Opens SwiftData on launch. On failure (e.g. incompatible schema after an app update), exposes recovery instead of silently wiping data.
@MainActor
final class PersistentStoreLauncher: ObservableObject {
    enum Phase {
        case ready(ModelContainer)
        case needsRecovery(Error)
    }

    @Published private(set) var phase: Phase

    private static let appSchema = Schema([
        UserHealthProfile.self,
        StoredGeneratedPlans.self,
        WorkoutSessionLog.self,
        LoggedSetEntry.self,
        CardioSessionLog.self,
        DailyNutritionLog.self,
        DailyWeightEntry.self
    ])

    init() {
        let config = ModelConfiguration(schema: Self.appSchema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: Self.appSchema, configurations: [config])
            phase = .ready(container)
        } catch {
            NSLog("HealthApp: SwiftData failed to open store (\(error)). User can erase local data to continue.")
            phase = .needsRecovery(error)
        }
    }

    /// Deletes on-disk store files and attempts to create a fresh container. Call only after explicit user consent.
    func eraseStoreAndRecreate() {
        let config = ModelConfiguration(schema: Self.appSchema, isStoredInMemoryOnly: false)
        Self.removeSwiftDataStoreFiles(for: config)
        do {
            let container = try ModelContainer(for: Self.appSchema, configurations: [config])
            phase = .ready(container)
        } catch {
            NSLog("HealthApp: SwiftData still failed after user-approved reset (\(error)).")
            phase = .needsRecovery(error)
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
}
