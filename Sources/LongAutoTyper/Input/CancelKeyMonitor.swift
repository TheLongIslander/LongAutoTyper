import Carbon.HIToolbox
import CoreGraphics
import AppKit
import Foundation

final class CancelKeyMonitor {
    var onDeletePressed: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private(set) var isActive = false

    init() {}

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        if isActive {
            return true
        }

        let tapStarted = startTapIfPossible()
        let globalMonitorStarted = startGlobalMonitor()
        startLocalMonitor()
        isActive = tapStarted || globalMonitorStarted
        return isActive
    }

    func stop() {
        stopTap()
        stopEventMonitors()
        isActive = false
    }

    @discardableResult
    private func startTapIfPossible() -> Bool {
        if eventTap != nil {
            enableTap()
            return true
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let monitor = Unmanaged<CancelKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()

                switch type {
                case .tapDisabledByTimeout, .tapDisabledByUserInput:
                    monitor.enableTap()
                case .keyDown:
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    if keyCode == Int64(kVK_Delete) || keyCode == Int64(kVK_ForwardDelete) {
                        monitor.onDeletePressed?()
                    }
                default:
                    break
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            eventTap = nil
            return false
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func startGlobalMonitor() -> Bool {
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyCode(Int64(event.keyCode))
            }
        }

        return globalMonitor != nil
    }

    private func startLocalMonitor() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyCode(Int64(event.keyCode))
                return event
            }
        }
    }

    private func enableTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func stopEventMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func stopTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func handleKeyCode(_ keyCode: Int64) {
        if keyCode == Int64(kVK_Delete) || keyCode == Int64(kVK_ForwardDelete) {
            onDeletePressed?()
        }
    }
}
