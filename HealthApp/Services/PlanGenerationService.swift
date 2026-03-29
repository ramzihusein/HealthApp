import Foundation

/// Generates structured workout + meal JSON. Uses OpenAI-compatible HTTP API when `OPENAI_API_KEY` is set in Info.plist (or `HealthAppOpenAIKey`); otherwise uses a deterministic mock plan aligned to profile goals.
enum PlanGenerationService {
    enum GenerationError: LocalizedError {
        case missingAPIKey
        case badResponse(Int)
        case emptyChoices
        case invalidJSON

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "No API key configured."
            case .badResponse(let c): return "API returned status \(c)."
            case .emptyChoices: return "No completion text from model."
            case .invalidJSON: return "Model output was not valid JSON."
            }
        }
    }

    private static var openAIKey: String? {
        let ud = UserDefaults.standard
        if let s = ud.string(forKey: AppConfig.openAIKeyUserDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        if let s = Bundle.main.object(forInfoDictionaryKey: "HealthAppOpenAIKey") as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return s
        }
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }

    private static var openAIBaseURL: String {
        let ud = UserDefaults.standard
        if let s = ud.string(forKey: AppConfig.openAIBaseURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        return (Bundle.main.object(forInfoDictionaryKey: "HealthAppOpenAIBaseURL") as? String)
            ?? "https://api.openai.com/v1"
    }

    private static var openAIModel: String {
        let ud = UserDefaults.standard
        if let s = ud.string(forKey: AppConfig.openAIModelKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        return (Bundle.main.object(forInfoDictionaryKey: "HealthAppOpenAIModel") as? String)
            ?? "gpt-4o-mini"
    }

    static func generatePlans(for profile: UserHealthProfile) async throws -> (workoutJSON: String, mealJSON: String, model: String?) {
        if let key = openAIKey, !key.isEmpty {
            let (w, m) = try await generateViaLLM(profile: profile, apiKey: key)
            return (w, m, openAIModel)
        }
        let mock = MockPlanBuilder.build(for: profile)
        let wData = try PlanCodec.jsonEncoder.encode(mock.workout)
        let mData = try PlanCodec.jsonEncoder.encode(mock.meal)
        let w = String(data: wData, encoding: .utf8) ?? ""
        let m = String(data: mData, encoding: .utf8) ?? ""
        return (w, m, nil)
    }

    private static func generateViaLLM(profile: UserHealthProfile, apiKey: String) async throws -> (String, String) {
        let system = """
        You are a certified strength & conditioning and nutrition planning assistant. You synthesize evidence-based guidance. \
        Output ONLY valid JSON with two top-level keys: "workoutPlan" and "mealPlan", matching these TypeScript shapes exactly (camelCase keys):

        workoutPlan: { programNotes?: string, weeks: { label: string, days: { dayIndex: number (0=Mon..6=Sun), name: string, exercises: { id: string, name: string, sets: number, reps: string, restSec?: number, notes?: string }[] }[] }[] }

        mealPlan: { targetDailyCalories: number, notes?: string, days: { dayIndex: number, meals: { id: string, name: string, description: string, approxCalories?: number }[] }[] }

        Respect injuries (avoid aggravating movements), time for cooking, weekly food budget, activity level, and stated goals. \
        Keep exercise names practical for a typical gym or home setup.
        """

        let userPayload: [String: Any] = [
            "stableUserId": UserAccountService.stableUserId.uuidString,
            "age": profile.age,
            "weightKg": profile.weightKg,
            "heightCm": profile.heightCm,
            "gender": profile.genderRaw,
            "activityLevel": profile.activityLevelRaw,
            "goals": profile.goals,
            "injuriesNotes": profile.injuriesNotes,
            "dailyCookingMinutes": profile.dailyCookingMinutes,
            "weeklyMealBudget": profile.weeklyMealBudget,
            "currencyCode": profile.currencyCode
        ]
        let user = (try? JSONSerialization.data(withJSONObject: userPayload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let url = URL(string: "\(openAIBaseURL)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": openAIModel,
            "temperature": 0.35,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GenerationError.badResponse(-1) }
        guard (200...299).contains(http.statusCode) else { throw GenerationError.badResponse(http.statusCode) }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let text = message["content"] as? String
        else { throw GenerationError.emptyChoices }

        guard let outer = text.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: outer) as? [String: Any]
        else { throw GenerationError.invalidJSON }

        guard let workoutPayload = obj["workoutPlan"] ?? obj["workout"] else {
            throw GenerationError.invalidJSON
        }
        guard let mealPayload = obj["mealPlan"] ?? obj["meal"] else {
            throw GenerationError.invalidJSON
        }
        let wpData = try JSONSerialization.data(withJSONObject: workoutPayload)
        let mpData = try JSONSerialization.data(withJSONObject: mealPayload)

        _ = try PlanCodec.jsonDecoder.decode(WorkoutPlanDTO.self, from: wpData)
        _ = try PlanCodec.jsonDecoder.decode(MealPlanDTO.self, from: mpData)

        let wStr = String(data: wpData, encoding: .utf8) ?? ""
        let mStr = String(data: mpData, encoding: .utf8) ?? ""
        return (wStr, mStr)
    }
}

private enum MockPlanBuilder {
    static func build(for profile: UserHealthProfile) -> (workout: WorkoutPlanDTO, meal: MealPlanDTO) {
        let goals = profile.goals.map { $0.lowercased() }
        let lose = goals.contains { $0.contains("lose") || $0.contains("fat") }
        let gain = goals.contains { $0.contains("gain") || $0.contains("muscle") }
        let flex = goals.contains { $0.contains("flex") }

        var dayNames = ["Push / legs", "Pull / core", "Full body", "Active recovery", "Strength", "Conditioning", "Rest or walk"]
        if flex { dayNames[3] = "Mobility & stretch" }

        let exercises: [[ExerciseTemplateDTO]] = [
            [
                .init(id: "sq1", name: "Goblet squat", sets: 3, reps: "10-12", restSec: 90, notes: nil),
                .init(id: "bp1", name: "DB bench press", sets: 3, reps: "8-10", restSec: 90, notes: nil),
                .init(id: "rw1", name: "One-arm row", sets: 3, reps: "10 each", restSec: 75, notes: nil)
            ],
            [
                .init(id: "dl1", name: "Romanian deadlift", sets: 3, reps: "8-10", restSec: 120, notes: nil),
                .init(id: "pu1", name: "Lat pulldown or band pull-down", sets: 3, reps: "10-12", restSec: 75, notes: nil),
                .init(id: "cu1", name: "Bicep curl", sets: 2, reps: "12-15", restSec: 60, notes: nil)
            ],
            [
                .init(id: "lj1", name: "Split squat", sets: 3, reps: "10 each", restSec: 90, notes: nil),
                .init(id: "oh1", name: "Overhead press", sets: 3, reps: "8-10", restSec: 90, notes: nil),
                .init(id: "pl1", name: "Plank", sets: 3, reps: "45-60s", restSec: 60, notes: "Brace; stop if back pain")
            ],
            [
                .init(id: "wk1", name: "Easy walk or bike", sets: 1, reps: "25-40 min", restSec: nil, notes: "Zone 2 pace")
            ],
            [
                .init(id: "sq2", name: "Back squat or leg press", sets: 4, reps: "6-8", restSec: 150, notes: profile.injuriesNotes.isEmpty ? nil : "Adjust depth per comfort")
            ],
            [
                .init(id: "br1", name: "Row erg or ski", sets: 5, reps: "3 min on / 1 off", restSec: nil, notes: "Moderate effort")
            ],
            []
        ]

        let days: [WorkoutDayDTO] = (0..<7).map { i in
            let ex = i < exercises.count ? exercises[i] : []
            return WorkoutDayDTO(dayIndex: i, name: dayNames[i], exercises: ex)
        }

        let week = WorkoutWeekDTO(label: "Week 1 — baseline", days: days)
        let workout = WorkoutPlanDTO(
            programNotes: buildWorkoutNotes(lose: lose, gain: gain, flex: flex, injuries: profile.injuriesNotes),
            weeks: [week]
        )

        let bmrApprox = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) + 5
        let activityMult: Double = switch profile.activityLevelRaw {
        case "sedentary": 1.2
        case "light": 1.35
        case "moderate": 1.5
        case "active": 1.7
        case "very_active": 1.9
        default: 1.45
        }
        var tdee = Int(bmrApprox * activityMult)
        if lose { tdee = max(1400, tdee - 450) }
        if gain { tdee += 350 }
        tdee = max(1200, min(4500, tdee))

        let mealDays: [MealDayDTO] = (0..<7).map { i in
            let isRest = i == 6
            let c1 = isRest ? max(tdee / 4, 300) : max(tdee / 3, 350)
            let meals: [PlannedMealDTO] = [
                .init(id: "m\(i)a", name: "Breakfast", description: "Greek yogurt, oats, berries; or eggs + whole grain toast", approxCalories: c1),
                .init(id: "m\(i)b", name: "Lunch", description: "Lean protein + mixed vegetables + starch (rice/potato)", approxCalories: c1),
                .init(id: "m\(i)c", name: "Dinner", description: "Fish/chicken/tofu + salad + olive oil", approxCalories: max(tdee - 2 * c1, 300))
            ]
            return MealDayDTO(dayIndex: i, meals: meals)
        }

        let meal = MealPlanDTO(
            targetDailyCalories: tdee,
            notes: buildMealNotes(
                budget: profile.weeklyMealBudget,
                cookMins: profile.dailyCookingMinutes,
                currencyCode: profile.currencyCode
            ),
            days: mealDays
        )

        return (workout, meal)
    }

    private static func buildWorkoutNotes(lose: Bool, gain: Bool, flex: Bool, injuries: String) -> String {
        var parts: [String] = []
        if lose { parts.append("Prioritize progressive overload with 2-3 full-body or upper/lower splits; add easy cardio.") }
        if gain { parts.append("Emphasize compound lifts, adequate volume, and recovery between hard days.") }
        if flex { parts.append("Include mobility finishers on recovery days.") }
        if !injuries.isEmpty { parts.append("Modify any movement that aggravates: \(injuries)") }
        return parts.joined(separator: " ")
    }

    private static func buildMealNotes(budget: Double, cookMins: Int, currencyCode: String) -> String {
        let sym = CurrencyOption(rawValue: currencyCode)?.symbol ?? currencyCode + " "
        return "Designed for roughly \(cookMins) minutes/day cooking and a weekly grocery budget near \(sym)\(Int(budget)). Adjust portions to hunger and energy."
    }
}
