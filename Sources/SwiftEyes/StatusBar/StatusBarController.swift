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
    private var screenChangeObserver: Any?
    private var windowMoveObserver: Any?
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
        if let m = rightClickMonitor {
            NSEvent.removeMonitor(m)
            rightClickMonitor = nil
        }
        if let o = frameObserver {
            NotificationCenter.default.removeObserver(o)
            frameObserver = nil
        }
        if let o = screenChangeObserver {
            NotificationCenter.default.removeObserver(o)
            screenChangeObserver = nil
        }
        if let o = windowMoveObserver {
            NotificationCenter.default.removeObserver(o)
            windowMoveObserver = nil
        }

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

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.updateEyeCenters() }
        }

        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow,
                  window == self?.statusItem?.button?.window else { return }
            self?.scheduleUpdateEyeCenters()
        }

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

        let finderPath = terminalLauncher.finderPath ?? L10n.tr("none")

        let pathLabel = NSMenuItem(title: L10n.tr("menu_path_label", finderPath), action: nil, keyEquivalent: "")
        pathLabel.isEnabled = false
        menu.addItem(pathLabel)

        let copyItem = NSMenuItem(title: L10n.tr("menu_copy_path"), action: #selector(copyFinderPath), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)

        let terminalItem = NSMenuItem(title: L10n.tr("menu_open_terminal"), action: #selector(openTerminalHere), keyEquivalent: "t")
        terminalItem.target = self
        menu.addItem(terminalItem)

        menu.addItem(NSMenuItem.separator())

        let sleepTitle = sleepPreventer.isActive ? L10n.tr("menu_sleep_on") : L10n.tr("menu_sleep_off")
        let sleepItem = NSMenuItem(title: sleepTitle, action: #selector(toggleSleepPrevention), keyEquivalent: "s")
        sleepItem.target = self
        menu.addItem(sleepItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: L10n.tr("menu_settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let refreshItem = NSMenuItem(title: L10n.tr("menu_refresh"), action: #selector(refreshPosition), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let aboutItem = NSMenuItem(title: L10n.tr("menu_about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: L10n.tr("menu_quit"), action: #selector(quitApp), keyEquivalent: "q")
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

    @objc private func refreshPosition() {
        updateEyeCenters()
    }

    @objc private func showAbout() {
        AboutWindowController.shared.show()
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
