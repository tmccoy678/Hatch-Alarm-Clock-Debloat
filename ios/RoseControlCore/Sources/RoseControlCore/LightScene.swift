import Foundation

public struct LightSceneStep: Equatable, Sendable {
    public let red: Int
    public let green: Int
    public let blue: Int
    public let brightness: Int
    public let holdSeconds: TimeInterval
    public let displayText: String?
    public let displayAnimation: Int?

    public init(
        red: Int,
        green: Int,
        blue: Int,
        brightness: Int,
        holdSeconds: TimeInterval,
        displayText: String? = nil,
        displayAnimation: Int? = nil
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.brightness = brightness
        self.holdSeconds = holdSeconds
        self.displayText = displayText
        self.displayAnimation = displayAnimation
    }

    public var isBlackout: Bool {
        brightness == 0
    }
}

public enum LightScenes {
    private struct LightValue {
        let red: Int
        let green: Int
        let blue: Int
        let brightness: Int
    }

    /// A miniature command-center overture: dormant, awakening, signal lock,
    /// red takeover, and a final return to Rose's warm resting light.
    public static let colossus: [LightSceneStep] = {
        let black = LightValue(red: 0, green: 0, blue: 0, brightness: 0)
        let deepBlue = LightValue(red: 5, green: 20, blue: 92, brightness: 14)
        let signalBlue = LightValue(red: 25, green: 160, blue: 255, brightness: 84)
        let red = LightValue(red: 255, green: 0, blue: 6, brightness: 100)
        let violet = LightValue(red: 78, green: 0, blue: 154, brightness: 70)
        let gold = LightValue(red: 255, green: 160, blue: 28, brightness: 78)
        let restingAmber = LightValue(red: 255, green: 142, blue: 62, brightness: 65)

        var scene = [
            step(black, holdSeconds: 0.5),
        ]
        scene += ramp(from: black, to: deepBlue, frames: 8, duration: 1.3)
        scene += ramp(from: deepBlue, to: signalBlue, frames: 9, duration: 1.4)
        scene += [
            step(black, holdSeconds: 0.12),
            step(signalBlue, holdSeconds: 0.16),
            step(black, holdSeconds: 0.10),
            step(LightValue(red: 165, green: 230, blue: 255, brightness: 100), holdSeconds: 0.24),
            step(black, holdSeconds: 0.35),
        ]
        scene += ramp(from: black, to: red, frames: 10, duration: 1.5)
        scene += [step(black, holdSeconds: 0.16), step(red, holdSeconds: 0.38)]
        scene += ramp(from: red, to: violet, frames: 8, duration: 1.2)
        scene += ramp(from: violet, to: gold, frames: 10, duration: 1.5)
        scene += ramp(from: gold, to: restingAmber, frames: 7, duration: 1.1)
        scene.append(step(restingAmber, holdSeconds: 0))
        return scene
    }()

    private static func step(_ value: LightValue, holdSeconds: TimeInterval) -> LightSceneStep {
        LightSceneStep(
            red: value.red,
            green: value.green,
            blue: value.blue,
            brightness: value.brightness,
            holdSeconds: holdSeconds
        )
    }

    private static func ramp(
        from start: LightValue,
        to end: LightValue,
        frames: Int,
        duration: TimeInterval
    ) -> [LightSceneStep] {
        (1...frames).map { frame in
            let progress = Double(frame) / Double(frames)
            return LightSceneStep(
                red: interpolate(start.red, end.red, progress),
                green: interpolate(start.green, end.green, progress),
                blue: interpolate(start.blue, end.blue, progress),
                brightness: interpolate(start.brightness, end.brightness, progress),
                holdSeconds: duration / Double(frames)
            )
        }
    }

    private static func interpolate(_ start: Int, _ end: Int, _ progress: Double) -> Int {
        Int((Double(start) + Double(end - start) * progress).rounded())
    }
}
