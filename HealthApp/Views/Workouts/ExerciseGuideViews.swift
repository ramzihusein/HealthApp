import SwiftUI

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

            diagramSection

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
                    Text("Follow your plan's sets and reps. Regenerate with an API key for richer step cues, or use the image search below.")
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

    @ViewBuilder
    private var diagramSection: some View {
        if let urlStr = exercise.diagramURL,
           let url = URL(string: urlStr),
           ["http", "https"].contains(url.scheme?.lowercased()) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                case .failure:
                    liftDiagramFallback
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                @unknown default:
                    liftDiagramFallback
                }
            }
        } else {
            liftDiagramFallback
        }
    }

    private var liftDiagramFallback: some View {
        VStack(spacing: 10) {
            Image(systemName: LiftDiagramFallback.symbol(for: exercise.name))
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(FocusPalette.accent.opacity(0.9))
            Text("No usable diagram link in your plan. Models often omit URLs — use search for form photos, or regenerate after an app update.")
                .font(.caption)
                .foregroundStyle(FocusPalette.textSecondary)
                .multilineTextAlignment(.center)
            if let link = LiftDiagramFallback.imageSearchURL(query: exercise.name) {
                Link(destination: link) {
                    Label("Search images for this lift", systemImage: "safari")
                        .font(.caption.weight(.semibold))
                }
                .tint(FocusPalette.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(FocusPalette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum LiftDiagramFallback {
    static func symbol(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("squat") || n.contains("leg press") || n.contains("lunge") { return "figure.strengthtraining.functional" }
        if n.contains("deadlift") || n.contains("rdl") || n.contains("hip thrust") { return "figure.strengthtraining.traditional" }
        if n.contains("press") || n.contains("bench") || n.contains("push-up") || n.contains("push up") || n.contains("dip") {
            return "figure.strengthtraining.traditional"
        }
        if n.contains("row") || n.contains("pull") || n.contains("curl") || n.contains("lat ") { return "figure.cooldown" }
        if n.contains("run") || n.contains("jog") || n.contains("walk") { return "figure.run" }
        return "figure.strengthtraining.traditional"
    }

    static func imageSearchURL(query: String) -> URL? {
        let q = "\(query) strength exercise form technique"
        guard let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.bing.com/images/search?q=\(enc)")
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

            StretchReferenceDiagramView(stretchName: item.name, diagramURLString: item.diagramURL)

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

// MARK: - Stretch diagrams (always visible for beginners)

private struct StretchReferenceDiagramView: View {
    let stretchName: String
    let diagramURLString: String?

    @State private var remoteFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let urlStr = diagramURLString,
               let url = URL(string: urlStr),
               ["http", "https"].contains(url.scheme?.lowercased()),
               !remoteFailed {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(FocusPalette.border, lineWidth: 1)
                            )
                    case .failure:
                        Color.clear
                            .frame(height: 1)
                            .onAppear { remoteFailed = true }
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    @unknown default:
                        Color.clear.onAppear { remoteFailed = true }
                    }
                }
                Text("Reference photo / animation (Wikimedia Commons or CDC public domain).")
                    .font(.caption2)
                    .foregroundStyle(FocusPalette.textSecondary)
            }

            if remoteFailed || diagramURLString == nil || URL(string: diagramURLString ?? "") == nil {
                stretchOfflineFallback
            }
        }
    }

    private var stretchOfflineFallback: some View {
        VStack(spacing: 10) {
            Image(systemName: StretchDiagramFallback.symbol(for: stretchName))
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(FocusPalette.accent.opacity(0.9))
            Text("Could not load the online diagram, or none is set. Use the steps above and the link below for examples.")
                .font(.caption)
                .foregroundStyle(FocusPalette.textSecondary)
                .multilineTextAlignment(.center)
            if let link = StretchDiagramFallback.imageSearchURL(query: stretchName) {
                Link(destination: link) {
                    Label("Search images for this stretch", systemImage: "safari")
                        .font(.caption.weight(.semibold))
                }
                .tint(FocusPalette.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(FocusPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum StretchDiagramFallback {
    static func symbol(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("quad") || n.contains("thigh front") { return "figure.stand" }
        if n.contains("hamstring") || n.contains("seated") { return "figure.flexibility" }
        if n.contains("chest") || n.contains("pec") || n.contains("doorway") { return "arrow.left.and.right" }
        if n.contains("shoulder") || n.contains("cross-body") || n.contains("cross body") { return "arrow.left.and.right" }
        if n.contains("cat") || n.contains("cow") || n.contains("spine") { return "figure.flexibility" }
        if n.contains("lunge") || n.contains("hip flexor") || n.contains("thoracic") { return "figure.walk" }
        return "figure.cooldown"
    }

    static func imageSearchURL(query: String) -> URL? {
        let q = "\(query) stretch exercise demonstration"
        guard let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.bing.com/images/search?q=\(enc)")
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
