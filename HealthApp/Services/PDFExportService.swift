import Foundation
import UIKit

enum PDFExportService {
    private static let pageW: CGFloat = 612
    private static let pageH: CGFloat = 792
    private static let margin: CGFloat = 48
    private static let contentW: CGFloat = pageW - margin * 2
    private static let pageBreakY: CGFloat = 720

    static func buildProgressPDF(
        profile: UserHealthProfile?,
        mealPlan: MealPlanDTO?,
        nutritionLogs: [DailyNutritionLog],
        weightEntries: [DailyWeightEntry],
        workoutSessions: [WorkoutSessionLog],
        generatedAt: Date = .now
    ) -> Data {
        let goalCal = mealPlan?.targetDailyCalories
        let weekDays = CalendarDay.daysInWeek(containing: generatedAt)
        let nutByKey: [String: DailyNutritionLog] = Dictionary(uniqueKeysWithValues: nutritionLogs.map { ($0.dayKey, $0) })
        let wtByKey: [String: DailyWeightEntry] = Dictionary(uniqueKeysWithValues: weightEntries.map { ($0.dayKey, $0) })

        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        return pdf.pdfData { ctx in
            var state = PageState(y: margin, ctx: ctx)
            state.beginPageIfNeeded()

            let accent = UIColor(red: 0.92, green: 0.55, blue: 0.18, alpha: 1)
            let muted = UIColor.secondaryLabel
            let grid = UIColor(white: 0.75, alpha: 1)

            state.drawTitle("Health progress report", font: .boldSystemFont(ofSize: 22), color: accent)
            state.drawLine("Generated: \(formattedDateTime(generatedAt))", font: .systemFont(ofSize: 11), color: muted)
            state.advance(8)

            if let p = profile {
                state.drawHeading("Profile")
                state.drawLine(
                    "Age \(p.age) · \(Int(p.heightCm)) cm · \(String(format: "%.1f", p.weightKg)) kg · activity: \(p.activityLevelRaw)",
                    font: .systemFont(ofSize: 12)
                )
                state.drawLine("Stated goals: \(p.goals.joined(separator: ", "))", font: .systemFont(ofSize: 12))
                if !p.injuriesNotes.isEmpty {
                    state.drawLine("Injuries / constraints: \(p.injuriesNotes)", font: .systemFont(ofSize: 12))
                }
                state.advance(8)
            }

            let weekLabel = weekRangeLabel(weekDays)
            state.drawHeading("This week (\(weekLabel))")

            let trainingDays = Set(weekDays.filter { dayHasWorkoutLog($0, sessions: workoutSessions) }.map { DayKey.string(for: $0) }).count
            let weightDaysInWeek = weekDays.filter { wtByKey[DayKey.string(for: $0)] != nil }.count
            let calorieLogDays = weekDays.filter { (nutByKey[DayKey.string(for: $0)]?.caloriesIn ?? 0) > 0 }.count

            var calorieHits = 0
            var calorieLoggedCount = 0
            if let g = goalCal {
                for d in weekDays {
                    let k = DayKey.string(for: d)
                    guard let n = nutByKey[k], n.caloriesIn > 0 else { continue }
                    calorieLoggedCount += 1
                    let lo = Int(Double(g) * 0.85)
                    let hi = Int(Double(g) * 1.15)
                    if n.caloriesIn >= lo && n.caloriesIn <= hi { calorieHits += 1 }
                }
            }

            state.drawHeading("Weekly goals — results", size: 14)
            state.drawWeeklyGoalRow(
                title: "Training consistency (≥3 days with logged sets)",
                met: trainingDays >= 3,
                detail: "\(trainingDays) day(s) with workout logs this week."
            )
            state.drawWeeklyGoalRow(
                title: "Calorie awareness (log intake ≥4 days)",
                met: calorieLogDays >= 4,
                detail: "Logged calories on \(calorieLogDays) of 7 days."
            )
            if let g = goalCal, calorieLoggedCount > 0 {
                let ratioOk = Double(calorieHits) / Double(calorieLoggedCount) >= 0.75
                state.drawWeeklyGoalRow(
                    title: "Calorie target (±15%) on logged days (≥75% hit rate)",
                    met: ratioOk,
                    detail: "\(calorieHits) of \(calorieLoggedCount) logged day(s) within range of \(g) kcal."
                )
            }
            state.drawWeeklyGoalRow(
                title: "Weight tracking (≥3 entries this week)",
                met: weightDaysInWeek >= 3,
                detail: "Weight logged on \(weightDaysInWeek) day(s)."
            )
            state.advance(10)

            state.drawHeading("Daily breakdown", size: 14)
            state.drawLine("Calorie goal from plan: \(goalCal.map(String.init) ?? "—") kcal", font: .systemFont(ofSize: 11), color: muted)
            state.advance(4)

            let colW: [CGFloat] = [100, 88, 72, 88, 72]
            let headers = ["Date", "Calories", "Cal goal?", "Workout?", "Weight"]
            state.drawTableRow(strings: headers, fonts: Array(repeating: .boldSystemFont(ofSize: 9), count: 5), widths: colW, accent: accent)

            let df = DateFormatter()
            df.dateFormat = "EEE M/d"
            for d in weekDays {
                let k = DayKey.string(for: d)
                let nut = nutByKey[k]
                let calStr: String
                let calMet: String
                if let n = nut, n.caloriesIn > 0 {
                    calStr = "\(n.caloriesIn)"
                    if let g = goalCal {
                        let lo = Int(Double(g) * 0.85)
                        let hi = Int(Double(g) * 1.15)
                        calMet = n.caloriesIn >= lo && n.caloriesIn <= hi ? "Met" : "Miss"
                    } else {
                        calMet = "—"
                    }
                } else {
                    calStr = "—"
                    calMet = "N/A"
                }
                let wo = dayHasWorkoutLog(d, sessions: workoutSessions)
                let woStr = wo ? "Logged" : "—"
                let wStr = wtByKey[k].map { String(format: "%.1f kg", $0.weightKg) } ?? "—"
                state.drawTableRow(
                    strings: [df.string(from: d), calStr, calMet, woStr, wStr],
                    fonts: Array(repeating: .systemFont(ofSize: 9), count: 5),
                    widths: colW,
                    accent: accent
                )
            }
            state.advance(14)

            state.drawHeading("Weight progress", size: 14)
            let sortedW = weightEntries.sorted { $0.dayDate < $1.dayDate }
            if let first = sortedW.first, let last = sortedW.last {
                let delta = last.weightKg - first.weightKg
                state.drawLine(
                    "First logged: \(formattedDate(first.dayDate)) — \(fmtKg(first.weightKg))", font: .systemFont(ofSize: 11)
                )
                state.drawLine(
                    "Latest: \(formattedDate(last.dayDate)) — \(fmtKg(last.weightKg)) · change \(String(format: "%+.1f", delta)) kg",
                    font: .systemFont(ofSize: 11)
                )
            } else {
                state.drawLine("No weight entries yet.", font: .italicSystemFont(ofSize: 11), color: muted)
            }

            let weightPts = Array(sortedW.suffix(14)).map(\.weightKg)
            if weightPts.count >= 2 {
                state.ensureSpace(140)
                state.drawLine("Weight trend (up to last 14 entries)", font: .boldSystemFont(ofSize: 11))
                state.advance(4)
                let chartRect = CGRect(x: margin, y: state.y, width: contentW, height: 110)
                drawLineChart(
                    in: ctx.cgContext,
                    rect: chartRect,
                    values: weightPts,
                    lineColor: accent,
                    gridColor: grid
                )
                state.y = chartRect.maxY + 16
            }

            state.drawHeading("Calorie intake vs goal (this week)", size: 14)
            let calBars: [CGFloat] = weekDays.map { d in
                let k = DayKey.string(for: d)
                return CGFloat(nutByKey[k]?.caloriesIn ?? 0)
            }
            let maxCal = max(calBars.max() ?? 0, CGFloat(goalCal ?? 0) * 1.2, 1)
            state.ensureSpace(150)
            let barRect = CGRect(x: margin, y: state.y, width: contentW, height: 120)
            drawBarChartWithGoalLine(
                in: ctx.cgContext,
                rect: barRect,
                values: calBars,
                goal: goalCal.map { CGFloat($0) },
                barColor: accent,
                goalColor: UIColor.darkGray,
                gridColor: grid,
                labels: weekDays.map { d in
                    let f = DateFormatter()
                    f.dateFormat = "EEE"
                    return f.string(from: d)
                }
            )
            state.y = barRect.maxY + 28

            state.drawHeading("Recent workout logs", size: 14)
            let byDay = Dictionary(grouping: workoutSessions, by: { DayKey.string(for: $0.dayDate) })
            if byDay.isEmpty {
                state.drawLine("No workout sets logged yet.", font: .italicSystemFont(ofSize: 11), color: muted)
            } else {
                for k in byDay.keys.sorted().suffix(7) {
                    let sessions = (byDay[k] ?? []).sorted { $0.sortOrder < $1.sortOrder }
                    let title = sessions.first.map { formattedDate($0.dayDate) } ?? k
                    state.drawLine(title, font: .boldSystemFont(ofSize: 11))
                    for s in sessions {
                        let setsDesc = s.sets.sorted { $0.setIndex < $1.setIndex }
                            .map { "\($0.reps)×\(String(format: "%.1f", $0.weightKg))kg" }
                            .joined(separator: ", ")
                        state.drawLine("  · \(s.exerciseName): \(setsDesc)", font: .systemFont(ofSize: 10), color: .darkGray)
                    }
                }
            }

            state.advance(12)
            state.drawLine(
                "Disclaimer: This app provides general fitness and nutrition structure, not medical advice. Consult licensed professionals for individualized care.",
                font: .italicSystemFont(ofSize: 9),
                color: muted
            )
        }
    }

    private struct PageState {
        var y: CGFloat
        let ctx: UIGraphicsPDFRendererContext

        mutating func beginPageIfNeeded() {
            ctx.beginPage()
            y = PDFExportService.margin
        }

        mutating func ensureSpace(_ needed: CGFloat) {
            if y + needed > PDFExportService.pageBreakY {
                ctx.beginPage()
                y = PDFExportService.margin
            }
        }

        mutating func advance(_ dy: CGFloat) {
            y += dy
        }

        mutating func drawTitle(_ text: String, font: UIFont, color: UIColor) {
            drawLine(text, font: font, color: color)
        }

        mutating func drawHeading(_ text: String, size: CGFloat = 15) {
            ensureSpace(24)
            drawLine(text, font: .boldSystemFont(ofSize: size))
            advance(4)
        }

        mutating func drawLine(_ text: String, font: UIFont, color: UIColor = .label) {
            let w = PDFExportService.contentW
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let r = (text as NSString).boundingRect(
                with: CGSize(width: w, height: 2000),
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
            let h = ceil(r.height)
            ensureSpace(h + 8)
            (text as NSString).draw(
                in: CGRect(x: PDFExportService.margin, y: y, width: w, height: h),
                withAttributes: attrs
            )
            y += h + 6
        }

        mutating func drawWeeklyGoalRow(title: String, met: Bool, detail: String) {
            let status = met ? "Met" : "Not met"
            let color: UIColor = met ? .systemGreen : .systemOrange
            ensureSpace(36)
            let titleFont = UIFont.boldSystemFont(ofSize: 11)
            let bodyFont = UIFont.systemFont(ofSize: 10)
            let w = PDFExportService.contentW
            let t1 = "\(status) — \(title)" as NSString
            t1.draw(
                in: CGRect(x: PDFExportService.margin, y: y, width: w, height: 16),
                withAttributes: [.font: titleFont, .foregroundColor: color]
            )
            y += 16
            let t2 = detail as NSString
            let r2 = t2.boundingRect(
                with: CGSize(width: w, height: 500),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: bodyFont, .foregroundColor: UIColor.secondaryLabel],
                context: nil
            )
            t2.draw(
                in: CGRect(x: PDFExportService.margin, y: y, width: w, height: ceil(r2.height)),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.secondaryLabel]
            )
            y += ceil(r2.height) + 8
        }

        mutating func drawTableRow(strings: [String], fonts: [UIFont], widths: [CGFloat], accent: UIColor) {
            var x = PDFExportService.margin
            let rowH: CGFloat = 14
            ensureSpace(rowH + 4)
            for (i, s) in strings.enumerated() {
                let fw = i < widths.count ? widths[i] : 80
                (s as NSString).draw(
                    in: CGRect(x: x, y: y, width: fw, height: rowH),
                    withAttributes: [.font: fonts[i], .foregroundColor: UIColor.label]
                )
                x += fw + 4
            }
            y += rowH + 2
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor.separator.cgColor)
            cg.setLineWidth(0.5)
            cg.move(to: CGPoint(x: PDFExportService.margin, y: y))
            cg.addLine(to: CGPoint(x: PDFExportService.margin + PDFExportService.contentW, y: y))
            cg.strokePath()
            y += 4
        }
    }

    private static func dayHasWorkoutLog(_ day: Date, sessions: [WorkoutSessionLog]) -> Bool {
        let k = DayKey.string(for: day)
        return sessions.filter { $0.dayKey == k }.contains { s in
            s.sets.contains { $0.reps > 0 || $0.weightKg > 0 }
        }
    }

    private static func weekRangeLabel(_ days: [Date]) -> String {
        guard let a = days.first, let b = days.last else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: a)) – \(f.string(from: b))"
    }

    private static func drawLineChart(
        in cg: CGContext,
        rect: CGRect,
        values: [Double],
        lineColor: UIColor,
        gridColor: UIColor
    ) {
        guard values.count >= 2 else { return }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let span = max(maxV - minV, 0.5)

        cg.saveGState()
        cg.setStrokeColor(gridColor.cgColor)
        cg.setLineWidth(0.5)
        for i in 0...4 {
            let gy = rect.minY + CGFloat(i) / 4 * rect.height
            cg.move(to: CGPoint(x: rect.minX, y: gy))
            cg.addLine(to: CGPoint(x: rect.maxX, y: gy))
            cg.strokePath()
        }

        let n = values.count
        cg.setStrokeColor(lineColor.cgColor)
        cg.setLineWidth(2)
        cg.beginPath()
        for (i, v) in values.enumerated() {
            let t = CGFloat(i) / CGFloat(max(n - 1, 1))
            let px = rect.minX + t * rect.width
            let ny = CGFloat((v - minV) / span)
            let py = rect.maxY - ny * rect.height
            if i == 0 { cg.move(to: CGPoint(x: px, y: py)) }
            else { cg.addLine(to: CGPoint(x: px, y: py)) }
        }
        cg.strokePath()

        cg.setFillColor(lineColor.cgColor)
        for (i, v) in values.enumerated() {
            let t = CGFloat(i) / CGFloat(max(n - 1, 1))
            let px = rect.minX + t * rect.width
            let ny = CGFloat((v - minV) / span)
            let py = rect.maxY - ny * rect.height
            cg.fillEllipse(in: CGRect(x: px - 3, y: py - 3, width: 6, height: 6))
        }
        cg.restoreGState()
    }

    private static func drawBarChartWithGoalLine(
        in cg: CGContext,
        rect: CGRect,
        values: [CGFloat],
        goal: CGFloat?,
        barColor: UIColor,
        goalColor: UIColor,
        gridColor: UIColor,
        labels: [String]
    ) {
        let maxV = max(values.max() ?? 0, goal ?? 0, 1)
        let count = values.count
        guard count > 0 else { return }
        let barW = (rect.width - CGFloat(count + 1) * 4) / CGFloat(count)

        cg.saveGState()
        cg.setStrokeColor(gridColor.cgColor)
        cg.setLineWidth(0.5)
        cg.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        cg.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        cg.strokePath()

        if let g = goal, g > 0 {
            let gy = rect.maxY - (g / maxV) * rect.height
            cg.setStrokeColor(goalColor.cgColor)
            cg.setLineDash(phase: 0, lengths: [4, 4])
            cg.setLineWidth(1)
            cg.move(to: CGPoint(x: rect.minX, y: gy))
            cg.addLine(to: CGPoint(x: rect.maxX, y: gy))
            cg.strokePath()
            cg.setLineDash(phase: 0, lengths: [])
        }

        cg.setFillColor(barColor.withAlphaComponent(0.85).cgColor)
        for (i, v) in values.enumerated() {
            let x = rect.minX + 4 + CGFloat(i) * (barW + 4)
            let h = (v / maxV) * rect.height
            cg.fill(CGRect(x: x, y: rect.maxY - h, width: barW, height: h))
        }

        let labelFont = UIFont.systemFont(ofSize: 8)
        for (i, lab) in labels.enumerated() where i < count {
            let x = rect.minX + 4 + CGFloat(i) * (barW + 4)
            (lab as NSString).draw(
                in: CGRect(x: x, y: rect.maxY + 4, width: barW, height: 12),
                withAttributes: [.font: labelFont, .foregroundColor: UIColor.secondaryLabel]
            )
        }
        cg.restoreGState()
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
