import SwiftUI
import SwiftData

struct ExerciseGuideDetailView: View {
    let exercise: ExerciseTemplateDTO

    var body: some View {
        ScrollView {
            ExerciseHowToContent(exercise: exercise)
                .padding(20)
        }
        .background(FocusScreenBackground())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Shared “how to” body for the guide screen and the exercise detail tab.
struct ExerciseHowToContent: View {
    let exercise: ExerciseTemplateDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let groups = exercise.muscleGroupsTrained, !groups.isEmpty {
                FlowTagsRow(tags: groups)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("How to do it")
                    .font(.headline)
                    .foregroundStyle(FocusPalette.textPrimary)
                if let steps = exercise.steps, !steps.isEmpty {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(FocusPalette.background)
                                .frame(width: 22, height: 22)
                                .background(FocusPalette.accent)
                                .clipShape(Circle())
                            Text(s)
                                .font(.subheadline)
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }
                } else {
                    Text("Follow your plan's sets and reps. Regenerate your plan for richer step cues.")
                        .font(.footnote)
                        .foregroundStyle(FocusPalette.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FocusPalette.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let n = exercise.notes, !n.isEmpty {
                Text(n)
                    .font(.footnote)
                    .foregroundStyle(FocusPalette.warning)
            }
        }
    }
}

private struct FlowTagsRow: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Muscle focus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { t in
                        Text(t.capitalized)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(FocusPalette.accent.opacity(0.2))
                            .foregroundStyle(FocusPalette.accent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

struct StretchGuideCard: View {
    let item: StretchItemDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FocusPalette.textPrimary)

            if let h = item.holdSeconds {
                Text("Hold about \(h) seconds (each side if the steps say to switch).")
                    .font(.caption)
                    .foregroundStyle(FocusPalette.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Steps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FocusPalette.textSecondary)
                ForEach(Array(item.steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FocusPalette.accent)
                            .frame(minWidth: 16, alignment: .leading)
                        Text(s)
                            .font(.caption)
                            .foregroundStyle(FocusPalette.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(FocusPalette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct CardioBlockCard: View {
    let block: CardioBlockDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(Color(red: 0.35, green: 0.82, blue: 0.88))
                Text(block.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusPalette.textPrimary)
            }
            Text("\(block.durationMinutes) min · \(block.modality.replacingOccurrences(of: "_", with: " "))")
                .font(.caption)
                .foregroundStyle(FocusPalette.textSecondary)
            if let p = block.targetPace, !p.isEmpty {
                Label(p, systemImage: "speedometer")
                    .font(.caption)
                    .foregroundStyle(FocusPalette.textSecondary)
            }
            if let z = block.intensityNote, !z.isEmpty {
                Text(z)
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.accent.opacity(0.9))
            }
            if let ins = block.instructions, !ins.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(ins.enumerated()), id: \.offset) { _, line in
                        Text("• \(line)")
                            .font(.caption2)
                            .foregroundStyle(FocusPalette.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.08, green: 0.22, blue: 0.28).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct CardioBlockLogCard: View {
    let block: CardioBlockDTO
    @Bindable var log: CardioSessionLog
    @Environment(\.modelContext) private var modelContext
    @State private var showSavedFlash = false

    private var minutesTextBinding: Binding<String> {
        Binding(
            get: { log.completedMinutes == 0 ? "" : "\(log.completedMinutes)" },
            set: { newVal in
                log.completedMinutes = Int(newVal.filter { $0.isNumber }) ?? 0
                persist()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardioBlockCard(block: block)
            VStack(alignment: .leading, spacing: 8) {
                Text("Log completion")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FocusPalette.textSecondary)
                HStack(spacing: 10) {
                    TextField("0", text: minutesTextBinding)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 72)
                    Text("min completed")
                        .font(.caption)
                        .foregroundStyle(FocusPalette.textSecondary)
                    Spacer(minLength: 8)
                    Button("Match plan (\(block.durationMinutes))") {
                        log.completedMinutes = block.durationMinutes
                        persist()
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .buttonStyle(.bordered)
                    .tint(FocusPalette.accent)
                }
                TextField("Notes (pace, distance, effort)", text: Binding(
                    get: { log.notes },
                    set: { log.notes = $0; persist() }
                ))
                .textFieldStyle(.roundedBorder)
                if showSavedFlash {
                    Text("Saved")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(FocusPalette.positive)
                }
            }
            .padding(12)
            .background(FocusPalette.surfaceElevated.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(FocusPalette.border.opacity(0.6), lineWidth: 1)
            )
        }
    }

    private func persist() {
        try? modelContext.save()
        showSavedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showSavedFlash = false
        }
    }
}
