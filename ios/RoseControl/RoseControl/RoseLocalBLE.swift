@preconcurrency import CoreBluetooth
import Foundation
import RoseControlCore

@MainActor
final class RoseLocalBLE: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    private let expectedNames = ["Hatch Restore"]
    private let serviceUUID = CBUUID(string: RoseBLEUUIDs.communicationService)
    private let uartWriteUUID = CBUUID(string: RoseBLEUUIDs.uartWrite)
    private let uartReadUUID = CBUUID(string: RoseBLEUUIDs.uartRead)
    private let jsonWriteUUID = CBUUID(string: RoseBLEUUIDs.jsonWrite)
    private let jsonReadUUID = CBUUID(string: RoseBLEUUIDs.jsonRead)

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var uartWriteCharacteristic: CBCharacteristic?
    private var jsonWriteCharacteristic: CBCharacteristic?
    private var notifyingCharacteristics = Set<CBUUID>()
    private var activeWriteCharacteristic: CBCharacteristic?
    private var activeResponseUUID: CBUUID?
    private var pendingWriteFrames: [Data] = []
    private var jsonResponseAssembler = RoseJSONPacketAssembler()
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var commandContinuation: CheckedContinuation<Void, Error>?
    private var connectTimeout: Task<Void, Never>?
    private var commandTimeout: Task<Void, Never>?

    var isReady: Bool {
        peripheral?.state == .connected
            && uartWriteCharacteristic != nil
            && jsonWriteCharacteristic != nil
            && notifyingCharacteristics.contains(uartReadUUID)
            && notifyingCharacteristics.contains(jsonReadUUID)
    }

    func connect() async throws {
        if isReady { return }
        guard connectContinuation == nil else { throw RoseLocalBLEError.busy }

        try await withCheckedThrowingContinuation { continuation in
            connectContinuation = continuation
            connectTimeout?.cancel()
            connectTimeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(12))
                self?.failConnection(RoseLocalBLEError.connectionTimedOut)
            }

            if let central {
                if central.state == .poweredOn { startScan(using: central) }
            } else {
                central = CBCentralManager(delegate: self, queue: .main)
            }
        }
    }

    func send(_ command: Data) async throws {
        try await connect()
        guard let uartWriteCharacteristic else {
            throw RoseLocalBLEError.disconnected
        }
        try await send(
            frames: [command],
            using: uartWriteCharacteristic,
            expecting: uartReadUUID
        )
    }

    func send(current: [String: Any]) async throws {
        let payload = try RoseBLEShadowDelta.payload(current: current)
        try await send(document: payload)
    }

    func send(document payload: Data) async throws {
        try await connect()
        guard let peripheral, let jsonWriteCharacteristic else {
            throw RoseLocalBLEError.disconnected
        }
        let frames = try RoseJSONPacketFramer.packets(
            for: payload,
            maxWriteLength: peripheral.maximumWriteValueLength(for: .withResponse)
        )
        try await send(
            frames: frames,
            using: jsonWriteCharacteristic,
            expecting: jsonReadUUID
        )
    }

    private func send(
        frames: [Data],
        using characteristic: CBCharacteristic,
        expecting responseUUID: CBUUID
    ) async throws {
        guard commandContinuation == nil else { throw RoseLocalBLEError.busy }
        guard let peripheral, !frames.isEmpty else {
            throw RoseLocalBLEError.disconnected
        }

        try await withCheckedThrowingContinuation { continuation in
            commandContinuation = continuation
            activeWriteCharacteristic = characteristic
            activeResponseUUID = responseUUID
            pendingWriteFrames = frames
            jsonResponseAssembler.reset()
            commandTimeout?.cancel()
            commandTimeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                self?.finishCommand(.failure(RoseLocalBLEError.commandTimedOut))
            }
            writeNextFrame(on: peripheral)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScan(using: central)
        case .unknown, .resetting:
            break
        case .poweredOff, .unauthorized, .unsupported:
            failConnection(RoseLocalBLEError.bluetoothUnavailable)
        @unknown default:
            failConnection(RoseLocalBLEError.bluetoothUnavailable)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard self.peripheral == nil else { return }
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? ""
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        guard expectedNames.contains(name)
                || name.hasPrefix("RestoreV4")
                || services.contains(serviceUUID) else { return }

        self.peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        self.peripheral = nil
        failConnection(error ?? RoseLocalBLEError.disconnected)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        self.peripheral = nil
        uartWriteCharacteristic = nil
        jsonWriteCharacteristic = nil
        notifyingCharacteristics.removeAll()
        let failure = error ?? RoseLocalBLEError.disconnected
        failConnection(failure)
        finishCommand(.failure(failure))
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            failConnection(error)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            failConnection(RoseLocalBLEError.serviceUnavailable)
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
            failConnection(error)
            return
        }
        let characteristics = service.characteristics ?? []
        uartWriteCharacteristic = characteristics.first(where: { $0.uuid == uartWriteUUID })
        jsonWriteCharacteristic = characteristics.first(where: { $0.uuid == jsonWriteUUID })
        guard let uartRead = characteristics.first(where: { $0.uuid == uartReadUUID }),
              let jsonRead = characteristics.first(where: { $0.uuid == jsonReadUUID }),
              uartWriteCharacteristic != nil,
              jsonWriteCharacteristic != nil else {
            failConnection(RoseLocalBLEError.serviceUnavailable)
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
            failConnection(error)
            return
        }
        guard characteristic.isNotifying else { return }
        notifyingCharacteristics.insert(characteristic.uuid)
        guard isReady else { return }
        print("[RoseControl] local BLE ready")
        finishConnection(.success(()))
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            finishCommand(.failure(error))
            return
        }
        writeNextFrame(on: peripheral)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            finishCommand(.failure(error))
            return
        }
        guard characteristic.uuid == activeResponseUUID,
              let data = characteristic.value else { return }
        let responseData: Data
        if characteristic.uuid == jsonReadUUID {
            do {
                guard let completed = try jsonResponseAssembler.append(data) else { return }
                responseData = completed
            } catch {
                finishCommand(.failure(error))
                return
            }
        } else {
            responseData = data
        }
        guard let decoded = String(data: responseData, encoding: .utf8) else { return }
        let response = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        if RoseCommandResponse.isAccepted(responseData) {
            print("[RoseControl] local BLE command accepted")
            finishCommand(.success(()))
        } else {
            finishCommand(.failure(RoseLocalBLEError.commandRejected(response)))
        }
    }

    private func startScan(using central: CBCentralManager) {
        guard connectContinuation != nil else { return }
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func writeNextFrame(on peripheral: CBPeripheral) {
        guard !pendingWriteFrames.isEmpty,
              let activeWriteCharacteristic else { return }
        let frame = pendingWriteFrames.removeFirst()
        peripheral.writeValue(frame, for: activeWriteCharacteristic, type: .withResponse)
    }

    private func failConnection(_ error: Error) {
        if let peripheral, !isReady {
            central?.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
            uartWriteCharacteristic = nil
            jsonWriteCharacteristic = nil
            notifyingCharacteristics.removeAll()
        }
        finishConnection(.failure(error))
    }

    private func finishConnection(_ result: Result<Void, Error>) {
        connectTimeout?.cancel()
        connectTimeout = nil
        let continuation = connectContinuation
        connectContinuation = nil
        continuation?.resume(with: result)
    }

    private func finishCommand(_ result: Result<Void, Error>) {
        commandTimeout?.cancel()
        commandTimeout = nil
        let continuation = commandContinuation
        commandContinuation = nil
        activeWriteCharacteristic = nil
        activeResponseUUID = nil
        pendingWriteFrames.removeAll()
        jsonResponseAssembler.reset()
        continuation?.resume(with: result)
    }
}

enum RoseLocalBLEError: LocalizedError {
    case bluetoothUnavailable
    case busy
    case commandRejected(String)
    case commandTimedOut
    case connectionTimedOut
    case disconnected
    case invalidState
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            "Turn on Bluetooth so Rose Control can reach the clock directly."
        case .busy:
            "Rose is finishing another local command."
        case let .commandRejected(response):
            "Rose rejected the local command (\(response))."
        case .commandTimedOut:
            "Rose received the Bluetooth write but did not confirm the command."
        case .connectionTimedOut:
            "Rose was not found nearby over Bluetooth."
        case .disconnected:
            "Rose disconnected from local control."
        case .invalidState:
            "Rose Control could not build a local state update."
        case .serviceUnavailable:
            "Rose connected, but its local control service is unavailable."
        }
    }
}
