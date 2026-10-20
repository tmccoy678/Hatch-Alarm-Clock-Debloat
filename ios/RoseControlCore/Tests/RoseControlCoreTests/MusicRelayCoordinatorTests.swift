import Foundation
import Testing
@testable import RoseControlCore

@Test("Music relay starts its source before opening the receiver")
func musicRelayStartsSourceFirst() async throws {
    let events = EventRecorder()
    let coordinator = MusicRelayCoordinator()

    try await coordinator.start(
        source: { await events.append("source") },
        receiver: { await events.append("receiver") },
        stopSource: { await events.append("stop") }
    )

    #expect(await events.values == ["source", "receiver"])
}

@Test("Music relay stops its source when the receiver cannot start")
func musicRelayStopsSourceAfterReceiverFailure() async {
    let events = EventRecorder()
    let coordinator = MusicRelayCoordinator()

    await #expect(throws: RelayFailure.self) {
        try await coordinator.start(
            source: { await events.append("source") },
            receiver: {
                await events.append("receiver")
                throw RelayFailure()
            },
            stopSource: { await events.append("stop") }
        )
    }

    #expect(await events.values == ["source", "receiver", "stop"])
}

private actor EventRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

private struct RelayFailure: Error {}
