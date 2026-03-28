import Foundation

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = CalendarDay.calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(for date: Date) -> String {
        formatter.string(from: CalendarDay.startOfDay(date))
    }
}
