import Foundation

public struct AlarmSettings: Sendable {
    public let enabled: Bool
    public let wakeTime: Date
    public let days: AlarmDays
    public let sunriseEnabled: Bool
    public let sunriseDurationMinutes: Int
    public let sunriseRed: Int
    public let sunriseGreen: Int
    public let sunriseBlue: Int
    public let sunriseBrightness: Int
    public let soundEnabled: Bool
    public let sound: HatchSound?
    public let volume: Int

    public init(
        enabled: Bool,
        wakeTime: Date,
        days: AlarmDays,
        sunriseEnabled: Bool,
        sunriseDurationMinutes: Int,
        sunriseRed: Int,
        sunriseGreen: Int,
        sunriseBlue: Int,
        sunriseBrightness: Int,
        soundEnabled: Bool = true,
        sound: HatchSound?,
        volume: Int
    ) {
        self.enabled = enabled
        self.wakeTime = wakeTime
        self.days = days
        self.sunriseEnabled = sunriseEnabled
        self.sunriseDurationMinutes = sunriseDurationMinutes
        self.sunriseRed = sunriseRed
        self.sunriseGreen = sunriseGreen
        self.sunriseBlue = sunriseBlue
        self.sunriseBrightness = sunriseBrightness
        self.soundEnabled = soundEnabled
        self.sound = sound
        self.volume = volume
    }
}
