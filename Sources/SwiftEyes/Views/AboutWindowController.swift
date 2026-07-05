import AppKit
import Darwin

@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    private override init() { super.init() }

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = AboutView()
        let hostingSize = contentView.fittingSize
        let contentRect = NSRect(x: 0, y: 0, width: max(hostingSize.width, 280), height: max(hostingSize.height, 180))

        let newWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = L10n.tr("about_title")
        newWindow.contentView = contentView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.makeKeyAndOrderFront(nil)
        WindowActivationManager.pushRegular()
        NSApp.activate(ignoringOtherApps: true)
        self.window = newWindow
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = window else { return }
        w.delegate = nil
        w.contentView = nil
        self.window = nil
        malloc_zone_pressure_relief(nil, 0)
        WindowActivationManager.popRegular()
    }
}

private final class AboutView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        let icon = NSImageView()
        if let appIcon = NSApp.applicationIconImage {
            icon.image = appIcon
        } else if let img = NSImage(systemSymbolName: "eyes", accessibilityDescription: "SwiftEyes") {
            icon.image = img
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let appName = NSTextField(labelWithString: "SwiftEyes")
        appName.font = .systemFont(ofSize: 18, weight: .semibold)
        appName.alignment = .center
        appName.translatesAutoresizingMaskIntoConstraints = false

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let versionLabel = NSTextField(labelWithString: "\(L10n.tr("about_version")) \(version) (\(build))")
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        let desc = NSTextField(labelWithString: L10n.tr("about_description"))
        desc.font = .systemFont(ofSize: 12)
        desc.textColor = .labelColor
        desc.alignment = .center
        desc.lineBreakMode = .byWordWrapping
        desc.preferredMaxLayoutWidth = 260
        desc.translatesAutoresizingMaskIntoConstraints = false

        let license = NSTextField(labelWithString: "MIT License")
        license.font = .systemFont(ofSize: 11)
        license.textColor = .tertiaryLabelColor
        license.alignment = .center
        license.translatesAutoresizingMaskIntoConstraints = false

        let repoURL = "https://github.com/WHYBBE/SwiftEyes"
        let repoLink = NSTextField(labelWithString: repoURL)
        repoLink.font = .systemFont(ofSize: 11)
        repoLink.textColor = .linkColor
        repoLink.alignment = .center
        repoLink.translatesAutoresizingMaskIntoConstraints = false
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(openRepo))
        repoLink.addGestureRecognizer(clickGesture)

        addSubview(icon)
        addSubview(appName)
        addSubview(versionLabel)
        addSubview(desc)
        addSubview(license)
        addSubview(repoLink)

        let spacing: CGFloat = 6

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 20),

            appName.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: spacing),
            appName.centerXAnchor.constraint(equalTo: centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: appName.bottomAnchor, constant: 2),
            versionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            desc.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: spacing),
            desc.centerXAnchor.constraint(equalTo: centerXAnchor),
            desc.widthAnchor.constraint(lessThanOrEqualToConstant: 260),

            license.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: spacing),
            license.centerXAnchor.constraint(equalTo: centerXAnchor),

            repoLink.topAnchor.constraint(equalTo: license.bottomAnchor, constant: 2),
            repoLink.centerXAnchor.constraint(equalTo: centerXAnchor),
            repoLink.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }

    @objc private func openRepo() {
        if let url = URL(string: "https://github.com/WHYBBE/SwiftEyes") {
            NSWorkspace.shared.open(url)
        }
    }
}
