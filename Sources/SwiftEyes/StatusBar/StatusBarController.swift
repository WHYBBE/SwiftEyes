import SwiftUI
import AppKit
import Combine

final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem!
    private let mouseTracker = MouseTracker.shared
    private let terminalLauncher = TerminalLauncher()
    private let sleepPreventer = SleepPreventer()
    private let eyesState = EyesState.shared
    private var contextMenu: NSMenu!
    private var rightClickMonitor: Any?
    private var frameObserver: Any?
    private var configCancellable: AnyCancellable?

    override private init() { super.init() }

    func setup() {
        rebuildStatusItem()

        configCancellable = EyesConfig.shared.$totalItemWidth
            .receive(on: RunLoop.main)
            .sink { [weak self] newWidth in
                guard let self, let item = self.statusItem else { return }
                if abs(item.length - newWidth) > 0.5 {
                    item.length = newWidth
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.updateEyeCenters()
                    }
                }
                self.mouseTracker.maxPupilOffset = EyesConfig.shared.maxPupilOffset
                self.updateEyeCenters()
            }
    }

    private func rebuildStatusItem() {
        let totalWidth = EyesConfig.shared.totalItemWidth
        statusItem = NSStatusBar.system.statusItem(withLength: totalWidth)

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "eyes")
        button.imagePosition = .noImage
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = .clear
        button.postsFrameChangedNotifications = true

        button.action = #selector(statusBarButtonClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp])

        let hostingView = NSHostingView(rootView: GooglyEyesView())
        hostingView.frame = button.bounds
        hostingView.autoresizingMask = [.width, .height]
        button.addSubview(hostingView)

        buildContextMenu()

        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
            self?.handleRightClickEvent(event) ?? event
        }

        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: button, queue: .main
        ) { [weak self] _ in self?.updateEyeCenters() }

        mouseTracker.startTracking()
        mouseTracker.maxPupilOffset = EyesConfig.shared.maxPupilOffset

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateEyeCenters()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateEyeCenters()
        }
    }

    private func updateEyeCenters() {
        guard let button = statusItem?.button,
              let window = button.window else { return }

        let btnScreenFrame = window.convertToScreen(button.convert(button.bounds, to: nil))

        let cfg = EyesConfig.shared
        let eyeW = cfg.eyeRadius * 2
        let totalWidth = eyeW * 2 + cfg.eyeGap
        let startX = btnScreenFrame.midX - totalWidth / 2

        let leftCenter = CGPoint(x: startX + cfg.eyeRadius, y: btnScreenFrame.midY)
        let rightCenter = CGPoint(x: startX + eyeW + cfg.eyeGap + cfg.eyeRadius, y: btnScreenFrame.midY)

        mouseTracker.maxPupilOffset = cfg.maxPupilOffset
        mouseTracker.updateScreenCenters(left: leftCenter, right: rightCenter)
    }

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button,
              let event = NSApp.currentEvent else { return }

        let point = button.convert(event.locationInWindow, from: nil)
        if point.x < button.bounds.width / 2 {
            handleLeftEyeClick()
        } else {
            handleRightEyeClick()
        }
    }

    private func handleRightClickEvent(_ event: NSEvent) -> NSEvent {
        guard let button = statusItem?.button else { return event }
        let point = button.convert(event.locationInWindow, from: nil)
        if button.bounds.contains(point) {
            showContextMenu()
            return event
        }
        return event
    }

    private func buildContextMenu() {
        contextMenu = NSMenu()
        contextMenu.delegate = self

        let finderPath = terminalLauncher.finderPath ?? "无"
        let pathItem = NSMenuItem(title: "Finder: \(finderPath)", action: #selector(copyFinderPath), keyEquivalent: "")
        pathItem.target = self
        pathItem.toolTip = "点击复制路径"
        contextMenu.addItem(pathItem)

        let sleepTitle = sleepPreventer.isActive ? "防睡眠: 开启" : "防睡眠: 关闭"
        let sleepItem = NSMenuItem(title: sleepTitle, action: nil, keyEquivalent: "")
        sleepItem.isEnabled = false
        contextMenu.addItem(sleepItem)

        contextMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        contextMenu.addItem(settingsItem)
        contextMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出 SwiftEyes", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func handleLeftEyeClick() {
        terminalLauncher.toggle()
    }

    private func handleRightEyeClick() {
        sleepPreventer.toggle()
        eyesState.rightEyeActive = sleepPreventer.isActive
    }

    @objc private func copyFinderPath() {
        let path = terminalLauncher.finderPath ?? ""
        if !path.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        menu.items.removeAll()
        buildContextMenu()
    }
}
