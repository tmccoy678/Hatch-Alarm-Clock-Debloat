@preconcurrency import CoreBluetooth
import Darwin
import Foundation
import RoseControlCore

private struct ProbeStep {
    enum Transport {
        case uart
        case json
    }

    let label: String
    let payload: Data
    let delayAfterAcknowledgement: TimeInterval
    var transport: Transport = .uart
}

private enum ProbePlan {
    case discover
    case lightOff
    case soundStop
    case allOff
    case cloudDisconnect
    case displayText(String)
    case displayAnimation(Int)
    case soundURL(url: String, volume: Int)
    case jsonCommand(String)
    case jsonSound(url: String, volume: Int)
    case jsonIncludedSound(id: Int, url: String, volume: Int)
    case state
    case lightSmoke(red: Int, green: Int, blue: Int, white: Int, intensityPercent: Int)

    init(arguments: [String]) throws {
        guard let action = arguments.first else {
            self = .state
            return
        }

        switch action {
        case "discover":
            self = .discover
        case "light-off":
            self = .lightOff
        case "sound-stop":
            self = .soundStop
        case "all-off":
            self = .allOff
        case "cloud-disconnect":
            self = .cloudDisconnect
        case "display-text":
            guard arguments.count == 2 else { throw ProbeError.usage }
            self = .displayText(arguments[1])
        case "display-animation":
            guard arguments.count == 2, let index = Int(arguments[1]) else {
                throw ProbeError.usage
            }
            self = .displayAnimation(index)
        case "sound-url":
            guard (2...3).contains(arguments.count) else { throw ProbeError.usage }
            let volume = arguments.count == 3 ? Int(arguments[2]) : 20
            guard let volume else { throw ProbeError.usage }
            self = .soundURL(url: arguments[1], volume: volume)
        case "json-command":
            guard arguments.count == 2 else { throw ProbeError.usage }
            self = .jsonCommand(arguments[1])
        case "json-sound":
            guard arguments.count == 3, let volume = Int(arguments[2]) else {
                throw ProbeError.usage
            }
            self = .jsonSound(url: arguments[1], volume: volume)
        case "json-included-sound":
            guard arguments.count == 4,
                  let id = Int(arguments[1]),
                  let volume = Int(arguments[3]) else {
                throw ProbeError.usage
            }
            self = .jsonIncludedSound(id: id, url: arguments[2], volume: volume)
        case "state":
            self = .state
        case "light-smoke":
            guard arguments.count == 6,
                  let red = Int(arguments[1]),
                  let green = Int(arguments[2]),
                  let blue = Int(arguments[3]),
                  let white = Int(arguments[4]),
                  let intensityPercent = Int(arguments[5]) else {
                throw ProbeError.usage
            }
            self = .lightSmoke(
                red: red,
                green: green,
                blue: blue,
                white: white,
                intensityPercent: intensityPercent
            )
        default:
            throw ProbeError.usage
        }
    }

    func steps() throws -> [ProbeStep] {
        switch self {
        case .discover:
            return []
        case .lightOff:
            return [
                ProbeStep(
                    label: "stop light",
                    payload: try RoseUARTCommand.fullColor(
                        red: 0,
                        green: 0,
                        blue: 0,
                        white: 0,
                        intensity: 0
                    ),
                    delayAfterAcknowledgement: 1
                )
            ]
        case .soundStop:
            return [
                ProbeStep(
                    label: "stop sound",
                    payload: RoseUARTCommand.stopSound(),
                    delayAfterAcknowledgement: 1
                )
            ]
        case .allOff:
            return [
                ProbeStep(
                    label: "stop sound and light",
                    payload: RoseUARTCommand.allOff(),
                    delayAfterAcknowledgement: 1
                )
            ]
        case .cloudDisconnect:
            return [
                ProbeStep(
                    label: "disconnect Hatch IoT",
                    payload: RoseUARTCommand.disconnectCloud(),
                    delayAfterAcknowledgement: 2
                )
            ]
        case let .displayText(value):
            return [
                ProbeStep(
                    label: "show display text \(value)",
                    payload: try RoseUARTCommand.displayText(value),
                    delayAfterAcknowledgement: 4
                )
            ]
        case let .displayAnimation(index):
            return [
                ProbeStep(
                    label: "play display animation \(index)",
                    payload: try RoseUARTCommand.displayAnimation(index),
                    delayAfterAcknowledgement: 5
                )
            ]
        case let .soundURL(url, volume):
            return [
                ProbeStep(
                    label: "play URL",
                    payload: try RoseUARTCommand.playURL(url),
                    delayAfterAcknowledgement: 1
                ),
                ProbeStep(
                    label: "set volume",
                    payload: try RoseUARTCommand.volume(volume),
                    delayAfterAcknowledgement: 2
                ),
            ]
        case let .jsonCommand(command):
            let payload = try JSONSerialization.data(withJSONObject: ["command": command], options: [.sortedKeys])
            return [
                ProbeStep(
                    label: "JSON command \(command)",
                    payload: payload,
                    delayAfterAcknowledgement: 2,
                    transport: .json
                )
            ]
        case let .jsonSound(url, volume):
            let desired = try RoseCommands.customAudio(url: url, volume: volume)
            guard let current = desired["current"] as? [String: Any] else {
                throw RoseBLEProtocolError.invalidShadowState
            }
            return [
                ProbeStep(
                    label: "JSON sound",
                    payload: try RoseBLEShadowDelta.payload(current: current),
                    delayAfterAcknowledgement: 3,
                    transport: .json
                )
            ]
        case let .jsonIncludedSound(id, url, volume):
            let sound = HatchSound(id: id, title: "BLE probe", wavUrl: url)
            let desired = try RoseCommands.sound(sound, volume: volume)
            guard let current = desired["current"] as? [String: Any] else {
                throw RoseBLEProtocolError.invalidShadowState
            }
            return [
                ProbeStep(
                    label: "JSON included sound id=\(id)",
                    payload: try RoseBLEShadowDelta.payload(current: current),
                    delayAfterAcknowledgement: 5,
                    transport: .json
                )
            ]
        case .state:
            return [ProbeStep(label: "read state", payload: Data("WGS".utf8), delayAfterAcknowledgement: 2)]
        case let .lightSmoke(red, green, blue, white, intensityPercent):
            guard intensityPercent > 0 else {
                throw RoseBLEProtocolError.valueOutOfRange(
                    field: "intensityPercent",
                    value: intensityPercent
                )
            }
            let baseline = try RoseUARTCommand.fullColor(
                red: red,
                green: green,
                blue: blue,
                white: white,
                intensityPercent: intensityPercent
            )
            let changed = try RoseUARTCommand.fullColor(
                red: red,
                green: green,
                blue: blue,
                white: white,
                intensityPercent: intensityPercent - 1
            )
            return [
                ProbeStep(label: "establish baseline", payload: baseline, delayAfterAcknowledgement: 0.75),
                ProbeStep(label: "decrease intensity by one", payload: changed, delayAfterAcknowledgement: 0.75),
                ProbeStep(label: "restore baseline", payload: baseline, delayAfterAcknowledgement: 1),
            ]
        }
    }

    var isDiscoveryOnly: Bool {
        if case .discover = self { return true }
        return false
    }
}

private enum ProbeError: Error {
    case usage
}

private final class RoseBLEProbe: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {
    private let expectedDeviceNames = ["Hatch Restore"]
    private let serviceUUID = CBUUID(string: RoseBLEUUIDs.communicationService)
    private let uartWriteUUID = CBUUID(string: RoseBLEUUIDs.uartWrite)
    private let uartReadUUID = CBUUID(string: RoseBLEUUIDs.uartRead)
    private let jsonWriteUUID = CBUUID(string: RoseBLEUUIDs.jsonWrite)
    private let jsonReadUUID = CBUUID(string: RoseBLEUUIDs.jsonRead)
    private let steps: [ProbeStep]
    private let discoveryOnly: Bool
    private var seenCandidates = Set<UUID>()
    private var nextStepIndex = 0
    private var central: CBCentralManager!
    private var target: CBPeripheral?
    private var uartWriteCharacteristic: CBCharacteristic?
    private var jsonWriteCharacteristic: CBCharacteristic?
    private var notifyingCharacteristics = Set<CBUUID>()
    private var pendingFrames: [Data] = []
    private var activeWriteCharacteristic: CBCharacteristic?
    private var didStartSteps = false
    private var finishWorkItem: DispatchWorkItem?
    private var rememberedConnectFallback: DispatchWorkItem?
    private var finished = false

    init(steps: [ProbeStep], discoveryOnly: Bool) {
        self.steps = steps
        self.discoveryOnly = discoveryOnly
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.finish(code: 2, message: "TIMEOUT")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            finish(code: 3, message: "BLUETOOTH_UNAVAILABLE state=\(central.state.rawValue)")
            return
        }
        log("SCANNING")
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard target == nil else { return }
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "unknown"
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        if discoveryOnly {
            guard RSSI.intValue >= -70,
                  seenCandidates.insert(peripheral.identifier).inserted else { return }
            let services = advertisedServices.map(\.uuidString).joined(separator: ",")
            log("CANDIDATE id=\(peripheral.identifier.uuidString) name=\(name) rssi=\(RSSI) services=\(services)")
            return
        }
        guard expectedDeviceNames.contains(name)
                || name.hasPrefix("RestoreV4")
                || advertisedServices.contains(serviceUUID) else { return }
        log("FOUND name=\(name) rssi=\(RSSI)")
        target = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        rememberedConnectFallback?.cancel()
        rememberedConnectFallback = nil
        log("CONNECTED")
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        log("CONNECT_ERROR \(error?.localizedDescription ?? "unknown") falling_back_to_scan")
        target = nil
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            finish(code: 5, message: "SERVICE_ERROR \(error.localizedDescription)")
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            finish(code: 6, message: "SERVICE_MISSING")
            return
        }
        peripheral.discoverCharacteristics(
            [uartWriteUUID, uartReadUUID, jsonWriteUUID, jsonReadUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            finish(code: 7, message: "CHARACTERISTIC_ERROR \(error.localizedDescription)")
            return
        }
        let characteristics = service.characteristics ?? []
        uartWriteCharacteristic = characteristics.first(where: { $0.uuid == uartWriteUUID })
        jsonWriteCharacteristic = characteristics.first(where: { $0.uuid == jsonWriteUUID })
        guard let uartRead = characteristics.first(where: { $0.uuid == uartReadUUID }),
              let jsonRead = characteristics.first(where: { $0.uuid == jsonReadUUID }),
              uartWriteCharacteristic != nil,
              jsonWriteCharacteristic != nil else {
            finish(code: 8, message: "UART_CHARACTERISTICS_MISSING")
            return
        }
        peripheral.setNotifyValue(true, for: uartRead)
        peripheral.setNotifyValue(true, for: jsonRead)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            finish(code: 9, message: "NOTIFY_ERROR \(error.localizedDescription)")
            return
        }
        guard characteristic.isNotifying else { return }
        notifyingCharacteristics.insert(characteristic.uuid)
        guard notifyingCharacteristics.contains(uartReadUUID),
              notifyingCharacteristics.contains(jsonReadUUID),
              !didStartSteps else { return }
        didStartSteps = true
        log(
            "READY max_write_with_response="
                + String(peripheral.maximumWriteValueLength(for: .withResponse))
                + " max_write_without_response="
                + String(peripheral.maximumWriteValueLength(for: .withoutResponse))
        )
        sendNextStep(on: peripheral)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            finish(code: 10, message: "WRITE_ERROR \(error.localizedDescription)")
            return
        }
        if !pendingFrames.isEmpty {
            sendNextFrame(on: peripheral)
            return
        }
        log("WRITE_ACK")
        guard nextStepIndex < steps.count else {
            scheduleFinish(after: steps.last?.delayAfterAcknowledgement ?? 1)
            return
        }
        let delay = steps[nextStepIndex - 1].delayAfterAcknowledgement
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak peripheral] in
            guard let self, let peripheral else { return }
            self.sendNextStep(on: peripheral)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            log("READ_ERROR \(error.localizedDescription)")
            return
        }
        guard (characteristic.uuid == uartReadUUID || characteristic.uuid == jsonReadUUID),
              let data = characteristic.value else { return }
        let hex = data.map { String(format: "%02X", $0) }.joined()
        let decoded = String(data: data, encoding: .utf8)
            .map { String(reflecting: $0) } ?? "<non-UTF8>"
        let channel = characteristic.uuid == uartReadUUID ? "UART" : "JSON"
        log("\(channel)_RX_HEX=\(hex)")
        log("\(channel)_RX_TEXT=\(decoded)")
    }

    private func sendNextStep(on peripheral: CBPeripheral) {
        guard nextStepIndex < steps.count else { return }
        let step = steps[nextStepIndex]
        nextStepIndex += 1
        log(
            "SEND step=\(nextStepIndex)/\(steps.count) action=\(step.label)"
                + " payload_bytes=\(step.payload.count)"
        )
        switch step.transport {
        case .uart:
            guard let uartWriteCharacteristic else {
                finish(code: 11, message: "UART_WRITE_MISSING")
                return
            }
            activeWriteCharacteristic = uartWriteCharacteristic
            pendingFrames = [step.payload]
        case .json:
            guard let jsonWriteCharacteristic else {
                finish(code: 12, message: "JSON_WRITE_MISSING")
                return
            }
            activeWriteCharacteristic = jsonWriteCharacteristic
            do {
                pendingFrames = try RoseJSONPacketFramer.packets(
                    for: step.payload,
                    maxWriteLength: peripheral.maximumWriteValueLength(for: .withResponse)
                )
            } catch {
                finish(code: 13, message: "JSON_FRAME_ERROR \(error)")
                return
            }
        }
        sendNextFrame(on: peripheral)
    }

    private func sendNextFrame(on peripheral: CBPeripheral) {
        guard !pendingFrames.isEmpty, let activeWriteCharacteristic else { return }
        let frame = pendingFrames.removeFirst()
        log(
            "WRITE characteristic=\(activeWriteCharacteristic.uuid.uuidString)"
                + " frame_bytes=\(frame.count) remaining_frames=\(pendingFrames.count)"
        )
        peripheral.writeValue(frame, for: activeWriteCharacteristic, type: .withResponse)
    }

    private func scheduleFinish(after delay: TimeInterval) {
        finishWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.finish(code: 0, message: "COMPLETE")
        }
        finishWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func finish(code: Int32, message: String) {
        guard !finished else { return }
        finished = true
        rememberedConnectFallback?.cancel()
        log(message)
        if let target {
            central.cancelPeripheralConnection(target)
        }
        exit(code)
    }

    private func log(_ message: String) {
        print(message)
        fflush(stdout)
    }
}

do {
    let plan = try ProbePlan(arguments: Array(CommandLine.arguments.dropFirst()))
    let probe = RoseBLEProbe(steps: try plan.steps(), discoveryOnly: plan.isDiscoveryOnly)
    withExtendedLifetime(probe) {
        RunLoop.main.run()
    }
} catch ProbeError.usage {
    fputs("Usage: RoseBLEProbe [discover | state | light-off | sound-stop | all-off | cloud-disconnect | sound-url URL [VOLUME] | json-command COMMAND | json-sound URL VOLUME | json-included-sound ID URL VOLUME | light-smoke RED GREEN BLUE WHITE INTENSITY_PERCENT]\n", stderr)
    exit(64)
} catch {
    fputs("Invalid probe request: \(error)\n", stderr)
    exit(65)
}
