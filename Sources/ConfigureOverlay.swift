import Cocoa

/// Full-size overlay drawn over the skin in configure mode (Cmd+D).
/// Shows every detected button/slider region so you can verify hit detection.
final class ConfigureOverlay: NSView {

    override var isFlipped: Bool { true }

    var anchors: [AnchorPoint] = [] { didSet { needsDisplay = true } }

    /// Called when the user clicks inside an anchor region (optional, for future use).
    var onAnchorClicked: ((AnchorPoint) -> Void)?

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        for anchor in anchors {
            let fill: NSColor = anchor.kind == .button
                ? NSColor.systemBlue.withAlphaComponent(0.35)
                : NSColor.systemOrange.withAlphaComponent(0.35)
            fill.setFill()
            anchor.frame.fill()

            NSColor.white.withAlphaComponent(0.85).setStroke()
            let path = NSBezierPath(rect: anchor.frame.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 1
            path.stroke()

            let label = anchor.suggestedAction.isEmpty ? anchor.key : anchor.suggestedAction
            let attrs: [NSAttributedString.Key: Any] = [
                .font:            NSFont.monospacedSystemFont(ofSize: 7, weight: .bold),
                .foregroundColor: NSColor.white,
                .strokeColor:     NSColor.black,
                .strokeWidth:     NSNumber(value: -2.0),
            ]
            NSAttributedString(string: label, attributes: attrs)
                .draw(at: CGPoint(x: anchor.frame.minX + 2, y: anchor.frame.minY + 2))
        }
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        for anchor in anchors.reversed() {
            if anchor.frame.contains(pt) {
                onAnchorClicked?(anchor)
                return
            }
        }
    }
}
