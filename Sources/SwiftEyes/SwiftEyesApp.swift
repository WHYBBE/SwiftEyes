import SwiftUI

@main
struct SwiftEyesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusBarController = StatusBarController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MouseTracker.shared.stopTracking()
    }
}
