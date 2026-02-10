import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    var onStartTrigger: (() -> Void)?
    var onStopTrigger: (() -> Void)?
    var onRegistrationWarning: ((String) -> Void)?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installEventHandler()
    }

    deinit {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func registerDefaultHotkey() {
        // Start: F12 / fn+F12
        // Primary global stop: Ctrl+Opt+Cmd+.
        register(
            bindings: [
                (id: 1, keyCode: UInt32(kVK_F12), modifiers: 0),
                (id: 2, keyCode: UInt32(kVK_F12), modifiers: UInt32(kEventKeyModifierFnMask)),
                (id: 3, keyCode: UInt32(kVK_ANSI_Period), modifiers: UInt32(controlKey | optionKey | cmdKey))
            ]
        )
    }

    private func register(bindings: [(id: UInt32, keyCode: UInt32, modifiers: UInt32)]) {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        for binding in bindings {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: binding.id)

            let status = RegisterEventHotKey(
                binding.keyCode,
                binding.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr, let hotKeyRef {
                hotKeyRefs.append(hotKeyRef)
            } else {
                onRegistrationWarning?("Hotkey registration failed for binding id \(binding.id) (status \(status)).")
            }
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr,
                      hotKeyID.signature == HotkeyManager.signature else {
                    return noErr
                }

                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                switch hotKeyID.id {
                case 1, 2:
                    manager.onStartTrigger?()
                case 3:
                    manager.onStopTrigger?()
                default:
                    break
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
    }

    private static let signature: OSType = {
        let value: UInt32 = 0x4C415459 // LATY
        return OSType(value)
    }()
}
