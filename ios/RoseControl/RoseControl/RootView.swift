import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: RoseModel

    var body: some View {
        ZStack {
            RoseTheme.background.ignoresSafeArea()
            switch model.phase {
            case .connecting:
                VStack(spacing: 18) {
                    GlowMark(size: 92)
                    ProgressView()
                        .tint(RoseTheme.rose)
                    Text("Connecting directly to rose")
                        .foregroundStyle(RoseTheme.secondaryText)
                }
            case .offline:
                VStack(spacing: 20) {
                    GlowMark(size: 92)
                    Text("Rose is offline")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(RoseTheme.text)
                    Text("Rose will reconnect automatically when it is nearby and Bluetooth is on. Use the clock's Bluetooth button only for first pairing or after a reset.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(RoseTheme.secondaryText)
                    Button("Retry") {
                        Task { await model.retry() }
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 14)
                    .background(RoseTheme.rose, in: Capsule())
                    .foregroundStyle(.white)
                }
                .padding(30)
            case .ready:
                DashboardView()
            }
        }
        .alert("Rose Control", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

enum RoseTheme {
    static let background = Color(red: 0.035, green: 0.075, blue: 0.16)
    static let panel = Color(red: 0.075, green: 0.13, blue: 0.24)
    static let raised = Color(red: 0.11, green: 0.18, blue: 0.31)
    static let line = Color(red: 0.23, green: 0.35, blue: 0.52)
    static let rose = Color(red: 1.0, green: 0.43, blue: 0.42)
    static let warm = Color(red: 1.0, green: 0.73, blue: 0.53)
    static let text = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let secondaryText = Color(red: 0.64, green: 0.71, blue: 0.82)
}

struct GlowMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RoseTheme.rose.opacity(0.17))
                .frame(width: size, height: size)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [RoseTheme.warm, RoseTheme.rose],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.36
                    )
                )
                .frame(width: size * 0.58, height: size * 0.58)
                .shadow(color: RoseTheme.rose.opacity(0.55), radius: 18)
        }
    }
}
