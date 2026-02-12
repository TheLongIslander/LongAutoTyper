import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appUpdater: AppUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Type Clipboard (F12 / fn+F12)") {
                Task {
                    await appModel.handleHotkeyTrigger()
                }
            }

            Text("Main stop: Ctrl+Opt+Cmd+.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Auto-pause on app switch")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Open Window") {
                appModel.openMainWindow()
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

            Divider()

            Text(appModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            Button("Check for Updates...") {
                appUpdater.checkForUpdates()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 260)
        .onAppear {
            appModel.menuBarDidAppear()
        }
        .onDisappear {
            appModel.menuBarDidDisappear()
        }
    }
}
