import AppKit
import Foundation

enum IconManager {
    @MainActor
    static func applyAppIconIfAvailable() {
        let candidates: [(String, String)] = [
            ("AppIcon", "icns"),
            ("AppIcon", "png")
        ]

        for (name, ext) in candidates {
            guard let url = Bundle.module.url(forResource: name, withExtension: ext),
                  let image = NSImage(contentsOf: url) else {
                continue
            }

            NSApplication.shared.applicationIconImage = image
            return
        }
    }
}
