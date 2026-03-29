import SwiftUI

enum ExerciseKind {
    case cardio
    case lifting

    static func classify(name: String, repsHint: String) -> ExerciseKind {
        let n = name.lowercased()
        let r = repsHint.lowercased()
        let cardioTerms = [
            "walk", "bike", "run", "jog", "row", "erg", "ski", "swim", "cycle", "cardio",
            "conditioning", "elliptic", "stair", "jump", "aerobic", "treadmill"
        ]
        if cardioTerms.contains(where: { n.contains($0) }) { return .cardio }
        if r.contains("min") || r.contains("zone") || r.contains("off") { return .cardio }
        return .lifting
    }

    var systemImage: String {
        switch self {
        case .cardio: return "figure.run"
        case .lifting: return "figure.strengthtraining.traditional"
        }
    }

    var cardBackground: Color {
        switch self {
        case .cardio: return Color(red: 0.08, green: 0.22, blue: 0.28)
        case .lifting: return Color(red: 0.18, green: 0.14, blue: 0.22)
        }
    }

    var accent: Color {
        switch self {
        case .cardio: return Color(red: 0.35, green: 0.82, blue: 0.88)
        case .lifting: return FocusPalette.accent
        }
    }
}
