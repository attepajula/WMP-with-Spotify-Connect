import Cocoa

/// Renders a WMS customSlider using its sprite sheet and handles mouse interaction.
///
/// Sheet layout: horizontal strip of N frames, each (sliderW × sliderH) pixels.
/// Frame 0 = minValue, last frame = maxValue.
/// Vertical orientation: fill grows bottom→top; drag up = higher value.
final class WMSSpriteSlider: NSView {

    override var isFlipped: Bool { true }

    var value: Double = 0 {
        didSet {
            value = max(minValue, min(maxValue, value))
            updateFrame()
        }
    }
    var minValue: Double = 0
    var maxValue: Double = 100
    var onValueChanged: ((Double) -> Void)?

    private let sheetCG: CGImage   // pixel-accurate source, no DPI ambiguity
    private let frameCount: Int
    private let pixelFrameW: Int
    private let pixelFrameH: Int

    private let activeTop:    CGFloat   // first non-magenta row in positionImage
    private let activeBottom: CGFloat   // last  non-magenta row

    private var currentFrameCG: CGImage?  // drawn directly via CGContext in draw(_:)

    // MARK: - Init

    init(frame: CGRect, sheet: NSImage, positionImage: NSImage?,
         minValue: Double, maxValue: Double) {
        self.minValue = minValue
        self.maxValue = maxValue

        guard let cg = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            fatalError("WMSSpriteSlider: no CGImage in sheet")
        }
        sheetCG = cg

        // Pixel frame width = slider view width in points (1 pt ≈ 1 px; WMS skins are 72 DPI)
        pixelFrameW = max(1, Int(round(frame.width)))
        pixelFrameH = cg.height
        frameCount  = max(1, cg.width / pixelFrameW)

        // Scan positionImage top-to-bottom to find the active (non-magenta) band.
        var aTop: CGFloat = 0
        var aBot: CGFloat = frame.height - 1
        if let pos = positionImage,
           let (pixels, pw, ph) = WMSSpriteSlider.rasterize(pos) {
            let midX = pw / 2
            for y in 0..<ph {
                let i = (y * pw + midX) * 4
                if !(pixels[i] == 255 && pixels[i+1] == 0 && pixels[i+2] == 255) {
                    aTop = CGFloat(y); break
                }
            }
            for y in stride(from: ph - 1, through: 0, by: -1) {
                let i = (y * pw + midX) * 4
                if !(pixels[i] == 255 && pixels[i+1] == 0 && pixels[i+2] == 255) {
                    aBot = CGFloat(y); break
                }
            }
        }
        activeTop    = aTop
        activeBottom = aBot

        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
        updateFrame()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Frame Selection

    private func updateFrame() {
        guard frameCount > 1, maxValue > minValue else { return }
        let norm = (value - minValue) / (maxValue - minValue)
        let idx  = max(0, min(frameCount - 1,
                              Int((norm * Double(frameCount - 1)).rounded())))
        let srcX = idx * pixelFrameW
        let cropRect = CGRect(x: CGFloat(srcX), y: 0,
                              width: CGFloat(pixelFrameW), height: CGFloat(pixelFrameH))
        currentFrameCG = sheetCG.cropping(to: cropRect)
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let cg = currentFrameCG,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        // The sprite sheet encodes fill growing top-to-bottom (row 0 = filled for max value).
        // We want fill to raise from the floor, so flip vertically by undoing the view's
        // y-down CTM and drawing in y-up space — ctx.draw in y-up maps CGImage row 0 to
        // the visual bottom, which turns the top fill into a bottom fill.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        ctx.restoreGState()
    }

    // MARK: - Mouse Interaction

    override func mouseDown(with event: NSEvent)    { handleMouse(event) }
    override func mouseDragged(with event: NSEvent) { handleMouse(event) }

    private func handleMouse(_ event: NSEvent) {
        let pt   = convert(event.locationInWindow, from: nil)
        let norm: Double
        if bounds.height >= bounds.width {
            // Vertical slider: visual top (small y in flipped coords) = maxValue.
            let y = max(activeTop, min(activeBottom, pt.y))
            norm = 1.0 - Double((y - activeTop) / (activeBottom - activeTop))
        } else {
            // Horizontal: left = min, right = max.
            norm = Double(max(0, min(bounds.width, pt.x)) / bounds.width)
        }
        value = minValue + norm.clamped(to: 0...1) * (maxValue - minValue)
        onValueChanged?(value)
    }

    // MARK: - Rasterizer (positionImage active-band detection, y=0 = top)

    private static func rasterize(_ image: NSImage) -> ([UInt8], Int, Int)? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: h * w * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        return (data, w, h)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
