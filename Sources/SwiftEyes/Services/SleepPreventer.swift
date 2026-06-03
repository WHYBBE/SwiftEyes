import AppKit
import Foundation
import IOKit
import IOKit.pwr_mgt

final class SleepPreventer {
    var isActive: Bool = false
    var onDeactivate: (() -> Void)?
    private var desiredActive: Bool
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var hasSystemAssertion = false
    private var hasDisplayAssertion = false
    private var lockObserver: Any?
    private var sleepObserver: Any?

    init() {
        desiredActive = UserDefaults.standard.bool(forKey: "sleepPreventionActive")
    }

    func toggle() {
        desiredActive = !desiredActive
        UserDefaults.standard.set(desiredActive, forKey: "sleepPreventionActive")
        isActive = desiredActive
        if isActive {
            preventSleep()
            startMonitoring()
        } else {
            stopMonitoring()
            allowSleep()
        }
    }

    func restore() {
        guard desiredActive else { return }
        isActive = true
        preventSleep()
        startMonitoring()
    }

    private func startMonitoring() {
        guard lockObserver == nil && sleepObserver == nil else { return }
        let dnc = DistributedNotificationCenter.default()
        lockObserver = dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.forceDeactivate()
        }
        let nc = NSWorkspace.shared.notificationCenter
        sleepObserver = nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.forceDeactivate()
        }
    }

    private func stopMonitoring() {
        let dnc = DistributedNotificationCenter.default()
        if let o = lockObserver { dnc.removeObserver(o); lockObserver = nil }
        let nc = NSWorkspace.shared.notificationCenter
        if let o = sleepObserver { nc.removeObserver(o); sleepObserver = nil }
    }

    private func forceDeactivate() {
        allowSleep()
        isActive = false
        onDeactivate?()
        stopMonitoring()
    }

    private func preventSleep() {
        guard !hasSystemAssertion else { return }
        let reason = "SwiftEyes keeping system awake" as CFString

        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &systemAssertionID
        )
        if systemResult == kIOReturnSuccess {
            hasSystemAssertion = true
        } else {
            print("Failed to create system sleep assertion: \(systemResult)")
        }

        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displayAssertionID
        )
        if displayResult == kIOReturnSuccess {
            hasDisplayAssertion = true
        } else {
            print("Failed to create display sleep assertion: \(displayResult)")
        }

        if !hasSystemAssertion && !hasDisplayAssertion {
            isActive = false
        }
    }

    private func allowSleep() {
        if hasSystemAssertion {
            IOPMAssertionRelease(systemAssertionID)
            hasSystemAssertion = false
            systemAssertionID = 0
        }
        if hasDisplayAssertion {
            IOPMAssertionRelease(displayAssertionID)
            hasDisplayAssertion = false
            displayAssertionID = 0
        }
    }

    deinit {
        stopMonitoring()
        allowSleep()
    }
}
