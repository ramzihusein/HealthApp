import SwiftUI
import SwiftData

private struct PDFShareDocument: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareExportView: View {
    @Query private var profiles: [UserHealthProfile]
    @Query(sort: \StoredGeneratedPlans.generatedAt, order: .reverse) private var plans: [StoredGeneratedPlans]
    @Query(sort: \DailyNutritionLog.dayDate) private var nutrition: [DailyNutritionLog]
    @Query(sort: \DailyWeightEntry.dayDate) private var weights: [DailyWeightEntry]
    @Query private var sessions: [WorkoutSessionLog]
    @Query(sort: \CardioSessionLog.dayDate) private var cardioSessions: [CardioSessionLog]

    @State private var pdfShareDocument: PDFShareDocument?
    @State private var exportErrorMessage: String?

    private var profile: UserHealthProfile? { profiles.first }
    private var meal: MealPlanDTO? {
        guard let p = plans.first else { return nil }
        return try? PlanCodec.decodeMeal(from: p.mealJSON)
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
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
                            Text("Creates a multi-page PDF: weekly goals (met / not met), daily calorie and workout status, weight trend chart, calorie bar chart for the week, and recent strength plus cardio logs. Data comes from logs saved on this device.")
                                .font(.footnote)
                                .foregroundStyle(FocusPalette.textSecondary)
                            Button("Build PDF") {
                                buildAndSharePDF()
                            }
                            .buttonStyle(FocusPrimaryButtonStyle())
                        }
                    }

                    FocusCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync (coming next)")
                                .font(.headline)
                                .foregroundStyle(FocusPalette.textPrimary)
                            Text("Stable user id on this install: \(UserAccountService.stableUserId.uuidString). OpenAI-style keys live in Settings (UserDefaults on device). Wire this user id to Supabase or Firebase so the web app reads the same rows.")
                                .font(.caption)
                                .foregroundStyle(FocusPalette.textSecondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(FocusScreenBackground())
            .navigationTitle("Share")
            .sheet(item: $pdfShareDocument) { doc in
                ShareSheet(items: [doc.url])
            }
            .alert("Could not export", isPresented: exportErrorBinding) {
                Button("OK", role: .cancel) { exportErrorMessage = nil }
            } message: {
                Text(exportErrorMessage ?? "")
            }
        }
    }

    private func buildAndSharePDF() {
        exportErrorMessage = nil
        let data = PDFExportService.buildProgressPDF(
            profile: profile,
            mealPlan: meal,
            nutritionLogs: nutrition,
            weightEntries: weights,
            workoutSessions: sessions,
            cardioSessions: cardioSessions
        )
        guard !data.isEmpty else {
            exportErrorMessage = "The PDF could not be generated."
            return
        }
        let name = "HealthProgress-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            guard FileManager.default.fileExists(atPath: url.path) else {
                exportErrorMessage = "The PDF file could not be saved."
                return
            }
            pdfShareDocument = PDFShareDocument(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
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
