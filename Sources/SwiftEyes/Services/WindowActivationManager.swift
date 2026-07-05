import AppKit

@MainActor
enum WindowActivationManager {
    private static var regularWindowCount = 0

    static func pushRegular() {
        regularWindowCount += 1
        if regularWindowCount == 1 {
            NSApp.setActivationPolicy(.regular)
        }
    }

    static func popRegular() {
        guard regularWindowCount > 0 else { return }
        regularWindowCount -= 1
        if regularWindowCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
