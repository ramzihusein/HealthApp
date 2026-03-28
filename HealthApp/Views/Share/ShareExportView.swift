import SwiftUI
import SwiftData

struct ShareExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserHealthProfile]
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @Query(sort: \DailyNutritionLog.dayDate) private var nutrition: [DailyNutritionLog]
    @Query(sort: \DailyWeightEntry.dayDate) private var weights: [DailyWeightEntry]
    @Query private var sessions: [WorkoutSessionLog]

    @State private var shareURL: URL?
    @State private var showShare = false

    private var profile: UserHealthProfile? { profiles.first }
    private var meal: MealPlanDTO? {
        guard let p = plans.first else { return nil }
        return try? PlanCodec.decodeMeal(from: p.mealJSON)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FocusCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Export for your coach")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("Creates a PDF summarizing goals, calorie goal vs logs, weight change, and recent workout entries.")
                                .font(.footnote)
                                .foregroundStyle(FocusPalette.textSecondary)
                            Button("Build PDF") {
                                let data = PDFExportService.buildProgressPDF(
                                    profile: profile,
                                    mealPlan: meal,
                                    nutritionLogs: nutrition,
                                    weightEntries: weights,
                                    workoutSessions: sessions
                                )
                                let name = "HealthProgress-\(Int(Date().timeIntervalSince1970)).pdf"
                                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                                try? data.write(to: url)
                                shareURL = url
                                showShare = true
                            }
                            .buttonStyle(FocusPrimaryButtonStyle())
                        }
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync (coming next)")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("Stable user id on this install: \(UserAccountService.stableUserId.uuidString). Wire this to Supabase or Firebase so the web app reads the same rows.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle("Share")
            .sheet(isPresented: $showShare, onDismiss: { shareURL = nil }) {
                Group {
                    if let shareURL {
                        ShareSheet(items: [shareURL])
                    } else {
                        Text("Could not build share file.")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
