import AppKit

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
    private var eyesView: GooglyEyesNSView?
    private var updateCentersScheduled = false

    override private init() { super.init() }

    func setup() {
        rebuildStatusItem()

        EyesConfig.shared.onChange = { [weak self] in
            guard let self, let item = self.statusItem else { return }
            let newWidth = EyesConfig.shared.totalItemWidth
            if abs(item.length - newWidth) > 0.5 {
                item.length = newWidth
            }
            self.mouseTracker.maxPupilOffset = EyesConfig.shared.maxPupilOffset
            self.scheduleUpdateEyeCenters()
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

        let view = GooglyEyesNSView()
        view.mouseTracker = mouseTracker
        view.eyesState = eyesState
        view.eyesConfig = EyesConfig.shared
        view.frame = button.bounds
        view.autoresizingMask = [.width, .height]
        button.addSubview(view)
        eyesView = view

        buildContextMenu()

        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
            self?.handleRightClickEvent(event) ?? event
        }

        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: button, queue: .main
        ) { [weak self] _ in self?.scheduleUpdateEyeCenters() }

        mouseTracker.startTracking()
        mouseTracker.maxPupilOffset = EyesConfig.shared.maxPupilOffset

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateEyeCenters()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateEyeCenters()
        }
    }

    private func scheduleUpdateEyeCenters() {
        guard !updateCentersScheduled else { return }
        updateCentersScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.updateCentersScheduled = false
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
        rebuildMenuItems(contextMenu)
    }

    private func rebuildMenuItems(_ menu: NSMenu) {
        menu.items.removeAll()

        let finderPath = terminalLauncher.finderPath ?? "无"

        let pathLabel = NSMenuItem(title: "当前路径: \(finderPath)", action: nil, keyEquivalent: "")
        pathLabel.isEnabled = false
        menu.addItem(pathLabel)

        let copyItem = NSMenuItem(title: "复制路径", action: #selector(copyFinderPath), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)

        let terminalItem = NSMenuItem(title: "在此打开终端", action: #selector(openTerminalHere), keyEquivalent: "t")
        terminalItem.target = self
        menu.addItem(terminalItem)

        menu.addItem(NSMenuItem.separator())

        let sleepTitle = sleepPreventer.isActive ? "防睡眠: 开启" : "防睡眠: 关闭"
        let sleepItem = NSMenuItem(title: sleepTitle, action: #selector(toggleSleepPrevention), keyEquivalent: "s")
        sleepItem.target = self
        menu.addItem(sleepItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出 SwiftEyes", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
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

    @objc private func openTerminalHere() {
        terminalLauncher.launchTerminalAtFinderPath()
    }

    @objc private func toggleSleepPrevention() {
        sleepPreventer.toggle()
        eyesState.rightEyeActive = sleepPreventer.isActive
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
        rebuildMenuItems(menu)
    }
}
