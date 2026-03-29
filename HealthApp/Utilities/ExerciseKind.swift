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
        if isLikelyStrengthRowExercise(name: n) { return .lifting }
        if n.contains("jump") {
            let jumpLiftHints = ["squat", "lunge", "split", "deadlift", "good morning", "good-morning", "tuck jump"]
            if jumpLiftHints.contains(where: { n.contains($0) }) { return .lifting }
        }
        // Avoid bare "row" — it matches dumbbell/barbell/cable rows (handled above).
        let cardioTerms = [
            "walk", "bike", "run", "jog", "rowing", "rower", " erg", "ergometer", "ski erg", "ski-erg",
            "concept2", "c2 bike", "air bike", "assault bike",
            "ski", "swim", "cycle", "cardio", "conditioning", "elliptic", "stair", "aerobic", "treadmill",
            "incline walk", "steady state", "hiit", "amrap", "jump rope", "jumping jack", "burpee"
        ]
        if cardioTerms.contains(where: { n.contains($0) }) { return .cardio }
        if n.hasSuffix(" row") || n.contains(" row ") { return .lifting }
        if r.contains("min") || r.contains("zone") || r.contains("rpm") || r.contains("off") { return .cardio }
        return .lifting
    }

    /// "Row" as a substring matches many back exercises; only treat as cardio when it's clearly machine/erg cardio.
    private static func isLikelyStrengthRowExercise(name: String) -> Bool {
        let n = name.lowercased()
        guard n.contains("row") else { return false }
        let liftHints = [
            "dumbbell", "barbell", "cable", "seated", "bent", "bent-over", "bent over", "t-bar", "t bar",
            "pendlay", "inverted", "machine", "landmine", "single-arm", "single arm", "one-arm", "one arm",
            "chest-supported", "chest supported", "meadows", "renegade", "trx", "high row", "low row",
            "iso row", "hammer strength", "chest supported"
        ]
        return liftHints.contains { n.contains($0) }
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
    /// Strength lifts only (excludes cardio mis-tagged inside `liftingExercises`).
    func liftingExercisesResolved() -> [ExerciseTemplateDTO] {
        if let lifts = liftingExercises, !lifts.isEmpty {
            return lifts.filter { ExerciseKind.classify(name: $0.name, repsHint: $0.reps) == .lifting }
        }
        return exercises.filter { ExerciseKind.classify(name: $0.name, repsHint: $0.reps) == .lifting }
    }

    /// Explicit cardio blocks plus any cardio-like rows the model put under `liftingExercises` or legacy `exercises`.
    func cardioBlocksResolved() -> [CardioBlockDTO] {
        var blocks: [CardioBlockDTO] = []
        if let c = cardioBlocks, !c.isEmpty {
            blocks.append(contentsOf: c)
        }
        if let lifts = liftingExercises {
            for ex in lifts where ExerciseKind.classify(name: ex.name, repsHint: ex.reps) == .cardio {
                blocks.append(CardioBlockDTO.fromLegacyExercise(ex))
            }
        }
        if blocks.isEmpty {
            blocks = exercises.compactMap { ex -> CardioBlockDTO? in
                guard ExerciseKind.classify(name: ex.name, repsHint: ex.reps) == .cardio else { return nil }
                return CardioBlockDTO.fromLegacyExercise(ex)
            }
        }
        return blocks
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
