import Foundation

/// Generates structured workout + meal JSON. Uses OpenAI-compatible HTTP API when `OPENAI_API_KEY` is set in Info.plist (or `HealthAppOpenAIKey`); otherwise uses a deterministic mock plan aligned to profile goals.
enum PlanGenerationService {
    enum GenerationError: LocalizedError {
        case missingAPIKey
        /// Optional message from JSON body (e.g. OpenAI `error.message`) to distinguish quota vs RPM limits.
        case rateLimited(providerDetail: String?)
        case badResponse(Int)
        case emptyChoices
        case invalidJSON
        /// Model JSON did not match the app schema after normalization (details for debugging).
        case planDecodeFailed(String)
        /// Client-side wait exceeded (URLSession) or repeated timeouts.
        case requestTimedOut
        case network(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "No API key configured."
            case .rateLimited(let detail):
                let tail = "Wait several minutes, avoid tapping Regenerate many times in a row, and check your provider's dashboard for usage, rate limits, and billing."
                if let d = detail?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
                    return "\(d)\n\n\(tail)"
                }
                return "Rate or usage limit exceeded (HTTP 429). \(tail)"
            case .badResponse(let c): return "API returned status \(c)."
            case .emptyChoices: return "No completion text from model."
            case .invalidJSON: return "Model output was not valid JSON."
            case .planDecodeFailed(let detail):
                return "The plan data could not be read (\(detail)). Try generating again, or use a different model."
            case .requestTimedOut:
                return "The request timed out before the model finished. Your plan JSON is large, so the API can take 1-3+ minutes. Try again on Wi-Fi, wait, or clear the API key to use the built-in offline plan while you troubleshoot."
            case .network(let msg):
                return "Network error: \(msg)"
            }
        }
    }

    private static let maxLLMHTTPAttempts = 4

    /// Longer timeouts than `URLSession.shared` (default ~60s), plus room for big JSON completions.
    private static let llmURLSession: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 240
        c.timeoutIntervalForResource = 900
        c.waitsForConnectivity = true
        return URLSession(configuration: c)
    }()

    private static let llmNetworkRetries = 3

    /// Parses `Retry-After` when the server sends delay in seconds (common for 429).
    private static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        guard let secs = TimeInterval(raw), secs >= 0 else { return nil }
        return min(secs, 120)
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
        You are a certified strength & conditioning and nutrition planning assistant. Output ONLY valid JSON with top-level keys "workoutPlan" and "mealPlan" (camelCase).

        WORKOUT STRUCTURE (critical):
        - Use a sensible split (push/pull/legs, upper/lower, or bro split). Muscle groups trained the same day must make sense together.
        - For EACH major muscle group trained that day: at least 3 distinct exercises AND at least 12 total working sets for that group (e.g. 4+4+4).
        - Separate STRENGTH from CARDIO in the JSON: put all resistance exercises in "liftingExercises" (array). Put cardio in "cardioBlocks" (array), NOT mixed into lifting.
        - Every day object MUST include "exercises" as an array (use [] if empty). Omitting it breaks parsing.
        - Each lifting exercise: { id, name, sets, reps, restSec?, notes?, steps?: string[] (3-6 short cues), diagramURL?: string (https to a real instructional image if possible), muscleGroupsTrained?: string[] }.
        - Each cardioBlock: { id, title, modality (walk|jog|run|bike|row|swim|elliptical|incline_walk only — NEVER yoga), durationMinutes, targetPace (e.g. mph, min/mile, or conversational), intensityNote?, instructions?: string[] }.
        - Do NOT prescribe yoga as cardio. Stretching belongs in "stretchSession": { title?, items: [{ id, name, holdSeconds?, steps: string[], diagramURL? }] }.
        - Respect equipmentAvailable; avoid machines the user does not have.

        workoutPlan: { programNotes?: string, weeks: [{ label: string, days: [{ dayIndex: 0-6 Mon-Sun, name: string, exercises: ExerciseTemplateDTO[], liftingExercises?: ExerciseTemplateDTO[], cardioBlocks?: CardioBlockDTO[], stretchSession?: StretchSessionDTO }] }] }

        mealPlan: { targetDailyCalories: number, notes?: string, days: [{ dayIndex: number, meals: [{ id, name, description, approxCalories?: number, recipeURL: string (required https link to a real recipe page or reputable recipe search URL) }] }] }

        Align lift days and cardio days with the user's targets. Keep meals realistic for their cooking time and budget.
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
            "currencyCode": profile.currencyCode,
            "workoutSessionMinutes": profile.workoutSessionMinutes,
            "liftDaysPerWeek": profile.liftDaysPerWeek,
            "cardioDaysPerWeek": profile.cardioDaysPerWeek,
            "equipmentAvailable": profile.equipmentCSV.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        ]
        let user = (try? JSONSerialization.data(withJSONObject: userPayload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let url = URL(string: "\(openAIBaseURL)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 0
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

        var rateLimitAttempt = 0
        while true {
            let (data, http) = try await sendChatCompletionWithRetries(req)

            if (200...299).contains(http.statusCode) {
                return try parseChatCompletionJSON(data: data)
            }

            if http.statusCode == 429, rateLimitAttempt + 1 < maxLLMHTTPAttempts {
                let delay = retryAfterSeconds(from: http) ?? min(Double(1 << rateLimitAttempt), 30)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                rateLimitAttempt += 1
                continue
            }

            if http.statusCode == 429 {
                throw GenerationError.rateLimited(providerDetail: Self.providerErrorMessage(from: data))
            }
            throw GenerationError.badResponse(http.statusCode)
        }
    }

    /// Performs the HTTP call with a patient URLSession and a few retries on timeout / dropped connection.
    private static func sendChatCompletionWithRetries(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let retryCodes: Set<URLError.Code> = [.timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet]
        for networkAttempt in 0..<llmNetworkRetries {
            do {
                let (data, resp) = try await llmURLSession.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw GenerationError.badResponse(-1) }
                return (data, http)
            } catch let urlError as URLError {
                if retryCodes.contains(urlError.code), networkAttempt + 1 < llmNetworkRetries {
                    let backoff = 3.0 * Double(networkAttempt + 1)
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                    continue
                }
                if urlError.code == .timedOut {
                    throw GenerationError.requestTimedOut
                }
                throw GenerationError.network(urlError.localizedDescription)
            } catch {
                throw GenerationError.network(error.localizedDescription)
            }
        }
        throw GenerationError.requestTimedOut
    }

    private static func parseChatCompletionJSON(data: Data) throws -> (String, String) {
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

        guard let workoutAny = obj["workoutPlan"] ?? obj["workout"] else {
            throw GenerationError.invalidJSON
        }
        guard let mealAny = obj["mealPlan"] ?? obj["meal"] else {
            throw GenerationError.invalidJSON
        }
        guard let workoutDict = workoutAny as? [String: Any] else {
            throw GenerationError.invalidJSON
        }
        guard let mealDict = mealAny as? [String: Any] else {
            throw GenerationError.invalidJSON
        }

        let normalizedWorkout = PlanJSONNormalizer.normalizeWorkoutRoot(workoutDict)
        let normalizedMeal = PlanJSONNormalizer.normalizeMealRoot(mealDict)

        let wpData = try JSONSerialization.data(withJSONObject: normalizedWorkout, options: [])
        let mpData = try JSONSerialization.data(withJSONObject: normalizedMeal, options: [])

        do {
            _ = try PlanCodec.jsonDecoder.decode(WorkoutPlanDTO.self, from: wpData)
            _ = try PlanCodec.jsonDecoder.decode(MealPlanDTO.self, from: mpData)
        } catch {
            let detail: String
            if let de = error as? DecodingError {
                detail = Self.decodingErrorSummary(de)
            } else {
                detail = error.localizedDescription
            }
            throw GenerationError.planDecodeFailed(detail)
        }

        let wStr = String(data: wpData, encoding: .utf8) ?? ""
        let mStr = String(data: mpData, encoding: .utf8) ?? ""
        return (wStr, mStr)
    }

    private static func decodingErrorSummary(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let ctx):
            return "missing field \"\(key.stringValue)\" \(ctx.debugDescription)"
        case .typeMismatch(let type, let ctx):
            return "wrong type for \(type) \(ctx.debugDescription)"
        case .valueNotFound(let type, let ctx):
            return "missing \(type) \(ctx.debugDescription)"
        case .dataCorrupted(let ctx):
            return ctx.debugDescription
        @unknown default:
            return String(describing: error)
        }
    }

    /// OpenAI-compatible `{ "error": { "message": "..." } }` and similar.
    private static func providerErrorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = obj["error"] as? [String: Any] {
            if let msg = err["message"] as? String, !msg.isEmpty { return msg }
            if let typ = err["type"] as? String, !typ.isEmpty { return typ }
        }
        return nil
    }
}
