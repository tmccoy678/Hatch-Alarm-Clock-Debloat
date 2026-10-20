public struct MusicRelayCoordinator: Sendable {
    public init() {}

    public func start(
        source: () async throws -> Void,
        receiver: () async throws -> Void,
        stopSource: () async -> Void
    ) async throws {
        try await source()
        do {
            try await receiver()
        } catch {
            await stopSource()
            throw error
        }
    }
}
