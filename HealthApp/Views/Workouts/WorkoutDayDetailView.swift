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

            if let week = workoutPlan?.weeks.first,
               let day = week.days.first(where: { $0.dayIndex == CalendarDay.planDayIndex(for: dayStart) }),
               day.exercises.isEmpty {
                Section {
                    Text("Scheduled rest. Easy walk or mobility still counts.")
                        .foregroundStyle(FocusPalette.textSecondary)
                }
            }

            Section {
                if sessionsForDay.isEmpty {
                    Text("No lifts scheduled for this weekday, or open the plan from onboarding.")
                        .font(.footnote)
                        .foregroundStyle(FocusPalette.textSecondary)
                }
                ForEach(sessionsForDay, id: \.id) { session in
                    ExerciseLogCard(session: session, usePounds: usePounds)
                }
            } header: {
                Text("Log performance")
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
