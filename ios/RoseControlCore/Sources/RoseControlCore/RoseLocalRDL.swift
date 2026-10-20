import Foundation

public enum RoseLocalRDL {
    public static let markerKey = "_aster"
    public static let noSoundID = 19_998
    public static let noSoundURL = "https://images.hatchbaby.com/content/sounds/noSound.wav"

    public static func payload(
        alarm: HatchAlarm,
        settings: AlarmSettings,
        dataVersion: String = dataVersion(),
        now: Date = Date()
    ) throws -> Data {
        guard dataVersion.count == 17, dataVersion.allSatisfy(\.isNumber) else {
            throw RoseLocalRDLError.invalidDataVersion
        }

        let wake = nextWakeDate(for: settings.wakeTime, after: now)
        let sunriseSeconds = settings.sunriseEnabled
            ? max(0, settings.sunriseDurationMinutes) * 60
            : 0
        let start = wake.addingTimeInterval(TimeInterval(-sunriseSeconds))
        var steps: [[String: Any]] = []

        if settings.sunriseEnabled {
            steps.append([
                "rdl": [],
                "color": color(
                    id: RoseCommands.customColorID,
                    red: RoseCommands.channel(settings.sunriseRed),
                    green: RoseCommands.channel(settings.sunriseGreen),
                    blue: RoseCommands.channel(settings.sunriseBlue),
                    brightness: RoseCommands.percent(settings.sunriseBrightness),
                    duration: sunriseSeconds
                ),
                "sound": sound(
                    id: noSoundID,
                    url: noSoundURL,
                    volume: 0,
                    duration: sunriseSeconds
                ),
            ])
        }

        steps.append([
            "rdl": [],
            "color": color(
                id: RoseCommands.noColorID,
                red: 0,
                green: 0,
                blue: 0,
                brightness: 0,
                duration: 3_600
            ),
            "sound": try wakeSound(settings: settings),
        ])

        var triggers: [[String: Any]] = []
        if settings.enabled {
            triggers.append([
                "startTime": localMinute.string(from: start),
                "displayTime": localTime.string(from: wake),
                "routineId": alarm.id,
                "daysOfWeek": settings.days.hatchMask,
                "interrupt": true,
            ])
        }

        let document: [String: Any] = [
            markerKey: 1,
            "dataVersion": dataVersion,
            "delete": [],
            "favorites": [],
            "controls": ["button_0": []],
            "sleepSceneId": NSNull(),
            "routines": [[
                "id": alarm.id,
                "replaces": NSNull(),
                "steps": steps,
            ]],
            "triggers": triggers,
        ]
        return try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
    }

    public static func updatedAlarm(
        _ alarm: HatchAlarm,
        settings: AlarmSettings,
        now: Date = Date()
    ) -> HatchAlarm {
        let wake = nextWakeDate(for: settings.wakeTime, after: now)
        let sunriseSeconds = settings.sunriseEnabled
            ? max(0, settings.sunriseDurationMinutes) * 60
            : 0
        let start = wake.addingTimeInterval(TimeInterval(-sunriseSeconds))
        let sunrise = HatchAlarmStep(
            name: "Sunrise",
            enabled: settings.sunriseEnabled,
            type: "basic",
            color: HatchAlarmColor(
                id: RoseCommands.customColorID,
                red: RoseCommands.channel(settings.sunriseRed),
                green: RoseCommands.channel(settings.sunriseGreen),
                blue: RoseCommands.channel(settings.sunriseBlue),
                white: 0,
                brightness: RoseCommands.percent(settings.sunriseBrightness),
                duration: sunriseSeconds,
                until: "duration",
                ignore: !settings.sunriseEnabled
            ),
            sound: HatchAlarmSound(
                id: noSoundID,
                duration: sunriseSeconds,
                volume: 0,
                ignore: true,
                until: "duration",
                url: noSoundURL
            )
        )
        let wakeStep = HatchAlarmStep(
            name: "Alarm",
            enabled: true,
            type: "basic",
            color: HatchAlarmColor(
                id: RoseCommands.noColorID,
                red: 0,
                green: 0,
                blue: 0,
                white: 0,
                brightness: 0,
                duration: 3_600,
                until: "duration",
                ignore: true
            ),
            sound: HatchAlarmSound(
                id: settings.soundEnabled ? settings.sound?.id : noSoundID,
                duration: 3_600,
                volume: settings.soundEnabled ? RoseCommands.percent(settings.volume) : 0,
                ignore: !settings.soundEnabled,
                until: "duration",
                contentfulId: settings.sound?.contentfulId,
                url: settings.soundEnabled ? normalizedURL(settings.sound?.wavUrl) : noSoundURL
            )
        )
        return HatchAlarm(
            id: alarm.id,
            name: alarm.name ?? "Wake Up",
            active: true,
            enabled: settings.enabled,
            type: "alarm",
            startTime: localSecond.string(from: start),
            endTime: localSecond.string(from: wake),
            daysOfWeek: settings.days.hatchMask,
            displayOrder: alarm.displayOrder ?? 0,
            steps: [sunrise, wakeStep]
        )
    }

    public static func defaultAlarm(at date: Date = Date()) -> HatchAlarm {
        let calendar = Calendar.current
        let wake = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date) ?? date
        return HatchAlarm(
            id: 1,
            name: "Wake Up",
            active: true,
            enabled: false,
            type: "alarm",
            startTime: localSecond.string(from: wake),
            endTime: localSecond.string(from: wake),
            daysOfWeek: AlarmDays.once.hatchMask,
            displayOrder: 0,
            steps: []
        )
    }

    public static func dataVersion(at date: Date = Date()) -> String {
        versionDate.string(from: date)
    }

    private static func wakeSound(settings: AlarmSettings) throws -> [String: Any] {
        guard settings.soundEnabled else {
            return sound(id: noSoundID, url: noSoundURL, volume: 0, duration: 3_600)
        }
        guard let selected = settings.sound,
              let url = normalizedURL(selected.wavUrl) else {
            throw RoseLocalRDLError.soundHasNoURL
        }
        return sound(
            id: selected.id,
            url: url,
            volume: RoseCommands.percent(settings.volume),
            duration: 3_600
        )
    }

    private static func color(
        id: Int,
        red: Int,
        green: Int,
        blue: Int,
        brightness: Int,
        duration: Int
    ) -> [String: Any] {
        [
            "id": id,
            "i": brightness,
            "until": "duration",
            "series": [[
                "r": red,
                "g": green,
                "b": blue,
                "w": 0,
                "duration": duration,
            ]],
        ]
    }

    private static func sound(id: Int, url: String, volume: Int, duration: Int) -> [String: Any] {
        [
            "id": id,
            "v": volume,
            "url": url,
            "duration": duration,
            "until": "duration",
            "playlist": [],
        ]
    }

    private static func nextWakeDate(for selected: Date, after now: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: selected)
        return calendar.nextDate(
            after: now.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTime
        ) ?? selected
    }

    private static func normalizedURL(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value.hasPrefix("//") ? "https:\(value)" : value
    }

    private static let localMinute = formatter("yyyy-MM-dd HH:mm")
    private static let localSecond = formatter("yyyy-MM-dd HH:mm:ss")
    private static let localTime = formatter("HH:mm")
    private static let versionDate = formatter("yyyyMMddHHmmssSSS")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}

public enum RoseLocalRDLError: LocalizedError {
    case invalidDataVersion
    case soundHasNoURL

    public var errorDescription: String? {
        switch self {
        case .invalidDataVersion:
            "The local alarm database version must contain exactly 17 digits."
        case .soundHasNoURL:
            "Choose an included Rose sound with a playable audio URL."
        }
    }
}
