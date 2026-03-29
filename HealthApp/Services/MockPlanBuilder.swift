import Foundation

/// Deterministic rich plans when no LLM key is set. Respects profile training prefs and equipment tags (`equipmentCSV`).
enum MockPlanBuilder {
    static func build(for profile: UserHealthProfile) -> (workout: WorkoutPlanDTO, meal: MealPlanDTO) {
        let goals = profile.goals.map { $0.lowercased() }
        let lose = goals.contains { $0.contains("lose") || $0.contains("fat") }
        let gain = goals.contains { $0.contains("gain") || $0.contains("muscle") }
        let flex = goals.contains { $0.contains("flex") }
        let eq = equipmentSet(profile)
        let mins = min(120, max(25, profile.workoutSessionMinutes))
        let liftDays = min(6, max(2, profile.liftDaysPerWeek))
        let cardioDays = min(7, max(0, profile.cardioDaysPerWeek))

        let days = buildWeekDays(
            liftDays: liftDays,
            cardioDays: cardioDays,
            equipment: eq,
            sessionMins: mins,
            flex: flex,
            injuries: profile.injuriesNotes
        )

        let week = WorkoutWeekDTO(
            label: "Week 1 — \(liftDays)× strength · \(cardioDays)× cardio · ~\(mins) min sessions",
            days: days
        )
        let workout = WorkoutPlanDTO(
            programNotes: buildWorkoutNotes(
                lose: lose,
                gain: gain,
                flex: flex,
                injuries: profile.injuriesNotes,
                liftDays: liftDays,
                cardioDays: cardioDays,
                sessionMins: mins,
                equipment: eq
            ),
            weeks: [week]
        )

        let meal = buildMeals(for: profile, lose: lose, gain: gain)
        return (workout, meal)
    }

    private static func equipmentSet(_ profile: UserHealthProfile) -> Set<String> {
        let parts = profile.equipmentTagsForPlanning.map { $0.lowercased() }
        var s = Set(parts)
        if s.isEmpty { s = ["dumbbells", "bodyweight", "running_paths"] }
        return s
    }

    private static func buildWeekDays(
        liftDays: Int,
        cardioDays: Int,
        equipment: Set<String>,
        sessionMins: Int,
        flex: Bool,
        injuries: String
    ) -> [WorkoutDayDTO] {
        var schedule = Array(repeating: DayKind.rest, count: 7)
        let liftCycle: [DayKind] = [.push, .pull, .legs]
        let slots = [0, 2, 4, 1, 5, 3, 6]
        var liftAssigned = 0
        for d in slots {
            guard liftAssigned < liftDays else { break }
            if schedule[d] == .rest {
                schedule[d] = liftCycle[liftAssigned % liftCycle.count]
                liftAssigned += 1
            }
        }
        var cardioAssigned = 0
        for d in slots {
            guard cardioAssigned < cardioDays else { break }
            if schedule[d] == .rest {
                schedule[d] = .cardioOnly
                cardioAssigned += 1
            }
        }
        for i in 0..<7 where schedule[i] == .rest {
            schedule[i] = flex ? .mobility : .rest
        }

        return (0..<7).map { i in
            switch schedule[i] {
            case .push:
                pushDay(dayIndex: i, equipment: equipment, sessionMins: sessionMins, injuries: injuries)
            case .pull:
                pullDay(dayIndex: i, equipment: equipment, sessionMins: sessionMins, injuries: injuries)
            case .legs:
                legsDay(dayIndex: i, equipment: equipment, sessionMins: sessionMins, injuries: injuries)
            case .cardioOnly:
                cardioDay(dayIndex: i, modality: cardioModality(for: i))
            case .mobility:
                mobilityDay(dayIndex: i)
            case .rest:
                restDay(dayIndex: i, flex: flex)
            }
        }
    }

    private enum DayKind {
        case push, pull, legs, cardioOnly, mobility, rest
    }

    private static func cardioModality(for dayIndex: Int) -> String {
        let m = ["jog", "bike", "incline_walk", "row", "swim", "elliptical"]
        return m[dayIndex % m.count]
    }

    // MARK: - Lifting days (≥3 exercises & ≥12 sets per major group)

    private static func pushDay(dayIndex: Int, equipment: Set<String>, sessionMins: Int, injuries _: String) -> WorkoutDayDTO {
        let hasBar = equipment.contains("barbell")
        let hasDB = equipment.contains("dumbbells")
        let hasMach = equipment.contains("machines")
        let hasCables = equipment.contains("cables")

        let chest1: ExerciseTemplateDTO
        let chest2: ExerciseTemplateDTO
        let chest3: ExerciseTemplateDTO
        if hasBar {
            chest1 = lift("c1", "Barbell bench press", sets: 4, reps: "6-10", rest: 120, muscles: ["chest"], steps: benchSteps, diagram: Diagrams.bench)
            chest2 = lift("c2", hasDB ? "Incline dumbbell press" : "Machine incline press", sets: 4, reps: "8-12", rest: 90, muscles: ["chest"], steps: inclineSteps, diagram: nil)
            chest3 = lift("c3", hasCables ? "Cable crossover" : (hasMach ? "Pec deck fly" : "Push-ups"), sets: 4, reps: "12-15", rest: 60, muscles: ["chest"], steps: flySteps, diagram: nil)
        } else if hasMach {
            chest1 = lift("c1", "Chest press machine", sets: 4, reps: "8-12", rest: 90, muscles: ["chest"], steps: machinePressSteps, diagram: nil)
            chest2 = lift("c2", "Incline machine press", sets: 4, reps: "10-12", rest: 75, muscles: ["chest"], steps: inclineSteps, diagram: nil)
            chest3 = lift("c3", "Pec deck or cable fly", sets: 4, reps: "12-15", rest: 60, muscles: ["chest"], steps: flySteps, diagram: nil)
        } else {
            chest1 = lift("c1", "Push-up variations", sets: 4, reps: "AMRAP", rest: 60, muscles: ["chest"], steps: pushupSteps, diagram: nil)
            chest2 = lift("c2", "Dumbbell floor press", sets: 4, reps: "8-12", rest: 75, muscles: ["chest"], steps: floorPressSteps, diagram: nil)
            chest3 = lift("c3", "Dumbbell fly", sets: 4, reps: "12-15", rest: 60, muscles: ["chest"], steps: flySteps, diagram: nil)
        }

        let sh1 = lift("s1", hasDB ? "Dumbbell shoulder press" : "Machine shoulder press", sets: 4, reps: "8-12", rest: 90, muscles: ["shoulders"], steps: ohpSteps, diagram: nil)
        let sh2 = lift("s2", "Lateral raise", sets: 4, reps: "12-15", rest: 45, muscles: ["shoulders"], steps: latRaiseSteps, diagram: nil)
        let sh3 = lift("s3", hasCables ? "Cable face pull" : "Band face pull", sets: 4, reps: "15-20", rest: 45, muscles: ["shoulders"], steps: facePullSteps, diagram: nil)

        let t1 = lift("t1", hasCables ? "Triceps rope pushdown" : "Overhead dumbbell extension", sets: 4, reps: "10-15", rest: 60, muscles: ["triceps"], steps: pushdownSteps, diagram: nil)
        let t2 = lift("t2", "Skull crusher or DB kickback superset mindset", sets: 4, reps: "10-12", rest: 60, muscles: ["triceps"], steps: skullSteps, diagram: nil)
        let t3 = lift("t3", "Bench dip or cable single-arm pushdown", sets: 4, reps: "12-20", rest: 45, muscles: ["triceps"], steps: dipSteps, diagram: nil)

        let lifts = [chest1, chest2, chest3, sh1, sh2, sh3, t1, t2, t3]
        let name = "Push — chest · shoulders · triceps (~\(sessionMins) min)"
        return WorkoutDayDTO(
            dayIndex: dayIndex,
            name: name,
            exercises: lifts,
            liftingExercises: lifts,
            cardioBlocks: nil,
            stretchSession: defaultUpperStretch(title: "Upper-body cooldown")
        )
    }

    private static func pullDay(dayIndex: Int, equipment: Set<String>, sessionMins: Int, injuries _: String) -> WorkoutDayDTO {
        let hasBar = equipment.contains("barbell")
        let hasDB = equipment.contains("dumbbells")
        let hasMach = equipment.contains("machines")
        let hasCables = equipment.contains("cables")
        let hasPull = equipment.contains("pullup_bar")

        let b1: ExerciseTemplateDTO
        if hasPull {
            b1 = lift("b1", "Pull-up or assisted pull-up", sets: 4, reps: "6-12", rest: 120, muscles: ["back"], steps: pullupSteps, diagram: nil)
        } else if hasMach {
            b1 = lift("b1", "Lat pulldown", sets: 4, reps: "8-12", rest: 90, muscles: ["back"], steps: pulldownSteps, diagram: nil)
        } else {
            b1 = lift("b1", "Dumbbell row", sets: 4, reps: "8-12 each", rest: 90, muscles: ["back"], steps: rowSteps, diagram: nil)
        }
        let b2 = lift("b2", hasBar ? "Barbell row" : "Chest-supported row", sets: 4, reps: "8-10", rest: 90, muscles: ["back"], steps: barbellRowSteps, diagram: nil)
        let b3 = lift("b3", hasCables ? "Straight-arm pulldown" : "Reverse fly", sets: 4, reps: "12-15", rest: 60, muscles: ["back"], steps: pulloverSteps, diagram: nil)

        let r1 = lift("r1", "EZ-bar or dumbbell curl", sets: 4, reps: "8-12", rest: 60, muscles: ["biceps"], steps: curlSteps, diagram: nil)
        let r2 = lift("r2", "Hammer curl", sets: 4, reps: "10-12", rest: 45, muscles: ["biceps"], steps: hammerSteps, diagram: nil)
        let r3 = lift("r3", "Incline dumbbell curl", sets: 4, reps: "10-15", rest: 45, muscles: ["biceps"], steps: inclineCurlSteps, diagram: nil)

        let h1 = lift("h1", hasDB ? "Farmer carry" : "Dead hang or rack hold", sets: 3, reps: "40-60s", rest: 90, muscles: ["forearms"], steps: carrySteps, diagram: nil)
        let h2 = lift("h2", "Wrist curl", sets: 4, reps: "12-20", rest: 45, muscles: ["forearms"], steps: wristSteps, diagram: nil)
        let h3 = lift("h3", "Reverse wrist curl", sets: 4, reps: "12-20", rest: 45, muscles: ["forearms"], steps: wristSteps, diagram: nil)

        let lifts = [b1, b2, b3, r1, r2, r3, h1, h2, h3]
        let name = "Pull — back · biceps · grip (~\(sessionMins) min)"
        return WorkoutDayDTO(
            dayIndex: dayIndex,
            name: name,
            exercises: lifts,
            liftingExercises: lifts,
            cardioBlocks: nil,
            stretchSession: defaultUpperStretch(title: "Pull-day stretching")
        )
    }

    private static func legsDay(dayIndex: Int, equipment: Set<String>, sessionMins: Int, injuries _: String) -> WorkoutDayDTO {
        let hasBar = equipment.contains("barbell")
        let hasDB = equipment.contains("dumbbells")
        let hasMach = equipment.contains("machines")
        let hasKettle = equipment.contains("kettlebells")

        let q1: ExerciseTemplateDTO
        if hasBar {
            q1 = lift("q1", "Back squat or safety bar squat", sets: 4, reps: "5-8", rest: 150, muscles: ["quads"], steps: squatSteps, diagram: Diagrams.squat)
        } else if hasMach {
            q1 = lift("q1", "Leg press", sets: 4, reps: "10-15", rest: 120, muscles: ["quads"], steps: legPressSteps, diagram: nil)
        } else {
            q1 = lift("q1", "Goblet squat", sets: 4, reps: "10-15", rest: 90, muscles: ["quads"], steps: gobletSteps, diagram: nil)
        }
        let q2 = lift("q2", "Split squat or Bulgarian split squat", sets: 4, reps: "10 each", rest: 90, muscles: ["quads"], steps: splitSteps, diagram: nil)
        let q3 = lift("q3", "Leg extension or sissy squat substitute", sets: 4, reps: "12-20", rest: 60, muscles: ["quads"], steps: extSteps, diagram: nil)

        let h1: ExerciseTemplateDTO
        if hasBar {
            h1 = lift("h1", "Romanian deadlift", sets: 4, reps: "6-10", rest: 120, muscles: ["hamstrings"], steps: rdlSteps, diagram: nil)
        } else {
            h1 = lift("h1", hasDB ? "Dumbbell RDL" : "Glute bridge", sets: 4, reps: "8-12", rest: 90, muscles: ["hamstrings"], steps: rdlSteps, diagram: nil)
        }
        let h2 = lift("h2", "Lying leg curl or Nordic curl progression", sets: 4, reps: "10-15", rest: 75, muscles: ["hamstrings"], steps: curlLegSteps, diagram: nil)
        let h3 = lift("h3", "Good morning (light) or cable pull-through", sets: 4, reps: "12-15", rest: 60, muscles: ["hamstrings"], steps: gmSteps, diagram: nil)

        let g1 = lift("g1", hasKettle ? "Kettlebell swing" : "Hip thrust", sets: 4, reps: "8-15", rest: 90, muscles: ["glutes"], steps: swingSteps, diagram: nil)
        let g2 = lift("g2", "Step-up", sets: 4, reps: "10 each", rest: 75, muscles: ["glutes"], steps: stepupSteps, diagram: nil)
        let g3 = lift("g3", "Cable or band kickback", sets: 4, reps: "15-20", rest: 45, muscles: ["glutes"], steps: kickbackSteps, diagram: nil)

        let lifts = [q1, q2, q3, h1, h2, h3, g1, g2, g3]
        let name = "Legs — quads · hamstrings · glutes (~\(sessionMins) min)"
        return WorkoutDayDTO(
            dayIndex: dayIndex,
            name: name,
            exercises: lifts,
            liftingExercises: lifts,
            cardioBlocks: nil,
            stretchSession: defaultLowerStretch(title: "Lower-body cooldown")
        )
    }

    private static func cardioDay(dayIndex: Int, modality: String) -> WorkoutDayDTO {
        let block: CardioBlockDTO
        switch modality {
        case "jog":
            block = CardioBlockDTO(
                id: "cardio1",
                title: "Easy jog",
                modality: "jog",
                durationMinutes: 30,
                targetPace: "Conversational pace (~5.0–6.0 mph / 8–9.5 km/h if comfortable)",
                intensityNote: "Zone 2 — nose breathing if possible",
                instructions: [
                    "5 min brisk walk warm-up.",
                    "Hold steady easy effort; you should speak in sentences.",
                    "5 min walk cool-down."
                ]
            )
        case "bike":
            block = CardioBlockDTO(
                id: "cardio1",
                title: "Stationary or outdoor bike",
                modality: "bike",
                durationMinutes: 35,
                targetPace: "Moderate cadence 80–95 RPM, light resistance",
                intensityNote: "RPE 5–6 / 10",
                instructions: ["Flat or rolling; avoid grinding heavy gears.", "Keep shoulders relaxed."]
            )
        case "row":
            block = CardioBlockDTO(
                id: "cardio1",
                title: "Rowing erg steady state",
                modality: "row",
                durationMinutes: 25,
                targetPace: "2:15–2:30 / 500m average (adjust to fitness)",
                intensityNote: "Legs → hips → arms sequencing",
                instructions: ["Drive with legs first.", "Maintain 24–28 strokes/min."]
            )
        case "swim":
            block = CardioBlockDTO(
                id: "cardio1",
                title: "Easy swim",
                modality: "swim",
                durationMinutes: 30,
                targetPace: "Easy to moderate laps; rest 15s as needed",
                intensityNote: "Continuous low-impact cardio",
                instructions: ["Warm up 5 min easy.", "Mix strokes if skilled; otherwise focus on freestyle easy pace."]
            )
        case "elliptical":
            block = CardioBlockDTO(
                id: "cardio1",
                title: "Elliptical",
                modality: "elliptical",
                durationMinutes: 30,
                targetPace: "Moderate resistance, full foot contact",
                intensityNote: "Stay tall; no leaning heavily on handles",
                instructions: ["5 min ramp up, 20 min steady, 5 min cool-down."]
            )
        default:
            block = CardioBlockDTO(
                id: "cardio1",
                title: "Incline treadmill walk",
                modality: "incline_walk",
                durationMinutes: 35,
                targetPace: "3.0–3.6 mph, 8–12% incline (adjust as needed)",
                intensityNote: "Low impact; steady breathing",
                instructions: ["Short strides, tall posture.", "Use handrails only for balance."]
            )
        }
        return WorkoutDayDTO(
            dayIndex: dayIndex,
            name: "Cardio — \(block.title)",
            exercises: [],
            liftingExercises: [],
            cardioBlocks: [block],
            stretchSession: defaultLowerStretch(title: "Post-cardio stretch")
        )
    }

    private static func mobilityDay(dayIndex: Int) -> WorkoutDayDTO {
        WorkoutDayDTO(
            dayIndex: dayIndex,
            name: "Mobility & stretch",
            exercises: [],
            liftingExercises: [],
            cardioBlocks: nil,
            stretchSession: fullBodyStretchSession()
        )
    }

    private static func restDay(dayIndex: Int, flex: Bool) -> WorkoutDayDTO {
        if flex {
            return mobilityDay(dayIndex: dayIndex)
        }
        return WorkoutDayDTO(
            dayIndex: dayIndex,
            name: "Rest — optional easy walk",
            exercises: [],
            liftingExercises: [],
            cardioBlocks: [
                CardioBlockDTO(
                    id: "walk1",
                    title: "Optional easy walk",
                    modality: "walk",
                    durationMinutes: 20,
                    targetPace: "Comfortable stroll",
                    intensityNote: "Active recovery",
                    instructions: ["Flat path; focus on relaxed breathing."]
                )
            ],
            stretchSession: defaultLowerStretch(title: "Optional light stretching")
        )
    }

    // MARK: - Stretch presets

    private static func defaultUpperStretch(title: String) -> StretchSessionDTO {
        StretchSessionDTO(title: title, items: [
            StretchItemDTO(
                id: "st1",
                name: "Doorway pec stretch",
                holdSeconds: 45,
                steps: [
                    "Forearm on door frame, elbow ~90°.",
                    "Step through until you feel a mild stretch in chest.",
                    "Keep ribs down; breathe slowly."
                ],
                diagramURL: Diagrams.doorStretch
            ),
            StretchItemDTO(
                id: "st2",
                name: "Cross-body shoulder stretch",
                holdSeconds: 40,
                steps: [
                    "Bring arm across chest, other hand above elbow.",
                    "Gently draw arm toward body; no shrugging."
                ],
                diagramURL: Diagrams.shoulderStretch
            )
        ])
    }

    private static func defaultLowerStretch(title: String) -> StretchSessionDTO {
        StretchSessionDTO(title: title, items: [
            StretchItemDTO(
                id: "sl1",
                name: "Standing quad stretch",
                holdSeconds: 45,
                steps: [
                    "Stand tall, bend knee, catch foot behind you.",
                    "Knees stay close; slight posterior pelvic tilt.",
                    "Switch sides."
                ],
                diagramURL: Diagrams.quadStretch
            ),
            StretchItemDTO(
                id: "sl2",
                name: "Seated hamstring reach",
                holdSeconds: 45,
                steps: [
                    "Sit with one leg extended, other foot inside thigh.",
                    "Hinge at hip toward extended leg.",
                    "Switch sides."
                ],
                diagramURL: Diagrams.hamstringStretch
            )
        ])
    }

    private static func fullBodyStretchSession() -> StretchSessionDTO {
        StretchSessionDTO(title: "Full-body mobility", items: [
            StretchItemDTO(
                id: "fb1",
                name: "Cat-cow spine",
                holdSeconds: 60,
                steps: ["Hands under shoulders, knees under hips.", "Alternate arch and round spine slowly."],
                diagramURL: Diagrams.catCow
            ),
            StretchItemDTO(
                id: "fb2",
                name: "Lunge with thoracic rotation",
                holdSeconds: 45,
                steps: ["Lunge, both hands inside front foot.", "Rotate open toward front leg; switch sides."],
                diagramURL: Diagrams.lungeStretch
            ),
            StretchItemDTO(
                id: "fb3",
                name: "Hip flexor lunge stretch",
                holdSeconds: 45,
                steps: ["Back knee down or elevated cushion.", "Tuck pelvis; shift forward slightly.", "Switch sides."],
                diagramURL: Diagrams.hipFlexor
            )
        ])
    }

    // MARK: - Step libraries

    private static let benchSteps = [
        "Lie on bench, eyes under bar, feet planted.",
        "Grip slightly wider than shoulders, squeeze shoulder blades.",
        "Lower to mid-chest with control; press up in a slight arc."
    ]
    private static let inclineSteps = ["Set bench 30–45°.", "Press dumbbells up without flaring elbows excessively.", "Control the descent."]
    private static let flySteps = ["Soft elbows, hug motion.", "Stop when stretch feels strong, not painful."]
    private static let pushupSteps = ["Hands under shoulders, plank ribs down.", "Chest to fist height; full lockout at top."]
    private static let floorPressSteps = ["Elbows touch floor lightly; press to lockout.", "Keep wrists stacked."]
    private static let machinePressSteps = ["Adjust seat so handles align mid-chest.", "Press without snapping elbows."]
    private static let ohpSteps = ["Brace core; press vertically.", "Clear nose with chin or lean slightly."]
    private static let latRaiseSteps = ["Slight bend in elbows; lift to shoulder height.", "No shrugging."]
    private static let facePullSteps = ["Elbows high, pull rope toward face.", "Squeeze rear shoulders."]
    private static let pushdownSteps = ["Elbows pinned; extend fully.", "No swinging torso."]
    private static let skullSteps = ["Upper arms vertical; bend elbows only.", "Stop before pain in elbows."]
    private static let dipSteps = ["Shoulders down; vertical torso bias for triceps.", "Stop if shoulder discomfort."]
    private static let pullupSteps = ["Full hang, pull chest toward bar.", "Use band or machine assist if needed."]
    private static let pulldownSteps = ["Chest tall; pull bar to upper chest.", "Control return."]
    private static let rowSteps = ["Flat back; pull elbow to hip.", "No torso twist."]
    private static let barbellRowSteps = ["Hinge hips, neutral spine.", "Pull bar to lower ribs."]
    private static let pulloverSteps = ["Straight arms from shoulders; sweep down.", "Feel lats, not shoulders pinching."]
    private static let curlSteps = ["Elbows fixed at sides.", "Full extension without resting between reps."]
    private static let hammerSteps = ["Neutral grip; same path as curl."]
    private static let inclineCurlSteps = ["Arms hang behind torso on incline.", "Curl without shrugging."]
    private static let carrySteps = ["Walk tall; short steps.", "Grip firm but not white-knuckle."]
    private static let wristSteps = ["Forearm supported; move only wrist.", "Controlled tempo."]
    private static let squatSteps = ["Bar balanced on traps or shelf.", "Break hips and knees together.", "Depth you own with neutral spine."]
    private static let legPressSteps = ["Feet shoulder width, full foot contact.", "Lower until comfortable depth without butt rounding."]
    private static let gobletSteps = ["Hold weight at chest.", "Squat between hips; elbows inside knees."]
    private static let splitSteps = ["Torso tall; front knee tracks over foot.", "Back knee soft tap optional."]
    private static let extSteps = ["Control negative; squeeze quads at top.", "No locking out aggressively if knees sensitive."]
    private static let rdlSteps = ["Soft knees fixed angle.", "Push hips back; bar close to legs."]
    private static let curlLegSteps = ["Pad adjusted above ankle.", "Control the stretch at bottom."]
    private static let gmSteps = ["Hinge with light load.", "Feel hamstrings load; avoid low back rounding."]
    private static let swingSteps = ["Hike bell back, snap hips.", "Arms are ropes; float to chest height."]
    private static let stepupSteps = ["Full foot on box.", "Drive through heel of top leg."]
    private static let kickbackSteps = ["Hinge slightly; kick heel to ceiling.", "Pause at top."]

    private static func lift(
        _ id: String,
        _ name: String,
        sets: Int,
        reps: String,
        rest: Int?,
        muscles: [String],
        steps: [String],
        diagram: String?
    ) -> ExerciseTemplateDTO {
        ExerciseTemplateDTO(
            id: id,
            name: name,
            sets: sets,
            reps: reps,
            restSec: rest,
            notes: nil,
            steps: steps,
            diagramURL: diagram,
            muscleGroupsTrained: muscles
        )
    }

    private enum Diagrams {
        static let bench = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Barbell_bench_press.png/320px-Barbell_bench_press.png"
        static let squat = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Squat_with_barbell.png/320px-Squat_with_barbell.png"

        // Stretch references: direct Commons URLs (JPEG/PNG/GIF) — CDC GIFs are U.S. public domain.
        static let quadStretch = "https://upload.wikimedia.org/wikipedia/commons/6/6e/Static_quadriceps_stretch.jpg"
        static let hamstringStretch = "https://upload.wikimedia.org/wikipedia/commons/3/32/Hamstring_stretch-CDC_strength_training_for_older_adults.gif"
        static let doorStretch = "https://upload.wikimedia.org/wikipedia/commons/4/41/Chest_stretch-CDC_strength_training_for_older_adults.gif"
        static let shoulderStretch = "https://upload.wikimedia.org/wikipedia/commons/c/c0/Woman_stretching.JPG"
        static let catCow = "https://upload.wikimedia.org/wikipedia/commons/8/8a/Yoga_cat-cow_pose.jpg"
        static let lungeStretch = "https://upload.wikimedia.org/wikipedia/commons/8/8d/Backstretch-CDC_strength_training_for_older_adults.gif"
        static let hipFlexor = "https://upload.wikimedia.org/wikipedia/commons/c/c0/Woman_stretching.JPG"
    }

    private static func buildWorkoutNotes(
        lose: Bool,
        gain: Bool,
        flex: Bool,
        injuries: String,
        liftDays: Int,
        cardioDays: Int,
        sessionMins: Int,
        equipment: Set<String>
    ) -> String {
        var parts: [String] = []
        parts.append("Split alternates push, pull, and legs with separate cardio blocks (no yoga). Strength and cardio are listed separately in the app.")
        parts.append("Each lift day targets major groups with ≥3 moves and ≥12 hard sets per group (mock template). Target session length ~\(sessionMins) min—trim rest if needed.")
        parts.append("Equipment assumed: \(equipment.sorted().joined(separator: ", ")).")
        if lose { parts.append("Fat-loss bias: keep 2–3 hard lifts + consistent cardio as scheduled.") }
        if gain { parts.append("Hypertrophy bias: progress loads or reps weekly when form is solid.") }
        if flex { parts.append("Extra mobility day uses guided stretches with reference images.") }
        if !injuries.isEmpty { parts.append("Modify anything that aggravates: \(injuries)") }
        parts.append("Planner targets: \(liftDays)× lifting / \(cardioDays)× cardio per week.")
        return parts.joined(separator: " ")
    }

    private static func buildMeals(for profile: UserHealthProfile, lose: Bool, gain: Bool) -> MealPlanDTO {
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
                meal(id: "m\(i)a", name: "Breakfast", description: "Greek yogurt parfait with oats and berries", kcal: c1, query: "Greek yogurt parfait oats berries"),
                meal(id: "m\(i)b", name: "Lunch", description: "Grilled chicken bowl with rice and vegetables", kcal: c1, query: "grilled chicken rice bowl vegetables"),
                meal(id: "m\(i)c", name: "Dinner", description: "Baked salmon with roasted potatoes and salad", kcal: max(tdee - 2 * c1, 300), query: "baked salmon roasted potatoes salad")
            ]
            return MealDayDTO(dayIndex: i, meals: meals)
        }

        return MealPlanDTO(
            targetDailyCalories: tdee,
            notes: buildMealNotes(
                budget: profile.weeklyMealBudget,
                cookMins: profile.dailyCookingMinutes,
                currencyCode: profile.currencyCode
            ),
            days: mealDays
        )
    }

    private static func meal(id: String, name: String, description: String, kcal: Int, query: String) -> PlannedMealDTO {
        let enc = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://www.allrecipes.com/search?q=\(enc)"
        return PlannedMealDTO(id: id, name: name, description: description, approxCalories: kcal, recipeURL: url)
    }

    private static func buildMealNotes(budget: Double, cookMins: Int, currencyCode: String) -> String {
        let sym = CurrencyOption(rawValue: currencyCode)?.symbol ?? currencyCode + " "
        return "Designed for ~\(cookMins) min/day cooking and ~\(sym)\(Int(budget))/week. Recipe links open Allrecipes search results you can match to the meal idea."
    }
}
