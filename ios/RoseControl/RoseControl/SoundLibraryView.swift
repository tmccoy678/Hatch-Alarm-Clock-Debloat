import RoseControlCore
import SwiftUI

struct SoundLibraryView: View {
    @EnvironmentObject private var model: RoseModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showingMusicLibrary = false
    @AppStorage("customRadioURL") private var customRadioURL = ""

    private var filtered: [HatchSound] {
        let values = search.isEmpty
            ? model.sounds
            : model.sounds.filter { $0.title.localizedCaseInsensitiveContains(search) }
        return values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Radio") {
                    ForEach(RadioCatalog.favorites) { station in
                        Button {
                            Task { await model.playRadio(station) }
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: model.radioStationID == station.id ? "radio.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(model.radioStationID == station.id ? RoseTheme.rose : RoseTheme.secondaryText)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(station.name)
                                        .foregroundStyle(RoseTheme.text)
                                    Text(station.description)
                                        .font(.caption)
                                        .foregroundStyle(RoseTheme.secondaryText)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    DisclosureGroup("Custom station") {
                        TextField("https://station.example/live.mp3", text: $customRadioURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .foregroundStyle(RoseTheme.text)
                        Button {
                            Task { await model.playRadio(url: customRadioURL) }
                        } label: {
                            Label("Play stream URL", systemImage: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(RoseTheme.rose)
                        }
                        .disabled(customRadioURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let title = model.radioStationTitle {
                        HStack {
                            Text("Playing \(title) directly on Rose.")
                                .font(.caption)
                                .foregroundStyle(RoseTheme.secondaryText)
                            Spacer()
                            Button("Stop") {
                                Task { await model.stopSound() }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RoseTheme.rose)
                        }
                    }
                }
                .listRowBackground(RoseTheme.panel)

                Section("Your audio") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Connect to Rose")
                                .foregroundStyle(RoseTheme.text)
                            Text("Tap AirPlay and choose Rose")
                                .font(.caption)
                                .foregroundStyle(RoseTheme.secondaryText)
                        }
                        Spacer()
                        RoseAirPlayPicker()
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Choose Rose AirPlay output")
                    }
                    Button {
                        showingMusicLibrary = true
                    } label: {
                        Label("Choose from Music", systemImage: "music.note.list")
                            .foregroundStyle(RoseTheme.rose)
                    }
                    Button {
                        Task { await model.stopSound() }
                    } label: {
                        Label("Stop sound", systemImage: "speaker.slash.fill")
                            .foregroundStyle(RoseTheme.secondaryText)
                    }
                    if let title = model.musicTrackTitle {
                        Text("Streaming \(title) through Rose.")
                            .font(.caption)
                            .foregroundStyle(RoseTheme.secondaryText)
                    }
                }
                .listRowBackground(RoseTheme.panel)

                Section("Included sounds") {
                    ForEach(filtered) { sound in
                        HStack(spacing: 13) {
                            Button {
                                Task { await model.play(sound) }
                            } label: {
                                Image(systemName: model.rose.soundID == sound.id ? "speaker.wave.2.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(model.rose.soundID == sound.id ? RoseTheme.rose : RoseTheme.secondaryText)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sound.title)
                                    .foregroundStyle(RoseTheme.text)
                                Text("Included sounds")
                                    .font(.caption)
                                    .foregroundStyle(RoseTheme.secondaryText)
                            }
                            Spacer()
                        }
                    }
                }
                .listRowBackground(RoseTheme.panel)
            }
            .scrollContentBackground(.hidden)
            .background(RoseTheme.background)
            .searchable(text: $search, prompt: "Search sounds")
            .navigationTitle("Sound library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(RoseTheme.rose)
                }
            }
            .sheet(isPresented: $showingMusicLibrary) {
                MusicLibraryView { item in
                    showingMusicLibrary = false
                    Task { await model.playMusicItem(item) }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
