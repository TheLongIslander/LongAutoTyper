import AppKit
import CoreGraphics
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var manualText: String {
        didSet {
            defaults.set(manualText, forKey: Keys.manualText)
        }
    }

    @Published var keyDelay: Double {
        didSet {
            defaults.set(keyDelay, forKey: Keys.keyDelay)
        }
    }

    @Published var countdownSeconds: Int {
        didSet {
            defaults.set(countdownSeconds, forKey: Keys.countdownSeconds)
        }
    }

    @Published private(set) var isTyping = false
    @Published private(set) var statusMessage = "Idle"

    private let defaults = UserDefaults.standard
    private let clipboardService = ClipboardService()
    private let permissionManager = PermissionManager()
    private let typingEngine = TypingEngine()
    private let hotkeyManager = HotkeyManager()
    private weak var mainWindow: NSWindow?

    private enum Keys {
        static let manualText = "manualText"
        static let keyDelay = "keyDelay"
        static let countdownSeconds = "countdownSeconds"
    }

    init() {
        manualText = defaults.string(forKey: Keys.manualText) ?? ""

        let storedDelay = defaults.object(forKey: Keys.keyDelay) as? Double
        keyDelay = max(0, min(storedDelay ?? 0.02, 2))

        let storedCountdown = defaults.object(forKey: Keys.countdownSeconds) as? Int
        countdownSeconds = max(0, min(storedCountdown ?? 5, 20))

        hotkeyManager.onTrigger = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.startClipboardTyping(
                    source: "Hotkey",
                    countdownOverride: 0,
                    waitForFunctionKeyRelease: true
                )
            }
        }
        hotkeyManager.registerDefaultHotkey()
    }

    func startClipboardTyping(
        source: String = "Button",
        countdownOverride: Int? = nil,
        waitForFunctionKeyRelease: Bool = false
    ) async {
        guard !isTyping else {
            statusMessage = "Typing is already in progress."
            return
        }

        guard permissionManager.isAccessibilityTrusted(prompt: true) else {
            statusMessage = "Accessibility permission is required. Enable it in System Settings."
            return
        }

        guard let text = clipboardService.readText(), !text.isEmpty else {
            statusMessage = "Clipboard is empty."
            return
        }

        if waitForFunctionKeyRelease {
            let released = await waitForFunctionKeyReleaseIfNeeded()
            guard released else {
                statusMessage = "Release fn key and press hotkey again."
                return
            }
        }

        startTyping(
            text: text,
            source: source,
            countdown: countdownOverride ?? countdownSeconds,
            initialDelay: 0
        )
    }

    func startManualTyping() async {
        guard !isTyping else {
            statusMessage = "Typing is already in progress."
            return
        }

        guard permissionManager.isAccessibilityTrusted(prompt: true) else {
            statusMessage = "Accessibility permission is required. Enable it in System Settings."
            return
        }

        let text = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "Manual text is empty."
            return
        }

        startTyping(text: manualText, source: "Manual", countdown: countdownSeconds, initialDelay: 0)
    }

    func stopTyping() {
        Task {
            await typingEngine.stop()
        }
        isTyping = false
        statusMessage = "Typing stopped."
    }

    func registerMainWindow(_ window: NSWindow) {
        mainWindow = window
    }

    func openMainWindow(openWindowAction: () -> Void) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
            return
        }

        openWindowAction()
    }

    private func startTyping(text: String, source: String, countdown: Int, initialDelay: Double) {
        isTyping = true
        statusMessage = "Preparing \(source.lowercased()) typing..."

        Task {
            await typingEngine.start(
                text: text,
                delayPerCharacter: keyDelay,
                countdownSeconds: countdown,
                initialDelaySeconds: initialDelay
            ) { [weak self] update in
                self?.handleTypingUpdate(update, source: source)
            }
        }
    }

    private func waitForFunctionKeyReleaseIfNeeded(timeoutSeconds: Double = 2.0) async -> Bool {
        guard isFunctionModifierDown() else {
            return true
        }

        statusMessage = "Waiting for fn key release..."
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while isFunctionModifierDown() && Date() < deadline {
            do {
                try await Task.sleep(for: .milliseconds(20))
            } catch {
                return false
            }
        }

        return !isFunctionModifierDown()
    }

    private func isFunctionModifierDown() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskSecondaryFn)
    }

    private func handleTypingUpdate(_ update: TypingUpdate, source: String) {
        switch update {
        case .countdown(let secondsLeft):
            statusMessage = "\(source) typing starts in \(secondsLeft)s..."
        case .started(let totalCharacters):
            statusMessage = "Typing \(totalCharacters) characters..."
        case .progress(let typed, let total):
            statusMessage = "Typing... \(typed)/\(total)"
        case .completed:
            isTyping = false
            statusMessage = "Typing finished."
        case .stopped:
            isTyping = false
            statusMessage = "Typing stopped."
        case .failed(let message):
            isTyping = false
            statusMessage = "Typing failed: \(message)"
        }
    }
}
