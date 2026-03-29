import SwiftUI

enum ExerciseKind {
    case lifting
    case cardio
    case mobility

    static func classify(name: String, repsHint: String) -> ExerciseKind {
        let n = name.lowercased()
        let r = repsHint.lowercased()
        let mobilityTerms = [
            "stretch", "mobility", "foam roll", "yoga", "pigeon", "hip flexor", "cat cow", "child pose",
            "hamstring stretch", "shoulder dislocat", "band pull apart warm"
        ]
        if mobilityTerms.contains(where: { n.contains($0) }) { return .mobility }
        let cardioTerms = [
            "walk", "bike", "run", "jog", "row", "erg", "ski", "swim", "cycle", "cardio",
            "conditioning", "elliptic", "stair", "jump", "aerobic", "treadmill", "incline walk"
        ]
        if cardioTerms.contains(where: { n.contains($0) }) { return .cardio }
        if r.contains("min") || r.contains("zone") || r.contains("off") { return .cardio }
        return .lifting
    }

    var systemImage: String {
        switch self {
        case .cardio: return "figure.run"
        case .lifting: return "figure.strengthtraining.traditional"
        case .mobility: return "figure.flexibility"
        }
    }

    var cardBackground: Color {
        switch self {
        case .cardio: return Color(red: 0.08, green: 0.22, blue: 0.28)
        case .lifting: return Color(red: 0.18, green: 0.14, blue: 0.22)
        case .mobility: return Color(red: 0.1, green: 0.2, blue: 0.14)
        }
    }

    var accent: Color {
        switch self {
        case .cardio: return Color(red: 0.35, green: 0.82, blue: 0.88)
        case .lifting: return FocusPalette.accent
        case .mobility: return Color(red: 0.55, green: 0.9, blue: 0.55)
        }
    }
}

extension WorkoutDayDTO {
    func liftingExercisesResolved() -> [ExerciseTemplateDTO] {
        if let l = liftingExercises, !l.isEmpty { return l }
        return exercises.filter { ExerciseKind.classify(name: $0.name, repsHint: $0.reps) == .lifting }
    }

    func cardioBlocksResolved() -> [CardioBlockDTO] {
        if let c = cardioBlocks, !c.isEmpty { return c }
        return exercises.compactMap { ex -> CardioBlockDTO? in
            guard ExerciseKind.classify(name: ex.name, repsHint: ex.reps) == .cardio else { return nil }
            return CardioBlockDTO.fromLegacyExercise(ex)
        }
    }

    func mobilityExercisesLegacy() -> [ExerciseTemplateDTO] {
        exercises.filter { ExerciseKind.classify(name: $0.name, repsHint: $0.reps) == .mobility }
    }

    var hasPlannedWork: Bool {
        !liftingExercisesResolved().isEmpty
            || !cardioBlocksResolved().isEmpty
            || !(stretchSession?.items.isEmpty ?? true)
            || !mobilityExercisesLegacy().isEmpty
    }
}
