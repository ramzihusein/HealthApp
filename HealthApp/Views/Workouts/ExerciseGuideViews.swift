import SwiftUI

struct ExerciseGuideDetailView: View {
    let exercise: ExerciseTemplateDTO

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let groups = exercise.muscleGroupsTrained, !groups.isEmpty {
                    FlowTagsRow(tags: groups)
                }

                if let urlStr = exercise.diagramURL, let url = URL(string: urlStr), ["http", "https"].contains(url.scheme?.lowercased()) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        case .failure:
                            diagramPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 120)
                        @unknown default:
                            diagramPlaceholder
                        }
                    }
                } else {
                    diagramPlaceholder
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
                        Text("Follow your plan’s sets and reps. Add step-by-step cues in Settings by regenerating with an API key for richer instructions.")
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
            .padding(20)
        }
        .background(FocusScreenBackground())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var diagramPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundStyle(FocusPalette.accent.opacity(0.85))
            Text("No diagram URL — use the steps above or search the move name.")
                .font(.caption)
                .foregroundStyle(FocusPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(FocusPalette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct FlowTagsRow: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Muscle focus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FocusPalette.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(tags, id: \.self) { t in
                    Text(t.capitalized)
                        .font(.caption.weight(.medium))
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

struct StretchGuideCard: View {
    let item: StretchItemDTO
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FocusPalette.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(FocusPalette.accent)
                }
            }
            .buttonStyle(.plain)

            if let h = item.holdSeconds {
                Text("Hold ~\(h)s")
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary)
            }

            if expanded {
                if let urlStr = item.diagramURL, let url = URL(string: urlStr), ["http", "https"].contains(url.scheme?.lowercased()) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        case .failure:
                            EmptyView()
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                ForEach(Array(item.steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FocusPalette.accent)
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
