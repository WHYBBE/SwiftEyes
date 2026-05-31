import Foundation
import AppKit

final class TerminalLauncher {
    var terminalPath: String {
        UserDefaults.standard.string(forKey: "terminalPath")
            ?? "/System/Applications/Utilities/Terminal.app"
    }

    private var cachedPath: String?
    private var cacheTime: TimeInterval = 0
    private let cacheTTL: TimeInterval = 2.0

    var finderPath: String? {
        let now = CACurrentMediaTime()
        if let cached = cachedPath, now - cacheTime < cacheTTL {
            return cached.isEmpty ? nil : cached
        }
        let path = getFrontFinderPath() ?? ""
        cachedPath = path
        cacheTime = now
        return path.isEmpty ? nil : path
    }

    func toggle() {
        launchTerminalAtFinderPath()
    }

    func launchTerminalAtFinderPath() {
        guard let path = getFrontFinderPath() else {
            openTerminal(at: NSHomeDirectory())
            return
        }
        openTerminal(at: path)
    }

    private func getFrontFinderPath() -> String? {
        let script = NSAppleScript(source: """
        tell application "Finder"
            if (count of Finder windows) > 0 then
                return POSIX path of (target of front Finder window as alias)
            else
                return ""
            end if
        end tell
        """)

        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if let error {
            print("AppleScript error: \(error)")
            return nil
        }
        let path = result?.stringValue ?? ""
        return path.isEmpty ? nil : path
    }

    private func openTerminal(at path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", terminalPath, path]
        try? task.run()
    }
}
