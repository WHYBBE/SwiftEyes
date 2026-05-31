import SwiftUI
import AppKit

struct GooglyEyesView: View {
    var body: some View {
        GooglyEyesNSViewRepresentable()
            .frame(width: EyesConfig.shared.totalItemWidth, height: EyesConfig.shared.itemHeight)
    }
}

struct GooglyEyesNSViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> GooglyEyesNSView {
        let view = GooglyEyesNSView()
        view.mouseTracker = MouseTracker.shared
        view.eyesState = EyesState.shared
        view.eyesConfig = EyesConfig.shared
        return view
    }

    func updateNSView(_ nsView: GooglyEyesNSView, context: Context) {}
}

final class GooglyEyesNSView: NSView {
    var mouseTracker: MouseTracker! {
        didSet { mouseTracker.onOffsetChanged = { [weak self] in self?.needsDisplay = true } }
    }
    var eyesState: EyesState! {
        didSet { eyesState.onChange = { [weak self] in self?.needsDisplay = true } }
    }
    var eyesConfig: EyesConfig! {
        didSet { eyesConfig.onChange = { [weak self] in self?.needsDisplay = true } }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

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
                highlightColor: NSColor.white.withAlphaComponent(0.7), blink: leftBlink)
        drawEye(in: ctx, center: rightCenter, offset: rightOffset,
                eyeRadius: eyeRadius, pupilRadius: pupilRadius,
                highlightColor: rightActive ? NSColor.red : NSColor.white.withAlphaComponent(0.7),
                blink: rightBlink)
    }

    private func drawEye(in ctx: CGContext, center: NSPoint, offset: CGPoint,
                         eyeRadius: Double, pupilRadius: Double,
                         highlightColor: NSColor, blink: Bool) {
        let er = CGFloat(eyeRadius)
        let pr = CGFloat(pupilRadius)

        let eyeRect = CGRect(x: center.x - er, y: center.y - er, width: er * 2, height: er * 2)

        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: eyeRect)
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1.2)
        ctx.strokeEllipse(in: eyeRect)

        if blink {
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: center.x - er + 2, y: center.y))
            ctx.addLine(to: CGPoint(x: center.x + er - 2, y: center.y))
            ctx.strokePath()
            return
        }

        let px = center.x + offset.x
        let py = center.y - offset.y

        let pupilRect = CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillEllipse(in: pupilRect)

        let hlR: CGFloat = max(1.5, pr * 0.35)
        let hlRect = CGRect(
            x: px - pr * 0.35 - hlR, y: py + pr * 0.2 - hlR,
            width: hlR * 2, height: hlR * 2
        )
        ctx.setFillColor(highlightColor.cgColor)
        ctx.fillEllipse(in: hlRect)
    }
}
