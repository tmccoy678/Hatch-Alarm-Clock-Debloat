import AVFoundation
import MediaPlayer
import SwiftUI

struct MusicLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var songs: [MPMediaItem] = []
    @State private var search = ""
    @State private var phase = Phase.loading
    let onPick: (MPMediaItem) -> Void

    private enum Phase {
        case loading
        case ready
        case denied
    }

    private var filtered: [MPMediaItem] {
        guard !search.isEmpty else { return songs }
        return songs.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(search)
                || ($0.artist ?? "").localizedCaseInsensitiveContains(search)
                || ($0.albumTitle ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView("Opening Music library…")
                        .tint(RoseTheme.rose)
                case .denied:
                    ContentUnavailableView(
                        "Music access is off",
                        systemImage: "music.note",
                        description: Text("Allow Music access for Rose Control in Settings.")
                    )
                case .ready where songs.isEmpty:
                    ContentUnavailableView(
                        "No songs found",
                        systemImage: "music.note.list",
                        description: Text("Add music to your library, then reopen this screen.")
                    )
                case .ready:
                    List(filtered, id: \.persistentID) { song in
                        Button {
                            onPick(song)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(RoseTheme.rose)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.title ?? "Untitled")
                                        .foregroundStyle(RoseTheme.text)
                                    Text(song.artist ?? song.albumTitle ?? "Apple Music")
                                        .font(.caption)
                                        .foregroundStyle(RoseTheme.secondaryText)
                                }
                                Spacer()
                                if song.assetURL == nil {
                                    Image(systemName: "icloud")
                                        .foregroundStyle(RoseTheme.secondaryText)
                                        .accessibilityLabel("Cloud library")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(RoseTheme.panel)
                    }
                    .scrollContentBackground(.hidden)
                    .searchable(text: $search, prompt: "Search songs or artists")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoseTheme.background)
            .navigationTitle("Your Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(RoseTheme.rose)
                }
            }
            .task { await loadSongs() }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func loadSongs() async {
        var status = MPMediaLibrary.authorizationStatus()
        if status == .notDetermined {
            status = await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
            }
        }
        guard status == .authorized else {
            phase = .denied
            return
        }
        songs = (MPMediaQuery.songs().items ?? []).sorted {
            ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending
        }
        phase = .ready
    }
}

@MainActor
final class MusicLibraryPlayer {
    private let player = MPMusicPlayerController.systemMusicPlayer

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    func play(_ item: MPMediaItem) async throws {
        player.setQueue(with: MPMediaItemCollection(items: [item]))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            player.prepareToPlay { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        player.play()
        for _ in 0..<40 {
            if player.playbackState == .playing { return }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw RoseMusicError.playbackDidNotStart
    }

    func stop() {
        player.stop()
    }

    var isRoseRouteSelected: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == .airPlay && $0.portName.caseInsensitiveCompare("Rose") == .orderedSame
        }
    }
}

struct RoseAirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let picker = MPVolumeView()
        picker.showsVolumeSlider = false
        applyTheme(to: picker)
        return picker
    }

    func updateUIView(_ picker: MPVolumeView, context: Context) {
        applyTheme(to: picker)
    }

    private func applyTheme(to picker: MPVolumeView) {
        picker.tintColor = UIColor(red: 1.0, green: 0.43, blue: 0.42, alpha: 1.0)
    }
}

enum RoseMusicError: LocalizedError {
    case roseRouteNotSelected
    case playbackDidNotStart

    var errorDescription: String? {
        switch self {
        case .roseRouteNotSelected:
            "Tap AirPlay and choose Rose before playing a song."
        case .playbackDidNotStart:
            "Music did not start the selected library song. Try a downloaded song or open it once in Music."
        }
    }
}
