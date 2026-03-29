import SwiftUI
import SwiftData

struct WorkoutDayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let date: Date
    let workoutPlan: WorkoutPlanDTO?

    @Query private var allSessions: [WorkoutSessionLog]
    @Query private var profiles: [UserHealthProfile]

    @State private var usePounds: Bool = false

    private var profile: UserHealthProfile? { profiles.first }

    private var dayStart: Date { CalendarDay.startOfDay(date) }
    private var dayKey: String { DayKey.string(for: dayStart) }

    private var planDay: WorkoutDayDTO? {
        guard let plan = workoutPlan, let week = plan.weeks.first else { return nil }
        let idx = CalendarDay.planDayIndex(for: dayStart)
        return week.days.first(where: { $0.dayIndex == idx })
    }

    private var sessionsForDay: [WorkoutSessionLog] {
        allSessions.filter { $0.dayKey == dayKey }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Weight units")
                        .font(.subheadline)
                        .foregroundStyle(FocusPalette.textSecondary)
                    Spacer()
                    Picker("", selection: $usePounds) {
                        Text("kg").tag(false)
                        Text("lb").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 160)
                }
                .listRowBackground(FocusPalette.surfaceElevated)
            }

            if let day = planDay, !day.hasPlannedWork {
                Section {
                    Text("Scheduled rest. Optional easy walk from your plan still counts as movement.")
                        .foregroundStyle(FocusPalette.textSecondary)
                }
            }

            if let day = planDay, !day.liftingExercisesResolved().isEmpty {
                Section {
                    ForEach(day.liftingExercisesResolved()) { ex in
                        NavigationLink {
                            ExerciseGuideDetailView(exercise: ex)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FocusPalette.textPrimary)
                                Text("\(ex.sets)× \(ex.reps)")
                                    .font(.caption2)
                                    .foregroundStyle(FocusPalette.textSecondary)
                                if ex.steps != nil, !(ex.steps ?? []).isEmpty {
                                    Text("Tap for steps & diagram")
                                        .font(.caption2)
                                        .foregroundStyle(FocusPalette.accent)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(FocusPalette.surfaceElevated)
                    }
                } header: {
                    Text("Strength plan")
                        .foregroundStyle(FocusPalette.textSecondary)
                }
            }

            if let day = planDay, !day.cardioBlocksResolved().isEmpty {
                Section {
                    ForEach(day.cardioBlocksResolved()) { b in
                        CardioBlockCard(block: b)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Cardio plan")
                        .foregroundStyle(FocusPalette.textSecondary)
                }
            }

            if let day = planDay, let stretch = day.stretchSession, !stretch.items.isEmpty {
                Section {
                    ForEach(stretch.items) { item in
                        StretchGuideCard(item: item)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(stretch.title ?? "Stretching")
                        .foregroundStyle(FocusPalette.textSecondary)
                }
            }

            if let day = planDay, !day.mobilityExercisesLegacy().isEmpty {
                Section {
                    ForEach(day.mobilityExercisesLegacy()) { ex in
                        NavigationLink {
                            ExerciseGuideDetailView(exercise: ex)
                        } label: {
                            Text(ex.name)
                                .foregroundStyle(FocusPalette.textPrimary)
                        }
                        .listRowBackground(FocusPalette.surfaceElevated)
                    }
                } header: {
                    Text("Mobility (legacy)")
                        .foregroundStyle(FocusPalette.textSecondary)
                }
            }

            Section {
                if sessionsForDay.isEmpty {
                    Text("No lifts logged yet for this day. Complete sets below when you train.")
                        .font(.footnote)
                        .foregroundStyle(FocusPalette.textSecondary)
                }
                ForEach(sessionsForDay, id: \.id) { session in
                    ExerciseLogCard(session: session, usePounds: usePounds)
                }
            } header: {
                Text("Log performance (strength)")
                    .foregroundStyle(FocusPalette.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FocusScreenBackground())
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            usePounds = profile?.measurementSystemRaw == "imperial"
            guard let plan = workoutPlan else { return }
            try? WorkoutSessionBootstrapper.ensureSessionsForDay(date: dayStart, plan: plan, context: modelContext)
            try? modelContext.save()
        }
        .onChange(of: profiles.first?.measurementSystemRaw) { _, new in
            guard let new else { return }
            usePounds = (new == "imperial")
        }
    }
}

private struct ExerciseLogCard: View {
    @Bindable var session: WorkoutSessionLog
    var usePounds: Bool

    private var kind: ExerciseKind {
        ExerciseKind.classify(name: session.exerciseName, repsHint: session.targetRepsHint)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(kind.cardBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: kind.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(kind.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.exerciseName)
                        .font(.headline)
                        .foregroundStyle(FocusPalette.textPrimary)
                    Text("Target \(session.targetSets)× · \(session.targetRepsHint)")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                }
                Spacer()
            }

            ForEach(session.sets.sorted { $0.setIndex < $1.setIndex }, id: \.persistentModelID) { set in
                SetEntryRow(set: set, usePounds: usePounds)
            }
        }
        .listRowBackground(FocusPalette.surfaceElevated)
        .padding(.vertical, 6)
    }
}
