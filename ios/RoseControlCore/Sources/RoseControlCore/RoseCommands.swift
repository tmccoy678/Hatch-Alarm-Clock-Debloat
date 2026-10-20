import Foundation

public struct RoseLightSnapshot: Equatable, Sendable {
    public let isOn: Bool
    public let colorID: Int
    public let red: Int
    public let green: Int
    public let blue: Int
    public let white: Int
    public let intensity: Int

    public init(
        isOn: Bool,
        colorID: Int,
        red: Int,
        green: Int,
        blue: Int,
        white: Int,
        intensity: Int
    ) {
        self.isOn = isOn
        self.colorID = colorID
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
        self.intensity = intensity
    }
}

public enum RoseCommands {
    public static let noColorID = 9_998
    public static let customColorID = 9_999

    public static func light(
        red: Int,
        green: Int,
        blue: Int,
        brightness: Int,
        activateRemoteMode: Bool = false
    ) -> [String: Any] {
        var current: [String: Any] = [
            "color": [
                "id": customColorID,
                "r": channel(red),
                "g": channel(green),
                "b": channel(blue),
                "i": percent(brightness),
                "w": 0,
            ]
        ]
        if activateRemoteMode {
            current["srId"] = 0
            current["step"] = 0
            current["playing"] = "remote"
        }
        return ["current": current]
    }

    public static func lightOff() -> [String: Any] {
        [
            "current": [
                "color": [
                    "id": noColorID,
                    "r": 0,
                    "g": 0,
                    "b": 0,
                    "i": 0,
                    "w": 0,
                ]
            ]
        ]
    }

    public static func volume(
        _ value: Int,
        preserving light: RoseLightSnapshot? = nil
    ) -> [String: Any] {
        var current: [String: Any] = ["sound": ["v": percent(value)]]
        if let light { current["color"] = color(light) }
        return ["current": current]
    }

    public static func sound(
        _ sound: HatchSound,
        volume: Int,
        preserving light: RoseLightSnapshot? = nil
    ) throws -> [String: Any] {
        guard let url = sound.wavUrl, !url.isEmpty else {
            throw RoseCommandError.soundHasNoURL
        }
        return [
            "current": remoteSound(
                id: sound.id,
                url: url,
                volume: volume,
                muted: false,
                preserving: light
            )
        ]
    }

    public static func customAudio(
        url value: String,
        volume: Int,
        preserving light: RoseLightSnapshot? = nil
    ) throws -> [String: Any] {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              (scheme == "https" || scheme == "http"),
              url.host != nil else {
            throw RoseCommandError.invalidAudioURL
        }
        return [
            "current": remoteSound(
                id: nil,
                url: url.absoluteString,
                volume: volume,
                muted: false,
                preserving: light
            )
        ]
    }

    public static func stopSoundSequence(
        volume: Int,
        preserving light: RoseLightSnapshot? = nil
    ) -> [[String: Any]] {
        var restore = remoteSound(
            id: 0,
            url: "",
            volume: volume,
            muted: true,
            preserving: light
        )
        restore["srId"] = 0
        restore["step"] = 0
        return [allOff(), ["current": restore]]
    }

    public static func allOff() -> [String: Any] {
        ["current": ["srId": 0, "step": 0, "playing": "none"]]
    }

    public static func percent(_ value: Int) -> Int {
        Int((Double(min(100, max(0, value))) / 100 * 65_535).rounded())
    }

    public static func channel(_ value: Int) -> Int {
        Int((Double(min(255, max(0, value))) / 255 * 65_535).rounded())
    }

    private static func color(_ light: RoseLightSnapshot) -> [String: Any] {
        guard light.isOn else {
            return [
                "id": noColorID,
                "r": 0,
                "g": 0,
                "b": 0,
                "i": 0,
                "w": 0,
            ]
        }
        return [
            "id": raw(light.colorID),
            "r": raw(light.red),
            "g": raw(light.green),
            "b": raw(light.blue),
            "i": raw(light.intensity),
            "w": raw(light.white),
        ]
    }

    private static func remoteSound(
        id: Int?,
        url: String,
        volume: Int,
        muted: Bool,
        preserving light: RoseLightSnapshot?
    ) -> [String: Any] {
        var sound: [String: Any] = [
            "mute": muted,
            "url": url,
            "v": percent(volume),
            "duration": 0,
            "until": "indefinite",
        ]
        if let id { sound["id"] = id }
        var current: [String: Any] = [
            "playing": "remote",
            "sound": sound,
        ]
        if let light { current["color"] = color(light) }
        return current
    }

    private static func raw(_ value: Int) -> Int {
        min(65_535, max(0, value))
    }
}

public enum RoseCommandError: LocalizedError {
    case soundHasNoURL
    case invalidAudioURL

    public var errorDescription: String? {
        switch self {
        case .soundHasNoURL: "This sound is missing its Restore 2 audio URL."
        case .invalidAudioURL: "Use a direct http or https link to an audio file."
        }
    }
}
