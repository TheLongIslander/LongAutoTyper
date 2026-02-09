import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Type Clipboard (F12 / fn+F12)") {
                Task {
                    await appModel.startClipboardTyping(
                        source: "Hotkey",
                        countdownOverride: 0,
                        waitForFunctionKeyRelease: true
                    )
                }
            }

            Button("Open Window") {
                appModel.openMainWindow {
                    openWindow(id: "main")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Delay")
                    Spacer()
                    Text(appModel.keyDelay.formatted(.number.precision(.fractionLength(2))) + "s")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $appModel.keyDelay, in: 0...1, step: 0.01)
            }
            .padding(.top, 2)

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
