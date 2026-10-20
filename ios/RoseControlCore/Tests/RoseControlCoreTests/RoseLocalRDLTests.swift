import Foundation
import Testing
@testable import RoseControlCore

@Test("Local alarm payload uses Aster's firmware envelope and native RDL schema")
func localAlarmPayload() throws {
    let calendar = Calendar(identifier: .gregorian)
    let wake = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 10,
        day: 13,
        hour: 7,
        minute: 15
    )))
    let alarm = RoseLocalRDL.defaultAlarm(at: wake)
    let sound = HatchSound(
        id: 10_173,
        title: "Morning Birds",
        tier: "free",
        wavUrl: "//images.hatchbaby.com/content/sounds/morning-birds.wav"
    )
    let settings = AlarmSettings(
        enabled: true,
        wakeTime: wake,
        days: .weekdays,
        sunriseEnabled: true,
        sunriseDurationMinutes: 20,
        sunriseRed: 255,
        sunriseGreen: 78,
        sunriseBlue: 92,
        sunriseBrightness: 70,
        sound: sound,
        volume: 35
    )

    let data = try RoseLocalRDL.payload(
        alarm: alarm,
        settings: settings,
        dataVersion: "20261012123456789",
        now: wake.addingTimeInterval(-3_600)
    )
    #expect(Array(data.prefix(4)) == Array(#"{"_a"#.utf8))

    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["_aster"] as? Int == 1)
    #expect(object["dataVersion"] as? String == "20261012123456789")
    #expect((object["favorites"] as? [Any])?.isEmpty == true)
    #expect((object["delete"] as? [Any])?.isEmpty == true)
    #expect(object["sleepSceneId"] is NSNull)

    let routines = try #require(object["routines"] as? [[String: Any]])
    #expect(routines.count == 1)
    #expect(routines[0]["id"] as? Int == alarm.id)
    let steps = try #require(routines[0]["steps"] as? [[String: Any]])
    #expect(steps.count == 2)
    let sunriseColor = try #require(steps[0]["color"] as? [String: Any])
    let sunriseSeries = try #require(sunriseColor["series"] as? [[String: Any]])
    #expect(sunriseColor["until"] as? String == "duration")
    #expect(sunriseSeries[0]["duration"] as? Int == 1_200)
    #expect(sunriseSeries[0]["r"] as? Int == 65_535)

    let wakeSound = try #require(steps[1]["sound"] as? [String: Any])
    #expect(wakeSound["id"] as? Int == 10_173)
    #expect(wakeSound["url"] as? String == "https://images.hatchbaby.com/content/sounds/morning-birds.wav")
    #expect(wakeSound["v"] as? Int == 22_937)

    let triggers = try #require(object["triggers"] as? [[String: Any]])
    #expect(triggers.count == 1)
    #expect(triggers[0]["routineId"] as? Int == alarm.id)
    #expect(triggers[0]["daysOfWeek"] as? Int == AlarmDays.weekdays.hatchMask)
    #expect(triggers[0]["displayTime"] as? String == "07:15")
    #expect(triggers[0]["startTime"] as? String == "2026-10-13 06:55")
    #expect(triggers[0]["interrupt"] as? Bool == true)
}

@Test("Disabling the alarm removes its local trigger but keeps an editable routine")
func disabledLocalAlarmHasNoTrigger() throws {
    let wake = Date(timeIntervalSince1970: 1_800_000_000)
    let alarm = RoseLocalRDL.defaultAlarm(at: wake)
    let settings = AlarmSettings(
        enabled: false,
        wakeTime: wake,
        days: .once,
        sunriseEnabled: false,
        sunriseDurationMinutes: 20,
        sunriseRed: 255,
        sunriseGreen: 78,
        sunriseBlue: 92,
        sunriseBrightness: 70,
        soundEnabled: false,
        sound: nil,
        volume: 35
    )

    let data = try RoseLocalRDL.payload(
        alarm: alarm,
        settings: settings,
        dataVersion: "20261012123456790",
        now: wake.addingTimeInterval(-3_600)
    )
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect((object["triggers"] as? [Any])?.isEmpty == true)
    #expect((object["routines"] as? [Any])?.count == 1)

    let updated = RoseLocalRDL.updatedAlarm(alarm, settings: settings, now: wake.addingTimeInterval(-3_600))
    #expect(updated.enabled == false)
    #expect(updated.steps?.count == 2)
    #expect(updated.steps?.last?.sound?.ignore == true)
}

@Test("Local alarm data versions use the firmware's 17 digit format")
func localAlarmDataVersion() throws {
    let calendar = Calendar(identifier: .gregorian)
    let date = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 10,
        day: 12,
        hour: 15,
        minute: 4,
        second: 5,
        nanosecond: 123_000_000
    )))
    let value = RoseLocalRDL.dataVersion(at: date)
    #expect(value.count == 17)
    #expect(value.allSatisfy { $0.isNumber })
}
