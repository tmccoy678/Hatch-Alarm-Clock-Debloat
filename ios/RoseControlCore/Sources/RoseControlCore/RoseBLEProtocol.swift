import Foundation

public enum RoseBLEUUIDs {
    public static let communicationService = "02340000-5EFD-47EB-9C1A-DE53F7A2B232"
    public static let uartWrite = "02340001-5EFD-47EB-9C1A-DE53F7A2B232"
    public static let uartRead = "02340002-5EFD-47EB-9C1A-DE53F7A2B232"
    public static let jsonWrite = "02340003-5EFD-47EB-9C1A-DE53F7A2B232"
    public static let jsonRead = "02340004-5EFD-47EB-9C1A-DE53F7A2B232"
}

public enum RoseBLEProtocolError: Error, Equatable, Sendable {
    case valueOutOfRange(field: String, value: Int)
    case invalidAudioURL(String)
    case invalidDisplayText(String)
    case invalidShadowState
    case invalidMaximumWriteLength(Int)
    case invalidPacketHeader
    case unexpectedPacketIndex(expected: UInt16, actual: UInt16)
    case tooManyPackets(Int)
}

public enum RoseUARTCommand {
    public static func stopSound() -> Data {
        Data("TMW".utf8)
    }

    public static func allOff() -> Data {
        Data("TAE".utf8)
    }

    public static func disconnectCloud() -> Data {
        Data("WSL".utf8)
    }

    public static func displayText(_ value: String) throws -> Data {
        let normalized = value.uppercased()
        guard (1...4).contains(normalized.count),
              normalized.unicodeScalars.allSatisfy({ scalar in
                  scalar.value == 32
                      || (48...57).contains(scalar.value)
                      || (65...90).contains(scalar.value)
              }) else {
            throw RoseBLEProtocolError.invalidDisplayText(value)
        }
        let padded = normalized.padding(toLength: 4, withPad: " ", startingAt: 0)
        return Data("TLC\(padded)0".utf8)
    }

    public static func displayAnimation(_ index: Int) throws -> Data {
        guard (0...136).contains(index) else {
            throw RoseBLEProtocolError.valueOutOfRange(field: "displayAnimation", value: index)
        }
        return Data("TGA:\(index)".utf8)
    }

    public static func playURL(_ value: String) throws -> Data {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              (scheme == "https" || scheme == "http"),
              url.host != nil else {
            throw RoseBLEProtocolError.invalidAudioURL(value)
        }
        return Data("TMP:\(url.absoluteString)".utf8)
    }

    public static func rawColor(
        red: Int,
        green: Int,
        blue: Int,
        white: Int
    ) throws -> Data {
        try command(
            prefix: "Sc",
            fields: [
                ("red", red),
                ("green", green),
                ("blue", blue),
                ("white", white),
            ]
        )
    }

    public static func fullColor(
        red: Int,
        green: Int,
        blue: Int,
        white: Int,
        intensity: Int
    ) throws -> Data {
        try command(
            prefix: "SC",
            fields: [
                ("red", red),
                ("green", green),
                ("blue", blue),
                ("white", white),
                ("intensity", intensity),
            ]
        )
    }

    public static func fullColor(
        red: Int,
        green: Int,
        blue: Int,
        white: Int,
        intensityPercent: Int
    ) throws -> Data {
        guard (0...100).contains(intensityPercent) else {
            throw RoseBLEProtocolError.valueOutOfRange(
                field: "intensityPercent",
                value: intensityPercent
            )
        }
        let rawIntensity = Int((Double(intensityPercent) / 100 * 255).rounded())
        return try fullColor(
            red: red,
            green: green,
            blue: blue,
            white: white,
            intensity: rawIntensity
        )
    }

    public static func volume(_ percent: Int) throws -> Data {
        guard (0...100).contains(percent) else {
            throw RoseBLEProtocolError.valueOutOfRange(field: "volume", value: percent)
        }
        return Data(String(format: "TMV%02X", percent).utf8)
    }

    private static func command(
        prefix: String,
        fields: [(name: String, value: Int)]
    ) throws -> Data {
        var result = prefix
        for field in fields {
            guard (0...255).contains(field.value) else {
                throw RoseBLEProtocolError.valueOutOfRange(
                    field: field.name,
                    value: field.value
                )
            }
            result += String(format: "%02X", field.value)
        }
        return Data(result.utf8)
    }
}

public enum RoseBLEShadowDelta {
    public static func payload(current: [String: Any]) throws -> Data {
        let envelope: [String: Any] = ["state": ["current": current]]
        guard JSONSerialization.isValidJSONObject(envelope) else {
            throw RoseBLEProtocolError.invalidShadowState
        }
        return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
    }
}

public enum RoseCommandResponse {
    public static func isAccepted(_ data: Data) -> Bool {
        if String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "OK" {
            return true
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object["result"] as? String == "OK"
    }
}

public enum RoseJSONPacketFramer {
    private static let vendorMaximumWriteLength = 80
    private static let headerLength = 4

    public static func packets(
        for payload: Data,
        maxWriteLength: Int
    ) throws -> [Data] {
        guard maxWriteLength > headerLength else {
            throw RoseBLEProtocolError.invalidMaximumWriteLength(maxWriteLength)
        }

        let packetLength = min(maxWriteLength, vendorMaximumWriteLength)
        let payloadLength = packetLength - headerLength
        let packetCount = max(1, (payload.count + payloadLength - 1) / payloadLength)
        guard packetCount <= Int(UInt16.max) + 1 else {
            throw RoseBLEProtocolError.tooManyPackets(packetCount)
        }

        return (0..<packetCount).map { packetIndex in
            let start = packetIndex * payloadLength
            let end = min(start + payloadLength, payload.count)
            let index = UInt16(packetIndex)
            let isFinal = packetIndex == packetCount - 1
            var packet = Data([
                UInt8(index >> 8),
                UInt8(index & 0x00FF),
                0x00,
                isFinal ? 0x80 : 0x00,
            ])
            if start < end {
                packet.append(payload[start..<end])
            }
            return packet
        }
    }
}

public struct RoseJSONPacketAssembler: Sendable {
    private var payload = Data()
    private var expectedIndex: UInt16 = 0

    public init() {}

    public mutating func append(_ packet: Data) throws -> Data? {
        guard packet.count >= 4,
              packet[2] == 0,
              packet[3] & 0x7F == 0 else {
            reset()
            throw RoseBLEProtocolError.invalidPacketHeader
        }

        let actualIndex = UInt16(packet[0]) << 8 | UInt16(packet[1])
        guard actualIndex == expectedIndex else {
            let expected = expectedIndex
            reset()
            throw RoseBLEProtocolError.unexpectedPacketIndex(
                expected: expected,
                actual: actualIndex
            )
        }

        payload.append(packet.dropFirst(4))
        if packet[3] & 0x80 != 0 {
            let completed = payload
            reset()
            return completed
        }

        guard expectedIndex < UInt16.max else {
            reset()
            throw RoseBLEProtocolError.invalidPacketHeader
        }
        expectedIndex += 1
        return nil
    }

    public mutating func reset() {
        payload.removeAll(keepingCapacity: true)
        expectedIndex = 0
    }
}
