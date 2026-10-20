import Foundation

public struct RadioStation: Identifiable, Equatable, Sendable {
    public enum AudioFormat: String, Equatable, Sendable {
        case aac
        case mp3
    }

    public let id: String
    public let name: String
    public let description: String
    public let streamURL: String
    public let format: AudioFormat

    public init(
        id: String,
        name: String,
        description: String,
        streamURL: String,
        format: AudioFormat
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.streamURL = streamURL
        self.format = format
    }
}

public enum RadioCatalog {
    public static let favorites = [
        RadioStation(
            id: "z104-madison",
            name: "Z104.1",
            description: "Madison hit music",
            streamURL: "https://stream.revma.ihrhls.com/zc2685",
            format: .aac
        ),
        RadioStation(
            id: "abc-oldies",
            name: "ABC Oldies",
            description: "60s, 70s & 80s pop hits",
            streamURL: "https://artemis.streamerr.co/listen/abcoldiesradio/radio.mp3",
            format: .mp3
        ),
    ]
}
