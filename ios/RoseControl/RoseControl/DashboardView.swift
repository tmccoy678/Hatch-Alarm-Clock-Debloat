import RoseControlCore
import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var model: RoseModel
    @State private var showingSounds = false
    @State private var showingAlarm = false
    @State private var brightness = 1.0
    @State private var volume = 9.0
    @State private var customColor = Color(red: 1, green: 0.26, blue: 0)

    private let colors: [(String, Int, Int, Int, Color)] = [
        ("Ember", 255, 67, 0, Color(red: 1, green: 0.26, blue: 0)),
        ("Rose", 255, 78, 92, Color(red: 1, green: 0.31, blue: 0.36)),
        ("Warm", 255, 142, 62, Color(red: 1, green: 0.56, blue: 0.24)),
        ("Moon", 74, 112, 255, Color(red: 0.29, green: 0.44, blue: 1)),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    statusHeader
                    colossusCard
                    lightCard
                    soundCard
                    alarmCard
                    Button(role: .destructive) {
                        Task { await model.allOff() }
                    } label: {
                        Label("Everything off", systemImage: "power")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoseTheme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RoseTheme.rose)
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
            .background(RoseTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                            .foregroundStyle(RoseTheme.secondaryText)
                    }
                    .accessibilityLabel("Reconnect to Rose")
                }
            }
            .sheet(isPresented: $showingSounds) { SoundLibraryView() }
            .sheet(isPresented: $showingAlarm) { AlarmView() }
            .onAppear {
                brightness = Double(model.rose.brightness)
                volume = Double(model.rose.volume)
            }
            .onChange(of: model.rose) { _, state in
                brightness = Double(state.brightness)
                volume = Double(state.volume)
            }
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 14) {
            GlowMark(size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("rose")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(RoseTheme.text)
                Label(
                    model.localControlAvailable ? "local" : (model.rose.online ? "online" : "reaching device"),
                    systemImage: "circle.fill"
                )
                    .font(.caption)
                    .foregroundStyle(model.rose.online ? Color.green.opacity(0.85) : RoseTheme.secondaryText)
            }
            Spacer()
            if model.isWorking { ProgressView().tint(RoseTheme.rose) }
        }
        .padding(.horizontal, 4)
    }

    private var lightCard: some View {
        RoseCard(title: "Light", symbol: "sun.max.fill") {
            HStack {
                Text(model.rose.lightOn ? "On" : "Off")
                    .font(.title3.weight(.medium))
                Spacer()
                Toggle("Light", isOn: Binding(
                    get: { model.rose.lightOn },
                    set: { value in Task { await model.setLight(on: value, brightness: Int(brightness)) } }
                ))
                .labelsHidden()
                .tint(RoseTheme.rose)
            }
            HStack(spacing: 17) {
                ForEach(colors, id: \.0) { item in
                    Button {
                        Task { await model.setLight(on: true, red: item.1, green: item.2, blue: item.3, brightness: Int(brightness)) }
                    } label: {
                        Circle()
                            .fill(item.4)
                            .frame(width: 38, height: 38)
                            .shadow(color: item.4.opacity(0.35), radius: 8)
                            .accessibilityLabel(item.0)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            HStack {
                ColorPicker("Custom color", selection: $customColor, supportsOpacity: false)
                    .foregroundStyle(RoseTheme.text)
                Button("Use") { applyCustomColor() }
                    .buttonStyle(RosePillStyle())
            }
            LabeledSlider(label: "Brightness", value: $brightness, range: 1...100, symbol: "sun.min") {
                Task { await model.setLight(on: true, brightness: Int(brightness)) }
            }
        }
    }

    private var colossusCard: some View {
        RoseCard(title: "World Control", symbol: "wave.3.right.circle.fill") {
            Text(
                model.isLightScenePlaying
                    ? "Transmission active"
                    : "A theatrical light and clock-display overture for Rose."
            )
            .font(.subheadline)
            .foregroundStyle(RoseTheme.secondaryText)

            Button {
                if model.isLightScenePlaying {
                    Task { await model.stopLightScene() }
                } else {
                    model.startColossusMode()
                }
            } label: {
                Label(
                    model.isLightScenePlaying ? "End transmission" : "Begin Colossus Mode",
                    systemImage: model.isLightScenePlaying ? "stop.fill" : "play.fill"
                )
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    model.isLightScenePlaying ? Color.red.opacity(0.7) : Color.blue.opacity(0.52),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
    }

    private var soundCard: some View {
        RoseCard(title: "Sound", symbol: "waveform") {
            LabeledSlider(label: "Volume", value: $volume, range: 0...100, symbol: "speaker.wave.2") {
                Task { await model.setVolume(Int(volume)) }
            }
            Button {
                showingSounds = true
            } label: {
                HStack {
                    Label("Sound library", systemImage: "music.note.list")
                    Spacer()
                    Text("\(model.sounds.count)")
                        .foregroundStyle(RoseTheme.secondaryText)
                    Image(systemName: "chevron.right")
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var alarmCard: some View {
        RoseCard(title: "Alarm", symbol: "alarm.fill") {
            Button {
                showingAlarm = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.alarms.first.flatMap(alarmTime) ?? "Choose a time")
                            .font(.title2.weight(.semibold))
                        Text(model.alarms.first.map { AlarmDays(hatchMask: $0.daysOfWeek).rawValue } ?? "Simple wake-up")
                            .font(.subheadline)
                            .foregroundStyle(RoseTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(RoseTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func alarmTime(_ alarm: HatchAlarm) -> String? {
        guard let date = AlarmTiming.wakeDate(for: alarm) else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func applyCustomColor() {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(customColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
        Task {
            await model.setLight(
                on: true,
                red: Int((red * 255).rounded()),
                green: Int((green * 255).rounded()),
                blue: Int((blue * 255).rounded()),
                brightness: Int(brightness)
            )
        }
    }
}

private struct RoseCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(RoseTheme.secondaryText)
            content
        }
        .padding(20)
        .background(RoseTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(RoseTheme.line.opacity(0.35)))
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let symbol: String
    let onCommit: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Label(label, systemImage: symbol)
                Spacer()
                Text("\(Int(value))%")
                    .monospacedDigit()
                    .foregroundStyle(RoseTheme.secondaryText)
            }
            .font(.subheadline)
            Slider(value: $value, in: range, onEditingChanged: { editing in if !editing { onCommit() } })
                .tint(RoseTheme.rose)
        }
    }
}

private struct RosePillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(RoseTheme.raised.opacity(configuration.isPressed ? 0.65 : 1), in: Capsule())
            .foregroundStyle(RoseTheme.text)
    }
}
