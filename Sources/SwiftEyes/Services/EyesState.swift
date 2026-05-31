import AppKit

final class EyesState {
    static let shared = EyesState()

    var rightEyeActive: Bool = false {
        didSet { if rightEyeActive != oldValue { onChange?() } }
    }
    var leftBlink: Bool = false {
        didSet { if leftBlink != oldValue { onChange?() } }
    }
    var rightBlink: Bool = false {
        didSet { if rightBlink != oldValue { onChange?() } }
    }

    var onChange: (() -> Void)?

    private var globalLeftDownMonitor: Any?
    private var globalLeftUpMonitor: Any?
    private var globalRightDownMonitor: Any?
    private var globalRightUpMonitor: Any?

    private init() {
        globalLeftDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.leftBlink = true
        }
        globalLeftUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.leftBlink = false
        }
        globalRightDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
            self?.rightBlink = true
        }
        globalRightUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseUp) { [weak self] _ in
            self?.rightBlink = false
        }
    }
}
