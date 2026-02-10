import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LongAutoTyper")
                .font(.title2.weight(.semibold))

            Text("Global hotkey: F12 (fn+F12 also supported)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Main stop key: Ctrl + Option + Command + .")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)

            GroupBox("Manual Text") {
                TextEditor(text: $appModel.manualText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
                    .padding(.top, 4)
            }

            GroupBox("Typing Settings") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Delay per character")
                        Spacer()
                        Text(appModel.keyDelay.formatted(.number.precision(.fractionLength(2))) + "s")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $appModel.keyDelay, in: 0...1, step: 0.01)

                    Stepper(value: $appModel.countdownSeconds, in: 0...20) {
                        Text("Countdown: \(appModel.countdownSeconds)s")
                    }
                }
                .padding(.top, 2)
            }

            HStack(spacing: 10) {
                Button("Type Manual Text") {
                    Task {
                        await appModel.startManualTyping()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Type Clipboard") {
                    Task {
                        await appModel.startClipboardTyping(source: "Button")
                    }
                }

                Button("Stop") {
                    appModel.stopTyping()
                }
                .disabled(!appModel.isTyping)
            }

            Text(appModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            WindowAccessor { window in
                appModel.registerMainWindow(window)
            }
        )
    }
}
