import Foundation

public struct HatchSound: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let tier: String?
    public let wavUrl: String?
    public let contentfulId: String?

    public init(
        id: Int,
        title: String,
        tier: String? = nil,
        wavUrl: String? = nil,
        contentfulId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.tier = tier
        self.wavUrl = wavUrl
        self.contentfulId = contentfulId
    }
}

public struct HatchAlarm: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String?
    public let active: Bool?
    public let enabled: Bool?
    public let type: String?
    public let startTime: String?
    public let endTime: String?
    public let daysOfWeek: Int?
    public let displayOrder: Int?
    public let steps: [HatchAlarmStep]?

    public init(
        id: Int,
        name: String?,
        active: Bool?,
        enabled: Bool?,
        type: String?,
        startTime: String?,
        endTime: String?,
        daysOfWeek: Int?,
        displayOrder: Int?,
        steps: [HatchAlarmStep]? = nil
    ) {
        self.id = id
        self.name = name
        self.active = active
        self.enabled = enabled
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.displayOrder = displayOrder
        self.steps = steps
    }
}

public struct HatchAlarmStep: Codable, Equatable, Sendable {
    public let id: Int?
    public let name: String?
    public let enabled: Bool?
    public let type: String?
    public let dayOffset: Int?
    public let appStepId: Int?
    public let mixId: Int?
    public let respectColorUrl: Bool?
    public let color: HatchAlarmColor?
    public let sound: HatchAlarmSound?

    public init(
        id: Int? = nil,
        name: String?,
        enabled: Bool?,
        type: String? = nil,
        dayOffset: Int? = nil,
        appStepId: Int? = nil,
        mixId: Int? = nil,
        respectColorUrl: Bool? = nil,
        color: HatchAlarmColor?,
        sound: HatchAlarmSound? = nil
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.type = type
        self.dayOffset = dayOffset
        self.appStepId = appStepId
        self.mixId = mixId
        self.respectColorUrl = respectColorUrl
        self.color = color
        self.sound = sound
    }
}

public struct HatchAlarmColor: Codable, Equatable, Sendable {
    public let id: Int?
    public let red: Int?
    public let green: Int?
    public let blue: Int?
    public let white: Int?
    public let brightness: Int?
    public let duration: Int?
    public let until: String?
    public let ignore: Bool?
    public let contentfulId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case red = "r"
        case green = "g"
        case blue = "b"
        case white = "w"
        case brightness = "i"
        case duration
        case until
        case ignore
        case contentfulId
    }

    public init(
        id: Int? = nil,
        red: Int? = nil,
        green: Int? = nil,
        blue: Int? = nil,
        white: Int? = nil,
        brightness: Int? = nil,
        duration: Int?,
        until: String? = nil,
        ignore: Bool?,
        contentfulId: String? = nil
    ) {
        self.id = id
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
        self.brightness = brightness
        self.duration = duration
        self.until = until
        self.ignore = ignore
        self.contentfulId = contentfulId
    }
}

public struct HatchAlarmSound: Codable, Equatable, Sendable {
    public let id: Int?
    public let duration: Int?
    public let volume: Int?
    public let ignore: Bool?
    public let until: String?
    public let contentfulId: String?
    public let url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case duration
        case volume = "v"
        case ignore
        case until
        case contentfulId
        case url
    }

    public init(
        id: Int? = nil,
        duration: Int? = nil,
        volume: Int? = nil,
        ignore: Bool? = nil,
        until: String? = nil,
        contentfulId: String? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.duration = duration
        self.volume = volume
        self.ignore = ignore
        self.until = until
        self.contentfulId = contentfulId
        self.url = url
    }
}
