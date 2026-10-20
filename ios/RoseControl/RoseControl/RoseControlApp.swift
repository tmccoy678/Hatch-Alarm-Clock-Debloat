import Security
import SwiftUI

@main
struct RoseControlApp: App {
    @StateObject private var model = RoseModel()

    init() {
        let keychainService = Bundle.main.bundleIdentifier.map { "\($0).hatch" }
            ?? "org.rose-control.hatch"
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
        ] as CFDictionary)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task { await model.start() }
        }
    }
}
