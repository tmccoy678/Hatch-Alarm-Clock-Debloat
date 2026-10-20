import Foundation
import MediaPlayer
import RoseControlCore

struct RoseState: Equatable {
    var online = false
    var playing = "none"
    var lightOn = false
    var brightness = 1
    var red = 255
    var green = 67
    var blue = 0
    var colorID = RoseCommands.noColorID
    var rawRed = 0
    var rawGreen = 0
    var rawBlue = 0
    var rawWhite = 0
    var rawIntensity = 0
    var volume = 9
    var soundID = 0
}

@MainActor
final class RoseModel: ObservableObject {
    enum Phase: Equatable {
        case connecting
        case offline
        case ready
    }

    @Published var phase: Phase = .connecting
    @Published var rose = RoseState()
    @Published var sounds: [HatchSound] = []
    @Published var alarms: [HatchAlarm] = []
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var musicTrackTitle: String?
    @Published var radioStationID: String?
    @Published var radioStationTitle: String?
    @Published var localControlAvailable = false
    @Published var isLightScenePlaying = false

    private let api = IncludedSoundCatalog()
    private let local = RoseLocalBLE()
    private let musicPlayer = MusicLibraryPlayer()
    private let musicRelay = MusicRelayCoordinator()
    private var musicRelayURL: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "RoseMusicRelayURL") as? String
        return configured.flatMap { $0.isEmpty ? nil : $0 }
            ?? "https://rose-relay.local/rose-stream.mp3"
    }
    private let soundCacheKey = "includedSoundCatalog"
    private let alarmCacheKey = "localAlarm"
    private var lightSceneTask: Task<Void, Never>?
    private var lightSceneID: UUID?

    init() {
        UserDefaults.standard.removeObject(forKey: "favoriteSoundIDs")
        UserDefaults.standard.removeObject(forKey: "customAudioURL")
        loadLocalPreferences()
    }

    func start() async {
        phase = .connecting
        errorMessage = nil
        do {
            try await local.connect()
            try? await local.send(RoseUARTCommand.disconnectCloud())
            localControlAvailable = true
            rose.online = true
            phase = .ready
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshIncludedSounds()
        if !localControlAvailable {
            phase = .offline
        }
    }

    func retry() async {
        phase = .connecting
        errorMessage = nil
        do {
            try await local.connect()
            try? await local.send(RoseUARTCommand.disconnectCloud())
            localControlAvailable = true
            rose.online = true
            phase = .ready
        } catch {
            localControlAvailable = false
        }
        if !localControlAvailable {
            errorMessage = RoseLocalBLEError.connectionTimedOut.localizedDescription
            phase = .offline
        }
    }

    func refresh() async {
        await perform {
            try await self.local.connect()
            self.localControlAvailable = true
            self.rose.online = true
        }
    }

    func setLight(on: Bool, red: Int? = nil, green: Int? = nil, blue: Int? = nil, brightness: Int? = nil) async {
        await perform {
            let nextRed = red ?? self.rose.red
            let nextGreen = green ?? self.rose.green
            let nextBlue = blue ?? self.rose.blue
            let nextBrightness = brightness ?? self.rose.brightness
            let command = on
                ? try RoseUARTCommand.fullColor(
                    red: nextRed,
                    green: nextGreen,
                    blue: nextBlue,
                    white: 0,
                    intensityPercent: nextBrightness
                )
                : try RoseUARTCommand.fullColor(
                    red: 0,
                    green: 0,
                    blue: 0,
                    white: 0,
                    intensity: 0
                )
            try await self.local.send(command)
            self.localControlAvailable = true
            self.applyLocalLight(
                on: on,
                red: nextRed,
                green: nextGreen,
                blue: nextBlue,
                brightness: nextBrightness
            )
        }
    }

    func setVolume(_ value: Int) async {
        await perform {
            try await self.local.send(try RoseUARTCommand.volume(value))
            self.localControlAvailable = true
            self.rose.volume = value
            UserDefaults.standard.set(value, forKey: "localVolume")
        }
    }

    func startColossusMode() {
        guard !isLightScenePlaying, !isWorking else { return }
        let sceneID = UUID()
        lightSceneID = sceneID
        isLightScenePlaying = true
        lightSceneTask = Task { [weak self] in
            await self?.runLightScene(LightScenes.colossus, id: sceneID)
        }
    }

    func stopLightScene() async {
        let task = lightSceneTask
        lightSceneID = nil
        lightSceneTask = nil
        task?.cancel()
        if let task { await task.value }

        isLightScenePlaying = false
        isWorking = true
        defer { isWorking = false }
        do {
            try await sendSceneLight(red: 255, green: 142, blue: 62, brightness: 65)
            persistLight(red: 255, green: 142, blue: 62, brightness: 65)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func play(_ sound: HatchSound) async {
        await perform {
            let desired = try RoseCommands.sound(
                sound,
                volume: self.rose.volume,
                preserving: self.lightSnapshot
            )
            try await self.local.send(current: try self.current(from: desired))
            self.localControlAvailable = true
            self.rose.online = true
            self.rose.playing = "remote"
            self.rose.soundID = sound.id
            self.musicPlayer.stop()
            self.musicTrackTitle = nil
            self.radioStationID = nil
            self.radioStationTitle = nil
        }
    }

    func playRadio(_ station: RadioStation) async {
        await playRadio(
            url: station.streamURL,
            title: station.name,
            stationID: station.id
        )
    }

    func playRadio(url: String, title: String = "Custom station") async {
        await playRadio(url: url, title: title, stationID: nil)
    }

    func playMusicItem(_ item: MPMediaItem) async {
        await perform {
            guard self.musicPlayer.isRoseRouteSelected else {
                throw RoseMusicError.roseRouteNotSelected
            }
            try await self.musicRelay.start(
                source: {
                    try await self.musicPlayer.play(item)
                    self.musicTrackTitle = item.title ?? "Selected song"
                },
                receiver: {
                    let desired = try RoseCommands.customAudio(
                        url: self.musicRelayURL,
                        volume: self.rose.volume,
                        preserving: self.lightSnapshot
                    )
                    try await self.local.send(current: try self.current(from: desired))
                },
                stopSource: {
                    self.musicPlayer.stop()
                    self.musicTrackTitle = nil
                }
            )
            self.localControlAvailable = true
            self.rose.online = true
            self.rose.playing = "remote"
            self.rose.soundID = 0
            self.radioStationID = nil
            self.radioStationTitle = nil
        }
    }

    func stopSound() async {
        musicPlayer.stop()
        musicTrackTitle = nil
        radioStationID = nil
        radioStationTitle = nil
        await perform {
            try await self.local.send(RoseUARTCommand.stopSound())
            self.localControlAvailable = true
            self.rose.online = true
            self.rose.playing = "none"
            self.rose.soundID = 0
        }
    }

    func allOff() async {
        musicPlayer.stop()
        musicTrackTitle = nil
        radioStationID = nil
        radioStationTitle = nil
        await perform {
            try await self.local.send(RoseUARTCommand.allOff())
            self.localControlAvailable = true
            self.rose.playing = "none"
            self.rose.soundID = 0
            self.applyLocalLight(
                on: false,
                red: self.rose.red,
                green: self.rose.green,
                blue: self.rose.blue,
                brightness: self.rose.brightness
            )
        }
    }

    func updateAlarm(_ alarm: HatchAlarm, settings: AlarmSettings) async {
        await perform {
            let payload = try RoseLocalRDL.payload(alarm: alarm, settings: settings)
            try await self.local.send(document: payload)
            let updated = RoseLocalRDL.updatedAlarm(alarm, settings: settings)
            self.alarms = [updated]
            if let data = try? JSONEncoder().encode(updated) {
                UserDefaults.standard.set(data, forKey: self.alarmCacheKey)
            }
            self.localControlAvailable = true
        }
    }

    func previewAlarm(settings: AlarmSettings) async {
        await perform {
            if settings.sunriseEnabled {
                try await self.local.send(
                    try RoseUARTCommand.fullColor(
                        red: settings.sunriseRed,
                        green: settings.sunriseGreen,
                        blue: settings.sunriseBlue,
                        white: 0,
                        intensityPercent: settings.sunriseBrightness
                    )
                )
                self.applyLocalLight(
                    on: true,
                    red: settings.sunriseRed,
                    green: settings.sunriseGreen,
                    blue: settings.sunriseBlue,
                    brightness: settings.sunriseBrightness
                )
            }
            if settings.soundEnabled, let sound = settings.sound {
                let desired = try RoseCommands.sound(
                    sound,
                    volume: settings.volume,
                    preserving: self.lightSnapshot
                )
                try await self.local.send(current: try self.current(from: desired))
                self.rose.playing = "remote"
                self.rose.soundID = sound.id
            }
            self.localControlAvailable = true
        }
    }

    private func perform(_ operation: @escaping () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
            if !localControlAvailable { phase = .offline }
        }
    }

    private func runLightScene(_ scene: [LightSceneStep], id: UUID) async {
        isWorking = true
        errorMessage = nil
        do {
            try await local.connect()
            localControlAvailable = true
            rose.online = true
            for step in scene {
                try Task.checkCancellation()
                try await sendSceneLight(
                    red: step.red,
                    green: step.green,
                    blue: step.blue,
                    brightness: step.brightness
                )
                if let displayText = step.displayText {
                    try await local.send(try RoseUARTCommand.displayText(displayText))
                }
                if let displayAnimation = step.displayAnimation {
                    try await local.send(try RoseUARTCommand.displayAnimation(displayAnimation))
                }
                if step.holdSeconds > 0 {
                    try await Task.sleep(for: .seconds(step.holdSeconds))
                }
            }
            if let final = scene.last {
                persistLight(
                    red: final.red,
                    green: final.green,
                    blue: final.blue,
                    brightness: final.brightness
                )
            }
        } catch is CancellationError {
            // The stop action applies Rose's warm resting light after this task exits.
        } catch {
            errorMessage = error.localizedDescription
        }

        guard lightSceneID == id else { return }
        lightSceneID = nil
        lightSceneTask = nil
        isLightScenePlaying = false
        isWorking = false
    }

    private func sendSceneLight(red: Int, green: Int, blue: Int, brightness: Int) async throws {
        try await local.send(
            try RoseUARTCommand.fullColor(
                red: red,
                green: green,
                blue: blue,
                white: 0,
                intensityPercent: brightness
            )
        )
        applyLocalLight(
            on: brightness > 0,
            red: red,
            green: green,
            blue: blue,
            brightness: brightness,
            persist: false
        )
    }

    private func persistLight(red: Int, green: Int, blue: Int, brightness: Int) {
        applyLocalLight(
            on: brightness > 0,
            red: red,
            green: green,
            blue: blue,
            brightness: brightness,
            persist: true
        )
    }

    private func playRadio(url: String, title: String, stationID: String?) async {
        await perform {
            let streamURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            let desired = try RoseCommands.customAudio(
                url: streamURL,
                volume: self.rose.volume,
                preserving: self.lightSnapshot
            )
            try await self.local.send(current: try self.current(from: desired))
            self.musicPlayer.stop()
            self.musicTrackTitle = nil
            self.radioStationID = stationID
            self.radioStationTitle = title
            self.localControlAvailable = true
            self.rose.online = true
            self.rose.playing = "remote"
            self.rose.soundID = 0
        }
    }

    private func applyLocalLight(
        on: Bool,
        red: Int,
        green: Int,
        blue: Int,
        brightness: Int,
        persist: Bool = true
    ) {
        rose.online = true
        rose.lightOn = on
        rose.colorID = on ? RoseCommands.customColorID : RoseCommands.noColorID
        rose.red = red
        rose.green = green
        rose.blue = blue
        rose.brightness = brightness
        rose.rawRed = on ? RoseCommands.channel(red) : 0
        rose.rawGreen = on ? RoseCommands.channel(green) : 0
        rose.rawBlue = on ? RoseCommands.channel(blue) : 0
        rose.rawWhite = 0
        rose.rawIntensity = on ? RoseCommands.percent(brightness) : 0
        if persist {
            UserDefaults.standard.set(red, forKey: "localRed")
            UserDefaults.standard.set(green, forKey: "localGreen")
            UserDefaults.standard.set(blue, forKey: "localBlue")
            UserDefaults.standard.set(brightness, forKey: "localBrightness")
        }
    }

    private func refreshIncludedSounds() async {
        let values = api.freeSounds()
        sounds = values
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: soundCacheKey)
        }
    }

    private func current(from desired: [String: Any]) throws -> [String: Any] {
        guard let current = desired["current"] as? [String: Any] else {
            throw RoseLocalBLEError.invalidState
        }
        return current
    }

    private func loadLocalPreferences() {
        let defaults = UserDefaults.standard
        rose.red = defaults.object(forKey: "localRed") as? Int ?? 255
        rose.green = defaults.object(forKey: "localGreen") as? Int ?? 142
        rose.blue = defaults.object(forKey: "localBlue") as? Int ?? 62
        rose.brightness = defaults.object(forKey: "localBrightness") as? Int ?? 65
        rose.volume = defaults.object(forKey: "localVolume") as? Int ?? 90
        if let data = defaults.data(forKey: soundCacheKey),
           let cached = try? JSONDecoder().decode([HatchSound].self, from: data) {
            sounds = cached
        }
        if let data = defaults.data(forKey: alarmCacheKey),
           let cached = try? JSONDecoder().decode(HatchAlarm.self, from: data) {
            alarms = [cached]
        } else {
            alarms = [RoseLocalRDL.defaultAlarm()]
        }
    }

    private var lightSnapshot: RoseLightSnapshot {
        RoseLightSnapshot(
            isOn: rose.lightOn,
            colorID: rose.colorID,
            red: rose.rawRed,
            green: rose.rawGreen,
            blue: rose.rawBlue,
            white: rose.rawWhite,
            intensity: rose.rawIntensity
        )
    }
}
