import Foundation
import IOKit
import IOKit.pwr_mgt

final class SleepPreventer {
    var isActive: Bool = false
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var hasSystemAssertion = false
    private var hasDisplayAssertion = false

    func toggle() {
        isActive = !isActive
        if isActive {
            preventSleep()
        } else {
            allowSleep()
        }
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
        allowSleep()
    }
}
