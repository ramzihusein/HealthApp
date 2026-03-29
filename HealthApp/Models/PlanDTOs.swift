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
    /// Legacy: lifting-only rows when using structured cardio/stretch fields; may still contain mixed rows in old plans.
    var exercises: [ExerciseTemplateDTO]
    /// Preferred list of strength exercises for this day (≥3 exercises and ≥12 total sets per major muscle group trained).
    var liftingExercises: [ExerciseTemplateDTO]? = nil
    var cardioBlocks: [CardioBlockDTO]? = nil
    var stretchSession: StretchSessionDTO? = nil
}

struct ExerciseTemplateDTO: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    var sets: Int
    var reps: String
    var restSec: Int?
    var notes: String?
    /// Step-by-step cues shown in the app (expandable).
    var steps: [String]? = nil
    /// HTTPS URL to an instructional image (diagram); optional.
    var diagramURL: String? = nil
    /// e.g. ["chest","shoulders"] — for plan QA / display.
    var muscleGroupsTrained: [String]? = nil
}

struct CardioBlockDTO: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var title: String
    var modality: String
    var durationMinutes: Int
    var targetPace: String?
    var intensityNote: String?
    var instructions: [String]? = nil

    static func fromLegacyExercise(_ ex: ExerciseTemplateDTO) -> CardioBlockDTO {
        CardioBlockDTO(
            id: ex.id,
            title: ex.name,
            modality: "cardio",
            durationMinutes: Self.parseDurationMinutes(from: ex.reps),
            targetPace: ex.notes,
            intensityNote: nil,
            instructions: []
        )
    }

    private static func parseDurationMinutes(from reps: String) -> Int {
        let lower = reps.lowercased()
        if let r = lower.range(of: #"\d+"#, options: .regularExpression) {
            let n = Int(lower[r]) ?? 25
            return min(180, max(5, n))
        }
        return 25
    }
}

struct StretchSessionDTO: Codable, Equatable {
    var title: String?
    var items: [StretchItemDTO]
}

struct StretchItemDTO: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    var holdSeconds: Int?
    var steps: [String]
    var diagramURL: String? = nil
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
    /// Full https URL to a recipe page (or reputable recipe search with query).
    var recipeURL: String? = nil
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
