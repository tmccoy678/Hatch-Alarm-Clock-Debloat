import Foundation
import Testing
@testable import RoseControlCore

@Test("Light payload preserves remote audio and uses Hatch's 16-bit values")
func lightPayload() throws {
    let payload = RoseCommands.light(red: 255, green: 67, blue: 0, brightness: 62)
    let current = try #require(payload["current"] as? [String: Any])
    let color = try #require(current["color"] as? [String: Any])
    #expect(current["playing"] == nil)
    #expect(color["id"] as? Int == 9999)
    #expect(color["r"] as? Int == 65_535)
    #expect(color["g"] as? Int == 17_219)
    #expect(color["b"] as? Int == 0)
    #expect(color["i"] as? Int == 40_632)
    #expect(color["w"] as? Int == 0)
}

@Test("Turning on an idle light starts Restore remote mode")
func idleLightPayload() throws {
    let payload = RoseCommands.light(
        red: 255,
        green: 67,
        blue: 0,
        brightness: 20,
        activateRemoteMode: true
    )
    let current = try #require(payload["current"] as? [String: Any])
    #expect(current["playing"] as? String == "remote")
    #expect(current["srId"] as? Int == 0)
    #expect(current["step"] as? Int == 0)
    #expect(current["color"] as? [String: Any] != nil)
}

@Test("Light off does not stop a playing sound")
func lightOffPayload() throws {
    let payload = RoseCommands.lightOff()
    let current = try #require(payload["current"] as? [String: Any])
    let color = try #require(current["color"] as? [String: Any])
    #expect(current["playing"] == nil)
    #expect(color["id"] as? Int == 9998)
    #expect(color["r"] as? Int == 0)
    #expect(color["g"] as? Int == 0)
    #expect(color["b"] as? Int == 0)
    #expect(color["i"] as? Int == 0)
    #expect(color["w"] as? Int == 0)
}

@Test("Alarm repeat choices map to Hatch's weekday bit mask")
func alarmDayMasks() {
    #expect(AlarmDays.weekdays.hatchMask == 62)
    #expect(AlarmDays.weekends.hatchMask == 65)
    #expect(AlarmDays.everyDay.hatchMask == 127)
    #expect(AlarmDays.once.hatchMask == 0)
}

@Test("Alarm wake time keeps the existing sunrise lead")
func alarmWakeTime() throws {
    let alarm = HatchAlarm(
        id: 4,
        name: "Wake Up",
        active: true,
        enabled: false,
        type: "alarm",
        startTime: "2026-10-10 06:30:00",
        endTime: nil,
        daysOfWeek: 62,
        displayOrder: 0,
        steps: [HatchAlarmStep(name: "Sunrise", enabled: true, color: .init(duration: 1_800, ignore: false))]
    )
    let calendar = Calendar(identifier: .gregorian)
    let wake = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 7)))
    let start = AlarmTiming.startDate(for: wake, alarm: alarm)
    #expect(calendar.component(.hour, from: start) == 6)
    #expect(calendar.component(.minute, from: start) == 30)
}

@Test("Alarm display derives wake time from the sunrise start")
func alarmDisplayedWakeTime() throws {
    let calendar = Calendar(identifier: .gregorian)
    let alarm = HatchAlarm(
        id: 4,
        name: "Wake Up",
        active: true,
        enabled: true,
        type: "alarm",
        startTime: "2026-10-12 06:40:00",
        endTime: nil,
        daysOfWeek: 62,
        displayOrder: 0,
        steps: [HatchAlarmStep(name: "Sunrise", enabled: true, color: .init(duration: 1_200, ignore: false))]
    )
    let wake = try #require(AlarmTiming.wakeDate(for: alarm))
    #expect(calendar.component(.hour, from: wake) == 7)
    #expect(calendar.component(.minute, from: wake) == 0)
}

@Test("Alarm display treats endTime as the explicit wake time")
func alarmExplicitWakeTime() throws {
    let calendar = Calendar(identifier: .gregorian)
    let alarm = HatchAlarm(
        id: 4,
        name: "Wake Up",
        active: true,
        enabled: true,
        type: "alarm",
        startTime: "2026-10-12 06:40:00",
        endTime: "2026-10-12 07:00:00",
        daysOfWeek: 62,
        displayOrder: 0,
        steps: [HatchAlarmStep(name: "Sunrise", enabled: true, color: .init(duration: 1_200, ignore: false))]
    )
    let wake = try #require(AlarmTiming.wakeDate(for: alarm))
    #expect(calendar.component(.hour, from: wake) == 7)
    #expect(calendar.component(.minute, from: wake) == 0)
}

@Test("Free sound payload includes the catalog URL required by Restore 2")
func soundPayload() throws {
    let sound = HatchSound(id: 11, title: "Ocean", tier: "free", wavUrl: "https://example.test/ocean.wav")
    let payload = try RoseCommands.sound(sound, volume: 9)
    let current = try #require(payload["current"] as? [String: Any])
    let encoded = try #require(current["sound"] as? [String: Any])
    #expect(current["playing"] as? String == "remote")
    #expect(current["srId"] == nil)
    #expect(current["step"] == nil)
    #expect(encoded["id"] as? Int == 11)
    #expect(encoded["url"] as? String == "https://example.test/ocean.wav")
    #expect(encoded["v"] as? Int == 5_898)
    #expect(encoded["mute"] as? Bool == false)
    #expect(encoded["duration"] as? Int == 0)
    #expect(encoded["until"] as? String == "indefinite")
}

@Test("Sound and volume changes preserve the current light")
func soundControlsPreserveLight() throws {
    let light = RoseLightSnapshot(
        isOn: true,
        colorID: 10_321,
        red: 65_535,
        green: 20_046,
        blue: 23_645,
        white: 17_000,
        intensity: 41_287
    )
    let selected = HatchSound(
        id: 11,
        title: "Ocean",
        tier: "free",
        wavUrl: "https://example.test/ocean.wav"
    )

    for payload in [
        RoseCommands.volume(22, preserving: light),
        try RoseCommands.sound(selected, volume: 22, preserving: light),
    ] {
        let current = try #require(payload["current"] as? [String: Any])
        let color = try #require(current["color"] as? [String: Any])
        #expect(color["id"] as? Int == 10_321)
        #expect(color["r"] as? Int == 65_535)
        #expect(color["g"] as? Int == 20_046)
        #expect(color["b"] as? Int == 23_645)
        #expect(color["w"] as? Int == 17_000)
        #expect(color["i"] as? Int == 41_287)
    }
}

@Test("Custom audio accepts web URLs and rejects local file paths")
func customAudioPayload() throws {
    let payload = try RoseCommands.customAudio(
        url: "https://media.example.test/my-song.mp3",
        volume: 18
    )
    let current = try #require(payload["current"] as? [String: Any])
    let sound = try #require(current["sound"] as? [String: Any])
    #expect(current["playing"] as? String == "remote")
    #expect(sound["url"] as? String == "https://media.example.test/my-song.mp3")
    #expect(sound["id"] == nil)
    #expect(throws: RoseCommandError.self) {
        try RoseCommands.customAudio(url: "file:///private/song.m4a", volume: 18)
    }
}

@Test("Radio catalog exposes stable direct HTTPS streams")
func radioCatalog() throws {
    let stations = RadioCatalog.favorites
    #expect(stations.map(\.name) == ["Z104.1", "ABC Oldies"])
    #expect(stations.map(\.format) == [.aac, .mp3])
    for station in stations {
        let url = try #require(URL(string: station.streamURL))
        #expect(url.scheme == "https")
        #expect(url.host != nil)
    }
}

@Test("Stop sound ends playback before restoring the light silently")
func stopSoundSequence() throws {
    let light = RoseLightSnapshot(
        isOn: true,
        colorID: RoseCommands.customColorID,
        red: 65_535,
        green: 36_494,
        blue: 15_931,
        white: 0,
        intensity: 42_598
    )

    let sequence = RoseCommands.stopSoundSequence(volume: 45, preserving: light)
    #expect(sequence.count == 2)

    let stop = try #require(sequence.first?["current"] as? [String: Any])
    #expect(stop["playing"] as? String == "none")
    #expect(stop["srId"] as? Int == 0)
    #expect(stop["step"] as? Int == 0)

    let restore = try #require(sequence.last?["current"] as? [String: Any])
    let sound = try #require(restore["sound"] as? [String: Any])
    let color = try #require(restore["color"] as? [String: Any])

    #expect(restore["playing"] as? String == "remote")
    #expect(sound["id"] as? Int == 0)
    #expect(sound["mute"] as? Bool == true)
    #expect(sound["url"] as? String == "")
    #expect(sound["v"] as? Int == RoseCommands.percent(45))
    #expect(color["id"] as? Int == RoseCommands.customColorID)
    #expect(color["i"] as? Int == 42_598)
}
