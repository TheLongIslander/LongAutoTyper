import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum KeyEventTyper {
    static func type(character: Character) -> Bool {
        if character == "\n" || character == "\r" {
            return postKeyCode(CGKeyCode(kVK_Return))
        }

        if character == "\t" {
            return postKeyCode(CGKeyCode(kVK_Tab))
        }

        return postUnicode(character)
    }

    private static func postUnicode(_ character: Character) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        var unicodeUnits = Array(String(character).utf16)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return false
        }

        keyDown.keyboardSetUnicodeString(stringLength: unicodeUnits.count, unicodeString: &unicodeUnits)
        keyUp.keyboardSetUnicodeString(stringLength: unicodeUnits.count, unicodeString: &unicodeUnits)

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private static func postKeyCode(_ keyCode: CGKeyCode) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
