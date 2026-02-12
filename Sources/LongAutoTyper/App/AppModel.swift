import AppKit
import CoreGraphics
import Foundation
import SwiftUI

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
    private let cancelKeyMonitor = CancelKeyMonitor()
    private weak var mainWindow: NSWindow?
    private var windowRetention: NSWindow?
    private var lastProgressStatusUpdate = Date.distantPast
    private var typingTargetAppIdentifier: String?
    private var typingTargetAppName: String?
    private var isMenuBarPanelOpen = false
    private var hasStartedCurrentTypingRun = false
    private var activeTypingRunID = UUID()

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

        hotkeyManager.onStartTrigger = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleHotkeyTrigger()
            }
        }

        hotkeyManager.onStopTrigger = { [weak self] in
            Task { @MainActor [weak self] in
                self?.emergencyStop(reason: "Typing stopped by emergency hotkey.")
            }
        }

        hotkeyManager.onRegistrationWarning = { [weak self] warning in
            Task { @MainActor [weak self] in
                self?.statusMessage = warning
            }
        }

        cancelKeyMonitor.onDeletePressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.emergencyStop(reason: "Typing stopped by delete key.")
            }
        }

        hotkeyManager.registerDefaultHotkey()
    }

    func handleHotkeyTrigger() async {
        if isTyping {
            statusMessage = "Typing in progress. Stop with Ctrl+Opt+Cmd+."
            return
        }

        await startClipboardTyping(
            source: "Hotkey",
            countdownOverride: 0,
            waitForFunctionKeyRelease: true
        )
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
        activeTypingRunID = UUID()
        Task {
            await typingEngine.stop()
        }
        cancelKeyMonitor.stop()
        resetTypingTarget()
        hasStartedCurrentTypingRun = false
        isTyping = false
        statusMessage = "Typing stopped."
    }

    private func emergencyStop(reason: String) {
        activeTypingRunID = UUID()
        Task {
            await typingEngine.stop()
        }
        cancelKeyMonitor.stop()
        resetTypingTarget()
        hasStartedCurrentTypingRun = false
        isTyping = false
        statusMessage = reason
    }

    func menuBarDidAppear() {
        isMenuBarPanelOpen = true
    }

    func menuBarDidDisappear() {
        isMenuBarPanelOpen = false
    }

    func registerMainWindow(_ window: NSWindow) {
        if mainWindow === window {
            return
        }
        mainWindow = window
        windowRetention = window
    }

    func openMainWindow() {
        if mainWindow != nil {
            focusMainWindow()
            return
        }

        let window = makeMainWindow()
        registerMainWindow(window)
        focusMainWindow()
    }

    private func makeMainWindow() -> NSWindow {
        let host = NSHostingController(
            rootView: MainWindowView()
                .environmentObject(self)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LongAutoTyper"
        window.contentViewController = host
        window.setContentSize(NSSize(width: 520, height: 440))
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("LongAutoTyperMainWindow")
        return window
    }

    private func startTyping(text: String, source: String, countdown: Int, initialDelay: Double) {
        resetTypingTarget()
        hasStartedCurrentTypingRun = false
        let runID = UUID()
        activeTypingRunID = runID
        isTyping = true
        let inputMonitoringGranted = permissionManager.requestInputMonitoringIfNeeded()
        let cancelMonitorReady = inputMonitoringGranted && cancelKeyMonitor.start()
        if cancelMonitorReady {
            statusMessage = "Preparing \(source.lowercased()) typing..."
        } else if !inputMonitoringGranted {
            statusMessage = "Preparing \(source.lowercased()) typing... (Enable Input Monitoring for delete-stop)"
        } else {
            statusMessage = "Preparing \(source.lowercased()) typing... (Delete stop unavailable)"
        }

        Task {
            await typingEngine.start(
                text: text,
                delayPerCharacter: keyDelay,
                countdownSeconds: countdown,
                initialDelaySeconds: initialDelay,
                focusStateProvider: { [weak self] in
                    self?.focusStateForCurrentRun() ?? TypingFocusState(isFocused: true, targetAppName: nil)
                }
            ) { [weak self] update in
                self?.handleTypingUpdate(update, source: source, runID: runID)
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

    private func focusMainWindow() {
        guard let mainWindow else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainWindow.deminiaturize(nil)
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.orderFrontRegardless()
    }

    private func resetTypingTarget() {
        typingTargetAppIdentifier = nil
        typingTargetAppName = nil
        hasStartedCurrentTypingRun = false
    }

    private func focusStateForCurrentRun() -> TypingFocusState {
        if isMenuBarPanelOpen && hasStartedCurrentTypingRun {
            return TypingFocusState(
                isFocused: false,
                targetAppName: typingTargetAppName
            )
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return TypingFocusState(
                isFocused: true,
                targetAppName: typingTargetAppName
            )
        }

        let identifier = frontmostApp.bundleIdentifier ?? "pid:\(frontmostApp.processIdentifier)"
        let name = frontmostApp.localizedName ?? "target app"

        if typingTargetAppIdentifier == nil {
            typingTargetAppIdentifier = identifier
            typingTargetAppName = name
        }

        return TypingFocusState(
            isFocused: identifier == typingTargetAppIdentifier,
            targetAppName: typingTargetAppName
        )
    }

    private func handleTypingUpdate(_ update: TypingUpdate, source: String, runID: UUID) {
        guard runID == activeTypingRunID else {
            return
        }

        switch update {
        case .countdown(let secondsLeft):
            isTyping = true
            statusMessage = "\(source) typing starts in \(secondsLeft)s..."
        case .started(let totalCharacters):
            isTyping = true
            hasStartedCurrentTypingRun = true
            lastProgressStatusUpdate = .distantPast
            statusMessage = "Typing \(totalCharacters) chars... Stop: Ctrl+Opt+Cmd+."
        case .paused(let targetAppName):
            isTyping = true
            let targetName = targetAppName ?? "target app"
            statusMessage = "Paused (focus changed). Return to \(targetName) to resume."
        case .resumed(let targetAppName):
            isTyping = true
            let targetName = targetAppName ?? "target app"
            statusMessage = "Resumed in \(targetName). Stop: Ctrl+Opt+Cmd+."
        case .progress(let typed, let total):
            isTyping = true
            let now = Date()
            if now.timeIntervalSince(lastProgressStatusUpdate) < 0.12 && typed < total {
                return
            }
            lastProgressStatusUpdate = now
            statusMessage = "Typing \(typed)/\(total) (Stop: Ctrl+Opt+Cmd+.)"
        case .completed:
            activeTypingRunID = UUID()
            cancelKeyMonitor.stop()
            resetTypingTarget()
            hasStartedCurrentTypingRun = false
            isTyping = false
            statusMessage = "Typing finished."
        case .stopped:
            activeTypingRunID = UUID()
            cancelKeyMonitor.stop()
            resetTypingTarget()
            hasStartedCurrentTypingRun = false
            isTyping = false
            statusMessage = "Typing stopped."
        case .failed(let message):
            activeTypingRunID = UUID()
            cancelKeyMonitor.stop()
            resetTypingTarget()
            hasStartedCurrentTypingRun = false
            isTyping = false
            statusMessage = "Typing failed: \(message)"
        }
    }
}
