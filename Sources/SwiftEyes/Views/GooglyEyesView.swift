import AppKit

@MainActor
final class GooglyEyesNSView: NSView {
    var mouseTracker: MouseTracker! {
        didSet { mouseTracker.onOffsetChanged = { [weak self] in self?.invalidatePupilAreas() } }
    }
    var eyesState: EyesState! {
        didSet { eyesState.onChange = { [weak self] in self?.needsDisplay = true } }
    }
    var eyesConfig: EyesConfig!

    private var configObserver: NSObjectProtocol?
    private var prevLeftOffset: CGPoint = .zero
    private var prevRightOffset: CGPoint = .zero

    private static let white70 = NSColor.white.withAlphaComponent(0.7).cgColor
    private static let white = NSColor.white.cgColor
    private static let black = NSColor.black.cgColor
    private static let red = NSColor.red.cgColor

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear

        configObserver = NotificationCenter.default.addObserver(
            forName: EyesConfig.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.needsDisplay = true }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    private func invalidatePupilAreas() {
        let leftOffset = mouseTracker?.leftPupilOffset ?? .zero
        let rightOffset = mouseTracker?.rightPupilOffset ?? .zero

        let pr = CGFloat(eyesConfig?.pupilRadius ?? 5) + 2

        let dirtyLeft = pupilDirtyRect(center: leftEyeCenter, offset: prevLeftOffset, pr: pr)
        let dirtyRight = pupilDirtyRect(center: rightEyeCenter, offset: prevRightOffset, pr: pr)

        prevLeftOffset = leftOffset
        prevRightOffset = rightOffset

        setNeedsDisplay(dirtyLeft)
        setNeedsDisplay(dirtyRight)
    }

    private var leftEyeCenter: NSPoint {
        let cfg = eyesConfig ?? EyesConfig.shared
        let eyeW = cfg.eyeRadius * 2
        let totalWidth = eyeW * 2 + cfg.eyeGap
        let startX = (bounds.width - totalWidth) / 2
        return NSPoint(x: startX + cfg.eyeRadius, y: bounds.height / 2)
    }

    private var rightEyeCenter: NSPoint {
        let cfg = eyesConfig ?? EyesConfig.shared
        let eyeW = cfg.eyeRadius * 2
        let totalWidth = eyeW * 2 + cfg.eyeGap
        let startX = (bounds.width - totalWidth) / 2
        return NSPoint(x: startX + eyeW + cfg.eyeGap + cfg.eyeRadius, y: bounds.height / 2)
    }

    private func pupilDirtyRect(center: NSPoint, offset: CGPoint, pr: CGFloat) -> NSRect {
        let margin: CGFloat = 4
        return NSRect(x: center.x - pr - margin, y: center.y - pr - margin,
                       width: (pr + margin) * 2, height: (pr + margin) * 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let eyeRadius = eyesConfig.eyeRadius
        let pupilRadius = eyesConfig.pupilRadius
        let gap = eyesConfig.eyeGap

        let eyeW = eyeRadius * 2
        let totalWidth = eyeW * 2 + gap
        let startX = (bounds.width - totalWidth) / 2

        let leftCenter = NSPoint(x: startX + eyeRadius, y: bounds.height / 2)
        let rightCenter = NSPoint(x: startX + eyeW + gap + eyeRadius, y: bounds.height / 2)

        let leftOffset = mouseTracker?.leftPupilOffset ?? .zero
        let rightOffset = mouseTracker?.rightPupilOffset ?? .zero
        let rightActive = eyesState?.rightEyeActive ?? false
        let leftBlink = eyesState?.leftBlink ?? false
        let rightBlink = eyesState?.rightBlink ?? false

        drawEye(in: ctx, center: leftCenter, offset: leftOffset,
                eyeRadius: eyeRadius, pupilRadius: pupilRadius,
                highlightColor: Self.white70, blink: leftBlink)
        drawEye(in: ctx, center: rightCenter, offset: rightOffset,
                eyeRadius: eyeRadius, pupilRadius: pupilRadius,
                highlightColor: rightActive ? Self.red : Self.white70,
                blink: rightBlink)
    }

    private func drawEye(in ctx: CGContext, center: NSPoint, offset: CGPoint,
                         eyeRadius: Double, pupilRadius: Double,
                         highlightColor: CGColor, blink: Bool) {
        let er = CGFloat(eyeRadius)
        let pr = CGFloat(pupilRadius)

        let eyeRect = CGRect(x: center.x - er, y: center.y - er, width: er * 2, height: er * 2)

        ctx.setFillColor(Self.white)
        ctx.fillEllipse(in: eyeRect)
        ctx.setStrokeColor(Self.black)
        ctx.setLineWidth(1.2)
        ctx.strokeEllipse(in: eyeRect)

        if blink {
            ctx.setStrokeColor(Self.black)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: center.x - er + 2, y: center.y))
            ctx.addLine(to: CGPoint(x: center.x + er - 2, y: center.y))
            ctx.strokePath()
            return
        }

        let px = center.x + offset.x
        let py = center.y - offset.y

        let pupilRect = CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)
        ctx.setFillColor(Self.black)
        ctx.fillEllipse(in: pupilRect)

        let hlR: CGFloat = max(1.5, pr * 0.35)
        let hlRect = CGRect(
            x: px - pr * 0.35 - hlR, y: py + pr * 0.2 - hlR,
            width: hlR * 2, height: hlR * 2
        )
        ctx.setFillColor(highlightColor)
        ctx.fillEllipse(in: hlRect)
    }
}
