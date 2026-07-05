import AppKit

@MainActor
final class MouseTracker {
    static let shared = MouseTracker()

    var leftPupilOffset: CGPoint = .zero
    var rightPupilOffset: CGPoint = .zero

    // Single-callback pattern: only one consumer (GooglyEyesNSView for partial redraw).
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
            autoreleasepool {
                self?.updatePupilPositions()
            }
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

        if leftChanged { leftPupilOffset = left }
        if rightChanged { rightPupilOffset = right }
        onOffsetChanged?()
    }

    private func computeOffset(from mouse: CGPoint, to center: CGPoint) -> CGPoint {
        guard center.x != 0 || center.y != 0 else { return .zero }
        let dx = mouse.x - center.x
        let dy = center.y - mouse.y
        let distance = hypot(dx, dy)
        guard distance > 0.5 else { return .zero }

        let saturationDistance: CGFloat = 20
        let t = min(distance / saturationDistance, 1.0)
        let easedT = t * (2 - t)

        let magnitude = maxPupilOffset * easedT
        return CGPoint(x: dx / distance * magnitude, y: dy / distance * magnitude)
    }
}
