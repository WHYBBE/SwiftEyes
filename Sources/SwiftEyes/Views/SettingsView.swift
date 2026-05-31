import AppKit

final class SettingsView: NSView {
    private let config = EyesConfig.shared

    private var eyeRadiusSlider: NSSlider!
    private var eyeRadiusLabel: NSTextField!
    private var pupilRadiusSlider: NSSlider!
    private var pupilRadiusLabel: NSTextField!
    private var eyeGapSlider: NSSlider!
    private var eyeGapLabel: NSTextField!
    private var warningLabel: NSTextField!

    private var languagePopUp: NSPopUpButton!
    private var launchAtLoginCheckbox: NSButton!
    private var launchHintLabel: NSTextField!

    private var terminalPopUp: NSPopUpButton!
    private var terminalPathField: NSTextField!
    private var browseButton: NSButton!

    private let commonTerminals = [
        ("Terminal", "/System/Applications/Utilities/Terminal.app"),
        ("iTerm", "/Applications/iTerm.app"),
        ("Alacritty", "/Applications/Alacritty.app"),
        ("Warp", "/Applications/Warp.app"),
        ("Kitty", "/Applications/kitty.app"),
        ("Hyper", "/Applications/Hyper.app"),
    ]

    private var configObserver: NSObjectProtocol?

    private enum SliderTag: Int {
        case eyeRadius = 1
        case pupilRadius = 2
        case eyeGap = 3
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        buildUI()
        updateLabels()
        configObserver = NotificationCenter.default.addObserver(
            forName: EyesConfig.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.updateLabels() }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let o = configObserver { NotificationCenter.default.removeObserver(o) }
    }

    private func buildUI() {
        var cy: CGFloat = 375

        cy = addSectionHeader(L10n.tr("appearance"), at: cy)
        eyeRadiusSlider = addSliderRow(label: L10n.tr("eye_size"), value: config.eyeRadius,
                                        min: 6, max: 18, tag: .eyeRadius, at: &cy)
        pupilRadiusSlider = addSliderRow(label: L10n.tr("pupil_size"), value: config.pupilRadius,
                                           min: 2, max: 10, tag: .pupilRadius, at: &cy)
        eyeGapSlider = addSliderRow(label: L10n.tr("eye_gap"), value: config.eyeGap,
                                     min: 0, max: 20, tag: .eyeGap, at: &cy)

        warningLabel = NSTextField(labelWithString: "")
        warningLabel.textColor = .systemOrange
        warningLabel.font = .systemFont(ofSize: 11)
        warningLabel.frame = NSRect(x: 130, y: cy - 2, width: 300, height: 16)
        addSubview(warningLabel)
        cy -= 24

        cy = addSectionHeader(L10n.tr("general"), at: cy)

        let langLabel = makeLabel(L10n.tr("language"))
        langLabel.frame = NSRect(x: 20, y: cy, width: 110, height: 20)
        addSubview(langLabel)
        languagePopUp = NSPopUpButton(frame: NSRect(x: 130, y: cy - 2, width: 280, height: 24))
        languagePopUp.addItem(withTitle: "中文")
        languagePopUp.addItem(withTitle: "English")
        languagePopUp.selectItem(at: config.language == "en" ? 1 : 0)
        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged)
        addSubview(languagePopUp)
        cy -= 30

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: L10n.tr("launch_at_login"),
                                          target: self, action: #selector(launchAtLoginChanged))
        launchAtLoginCheckbox.frame = NSRect(x: 130, y: cy, width: 280, height: 20)
        launchAtLoginCheckbox.state = config.launchAtLogin ? .on : .off
        launchAtLoginCheckbox.isEnabled = config.isInAppBundle
        addSubview(launchAtLoginCheckbox)
        cy -= 22

        launchHintLabel = NSTextField(labelWithString: L10n.tr("launch_at_login_hint"))
        launchHintLabel.textColor = .secondaryLabelColor
        launchHintLabel.font = .systemFont(ofSize: 11)
        launchHintLabel.frame = NSRect(x: 130, y: cy, width: 300, height: 16)
        launchHintLabel.isHidden = config.isInAppBundle
        addSubview(launchHintLabel)
        cy -= 26

        cy = addSectionHeader(L10n.tr("terminal_app"), at: cy)

        let termLabel = makeLabel(L10n.tr("select_terminal"))
        termLabel.frame = NSRect(x: 20, y: cy, width: 110, height: 20)
        addSubview(termLabel)
        terminalPopUp = NSPopUpButton(frame: NSRect(x: 130, y: cy - 2, width: 280, height: 24))
        let savedPath = UserDefaults.standard.string(forKey: "terminalPath")
            ?? "/System/Applications/Utilities/Terminal.app"
        for (i, (name, path)) in commonTerminals.enumerated() {
            terminalPopUp.addItem(withTitle: name)
            terminalPopUp.lastItem?.representedObject = path
            if path == savedPath { terminalPopUp.selectItem(at: i) }
        }
        terminalPopUp.target = self
        terminalPopUp.action = #selector(terminalChanged)
        addSubview(terminalPopUp)
        cy -= 30

        let pathLabel = makeLabel(L10n.tr("terminal_path"))
        pathLabel.frame = NSRect(x: 20, y: cy, width: 110, height: 20)
        addSubview(pathLabel)
        terminalPathField = NSTextField(frame: NSRect(x: 130, y: cy - 1, width: 210, height: 22))
        terminalPathField.stringValue = savedPath
        terminalPathField.target = self
        terminalPathField.action = #selector(terminalPathEdited)
        addSubview(terminalPathField)
        browseButton = NSButton(frame: NSRect(x: 350, y: cy - 1, width: 70, height: 22))
        browseButton.title = L10n.tr("browse")
        browseButton.bezelStyle = .rounded
        browseButton.target = self
        browseButton.action = #selector(browseTerminal)
        addSubview(browseButton)
        cy -= 30

        cy = addSectionHeader(L10n.tr("shortcuts"), at: cy)

        let shortcuts = [
            L10n.tr("shortcut_left_eye"),
            L10n.tr("shortcut_right_eye"),
            L10n.tr("shortcut_left_click"),
            L10n.tr("shortcut_right_click"),
        ]
        for text in shortcuts {
            let lbl = NSTextField(labelWithString: text)
            lbl.font = .systemFont(ofSize: 12)
            lbl.frame = NSRect(x: 130, y: cy, width: 300, height: 16)
            addSubview(lbl)
            cy -= 20
        }
    }

    private func addSectionHeader(_ title: String, at y: CGFloat) -> CGFloat {
        let line = NSView(frame: NSRect(x: 20, y: y + 5, width: 400, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(line)
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.frame = NSRect(x: 20, y: y - 14, width: 400, height: 18)
        addSubview(label)
        return y - 28
    }

    @discardableResult
    private func addSliderRow(label: String, value: Double, min: Double, max: Double,
                              tag: SliderTag, at cy: inout CGFloat) -> NSSlider {
        let lbl = makeLabel(label)
        lbl.frame = NSRect(x: 20, y: cy, width: 110, height: 20)
        addSubview(lbl)

        let slider = NSSlider(frame: NSRect(x: 130, y: cy, width: 230, height: 20))
        slider.minValue = min
        slider.maxValue = max
        slider.doubleValue = value
        slider.isContinuous = true
        slider.tag = tag.rawValue
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        addSubview(slider)

        let vf = NSTextField(labelWithString: "")
        vf.alignment = .right
        vf.frame = NSRect(x: 370, y: cy, width: 36, height: 20)
        addSubview(vf)

        switch tag {
        case .eyeRadius: eyeRadiusLabel = vf
        case .pupilRadius: pupilRadiusLabel = vf
        case .eyeGap: eyeGapLabel = vf
        }

        cy -= 28
        return slider
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.alignment = .right
        lbl.font = .systemFont(ofSize: 13)
        return lbl
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        switch SliderTag(rawValue: sender.tag) {
        case .eyeRadius: config.eyeRadius = sender.doubleValue
        case .pupilRadius: config.pupilRadius = sender.doubleValue
        case .eyeGap: config.eyeGap = sender.doubleValue
        default: break
        }
    }

    private func updateLabels() {
        eyeRadiusLabel?.stringValue = "\(Int(config.eyeRadius))"
        pupilRadiusLabel?.stringValue = String(format: "%.1f", config.pupilRadius)
        eyeGapLabel?.stringValue = "\(Int(config.eyeGap))"

        eyeRadiusSlider?.doubleValue = config.eyeRadius
        pupilRadiusSlider?.doubleValue = config.pupilRadius
        eyeGapSlider?.doubleValue = config.eyeGap

        warningLabel?.stringValue = config.pupilRadius >= config.eyeRadius - 1 ? L10n.tr("pupil_too_large") : ""
    }

    @objc private func languageChanged() {
        config.language = languagePopUp.indexOfSelectedItem == 1 ? "en" : "zh"
        if let window = self.window {
            window.title = L10n.tr("settings_title")
        }
        rebuildUI()
    }

    @objc private func launchAtLoginChanged() {
        config.launchAtLogin = launchAtLoginCheckbox.state == .on
    }

    @objc private func terminalChanged() {
        guard let path = terminalPopUp.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(path, forKey: "terminalPath")
        terminalPathField.stringValue = path
    }

    @objc private func terminalPathEdited() {
        UserDefaults.standard.set(terminalPathField.stringValue, forKey: "terminalPath")
    }

    @objc private func browseTerminal() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            terminalPathField.stringValue = url.path
            UserDefaults.standard.set(url.path, forKey: "terminalPath")
        }
    }

    private func rebuildUI() {
        subviews.forEach { $0.removeFromSuperview() }
        buildUI()
        updateLabels()
    }
}
