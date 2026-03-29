import Foundation

/// Generates structured workout + meal JSON. Uses OpenAI-compatible HTTP API when a key is available (Settings override, embedded Info.plist value from build settings, or `OPENAI_API_KEY` env); otherwise uses a deterministic mock plan.
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
                return "The request timed out before the model finished. Your plan JSON is large, so the API can take 1-3+ minutes. Try again on Wi-Fi or wait; without a working key the app falls back to offline mock plans."
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

    private static var openAIKey: String? { LLMCredentialStore.resolvedOpenAIKey() }

    private static var openAIBaseURL: String { LLMCredentialStore.resolvedBaseURL() }

    private static var openAIModel: String { LLMCredentialStore.resolvedModel() }

    static func generatePlans(
        for profile: UserHealthProfile,
        planMonthSequence: Int = 1,
        priorMonthSummaryForLLM: String = "",
        priorLiftMaxKgByExerciseName: [String: Double] = [:],
        priorWorkoutPlanJSON: String? = nil
    ) async throws -> (workoutJSON: String, mealJSON: String, model: String?) {
        if let key = openAIKey, !key.isEmpty {
            let (w, m) = try await generateViaLLM(
                profile: profile,
                apiKey: key,
                planMonthSequence: planMonthSequence,
                priorMonthSummaryForLLM: priorMonthSummaryForLLM,
                priorWorkoutPlanJSON: priorWorkoutPlanJSON
            )
            return (w, m, openAIModel)
        }
        let mock = MockPlanBuilder.build(
            for: profile,
            planMonthSequence: planMonthSequence,
            priorLiftMaxKgByExerciseName: priorLiftMaxKgByExerciseName,
            priorWorkoutPlanJSON: priorWorkoutPlanJSON
        )
        let wData = try PlanCodec.jsonEncoder.encode(mock.workout)
        let mData = try PlanCodec.jsonEncoder.encode(mock.meal)
        let w = String(data: wData, encoding: .utf8) ?? ""
        let m = String(data: mData, encoding: .utf8) ?? ""
        return (w, m, nil)
    }

    private static func monthlyPlanningInstructions(planMonthSequence: Int) -> String {
        if planMonthSequence <= 1 {
            return """

            MONTHLY PLAN (first calendar month):
            - Include about 4–5 weeks in "weeks".
            - Omit suggestedWeightKg on lifting exercises (or null). The user establishes baseline loads by logging.
            - In programNotes, state clearly that month 1 is for accurate logging so the next month can auto-suggest weights and cardio targets from real data.
            - Prefer days that combine liftingExercises with cardioBlocks when that matches weekly lift/cardio targets (same-day strength + conditioning is expected, not exceptional).
            """
        }
        return """

        MONTHLY PLAN (continuation — month index \(planMonthSequence)):
        - Include about 4–5 weeks for the next training month.
        - Read priorMonthPerformanceSummary and priorWorkoutPlanJSON. Progress strength using conservative overload from logged maxes (common practice often uses roughly ~2–3% monthly for upper-body work and ~5–10% for lower-body when prior reps were completed with good form; choose smaller steps when unsure).
        - For EVERY lifting exercise set "suggestedWeightKg" (number, kilograms) for the first working sets; the user can override in the app.
        - Progress cardio in cardioBlocks vs the prior month when adherence was good (~5–10% more duration or a slightly faster easy pace); encode targets in durationMinutes and targetPace.
        - Keep combining lifting and cardio on the same day where appropriate; progression applies to cardioBlocks whether they sit on lift days or cardio-only days.
        """
    }

    private static func generateViaLLM(
        profile: UserHealthProfile,
        apiKey: String,
        planMonthSequence: Int,
        priorMonthSummaryForLLM: String,
        priorWorkoutPlanJSON: String?
    ) async throws -> (String, String) {
        let systemBase = """
        You are a certified strength & conditioning and nutrition planning assistant. Output ONLY valid JSON with top-level keys "workoutPlan" and "mealPlan" (camelCase).

        WORKOUT STRUCTURE (critical):
        - Use a sensible split (push/pull/legs, upper/lower, or bro split). Muscle groups trained the same day must make sense together.
        - For EACH major muscle group trained that day: at least 3 distinct exercises AND at least 12 total working sets for that group (e.g. 4+4+4).
        - Separate STRENGTH from CARDIO in the JSON only structurally: put all resistance exercises in "liftingExercises" (array) and cardio in "cardioBlocks" (array). **Do NOT treat them as mutually exclusive**—the same day very often includes BOTH arrays filled (e.g. full lift session plus 15–35 min easy conditioning after or before lifts). Cardio-only days are fine when needed to hit weekly cardio frequency, but do not default to "never both on one day."
        - Every day object MUST include "exercises" as an array (use [] if empty). Omitting it breaks parsing.
        - Each lifting exercise: { id, name, sets, reps, restSec?, notes?, steps?: string[] (3-6 short cues), diagramURL?: string, muscleGroupsTrained?: string[], suggestedWeightKg?: number (kg; month 2+ only) }. For diagramURL prefer a direct link to ONE image file you can verify (e.g. upload.wikimedia.org/.../...png or .jpg). If you cannot verify a real URL, omit diagramURL entirely — do not use placeholder or fake hosts. The app shows an image search link when omitted.
        - Each cardioBlock: { id, title, modality (walk|jog|run|bike|row|swim|elliptical|incline_walk only — NEVER yoga), durationMinutes, targetPace (e.g. mph, min/mile, or conversational), intensityNote?, instructions?: string[] }.
        - Do NOT prescribe yoga as cardio. Stretching belongs in "stretchSession": { title?, items: [{ id, name, holdSeconds?, steps: string[], diagramURL? }] }.
        - Respect equipmentAvailable; avoid machines the user does not have.
        - If equipmentAvailable includes "no_gym_equipment", the user has no weights or gym machines — prioritize calisthenics and environment-based cardio; still honor other listed items (e.g. pull-up bar, resistance bands).

        workoutPlan: { programNotes?: string, weeks: [{ label: string, days: [{ dayIndex: 0-6 Mon-Sun, name: string, exercises: ExerciseTemplateDTO[], liftingExercises?: ExerciseTemplateDTO[], cardioBlocks?: CardioBlockDTO[], stretchSession?: StretchSessionDTO }] }] }

        mealPlan: { targetDailyCalories: number, notes?: string, days: [{ dayIndex: number, meals: [{ id, name, description, approxCalories?: number, recipeURL: string (required https link to a real recipe page or reputable recipe search URL) }] }] }

        Match liftDaysPerWeek and cardioDaysPerWeek. **Prioritize** putting cardio on days that already have lifting when counts allow (combined days are normal). Use separate cardio-only days for extra weekly cardio volume beyond that. Keep meals realistic for their cooking time and budget.
        """
        let system = systemBase + monthlyPlanningInstructions(planMonthSequence: planMonthSequence)

        var userPayload: [String: Any] = [
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
            "equipmentAvailable": profile.equipmentTagsForPlanning,
            "planMonthSequence": planMonthSequence
        ]
        if !priorMonthSummaryForLLM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userPayload["priorMonthPerformanceSummary"] = priorMonthSummaryForLLM
        }
        if let pj = priorWorkoutPlanJSON, !pj.isEmpty {
            userPayload["priorWorkoutPlanJSON"] = String(pj.prefix(12_000))
        }
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
