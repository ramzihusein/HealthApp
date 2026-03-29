import Foundation
import SwiftData

/// Clears SwiftData and app UserDefaults so the simulator behaves like a fresh install. DEBUG builds only; Release is a no-op.
enum DebugLocalDataReset {
    static func wipeAllLocalData(modelContext: ModelContext) throws {
        #if DEBUG
        let plans = try modelContext.fetch(FetchDescriptor<StoredGeneratedPlans>())
        plans.forEach { modelContext.delete($0) }

        let sessions = try modelContext.fetch(FetchDescriptor<WorkoutSessionLog>())
        sessions.forEach { modelContext.delete($0) }

        let nutrition = try modelContext.fetch(FetchDescriptor<DailyNutritionLog>())
        nutrition.forEach { modelContext.delete($0) }

        let weights = try modelContext.fetch(FetchDescriptor<DailyWeightEntry>())
        weights.forEach { modelContext.delete($0) }

        let profiles = try modelContext.fetch(FetchDescriptor<UserHealthProfile>())
        profiles.forEach { modelContext.delete($0) }

        clearAppUserDefaults()
        UserAccountService.clearStableUserIdForDebug()

        let fresh = UserHealthProfile()
        modelContext.insert(fresh)
        try modelContext.save()
        #else
        _ = modelContext
        #endif
    }

    #if DEBUG
    private static func clearAppUserDefaults() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: AppConfig.openAIKeyUserDefaultsKey)
        ud.removeObject(forKey: AppConfig.openAIBaseURLKey)
        ud.removeObject(forKey: AppConfig.openAIModelKey)
        ud.removeObject(forKey: AppConfig.llmProviderRawKey)
    }
    #endif
}
