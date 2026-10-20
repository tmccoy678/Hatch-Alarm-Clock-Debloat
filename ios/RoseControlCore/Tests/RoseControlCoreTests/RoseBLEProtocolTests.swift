import Foundation
import Testing
@testable import RoseControlCore

@Test("Restore 2 BLE UUIDs stay pinned to the observed service")
func restoreBLEUUIDs() {
    #expect(RoseBLEUUIDs.communicationService == "02340000-5EFD-47EB-9C1A-DE53F7A2B232")
    #expect(RoseBLEUUIDs.uartWrite == "02340001-5EFD-47EB-9C1A-DE53F7A2B232")
    #expect(RoseBLEUUIDs.uartRead == "02340002-5EFD-47EB-9C1A-DE53F7A2B232")
    #expect(RoseBLEUUIDs.jsonWrite == "02340003-5EFD-47EB-9C1A-DE53F7A2B232")
    #expect(RoseBLEUUIDs.jsonRead == "02340004-5EFD-47EB-9C1A-DE53F7A2B232")
}

@Test("UART color commands use the firmware's fixed-width hexadecimal format")
func uartColorCommands() throws {
    let raw = try RoseUARTCommand.rawColor(red: 255, green: 142, blue: 62, white: 0)
    let full = try RoseUARTCommand.fullColor(
        red: 255,
        green: 142,
        blue: 62,
        white: 0,
        intensity: 65
    )

    #expect(String(decoding: raw, as: UTF8.self) == "ScFF8E3E00")
    #expect(String(decoding: full, as: UTF8.self) == "SCFF8E3E0041")
}

@Test("UART percentage intensity maps the app scale onto the firmware byte")
func uartPercentageIntensity() throws {
    let full = try RoseUARTCommand.fullColor(
        red: 255,
        green: 142,
        blue: 62,
        white: 0,
        intensityPercent: 65
    )

    #expect(String(decoding: full, as: UTF8.self) == "SCFF8E3E00A6")
    #expect(throws: RoseBLEProtocolError.valueOutOfRange(field: "intensityPercent", value: 101)) {
        try RoseUARTCommand.fullColor(
            red: 0,
            green: 0,
            blue: 0,
            white: 0,
            intensityPercent: 101
        )
    }
}

@Test("UART volume uses a hexadecimal value and enforces the firmware range")
func uartVolumeCommand() throws {
    let volume = try RoseUARTCommand.volume(73)
    #expect(String(decoding: volume, as: UTF8.self) == "TMV49")

    #expect(throws: RoseBLEProtocolError.valueOutOfRange(field: "volume", value: 101)) {
        try RoseUARTCommand.volume(101)
    }
}

@Test("UART stop commands keep sound and all-off distinct")
func uartStopCommandsAreIndependent() {
    #expect(String(decoding: RoseUARTCommand.stopSound(), as: UTF8.self) == "TMW")
    #expect(String(decoding: RoseUARTCommand.allOff(), as: UTF8.self) == "TAE")
}

@Test("UART cloud disconnect uses the firmware's dedicated local command")
func uartCloudDisconnectCommand() {
    #expect(RoseUARTCommand.disconnectCloud() == Data("WSL".utf8))
}

@Test("UART URL playback accepts direct HTTP audio and rejects other URLs")
func uartURLPlayback() throws {
    let url = "https://example.com/rain.wav"
    #expect(String(decoding: try RoseUARTCommand.playURL(url), as: UTF8.self) == "TMP:\(url)")

    #expect(throws: RoseBLEProtocolError.invalidAudioURL("file:///tmp/rain.wav")) {
        try RoseUARTCommand.playURL("file:///tmp/rain.wav")
    }
    #expect(throws: RoseBLEProtocolError.invalidAudioURL("https:///rain.wav")) {
        try RoseUARTCommand.playURL("https:///rain.wav")
    }
}

@Test("UART color values reject overflow instead of silently wrapping")
func uartColorRange() {
    #expect(throws: RoseBLEProtocolError.valueOutOfRange(field: "red", value: 256)) {
        try RoseUARTCommand.rawColor(red: 256, green: 0, blue: 0, white: 0)
    }
}

@Test("A one-packet JSON command carries a big-endian final header")
func singleJSONPacket() throws {
    let payload = Data(#"{"command":"WGS"}"#.utf8)
    let packets = try RoseJSONPacketFramer.packets(for: payload, maxWriteLength: 80)

    #expect(packets.count == 1)
    #expect(Array(packets[0].prefix(4)) == [0x00, 0x00, 0x00, 0x80])
    #expect(Data(packets[0].dropFirst(4)) == payload)
}

@Test("JSON framing numbers later packets and marks only the final packet")
func multipleJSONPackets() throws {
    let payload = Data((0..<77).map { UInt8($0) })
    let packets = try RoseJSONPacketFramer.packets(for: payload, maxWriteLength: 80)

    #expect(packets.count == 2)
    #expect(Array(packets[0].prefix(4)) == [0x00, 0x00, 0x00, 0x00])
    #expect(Data(packets[0].dropFirst(4)) == payload.prefix(76))
    #expect(Array(packets[1].prefix(4)) == [0x00, 0x01, 0x00, 0x80])
    #expect(Data(packets[1].dropFirst(4)) == payload.suffix(1))
}

@Test("JSON framing rejects a write size with no payload capacity")
func invalidJSONWriteSize() {
    #expect(throws: RoseBLEProtocolError.invalidMaximumWriteLength(4)) {
        try RoseJSONPacketFramer.packets(for: Data([0x01]), maxWriteLength: 4)
    }
}

@Test("JSON response assembler waits for the final frame")
func jsonResponseAssembly() throws {
    let payload = Data((0..<97).map { UInt8($0) })
    let packets = try RoseJSONPacketFramer.packets(for: payload, maxWriteLength: 80)
    var assembler = RoseJSONPacketAssembler()

    #expect(try assembler.append(packets[0]) == nil)
    #expect(try assembler.append(packets[1]) == payload)
}

@Test("JSON response assembler rejects a skipped frame")
func jsonResponseAssemblyRejectsSkippedFrame() throws {
    let payload = Data((0..<97).map { UInt8($0) })
    let packets = try RoseJSONPacketFramer.packets(for: payload, maxWriteLength: 80)
    var assembler = RoseJSONPacketAssembler()

    #expect(throws: RoseBLEProtocolError.unexpectedPacketIndex(expected: 0, actual: 1)) {
        try assembler.append(packets[1])
    }
}

@Test("JSON response assembler rejects a malformed header")
func jsonResponseAssemblyRejectsMalformedHeader() {
    var assembler = RoseJSONPacketAssembler()

    #expect(throws: RoseBLEProtocolError.invalidPacketHeader) {
        try assembler.append(Data([0x00, 0x00, 0x01, 0x80, 0x4F, 0x4B]))
    }
}

@Test("BLE shadow delta wraps current state in the firmware backup envelope")
func shadowDeltaEnvelope() throws {
    let payload = try RoseBLEShadowDelta.payload(current: [
        "playing": "none",
        "sound": ["mute": true],
    ])
    let object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
    let state = try #require(object["state"] as? [String: Any])
    let current = try #require(state["current"] as? [String: Any])

    #expect(current["playing"] as? String == "none")
    #expect((current["sound"] as? [String: Any])?["mute"] as? Bool == true)
}

@Test("BLE commands accept both UART and JSON success replies")
func commandSuccessReplies() {
    #expect(RoseCommandResponse.isAccepted(Data("OK".utf8)))
    #expect(RoseCommandResponse.isAccepted(Data(#"{"result":"OK"}"#.utf8)))
    #expect(!RoseCommandResponse.isAccepted(Data(#"{"result":"ERROR"}"#.utf8)))
}
