import SwiftUI
import Combine

final class EyesState: ObservableObject {
    static let shared = EyesState()

    @Published var rightEyeActive: Bool = false
    @Published var leftBlink: Bool = false
    @Published var rightBlink: Bool = false

    var onChange: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private var globalLeftDownMonitor: Any?
    private var globalLeftUpMonitor: Any?
    private var globalRightDownMonitor: Any?
    private var globalRightUpMonitor: Any?

    private init() {
        $rightEyeActive
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] _ in self?.onChange?() })
            .store(in: &cancellables)

        $leftBlink
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] _ in self?.onChange?() })
            .store(in: &cancellables)

        $rightBlink
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] _ in self?.onChange?() })
            .store(in: &cancellables)

        globalLeftDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.leftBlink = true; self?.onChange?()
        }
        globalLeftUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.leftBlink = false; self?.onChange?()
        }
        globalRightDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
            self?.rightBlink = true; self?.onChange?()
        }
        globalRightUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseUp) { [weak self] _ in
            self?.rightBlink = false; self?.onChange?()
        }
    }
}
