import SwiftUI
import SwiftData

struct WorkoutDayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let date: Date
    let workoutPlan: WorkoutPlanDTO?

    @Query private var allSessions: [WorkoutSessionLog]

    private var dayStart: Date { CalendarDay.startOfDay(date) }
    private var dayKey: String { DayKey.string(for: dayStart) }

    private var sessionsForDay: [WorkoutSessionLog] {
        allSessions.filter { $0.dayKey == dayKey }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
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
                    ExerciseLogCard(session: session)
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
            guard let plan = workoutPlan else { return }
            try? WorkoutSessionBootstrapper.ensureSessionsForDay(date: dayStart, plan: plan, context: modelContext)
            try? modelContext.save()
        }
    }
}

private struct ExerciseLogCard: View {
    @Bindable var session: WorkoutSessionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
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
                SetEntryRow(set: set)
            }
        }
        .listRowBackground(FocusPalette.surfaceElevated)
        .padding(.vertical, 6)
    }
}
