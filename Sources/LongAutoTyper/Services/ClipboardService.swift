import AppKit
import Foundation

struct ClipboardService {
    func readText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
