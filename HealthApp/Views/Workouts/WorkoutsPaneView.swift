import SwiftUI
import SwiftData

struct WorkoutsPaneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @State private var weekAnchor = Date()
    @State private var selectedDay: Date?

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
            .onAppear {
                if selectedDay == nil {
                    selectedDay = CalendarDay.startOfDay(Date())
                }
            }
        }
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
        guard let plan = planDTO, let week = plan.weeks.first else { return "Log sets when you train" }
        let idx = CalendarDay.planDayIndex(for: d)
        if let day = week.days.first(where: { $0.dayIndex == idx }) {
            if day.exercises.isEmpty { return "Rest — light walk optional" }
            return "\(day.exercises.count) exercises · \(day.name)"
        }
        return "Log sets when you train"
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
