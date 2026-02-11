@preconcurrency import ApplicationServices
import Foundation

struct PermissionManager {
    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func requestInputMonitoringIfNeeded() -> Bool {
        if #available(macOS 10.15, *) {
            if CGPreflightListenEventAccess() {
                return true
            }
            return CGRequestListenEventAccess()
        }
        return true
    }
}
