import SwiftUI
import Combine
import ServiceManagement

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
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin"); updateLaunchAtLogin() }
    }

    @Published var maxPupilOffset: Double = 0
    @Published var totalItemWidth: Double = 0
    @Published var itemHeight: Double = 0

    var onChange: (() -> Void)?

    private init() {
        eyeRadius = UserDefaults.standard.object(forKey: "eyeRadius") as? Double ?? 11
        pupilRadius = UserDefaults.standard.object(forKey: "pupilRadius") as? Double ?? 5
        eyeGap = UserDefaults.standard.object(forKey: "eyeGap") as? Double ?? 6
        launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
        updateDerived()
    }

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    private func updateDerived() {
        maxPupilOffset = max(eyeRadius - pupilRadius - 1, 0)
        totalItemWidth = eyeRadius * 2 * 2 + eyeGap
        itemHeight = eyeRadius * 2 + 4
        onChange?()
    }
}
