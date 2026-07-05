import AppKit

@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem!
    private let mouseTracker = MouseTracker.shared
    private let terminalLauncher = TerminalLauncher()
    private let sleepPreventer = SleepPreventer()
    private let eyesState = EyesState.shared
    private var contextMenu: NSMenu!
    private var frameObserver: Any?
    private var screenChangeObserver: Any?
    private var windowMoveObserver: Any?
    private var eyesView: GooglyEyesNSView?
    private var updateCentersScheduled = false

    override private init() { super.init() }

    func setup() {
        rebuildStatusItem()

        sleepPreventer.onDeactivate = { [weak self] in
            guard let self else { return }
            self.eyesState.rightEyeActive = false
        }
        sleepPreventer.restore()
        if sleepPreventer.isActive {
            eyesState.rightEyeActive = true
        }

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
        button.sendAction(on: [.leftMouseUp, .rightMouseDown])

        let view = GooglyEyesNSView()
        view.mouseTracker = mouseTracker
        view.eyesState = eyesState
        view.eyesConfig = EyesConfig.shared
        view.frame = button.bounds
        view.autoresizingMask = [.width, .height]
        button.addSubview(view)
        eyesView = view

        buildContextMenu()

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

    private var isHandlingRightClick = false

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button,
              let event = NSApp.currentEvent else { return }
        switch event.type {
        case .leftMouseUp:
            rebuildMenuItems(contextMenu)
            // y: button.bounds.height 在按钮顶部弹出菜单；macOS 27 略偏上但可接受，macOS 15 位置正常
            contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        case .rightMouseDown:
            guard !isHandlingRightClick else { return }
            isHandlingRightClick = true
            let mouseLoc = NSEvent.mouseLocation
            guard let buttonWindow = button.window else {
                isHandlingRightClick = false
                return
            }
            let buttonScreenRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            guard buttonScreenRect.contains(mouseLoc) else {
                isHandlingRightClick = false
                return
            }
            let relativeX = mouseLoc.x - buttonScreenRect.minX
            if relativeX < buttonScreenRect.width / 2 {
                handleLeftEyeClick()
            } else {
                handleRightEyeClick()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isHandlingRightClick = false
            }
        default:
            break
        }
    }

    private func buildContextMenu() {
        contextMenu = NSMenu()
        rebuildMenuItems(contextMenu)
    }

    private func rebuildMenuItems(_ menu: NSMenu) {
        menu.items.removeAll()

        let finderPath = terminalLauncher.finderPath ?? L10n.tr("none")
        let truncatedPath = middleTruncate(finderPath, maxLength: 20)
        let pathLabel = NSMenuItem(title: L10n.tr("menu_path_label", truncatedPath), action: nil, keyEquivalent: "")
        pathLabel.isEnabled = false
        pathLabel.toolTip = finderPath != L10n.tr("none") ? L10n.tr("menu_path_label", finderPath) : nil
        menu.addItem(pathLabel)

        let copyItem = NSMenuItem(title: L10n.tr("menu_copy_path"), action: #selector(copyFinderPath), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        let terminalItem = NSMenuItem(title: L10n.tr("menu_open_terminal"), action: #selector(openTerminalHere), keyEquivalent: "")
        terminalItem.target = self
        menu.addItem(terminalItem)

        menu.addItem(NSMenuItem.separator())

        let sleepTitle = sleepPreventer.isActive ? L10n.tr("menu_sleep_on") : L10n.tr("menu_sleep_off")
        let sleepItem = NSMenuItem(title: sleepTitle, action: #selector(toggleSleepPrevention), keyEquivalent: "")
        sleepItem.target = self
        menu.addItem(sleepItem)

        let settingsItem = NSMenuItem(title: L10n.tr("menu_settings"), action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let refreshItem = NSMenuItem(title: L10n.tr("menu_refresh"), action: #selector(refreshPosition), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let aboutItem = NSMenuItem(title: L10n.tr("menu_about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: L10n.tr("menu_quit"), action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
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

private func middleTruncate(_ s: String, maxLength: Int) -> String {
    guard s.count > maxLength else { return s }
    let head = s.prefix((maxLength - 1) / 2)
    let tail = s.suffix(maxLength - 1 - (maxLength - 1) / 2)
    return "\(head)…\(tail)"
}


