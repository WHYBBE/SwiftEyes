import Foundation
import ServiceManagement

enum SleepPersistMode: Int, CaseIterable {
    case alwaysMaintain = 0
    case noMaintainOnSleep = 1
    case neverMaintain = 2

    var labelKey: String {
        switch self {
        case .alwaysMaintain: return "sleep_mode_always"
        case .noMaintainOnSleep: return "sleep_mode_no_sleep"
        case .neverMaintain: return "sleep_mode_never"
        }
    }
}

@MainActor
final class EyesConfig: ObservableObject {
    static let shared = EyesConfig()

    @Published var eyeRadius: Double {
        didSet { UserDefaults.standard.set(eyeRadius, forKey: "eyeRadius"); updateDerived() }
    }
    @Published var pupilRadius: Double {
        didSet { UserDefaults.standard.set(pupilRadius, forKey: "pupilRadius"); updateDerived() }
    }
    @Published var eyeGap: Double {
        didSet { UserDefaults.standard.set(eyeGap, forKey: "eyeGap"); updateDerived() }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            if isInAppBundle { updateLaunchAtLogin() }
        }
    }

    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language"); onChange?() }
    }

    @Published var sleepPersistMode: SleepPersistMode {
        didSet { UserDefaults.standard.set(sleepPersistMode.rawValue, forKey: "sleepPersistMode") }
    }

    let isInAppBundle: Bool

    var maxPupilOffset: Double = 0
    var totalItemWidth: Double = 0
    var itemHeight: Double = 0

    var onChange: (() -> Void)?

    static let didChangeNotification = Notification.Name("EyesConfig.didChange")

    private init() {
        isInAppBundle = Bundle.main.bundleURL.pathExtension == "app"
        eyeRadius = UserDefaults.standard.object(forKey: "eyeRadius") as? Double ?? 11
        pupilRadius = UserDefaults.standard.object(forKey: "pupilRadius") as? Double ?? 5
        eyeGap = UserDefaults.standard.object(forKey: "eyeGap") as? Double ?? 6
        launchAtLogin = isInAppBundle && (UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false)
        language = UserDefaults.standard.string(forKey: "language") ?? "zh"
        sleepPersistMode = SleepPersistMode(rawValue: UserDefaults.standard.integer(forKey: "sleepPersistMode")) ?? .noMaintainOnSleep
        updateDerived()
    }

    private func updateLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login \(launchAtLogin ? "register" : "unregister") failed: \(error).")
            launchAtLogin = false
            UserDefaults.standard.set(false, forKey: "launchAtLogin")
        }
    }

    private func updateDerived() {
        maxPupilOffset = max(eyeRadius - pupilRadius - 1, 0)
        totalItemWidth = eyeRadius * 2 * 2 + eyeGap
        itemHeight = eyeRadius * 2 + 4
        onChange?()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
