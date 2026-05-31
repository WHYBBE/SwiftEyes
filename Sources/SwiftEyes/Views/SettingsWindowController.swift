import SwiftUI
import AppKit
import Combine

final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var configCancellable: AnyCancellable?

    private override init() { super.init() }

    func show() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = L10n.tr("settings_title")
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.window = newWindow

        configCancellable = EyesConfig.shared.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.title = L10n.tr("settings_title")
            }
    }

    func windowWillClose(_ notification: Notification) {
        configCancellable = nil
        NSApp.setActivationPolicy(.accessory)
        window = nil
    }
}
