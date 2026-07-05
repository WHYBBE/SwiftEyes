import AppKit
import Foundation
import IOKit
import IOKit.pwr_mgt

@MainActor
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
    private var unlockObserver: Any?
    private var wakeObserver: Any?

    init() {
        desiredActive = UserDefaults.standard.bool(forKey: "sleepPreventionActive")
    }

    func toggle() {
        let newDesired = !desiredActive
        if newDesired {
            guard createAssertions() else { return }
            desiredActive = true
            persistDesiredState()
            isActive = true
            startSleepLockMonitoring()
        } else {
            desiredActive = false
            persistDesiredState()
            isActive = false
            stopAllMonitoring()
            releaseAssertions()
        }
    }

    func restoreOnLaunch() {
        guard desiredActive else { return }
        guard createAssertions() else {
            desiredActive = false
            persistDesiredState()
            return
        }
        isActive = true
        startSleepLockMonitoring()
    }

    private func persistDesiredState() {
        let mode = EyesConfig.shared.sleepPersistMode
        if mode == .neverMaintain {
            UserDefaults.standard.removeObject(forKey: "sleepPreventionActive")
        } else {
            UserDefaults.standard.set(desiredActive, forKey: "sleepPreventionActive")
        }
    }

    private func startSleepLockMonitoring() {
        guard lockObserver == nil else { return }
        let dnc = DistributedNotificationCenter.default()
        lockObserver = dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleSleepOrLock() }
        }
        let nc = NSWorkspace.shared.notificationCenter
        sleepObserver = nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleSleepOrLock() }
        }
        startWakeUnlockMonitoring()
    }

    private func startWakeUnlockMonitoring() {
        guard unlockObserver == nil else { return }
        let mode = EyesConfig.shared.sleepPersistMode
        guard mode == .alwaysMaintain, desiredActive else { return }
        let dnc = DistributedNotificationCenter.default()
        unlockObserver = dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleWakeOrUnlock() }
        }
        let nc = NSWorkspace.shared.notificationCenter
        wakeObserver = nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleWakeOrUnlock() }
        }
    }

    private func stopSleepLockMonitoring() {
        let dnc = DistributedNotificationCenter.default()
        if let o = lockObserver { dnc.removeObserver(o); lockObserver = nil }
        let nc = NSWorkspace.shared.notificationCenter
        if let o = sleepObserver { nc.removeObserver(o); sleepObserver = nil }
        stopWakeUnlockMonitoring()
    }

    private func stopWakeUnlockMonitoring() {
        let dnc = DistributedNotificationCenter.default()
        if let o = unlockObserver { dnc.removeObserver(o); unlockObserver = nil }
        let nc = NSWorkspace.shared.notificationCenter
        if let o = wakeObserver { nc.removeObserver(o); wakeObserver = nil }
    }

    private func stopAllMonitoring() {
        stopSleepLockMonitoring()
    }

    private func handleSleepOrLock() {
        releaseAssertions()
        isActive = false
        onDeactivate?()
        stopWakeUnlockMonitoring()
        startWakeUnlockMonitoring()
    }

    private func handleWakeOrUnlock() {
        let mode = EyesConfig.shared.sleepPersistMode
        guard mode == .alwaysMaintain, desiredActive else { return }
        guard createAssertions() else { return }
        isActive = true
        onActivate?()
    }

    var onActivate: (() -> Void)?

    private func createAssertions() -> Bool {
        guard !hasSystemAssertion else { return true }
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

        return hasSystemAssertion || hasDisplayAssertion
    }

    private func releaseAssertions() {
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
        NotificationCenter.default.removeObserver(self)
    }
}
