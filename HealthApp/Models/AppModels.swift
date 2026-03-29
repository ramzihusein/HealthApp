import Foundation
import SwiftData

@Model
final class UserHealthProfile {
    @Attribute(.unique) var id: UUID
    var onboardingComplete: Bool

    var age: Int
    var weightKg: Double
    var heightCm: Double
    var genderRaw: String
    var activityLevelRaw: String
    var goalsCSV: String
    var injuriesNotes: String
    var dailyCookingMinutes: Int
    var weeklyMealBudget: Double
    /// Typical time available for a workout session (strength + mobility buffer).
    var workoutSessionMinutes: Int
    /// Target lifting sessions per week (planner guidance).
    var liftDaysPerWeek: Int
    /// Target cardio sessions per week.
    var cardioDaysPerWeek: Int
    /// Comma-separated equipment tags, e.g. "dumbbells,machines,treadmill"
    var equipmentCSV: String
    /// "metric" or "imperial"
    var measurementSystemRaw: String
    /// ISO currency code, e.g. USD, EUR
    var currencyCode: String

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        onboardingComplete: Bool = false,
        age: Int = 30,
        weightKg: Double = 70,
        heightCm: Double = 170,
        genderRaw: String = "prefer_not_say",
        activityLevelRaw: String = "moderate",
        goalsCSV: String = "",
        injuriesNotes: String = "",
        dailyCookingMinutes: Int = 45,
        weeklyMealBudget: Double = 100,
        workoutSessionMinutes: Int = 45,
        liftDaysPerWeek: Int = 4,
        cardioDaysPerWeek: Int = 3,
        equipmentCSV: String = "",
        measurementSystemRaw: String = "imperial",
        currencyCode: String = "USD",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.onboardingComplete = onboardingComplete
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.genderRaw = genderRaw
        self.activityLevelRaw = activityLevelRaw
        self.goalsCSV = goalsCSV
        self.injuriesNotes = injuriesNotes
        self.dailyCookingMinutes = dailyCookingMinutes
        self.weeklyMealBudget = weeklyMealBudget
        self.workoutSessionMinutes = workoutSessionMinutes
        self.liftDaysPerWeek = liftDaysPerWeek
        self.cardioDaysPerWeek = cardioDaysPerWeek
        self.equipmentCSV = equipmentCSV
        self.measurementSystemRaw = measurementSystemRaw
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var goals: [String] {
        goalsCSV.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

@Model
final class StoredGeneratedPlans {
    @Attribute(.unique) var id: UUID
    var workoutJSON: String
    var mealJSON: String
    var generatedAt: Date
    var llmModelUsed: String?

    init(
        id: UUID = UUID(),
        workoutJSON: String,
        mealJSON: String,
        generatedAt: Date = .now,
        llmModelUsed: String? = nil
    ) {
        self.id = id
        self.workoutJSON = workoutJSON
        self.mealJSON = mealJSON
        self.generatedAt = generatedAt
        self.llmModelUsed = llmModelUsed
    }
}

@Model
final class WorkoutSessionLog {
    @Attribute(.unique) var id: UUID
    var dayKey: String
    var dayDate: Date
    var exerciseId: String
    var exerciseName: String
    var sortOrder: Int
    var targetSets: Int
    var targetRepsHint: String
    @Relationship(deleteRule: .cascade, inverse: \LoggedSetEntry.session)
    var sets: [LoggedSetEntry]

    init(
        id: UUID = UUID(),
        dayKey: String,
        dayDate: Date,
        exerciseId: String,
        exerciseName: String,
        sortOrder: Int,
        targetSets: Int,
        targetRepsHint: String,
        sets: [LoggedSetEntry] = []
    ) {
        self.id = id
        self.dayKey = dayKey
        self.dayDate = dayDate
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.sortOrder = sortOrder
        self.targetSets = targetSets
        self.targetRepsHint = targetRepsHint
        self.sets = sets
    }
}

@Model
final class LoggedSetEntry {
    var setIndex: Int
    var reps: Int
    var weightKg: Double
    var session: WorkoutSessionLog?

    init(setIndex: Int, reps: Int = 0, weightKg: Double = 0, session: WorkoutSessionLog? = nil) {
        self.setIndex = setIndex
        self.reps = reps
        self.weightKg = weightKg
        self.session = session
    }
}

@Model
final class DailyNutritionLog {
    @Attribute(.unique) var dayKey: String
    var dayDate: Date
    var caloriesIn: Int
    var notes: String

    init(dayKey: String, dayDate: Date, caloriesIn: Int = 0, notes: String = "") {
        self.dayKey = dayKey
        self.dayDate = dayDate
        self.caloriesIn = caloriesIn
        self.notes = notes
    }
}

@Model
final class DailyWeightEntry {
    @Attribute(.unique) var dayKey: String
    var dayDate: Date
    var weightKg: Double

    init(dayKey: String, dayDate: Date, weightKg: Double) {
        self.dayKey = dayKey
        self.dayDate = dayDate
        self.weightKg = weightKg
    }
}
