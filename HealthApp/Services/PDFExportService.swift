import Foundation
import UIKit

enum PDFExportService {
    static func buildProgressPDF(
        profile: UserHealthProfile?,
        mealPlan: MealPlanDTO?,
        nutritionLogs: [DailyNutritionLog],
        weightEntries: [DailyWeightEntry],
        workoutSessions: [WorkoutSessionLog],
        generatedAt: Date = .now
    ) -> Data {
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let sortedNutrition = nutritionLogs.sorted { $0.dayDate < $1.dayDate }
        let sortedWeight = weightEntries.sorted { $0.dayDate < $1.dayDate }
        let goalCal = mealPlan?.targetDailyCalories

        let data = pdf.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 48
            let left: CGFloat = 48
            let width = 612 - left * 2

            func draw(_ text: String, font: UIFont, color: UIColor = .label) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let r = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: 1000),
                    options: [.usesLineFragmentOrigin],
                    attributes: attrs,
                    context: nil
                )
                (text as NSString).draw(in: CGRect(x: left, y: y, width: width, height: ceil(r.height)), withAttributes: attrs)
                y += ceil(r.height) + 8
            }

            draw("Health progress report", font: .boldSystemFont(ofSize: 22), color: UIColor(red: 0.92, green: 0.55, blue: 0.18, alpha: 1))
            draw("Generated: \(formattedDateTime(generatedAt))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 8

            if let p = profile {
                draw("Profile", font: .boldSystemFont(ofSize: 15))
                draw(
                    "Age \(p.age) · \(Int(p.heightCm)) cm · \(String(format: "%.1f", p.weightKg)) kg · activity: \(p.activityLevelRaw)",
                    font: .systemFont(ofSize: 12)
                )
                draw("Goals: \(p.goals.joined(separator: ", "))", font: .systemFont(ofSize: 12))
                if !p.injuriesNotes.isEmpty {
                    draw("Injuries / constraints: \(p.injuriesNotes)", font: .systemFont(ofSize: 12))
                }
                y += 8
            }

            if let g = goalCal {
                draw("Nutrition goal", font: .boldSystemFont(ofSize: 15))
                draw("Target average daily calories (from plan): \(g)", font: .systemFont(ofSize: 12))
                let recent = sortedNutrition.suffix(14)
                if recent.isEmpty {
                    draw("No calorie logs yet in this export.", font: .italicSystemFont(ofSize: 11), color: .secondaryLabel)
                } else {
                    let avg = recent.map(\.caloriesIn).reduce(0, +) / max(recent.count, 1)
                    let met = avg <= Int(Double(g) * 1.08) && avg >= Int(Double(g) * 0.85)
                    draw(
                        "Last \(recent.count) days avg intake: \(avg) kcal — vs goal: \(met ? "roughly on track" : "review portions or goal")",
                        font: .systemFont(ofSize: 12)
                    )
                }
                y += 8
            }

            draw("Weight", font: .boldSystemFont(ofSize: 15))
            if let first = sortedWeight.first, let last = sortedWeight.last {
                let delta = last.weightKg - first.weightKg
                draw(
                    "From \(formattedDate(first.dayDate)) (\(fmtKg(first.weightKg))) → \(formattedDate(last.dayDate)) (\(fmtKg(last.weightKg))) · Δ \(String(format: "%+.1f", delta)) kg",
                    font: .systemFont(ofSize: 12)
                )
            } else {
                draw("No weight entries yet.", font: .italicSystemFont(ofSize: 11), color: .secondaryLabel)
            }
            y += 8

            draw("Workouts logged", font: .boldSystemFont(ofSize: 15))
            let byDay = Dictionary(grouping: workoutSessions, by: { DayKey.string(for: $0.dayDate) })
            if byDay.isEmpty {
                draw("No workout sets logged yet.", font: .italicSystemFont(ofSize: 11), color: .secondaryLabel)
            } else {
                let keys = byDay.keys.sorted()
                for k in keys.suffix(10) {
                    let sessions = (byDay[k] ?? []).sorted { $0.sortOrder < $1.sortOrder }
                    let title = sessions.first.map { formattedDate($0.dayDate) } ?? k
                    draw("\(title)", font: .boldSystemFont(ofSize: 12))
                    for s in sessions {
                        let setsDesc = s.sets.sorted { $0.setIndex < $1.setIndex }
                            .map { "\($0.reps)×\(String(format: "%.1f", $0.weightKg))kg" }
                            .joined(separator: ", ")
                        draw("· \(s.exerciseName): \(setsDesc)", font: .systemFont(ofSize: 11), color: .darkGray)
                    }
                }
            }

            y += 12
            draw(
                "Disclaimer: This app provides general fitness and nutrition structure, not medical advice. Consult licensed professionals for individualized care.",
                font: .italicSystemFont(ofSize: 9),
                color: .secondaryLabel
            )
        }
        return data
    }

    private static func formattedDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    private static func formattedDateTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }

    private static func fmtKg(_ v: Double) -> String {
        String(format: "%.1f kg", v)
    }
}
