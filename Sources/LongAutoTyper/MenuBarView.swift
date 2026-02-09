import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Type Clipboard (Cmd+Shift+V)") {
                Task {
                    await appModel.startClipboardTyping(source: "Hotkey")
                }
            }

            Button("Open Window") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            Button("Stop Typing") {
                appModel.stopTyping()
            }
            .disabled(!appModel.isTyping)

            Divider()

            Text(appModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 260)
    }
}
