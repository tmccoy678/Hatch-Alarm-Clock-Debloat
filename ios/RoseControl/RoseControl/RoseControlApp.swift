import SwiftUI

@main
struct RoseControlApp: App {
    @StateObject private var model = RoseModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task { await model.start() }
        }
    }
}
