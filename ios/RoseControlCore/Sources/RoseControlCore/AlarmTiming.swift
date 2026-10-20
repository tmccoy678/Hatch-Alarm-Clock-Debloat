import Foundation

public enum AlarmTiming {
    public static func startDate(for wakeTime: Date, alarm: HatchAlarm) -> Date {
        wakeTime.addingTimeInterval(-sunriseLead(for: alarm))
    }

    public static func sunriseLead(for alarm: HatchAlarm) -> TimeInterval {
        let candidates = alarm.steps ?? []
        let sunrise = candidates.first {
            $0.enabled != false &&
            $0.color?.ignore != true &&
            ($0.color?.duration ?? 0) > 0 &&
            $0.name?.localizedCaseInsensitiveCompare("Sunrise") == .orderedSame
        }
        let fallback = candidates.first {
            $0.enabled != false && $0.color?.ignore != true && ($0.color?.duration ?? 0) > 0
        }
        return TimeInterval(sunrise?.color?.duration ?? fallback?.color?.duration ?? 0)
    }

    public static func wakeDate(for alarm: HatchAlarm) -> Date? {
        if let endTime = alarm.endTime, let end = parse(endTime) {
            return end
        }
        guard let startTime = alarm.startTime, let start = parse(startTime) else {
            return nil
        }
        return start.addingTimeInterval(sunriseLead(for: alarm))
    }

    private static func parse(_ value: String) -> Date? {
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return ISO8601DateFormatter().date(from: value)
    }
}
