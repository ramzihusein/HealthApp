import SwiftUI
import SwiftData

struct WorkoutsPaneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @Query(sort: \CardioSessionLog.dayDate) private var allCardioLogs: [CardioSessionLog]
    @State private var weekAnchor = Date()
    @State private var selectedDay: Date?

    private var activePlanRecord: StoredGeneratedPlans? { plans.first }

    private var planPeriodEnded: Bool {
        guard let end = activePlanRecord?.planPeriodEnd else { return false }
        return CalendarDay.startOfDay(Date()) > CalendarDay.startOfDay(end)
    }

    private var planDTO: WorkoutPlanDTO? {
        guard let p = plans.first else { return nil }
        return try? PlanCodec.decodeWorkout(from: p.workoutJSON)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if planPeriodEnded {
                        FocusCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Time for next month’s plan")
                                    .font(.headline)
                                    .foregroundStyle(FocusPalette.textPrimary)
                                Text("Open the Settings tab and tap “Regenerate workout & meal plans.” Your last month of logs will guide suggested weights and cardio targets for the new block.")
                                    .font(.caption)
                                    .foregroundStyle(FocusPalette.textSecondary)
                            }
                        }
                    }

                    if let dto = planDTO, let notes = dto.programNotes, !notes.isEmpty {
                        FocusCard {
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    } else if planDTO == nil {
                        FocusCard {
                            Text("No plan found. Complete onboarding to generate workouts.")
                                .font(.footnote)
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }

                    weekStrip

                    if let d = selectedDay {
                        plannedStrengthSection(for: d)
                        plannedCardioSection(for: d)
                        plannedStretchSection(for: d)
                        plannedMobilityLegacySection(for: d)

                        NavigationLink {
                            WorkoutDayDetailView(date: d, workoutPlan: planDTO)
                        } label: {
                            FocusCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Daily progress recap")
                                            .font(.headline)
                                            .foregroundStyle(FocusPalette.textPrimary)
                                        Text("\(dayTitle(d)) · \(subtitleForDay(d))")
                                            .font(.caption)
                                            .foregroundStyle(FocusPalette.textSecondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(FocusPalette.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle("Training week")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if selectedDay == nil {
                    selectedDay = CalendarDay.startOfDay(Date())
                }
                bootstrapSessionsForSelectedDay()
            }
            .onChange(of: selectedDay) { _, _ in
                bootstrapSessionsForSelectedDay()
            }
            .onChange(of: plans.first?.generatedAt) { _, _ in
                bootstrapSessionsForSelectedDay()
            }
        }
    }

    private func cardioLog(day: Date, blockId: String) -> CardioSessionLog? {
        let dk = DayKey.string(for: CalendarDay.startOfDay(day))
        return allCardioLogs.first { $0.dayKey == dk && $0.cardioBlockId == blockId }
    }

    private func bootstrapSessionsForSelectedDay() {
        guard let d = selectedDay, let p = planDTO else { return }
        try? WorkoutSessionBootstrapper.ensureSessionsForDay(date: d, plan: p, context: modelContext)
        try? CardioSessionBootstrapper.ensureForDay(date: d, plan: p, context: modelContext)
        try? modelContext.save()
    }

    private func dayModel(for d: Date) -> WorkoutDayDTO? {
        guard let plan = planDTO, let week = plan.weeks.first else { return nil }
        let idx = CalendarDay.planDayIndex(for: d)
        return week.days.first(where: { $0.dayIndex == idx })
    }

    @ViewBuilder
    private func plannedStrengthSection(for d: Date) -> some View {
        let lifts = dayModel(for: d)?.liftingExercisesResolved() ?? []
        if lifts.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Strength / lifting", systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textSecondary)
                VStack(spacing: 10) {
                    ForEach(lifts) { ex in
                        NavigationLink {
                            WorkoutExerciseDetailView(dayDate: d, exercise: ex, workoutPlan: planDTO)
                        } label: {
                            exercisePlanRow(ex)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Tap an exercise to log sets or view how to.")
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func plannedCardioSection(for d: Date) -> some View {
        let blocks = dayModel(for: d)?.cardioBlocksResolved() ?? []
        if blocks.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Cardio", systemImage: "figure.run")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textSecondary)
                VStack(spacing: 10) {
                    ForEach(blocks) { b in
                        if let log = cardioLog(day: d, blockId: b.id) {
                            CardioBlockLogCard(block: b, log: log)
                        }
                    }
                }
                Text("Log minutes and notes here or in Daily progress recap.")
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func plannedStretchSection(for d: Date) -> some View {
        if let s = dayModel(for: d)?.stretchSession, !s.items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(s.title ?? "Stretching", systemImage: "figure.flexibility")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textSecondary)
                VStack(spacing: 10) {
                    ForEach(s.items) { item in
                        StretchGuideCard(item: item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func plannedMobilityLegacySection(for d: Date) -> some View {
        let mob = dayModel(for: d)?.mobilityExercisesLegacy() ?? []
        if mob.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Mobility (legacy list)", systemImage: "figure.flexibility")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textSecondary)
                VStack(spacing: 10) {
                    ForEach(mob) { ex in
                        NavigationLink {
                            ExerciseGuideDetailView(exercise: ex)
                        } label: {
                            exercisePlanRow(ex)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Full-width row for strength list (always lifting styling in this section).
    private func exercisePlanRow(_ ex: ExerciseTemplateDTO) -> some View {
        let kind = ExerciseKind.classify(name: ex.name, repsHint: ex.reps)
        return HStack(spacing: 12) {
            Image(systemName: kind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(kind.accent)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(ex.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textPrimary)
                    .multilineTextAlignment(.leading)
                Text("\(ex.sets)× \(ex.reps)")
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FocusPalette.accent.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(kind.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private var weekStrip: some View {
        let days = CalendarDay.daysInWeek(containing: weekAnchor)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    if let d = CalendarDay.calendar.date(byAdding: .weekOfYear, value: -1, to: weekAnchor) {
                        weekAnchor = d
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(FocusPalette.accent)
                }
                Spacer()
                Text(weekRangeLabel(days))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textSecondary)
                Spacer()
                Button {
                    if let d = CalendarDay.calendar.date(byAdding: .weekOfYear, value: 1, to: weekAnchor) {
                        weekAnchor = d
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(FocusPalette.accent)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { d in
                        dayCell(d)
                    }
                }
            }
        }
    }

    private func dayCell(_ d: Date) -> some View {
        let sel = selectedDay.map { CalendarDay.isSameDay($0, d) } ?? false
        let wd = DateFormatter()
        wd.dateFormat = "EEE"
        let label = wd.string(from: d)
        let num = CalendarDay.calendar.component(.day, from: d)
        return Button {
            selectedDay = CalendarDay.startOfDay(d)
        } label: {
            VStack(spacing: 6) {
                Text(String(label.prefix(3)).uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(sel ? FocusPalette.background : FocusPalette.textSecondary)
                Text("\(num)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(sel ? FocusPalette.background : FocusPalette.textPrimary)
            }
            .frame(width: 56, height: 64)
            .background(sel ? FocusPalette.accent : FocusPalette.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(sel ? Color.clear : FocusPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dayTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: d)
    }

    private func subtitleForDay(_ d: Date) -> String {
        guard let day = dayModel(for: d) else { return "Log sets when you train" }
        let l = day.liftingExercisesResolved().count
        let c = day.cardioBlocksResolved().count
        if !day.hasPlannedWork { return "Rest — optional easy movement" }
        var parts: [String] = []
        if l > 0 { parts.append("\(l) strength moves") }
        if c > 0 { parts.append("\(c) cardio block(s)") }
        if day.stretchSession != nil { parts.append("stretching") }
        let tail = parts.joined(separator: " · ")
        return "\(day.name) — \(tail)"
    }

    private func weekRangeLabel(_ days: [Date]) -> String {
        guard let a = days.first, let b = days.last else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: a)) – \(f.string(from: b))"
    }
}

private extension CalendarDay {
    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }
}
