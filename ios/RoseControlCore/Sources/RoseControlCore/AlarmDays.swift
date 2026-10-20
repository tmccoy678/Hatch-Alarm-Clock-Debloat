import Foundation

public enum AlarmDays: String, CaseIterable, Codable, Identifiable, Sendable {
    case once = "Once"
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    case everyDay = "Every day"

    public var id: String { rawValue }

    public var hatchMask: Int {
        switch self {
        case .once: 0
        case .weekdays: 2 | 4 | 8 | 16 | 32
        case .weekends: 1 | 64
        case .everyDay: 1 | 2 | 4 | 8 | 16 | 32 | 64
        }
    }

    public init(hatchMask: Int?) {
        self = Self.allCases.first { $0.hatchMask == (hatchMask ?? 0) } ?? .once
    }
}
