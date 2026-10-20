import RoseControlCore
import SwiftUI
import UIKit

struct AlarmView: View {
    @EnvironmentObject private var model: RoseModel
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = false
    @State private var time = Date()
    @State private var days = AlarmDays.once
    @State private var sunriseEnabled = true
    @State private var sunriseMinutes = 20
    @State private var sunriseBrightness = 70.0
    @State private var sunriseColor = Color(red: 1, green: 0.31, blue: 0.36)
    @State private var soundEnabled = true
    @State private var selectedSoundID = 0
    @State private var alarmVolume = 35.0
    @State private var loadedAlarmID: Int?

    private let sunriseDurations = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ZStack {
                RoseTheme.background.ignoresSafeArea()
                if let alarm = model.alarms.first {
                    ScrollView {
                        VStack(spacing: 18) {
                            wakeCard
                            sunriseCard
                            soundCard
                            previewCard
                            Button {
                                Task {
                                    await model.updateAlarm(alarm, settings: settings)
                                    if model.errorMessage == nil { dismiss() }
                                }
                            } label: {
                                Text("Save on Rose")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(RoseTheme.rose, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isWorking)

                            Text("The schedule is saved to the alarm clock and keeps working without this phone.")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(RoseTheme.secondaryText)
                                .padding(.horizontal)
                            Text("Press either button on Rose to snooze. Press and hold to stop the alarm.")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(RoseTheme.secondaryText)
                                .padding(.horizontal)
                        }
                        .padding(18)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear { load(alarm) }
                    .onChange(of: alarm.id) { _, _ in load(alarm) }
                } else {
                    ContentUnavailableView(
                        "No alarm slot",
                        systemImage: "alarm",
                        description: Text("Rose needs one saved alarm slot before it can be customized.")
                    )
                }
            }
            .navigationTitle("Wake up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(RoseTheme.rose)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var wakeCard: some View {
        alarmCard(title: "Schedule", symbol: "alarm.fill") {
            DatePicker("Wake at", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .font(.title3.weight(.semibold))
                .tint(RoseTheme.rose)
            Picker("Repeat", selection: $days) {
                ForEach(AlarmDays.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.menu)
            .tint(RoseTheme.rose)
            Toggle("Alarm enabled", isOn: $enabled)
                .font(.headline)
                .tint(RoseTheme.rose)
        }
    }

    private var sunriseCard: some View {
        alarmCard(title: "Sunrise", symbol: "sunrise.fill") {
            Toggle("Wake light", isOn: $sunriseEnabled)
                .font(.headline)
                .tint(RoseTheme.rose)
            if sunriseEnabled {
                Picker("Fade in", selection: $sunriseMinutes) {
                    ForEach(sunriseDurations, id: \.self) { value in
                        Text("\(value) min").tag(value)
                    }
                }
                .pickerStyle(.menu)
                .tint(RoseTheme.rose)
                ColorPicker("Light color", selection: $sunriseColor, supportsOpacity: false)
                VStack(spacing: 7) {
                    HStack {
                        Text("Brightness")
                        Spacer()
                        Text("\(Int(sunriseBrightness))%")
                            .monospacedDigit()
                            .foregroundStyle(RoseTheme.secondaryText)
                    }
                    Slider(value: $sunriseBrightness, in: 1...100)
                        .tint(RoseTheme.rose)
                }
            }
        }
    }

    private var soundCard: some View {
        alarmCard(title: "Wake sound", symbol: "speaker.wave.2.fill") {
            Toggle("Wake sound", isOn: $soundEnabled)
                .font(.headline)
                .tint(RoseTheme.rose)
            if soundEnabled {
                Picker("Sound", selection: $selectedSoundID) {
                    ForEach(model.sounds) { sound in
                        Text(sound.title).tag(sound.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(RoseTheme.rose)
                VStack(spacing: 7) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(alarmVolume))%")
                            .monospacedDigit()
                            .foregroundStyle(RoseTheme.secondaryText)
                    }
                    Slider(value: $alarmVolume, in: 1...100)
                        .tint(RoseTheme.rose)
                }
                Text("Music library tracks play through the iPhone. Saved alarms use Rose's included sounds so they work without the phone.")
                    .font(.caption)
                    .foregroundStyle(RoseTheme.secondaryText)
            }
        }
    }

    private var previewCard: some View {
        alarmCard(title: "Preview", symbol: "play.circle.fill") {
            HStack(spacing: 12) {
                Button("Test alarm") {
                    Task { await model.previewAlarm(settings: settings) }
                }
                .buttonStyle(AlarmPillStyle(accented: true))
                .disabled(!sunriseEnabled && !soundEnabled)
                Button("Stop") {
                    Task { await model.allOff() }
                }
                .buttonStyle(AlarmPillStyle(accented: false))
            }
        }
    }

    private var settings: AlarmSettings {
        let rgb = colorChannels(sunriseColor)
        return AlarmSettings(
            enabled: enabled,
            wakeTime: time,
            days: days,
            sunriseEnabled: sunriseEnabled,
            sunriseDurationMinutes: sunriseMinutes,
            sunriseRed: rgb.red,
            sunriseGreen: rgb.green,
            sunriseBlue: rgb.blue,
            sunriseBrightness: Int(sunriseBrightness),
            soundEnabled: soundEnabled,
            sound: selectedSound,
            volume: Int(alarmVolume)
        )
    }

    private var selectedSound: HatchSound? {
        return model.sounds.first { $0.id == selectedSoundID }
    }

    private func load(_ alarm: HatchAlarm) {
        guard loadedAlarmID != alarm.id else { return }
        loadedAlarmID = alarm.id
        enabled = alarm.enabled ?? false
        days = AlarmDays(hatchMask: alarm.daysOfWeek)

        let sunrise = alarm.steps?.first { $0.name?.localizedCaseInsensitiveCompare("Sunrise") == .orderedSame }
        sunriseEnabled = sunrise.map { $0.enabled != false && $0.color?.ignore != true } ?? false
        if let seconds = sunrise?.color?.duration, seconds > 0 {
            sunriseMinutes = max(1, seconds / 60)
        }
        if let intensity = sunrise?.color?.brightness {
            sunriseBrightness = Double(intensity) / 65_535 * 100
        }
        if let color = sunrise?.color {
            sunriseColor = Color(
                red: channel(color.red),
                green: channel(color.green),
                blue: channel(color.blue)
            )
        }

        let wake = alarm.steps?.first { $0.name?.localizedCaseInsensitiveCompare("Alarm") == .orderedSame }
        soundEnabled = wake.map {
            $0.enabled != false && $0.sound != nil && $0.sound?.ignore != true
        } ?? false
        if let value = wake?.sound?.volume { alarmVolume = Double(value) / 65_535 * 100 }
        if let soundID = wake?.sound?.id, model.sounds.contains(where: { $0.id == soundID }) {
            selectedSoundID = soundID
        } else if let first = model.sounds.first {
            selectedSoundID = first.id
        }

        if let wake = AlarmTiming.wakeDate(for: alarm) { time = wake }
    }

    private func channel(_ value: Int?) -> Double {
        Double(value ?? 0) / 65_535
    }

    private func colorChannels(_ color: Color) -> (red: Int, green: Int, blue: Int) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (255, 78, 92)
        }
        return (
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    private func alarmCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(RoseTheme.secondaryText)
            content()
        }
        .padding(20)
        .background(RoseTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(RoseTheme.line.opacity(0.35)))
    }
}

private struct AlarmPillStyle: ButtonStyle {
    let accented: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                (accented ? RoseTheme.rose : RoseTheme.raised).opacity(configuration.isPressed ? 0.65 : 1),
                in: Capsule()
            )
            .foregroundStyle(RoseTheme.text)
    }
}
