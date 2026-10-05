import Foundation

/// Dates as the All Hours API speaks them.
enum APIDate {
    private static let local: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let zoned: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Parses "2026-10-05T08:03:12", "…12.1234567", "…Z" or "…+02:00".
    /// Timestamps without a zone are local time, which is how the web app reads them too.
    static func parse(_ string: String?) -> Date? {
        guard var string, string.count >= 19 else { return nil }
        string = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        let date = string.count > 19 ? zoned.date(from: string) : local.date(from: string)
        guard let date, Calendar.current.component(.year, from: date) > 1 else { return nil }
        return date
    }

    static func string(_ date: Date) -> String {
        local.timeZone = .current
        return local.string(from: date)
    }
}

enum Fmt {
    /// "6h 05m", "42m"
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m" : "\(minutes)m"
    }

    /// "6:05" — compact form for the menu bar.
    static func clock(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    /// "+3h 20m" / "−45m"
    static func signedMinutes(_ minutes: Int) -> String {
        (minutes < 0 ? "−" : "+") + duration(TimeInterval(abs(minutes) * 60))
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "08:03", "yesterday 17:02", "Fri 17:02"
    static func moment(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return time(date) }
        if calendar.isDateInYesterday(date) { return "yesterday \(time(date))" }
        return "\(date.formatted(.dateTime.weekday(.abbreviated))) \(time(date))"
    }

    static func today(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
