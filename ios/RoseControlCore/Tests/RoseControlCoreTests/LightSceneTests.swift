import Testing
@testable import RoseControlCore

@Test("Colossus mode tells a complete light story and returns Rose to amber")
func colossusLightStory() throws {
    let scene = LightScenes.colossus
    let first = try #require(scene.first)
    let last = try #require(scene.last)

    #expect(first.isBlackout)
    #expect(scene.contains { $0.blue > $0.red && $0.brightness >= 80 })
    #expect(scene.filter(\.isBlackout).count >= 4)
    #expect(scene.contains { $0.red == 255 && $0.green == 0 && $0.brightness == 100 })
    #expect(last == .init(red: 255, green: 142, blue: 62, brightness: 65, holdSeconds: 0))
    #expect(scene.reduce(0) { $0 + $1.holdSeconds } >= 8)
    #expect(scene.count >= 60)

    let blueRise = Array(scene.dropFirst().prefix(17))
    #expect(blueRise.allSatisfy { $0.blue > $0.red && !$0.isBlackout })
    #expect(zip(blueRise, blueRise.dropFirst()).allSatisfy { $1.brightness >= $0.brightness })
}

@Test("Clock text uses Restore 2's native four-character command")
func clockTextCommand() throws {
    #expect(String(decoding: try RoseUARTCommand.displayText("nevr"), as: UTF8.self) == "TLCNEVR0")
    #expect(String(decoding: try RoseUARTCommand.displayText("AI"), as: UTF8.self) == "TLCAI  0")
    #expect(throws: RoseBLEProtocolError.invalidDisplayText("TOO LONG")) {
        try RoseUARTCommand.displayText("TOO LONG")
    }
}

@Test("Display animations use the firmware's native bounded index command")
func displayAnimationCommand() throws {
    #expect(String(decoding: try RoseUARTCommand.displayAnimation(0), as: UTF8.self) == "TGA:0")
    #expect(String(decoding: try RoseUARTCommand.displayAnimation(136), as: UTF8.self) == "TGA:136")
    #expect(throws: RoseBLEProtocolError.valueOutOfRange(field: "displayAnimation", value: 137)) {
        try RoseUARTCommand.displayAnimation(137)
    }
}

@Test("Every Colossus light command stays inside Rose's accepted ranges")
func colossusLightRanges() {
    for step in LightScenes.colossus {
        #expect((0...255).contains(step.red))
        #expect((0...255).contains(step.green))
        #expect((0...255).contains(step.blue))
        #expect((0...100).contains(step.brightness))
        #expect(step.holdSeconds >= 0)
    }
}
