import SwiftUI
import SwiftData

struct WorkoutsPaneView: View {
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @State private var weekAnchor = Date()
    @State private var selectedDay: Date?
    @State private var guideExercise: ExerciseTemplateDTO?

    private var planDTO: WorkoutPlanDTO? {
        guard let p = plans.first else { return nil }
        return try? PlanCodec.decodeWorkout(from: p.workoutJSON)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                                        Text(dayTitle(d))
                                            .font(.headline)
                                            .foregroundStyle(FocusPalette.textPrimary)
                                        Text(subtitleForDay(d))
                                            .font(.caption)
                                            .foregroundStyle(FocusPalette.textSecondary)
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
            .navigationDestination(item: $guideExercise) { ex in
                ExerciseGuideDetailView(exercise: ex)
            }
            .onAppear {
                if selectedDay == nil {
                    selectedDay = CalendarDay.startOfDay(Date())
                }
            }
        }
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(lifts) { ex in
                            Button {
                                guideExercise = ex
                            } label: {
                                exercisePlanChip(ex)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text("Tap an exercise for steps and diagram.")
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
                        CardioBlockCard(block: b)
                    }
                }
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(mob) { ex in
                            Button {
                                guideExercise = ex
                            } label: {
                                exercisePlanChip(ex)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func exercisePlanChip(_ ex: ExerciseTemplateDTO) -> some View {
        let kind = ExerciseKind.classify(name: ex.name, repsHint: ex.reps)
        return HStack(spacing: 10) {
            Image(systemName: kind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(kind.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textPrimary)
                    .lineLimit(2)
                Text("\(ex.sets)× \(ex.reps)")
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary)
            }
            .frame(maxWidth: 200, alignment: .leading)
        }
        .padding(12)
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
