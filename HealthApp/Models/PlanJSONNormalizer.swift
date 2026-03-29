import Foundation

/// Coerces OpenAI-style JSON into shapes our `Codable` DTOs expect (missing keys, `NSNumber`, etc.).
enum PlanJSONNormalizer {
    static func normalizeWorkoutRoot(_ root: [String: Any]) -> [String: Any] {
        var root = root
        if root["weeks"] == nil { root["weeks"] = [] }
        guard let weeks = root["weeks"] as? [[String: Any]] else {
            root["weeks"] = []
            return root
        }
        root["weeks"] = weeks.enumerated().map { _, week in normalizeWeek(week) }
        return root
    }

    static func normalizeMealRoot(_ root: [String: Any]) -> [String: Any] {
        var root = root
        if let cal = root["targetDailyCalories"], root["targetDailyCalories"] != nil {
            root["targetDailyCalories"] = coerceToInt(cal) ?? 2000
        } else {
            root["targetDailyCalories"] = 2000
        }
        if root["days"] == nil { root["days"] = [] }
        guard let days = root["days"] as? [[String: Any]] else {
            root["days"] = []
            return root
        }
        root["days"] = days.enumerated().map { i, day in normalizeMealDay(day, fallbackIndex: i) }
        return root
    }

    // MARK: - Workout

    private static func normalizeWeek(_ week: [String: Any]) -> [String: Any] {
        var week = week
        let lab = coerceToString(week["label"]) ?? ""
        week["label"] = lab.isEmpty ? "Week 1" : lab
        if week["days"] == nil { week["days"] = [] }
        guard let days = week["days"] as? [[String: Any]] else {
            week["days"] = []
            return week
        }
        week["days"] = days.enumerated().map { i, day in normalizeWorkoutDay(day, fallbackIndex: i) }
        return week
    }

    private static func normalizeWorkoutDay(_ day: [String: Any], fallbackIndex: Int) -> [String: Any] {
        var day = day
        if let di = day["dayIndex"] {
            day["dayIndex"] = coerceToInt(di) ?? fallbackIndex
        } else {
            day["dayIndex"] = fallbackIndex
        }
        let nm = coerceToString(day["name"]) ?? ""
        day["name"] = nm.isEmpty ? "Day \(fallbackIndex + 1)" : nm
        if day["exercises"] == nil {
            day["exercises"] = []
        } else if let arr = day["exercises"] as? [[String: Any]] {
            day["exercises"] = arr.map { normalizeExercise($0) }
        } else {
            day["exercises"] = []
        }
        if let arr = day["liftingExercises"] as? [[String: Any]] {
            day["liftingExercises"] = arr.map { normalizeExercise($0) }
        } else if day["liftingExercises"] != nil {
            day["liftingExercises"] = []
        }
        if let arr = day["cardioBlocks"] as? [[String: Any]] {
            day["cardioBlocks"] = arr.map { normalizeCardioBlock($0) }
        } else if day["cardioBlocks"] != nil {
            day["cardioBlocks"] = []
        }
        if let ss = day["stretchSession"] as? [String: Any] {
            day["stretchSession"] = normalizeStretchSession(ss)
        } else if day["stretchSession"] != nil {
            day["stretchSession"] = nil
        }
        return day
    }

    private static func normalizeExercise(_ ex: [String: Any]) -> [String: Any] {
        var ex = ex
        if let idStr = coerceToString(ex["id"]), !idStr.isEmpty {
            ex["id"] = idStr
        } else {
            ex["id"] = "ex-\(UUID().uuidString.prefix(8))"
        }
        let exName = coerceToString(ex["name"]) ?? ""
        ex["name"] = exName.isEmpty ? "Exercise" : exName
        if let s = ex["sets"] {
            ex["sets"] = coerceToInt(s) ?? 3
        } else {
            ex["sets"] = 3
        }
        if let r = ex["reps"] {
            ex["reps"] = coerceToString(r) ?? "8-12"
        } else {
            ex["reps"] = "8-12"
        }
        if let rs = ex["restSec"] { ex["restSec"] = coerceToInt(rs) }
        if let n = ex["notes"] { ex["notes"] = coerceToString(n) }
        if let st = ex["steps"] {
            ex["steps"] = coerceToStringArray(st)
        }
        if let u = ex["diagramURL"] { ex["diagramURL"] = coerceToString(u) }
        if let m = ex["muscleGroupsTrained"] {
            if let arr = m as? [Any] {
                let strings = arr.compactMap { coerceToString($0) }.filter { !$0.isEmpty }
                if !strings.isEmpty { ex["muscleGroupsTrained"] = strings }
            } else if let s = coerceToString(m), !s.isEmpty {
                ex["muscleGroupsTrained"] = [s]
            }
        }
        return ex
    }

    private static func normalizeCardioBlock(_ c: [String: Any]) -> [String: Any] {
        var c = c
        if let idStr = coerceToString(c["id"]), !idStr.isEmpty {
            c["id"] = idStr
        } else {
            c["id"] = "cardio-\(UUID().uuidString.prefix(8))"
        }
        let title = coerceToString(c["title"]) ?? ""
        c["title"] = title.isEmpty ? "Cardio" : title
        let mod = coerceToString(c["modality"]) ?? ""
        c["modality"] = mod.isEmpty ? "walk" : mod
        if let d = c["durationMinutes"] {
            c["durationMinutes"] = coerceToInt(d) ?? 20
        } else {
            c["durationMinutes"] = 20
        }
        if c["targetPace"] != nil { c["targetPace"] = coerceToString(c["targetPace"]) }
        if c["intensityNote"] != nil { c["intensityNote"] = coerceToString(c["intensityNote"]) }
        if let ins = c["instructions"] {
            c["instructions"] = coerceToStringArray(ins)
        }
        return c
    }

    private static func normalizeStretchSession(_ s: [String: Any]) -> [String: Any] {
        var s = s
        if s["items"] == nil {
            s["items"] = []
        } else if let items = s["items"] as? [[String: Any]] {
            s["items"] = items.map { normalizeStretchItem($0) }
        } else {
            s["items"] = []
        }
        return s
    }

    private static func normalizeStretchItem(_ item: [String: Any]) -> [String: Any] {
        var item = item
        let stName = coerceToString(item["name"]) ?? ""
        item["name"] = stName.isEmpty ? "Stretch" : stName
        if let idStr = coerceToString(item["id"]), !idStr.isEmpty {
            item["id"] = idStr
        } else {
            item["id"] = "st-\(UUID().uuidString.prefix(8))"
        }
        if let h = item["holdSeconds"] { item["holdSeconds"] = coerceToInt(h) }
        if let st = item["steps"] {
            item["steps"] = coerceToStringArray(st)
        } else {
            item["steps"] = []
        }
        if let u = item["diagramURL"] { item["diagramURL"] = coerceToString(u) }
        return item
    }

    // MARK: - Meals

    private static func normalizeMealDay(_ day: [String: Any], fallbackIndex: Int) -> [String: Any] {
        var day = day
        if let di = day["dayIndex"] {
            day["dayIndex"] = coerceToInt(di) ?? fallbackIndex
        } else {
            day["dayIndex"] = fallbackIndex
        }
        if day["meals"] == nil {
            day["meals"] = []
        } else if let meals = day["meals"] as? [[String: Any]] {
            day["meals"] = meals.map { normalizePlannedMeal($0) }
        } else {
            day["meals"] = []
        }
        return day
    }

    private static func normalizePlannedMeal(_ m: [String: Any]) -> [String: Any] {
        var m = m
        if let idStr = coerceToString(m["id"]), !idStr.isEmpty {
            m["id"] = idStr
        } else {
            m["id"] = "meal-\(UUID().uuidString.prefix(8))"
        }
        let mealName = coerceToString(m["name"]) ?? ""
        m["name"] = mealName.isEmpty ? "Meal" : mealName
        m["description"] = coerceToString(m["description"]) ?? ""
        if let cal = m["approxCalories"] { m["approxCalories"] = coerceToInt(cal) }
        if let u = m["recipeURL"] { m["recipeURL"] = coerceToString(u) }
        return m
    }

    // MARK: - Coercion

    private static func coerceToInt(_ any: Any) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String, let i = Int(s.trimmingCharacters(in: .whitespaces)) { return i }
        return nil
    }

    private static func coerceToString(_ any: Any?) -> String? {
        guard let any else { return nil }
        if let s = any as? String { return s }
        if let n = any as? NSNumber { return n.stringValue }
        if let i = any as? Int { return String(i) }
        if let d = any as? Double {
            if d.rounded() == d { return String(Int(d)) }
            return String(d)
        }
        return String(describing: any)
    }

    private static func coerceToStringArray(_ any: Any) -> [String] {
        if let arr = any as? [String] { return arr }
        if let arr = any as? [Any] {
            return arr.compactMap { coerceToString($0) }
        }
        if let s = coerceToString(any) { return [s] }
        return []
    }
}
