import Foundation

enum CalendarDay {
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Monday = 0 ... Sunday = 6 when firstWeekday is Monday.
    static func planDayIndex(for date: Date) -> Int {
        let wd = calendar.component(.weekday, from: date)
        let mondayBased = (wd + 5) % 7
        return mondayBased
    }

    static func weekInterval(containing date: Date) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? date
        return DateInterval(start: start, end: end)
    }

    static func daysInWeek(containing date: Date) -> [Date] {
        let interval = weekInterval(containing: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    static func startOfMonth(containing date: Date) -> Date {
        let c = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: c) ?? startOfDay(date)
    }

    static func endOfMonth(containing date: Date) -> Date {
        let start = startOfMonth(containing: date)
        guard let next = calendar.date(byAdding: .month, value: 1, to: start) else { return start }
        guard let end = calendar.date(byAdding: .day, value: -1, to: next) else { return start }
        return startOfDay(end)
    }

    /// Every calendar day in `monthOfReference` (typically pass startOfMonth).
    static func daysInMonth(containing monthOfReference: Date) -> [Date] {
        let start = startOfMonth(containing: monthOfReference)
        let end = endOfMonth(containing: monthOfReference)
        var days: [Date] = []
        var d = start
        while d <= end {
            days.append(d)
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = startOfDay(next)
        }
        return days
    }

    static func isSameMonth(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, equalTo: b, toGranularity: .month)
    }
}
