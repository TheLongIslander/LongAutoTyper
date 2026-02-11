import AppKit
import SwiftUI

@main
struct LongAutoTyperApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        IconManager.applyAppIconIfAvailable()
    }

    var body: some Scene {
        MenuBarExtra("LongAutoTyper", systemImage: "keyboard") {
            MenuBarView()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)
    }
}
