import SwiftUI

@main
struct LongAutoTyperApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        Window("LongAutoTyper", id: "main") {
            MainWindowView()
                .environmentObject(appModel)
        }
        .defaultSize(width: 520, height: 440)

        MenuBarExtra("LongAutoTyper", systemImage: "keyboard") {
            MenuBarView()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)
    }
}
