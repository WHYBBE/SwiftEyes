import Foundation
import IOKit
import IOKit.pwr_mgt

final class SleepPreventer {
    var isActive: Bool = false
    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false

    func toggle() {
        isActive = !isActive
        if isActive {
            preventSleep()
        } else {
            allowSleep()
        }
    }

    private func preventSleep() {
        guard !hasAssertion else { return }
        let reason = "SwiftEyes keeping system awake" as CFString
        let assertionName = "PreventUserIdleSystemSleep" as CFString
        let result = IOPMAssertionCreateWithName(
            assertionName,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if result == kIOReturnSuccess {
            hasAssertion = true
        } else {
            print("Failed to create sleep assertion: \(result)")
            isActive = false
            hasAssertion = false
        }
    }

    private func allowSleep() {
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
            assertionID = 0
        }
    }

    deinit {
        allowSleep()
    }
}
