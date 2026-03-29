import Foundation

enum MeasureConversion {
    static let lbPerKg = 2.2046226218

    static func kgToLb(_ kg: Double) -> Double { kg * lbPerKg }
    static func lbToKg(_ lb: Double) -> Double { lb / lbPerKg }

    /// Distinct calendar days with meaningful entries.
    static func distinctDaysWithCalories(_ logs: [DailyNutritionLog]) -> Int {
        Set(logs.filter { $0.caloriesIn > 0 }.map { DayKey.string(for: $0.dayDate) }).count
    }

    static func distinctDaysWithWeight(_ entries: [DailyWeightEntry]) -> Int {
        Set(entries.filter { $0.weightKg > 0 }.map { DayKey.string(for: $0.dayDate) }).count
    }

    static let minDaysForChart = 3

    static var chartWaitMessage: String {
        "Charts appear after at least \(minDaysForChart) separate days with logged data."
    }
}

enum CurrencyOption: String, CaseIterable, Identifiable {
    case USD, EUR, GBP, JPY, CNY
    var id: String { rawValue }
    var label: String {
        switch self {
        case .USD: return "USD — US dollar"
        case .EUR: return "EUR — Euro"
        case .GBP: return "GBP — British pound"
        case .JPY: return "JPY — Japanese yen"
        case .CNY: return "CNY — Chinese yuan"
        }
    }
    var symbol: String {
        switch self {
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        case .JPY: return "¥"
        case .CNY: return "¥"
        }
    }
}
