import Foundation

// MARK: - Workout plan (LLM + mock)

struct WorkoutPlanDTO: Codable, Equatable {
    var programNotes: String?
    var weeks: [WorkoutWeekDTO]
}

struct WorkoutWeekDTO: Codable, Equatable {
    var label: String
    var days: [WorkoutDayDTO]
}

struct WorkoutDayDTO: Codable, Equatable, Identifiable {
    var id: String { "\(dayIndex)-\(name)" }
    var dayIndex: Int
    var name: String
    var exercises: [ExerciseTemplateDTO]
}

struct ExerciseTemplateDTO: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var sets: Int
    var reps: String
    var restSec: Int?
    var notes: String?
}

// MARK: - Meal plan

struct MealPlanDTO: Codable, Equatable {
    var targetDailyCalories: Int
    var notes: String?
    var days: [MealDayDTO]
}

struct MealDayDTO: Codable, Equatable, Identifiable {
    var id: String { "\(dayIndex)" }
    var dayIndex: Int
    var meals: [PlannedMealDTO]
}

struct PlannedMealDTO: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var description: String
    var approxCalories: Int?
}

enum PlanCodec {
    static let jsonDecoder: JSONDecoder = JSONDecoder()
    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static func decodeWorkout(from json: String) throws -> WorkoutPlanDTO {
        guard let data = json.data(using: .utf8) else {
            throw PlanDecodeError.invalidUTF8
        }
        return try jsonDecoder.decode(WorkoutPlanDTO.self, from: data)
    }

    static func decodeMeal(from json: String) throws -> MealPlanDTO {
        guard let data = json.data(using: .utf8) else {
            throw PlanDecodeError.invalidUTF8
        }
        return try jsonDecoder.decode(MealPlanDTO.self, from: data)
    }
}

enum PlanDecodeError: Error {
    case invalidUTF8
}
