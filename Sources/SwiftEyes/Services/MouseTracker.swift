import SwiftUI
import Combine

final class MouseTracker: ObservableObject {
    static let shared = MouseTracker()

    @Published var leftPupilOffset: CGPoint = .zero
    @Published var rightPupilOffset: CGPoint = .zero

    var onOffsetChanged: (() -> Void)?

    private var monitor: Any?
    private var lastUpdateTime: TimeInterval = 0
    private let throttleInterval: TimeInterval = 1.0 / 12.0

    var leftEyeScreenCenter: CGPoint = .zero
    var rightEyeScreenCenter: CGPoint = .zero
    var maxPupilOffset: CGFloat = 6.5

    private var prevLeft: CGPoint = CGPoint(x: -999, y: -999)
    private var prevRight: CGPoint = CGPoint(x: -999, y: -999)

    private init() {}

    func startTracking() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.updatePupilPositions()
        }
    }

    func stopTracking() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    func updateScreenCenters(left: CGPoint, right: CGPoint) {
        leftEyeScreenCenter = left
        rightEyeScreenCenter = right
        updatePupilPositions()
    }

    private func updatePupilPositions() {
        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= throttleInterval else { return }
        lastUpdateTime = now

        let mouse = NSEvent.mouseLocation
        let left = computeOffset(from: mouse, to: leftEyeScreenCenter)
        let right = computeOffset(from: mouse, to: rightEyeScreenCenter)

        let leftChanged = abs(left.x - prevLeft.x) > 0.01 || abs(left.y - prevLeft.y) > 0.01
        let rightChanged = abs(right.x - prevRight.x) > 0.01 || abs(right.y - prevRight.y) > 0.01

        guard leftChanged || rightChanged else { return }

        prevLeft = left
        prevRight = right

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if leftChanged { self.leftPupilOffset = left }
            if rightChanged { self.rightPupilOffset = right }
            self.onOffsetChanged?()
        }
    }

    private func computeOffset(from mouse: CGPoint, to center: CGPoint) -> CGPoint {
        guard center.x != 0 || center.y != 0 else { return .zero }
        let dx = mouse.x - center.x
        let dy = center.y - mouse.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 0.5 else { return .zero }

        let angle = atan2(dy, dx)
        let normalX = cos(angle)
        let normalY = sin(angle)

        let saturationDistance: CGFloat = 20
        let t = min(distance / saturationDistance, 1.0)
        let easedT = t * (2 - t)

        let magnitude = maxPupilOffset * easedT
        return CGPoint(x: normalX * magnitude, y: normalY * magnitude)
    }
}
