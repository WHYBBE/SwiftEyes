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
        guard let path = finderPath else {
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
        let appPath = terminalPath
        guard FileManager.default.fileExists(atPath: appPath),
              appPath.hasSuffix(".app") else {
            showAlert(message: "终端应用路径无效: \(appPath)")
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", appPath, path]
        do {
            try task.run()
        } catch {
            showAlert(message: "打开终端失败: \(error.localizedDescription)")
        }
    }

    private func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "SwiftEyes"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            NSApp.setActivationPolicy(.regular)
            alert.runModal()
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
