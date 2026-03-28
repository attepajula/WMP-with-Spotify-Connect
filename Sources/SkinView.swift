import Cocoa

final class SkinView: NSView {

    override var isFlipped: Bool { true }

    private let resourceDir: URL
    private var wmsView: WMSView?
    private(set) var configureMode: Bool = false   // start in play mode

    private var configureOverlay: ConfigureOverlay?
    private var interactiveSubviews: [NSView] = []

    // Play/pause toggle — pauseButton starts hidden; swapped on play/pause/stop
    private var playButton:  NSButton?
    private var pauseButton: NSButton?

    // MARK: - Init

    init(skin: WMSSkin, resourceDir: URL) {
        self.resourceDir = resourceDir
        let v = skin.primaryView
        super.init(frame: CGRect(x: 0, y: 0,
                                 width:  CGFloat(v?.width  ?? 300),
                                 height: CGFloat(v?.height ?? 100)))
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
        if let view = v {
            wmsView = view
            renderBackground(view)
            renderInteractive(view)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Mode Toggle (Cmd+D)

    @discardableResult
    func toggleMode() -> Bool {
        configureMode = !configureMode
        guard let view = wmsView else { return configureMode }
        interactiveSubviews.forEach { $0.removeFromSuperview() }
        interactiveSubviews = []
        configureOverlay = nil
        playButton  = nil
        pauseButton = nil
        renderInteractive(view)
        return configureMode
    }

    // MARK: - Background

    private func renderBackground(_ view: WMSView) {
        if !view.backgroundImage.isEmpty, let img = loadImage(view.backgroundImage) {
            addBgImageView(img, at: .zero, size: bounds.size)
        }
        for wmsImg in view.images {
            guard var img = loadImage(wmsImg.image) else { continue }
            if !wmsImg.transparencyColor.isEmpty {
                img = masked(img, removing: wmsImg.transparencyColor) ?? img
            }
            addBgImageView(img, at: CGPoint(x: wmsImg.left, y: wmsImg.top), size: img.size)
        }
        for txt in view.texts { renderText(txt) }
    }

    private func addBgImageView(_ image: NSImage, at origin: CGPoint, size: CGSize) {
        let iv = NSImageView(frame: CGRect(origin: origin, size: size))
        iv.image = image
        iv.imageScaling = .scaleAxesIndependently
        iv.wantsLayer = true
        iv.layer?.backgroundColor = CGColor.clear
        addSubview(iv)
    }

    // MARK: - Interactive Layer

    private func renderInteractive(_ view: WMSView) {
        if configureMode {
            var anchors: [AnchorPoint] = []
            for group in view.buttonGroups      { anchors += collectAnchors(group) }
            for btn   in view.standaloneButtons { if let a = anchor(for: btn) { anchors.append(a) } }
            for sld   in view.sliders          { anchors.append(anchor(for: sld)) }

            let ov = ConfigureOverlay(frame: bounds)
            ov.anchors = anchors
            addSubview(ov)
            interactiveSubviews.append(ov)
            configureOverlay = ov

            ActionLogger.shared.log(
                "Configure mode: \(anchors.filter { $0.kind == .button }.count) buttons, " +
                "\(anchors.filter { $0.kind == .slider }.count) sliders"
            )
        } else {
            for group in view.buttonGroups      { renderButtonGroup(group) }
            for btn   in view.standaloneButtons { renderStandaloneButton(btn) }
            for sld   in view.sliders          { renderSlider(sld) }
        }
    }

    // MARK: - Anchor Collection (configure mode)

    private func collectAnchors(_ group: WMSButtonGroup) -> [AnchorPoint] {
        guard !group.mappingImage.isEmpty,
              let mapImg = loadImage(group.mappingImage) else { return [] }
        var result: [AnchorPoint] = []
        for btn in group.buttons {
            guard !btn.mappingColor.isEmpty,
                  let localRect = buttonRect(forHex: btn.mappingColor, in: mapImg) else { continue }
            let viewRect = CGRect(
                x: CGFloat(group.left) + localRect.origin.x,
                y: CGFloat(group.top)  + localRect.origin.y,
                width: localRect.width, height: localRect.height
            )
            result.append(AnchorPoint(key: btn.mappingColor, frame: viewRect,
                                      suggestedAction: btn.action, kind: .button))
        }
        return result
    }

    private func anchor(for btn: WMSStandaloneButton) -> AnchorPoint? {
        var size = CGSize(width: 24, height: 24)
        if !btn.image.isEmpty, let img = loadImage(btn.image) { size = img.size }
        let frame = CGRect(x: CGFloat(btn.left), y: CGFloat(btn.top),
                           width: size.width, height: size.height)
        let key = btn.id.isEmpty ? "sa-\(btn.action)" : btn.id
        return AnchorPoint(key: key, frame: frame, suggestedAction: btn.action, kind: .button)
    }

    private func anchor(for s: WMSSlider) -> AnchorPoint {
        var w = CGFloat(s.width), h = CGFloat(s.height)
        if (w == 0 || h == 0), !s.positionImage.isEmpty, let img = loadImage(s.positionImage) {
            w = img.size.width; h = img.size.height
        }
        if w == 0 { w = 16 }; if h == 0 { h = 100 }
        let frame = CGRect(x: CGFloat(s.left), y: CGFloat(s.top), width: w, height: h)
        let key = s.id.isEmpty ? "sl-\(s.action)" : s.id
        return AnchorPoint(key: key, frame: frame, suggestedAction: s.action, kind: .slider)
    }

    // MARK: - Button Group Rendering

    private func renderButtonGroup(_ group: WMSButtonGroup) {
        guard !group.mappingImage.isEmpty,
              let mapImg = loadImage(group.mappingImage) else {
            ActionLogger.shared.log("ButtonGroup: can't load '\(group.mappingImage)'")
            return
        }
        let groupUpImg   = loadImage(group.upImage)
        let groupDownImg = loadImage(group.downImage)

        for btn in group.buttons {
            guard btn.action != "unknown" else { continue }
            guard !btn.mappingColor.isEmpty,
                  let localRect = buttonRect(forHex: btn.mappingColor, in: mapImg) else {
                ActionLogger.shared.log("Button '\(btn.action)': no pixels for \(btn.mappingColor)")
                continue
            }
            let viewRect = CGRect(
                x: CGFloat(group.left) + localRect.origin.x,
                y: CGFloat(group.top)  + localRect.origin.y,
                width: localRect.width, height: localRect.height
            )
            let upImg   = groupUpImg.map   { cropImage($0, to: localRect) }
            let downImg = groupDownImg.map { cropImage($0, to: localRect) }
            let button  = makeButton(frame: viewRect, action: btn.action,
                                     tooltip: btn.tooltip, up: upImg, down: downImg)
            addSubview(button)
            interactiveSubviews.append(button)
        }
    }

    // MARK: - Standalone Button Rendering

    private func renderStandaloneButton(_ btn: WMSStandaloneButton) {
        guard btn.action != "unknown" else { return }
        guard !btn.image.isEmpty, let upImg = loadImage(btn.image) else { return }
        let frame = CGRect(x: CGFloat(btn.left), y: CGFloat(btn.top),
                           width: upImg.size.width, height: upImg.size.height)
        let downImg = loadImage(btn.downImage)
        let button  = makeButton(frame: frame, action: btn.action,
                                 tooltip: btn.tooltip, up: upImg, down: downImg)
        addSubview(button)
        interactiveSubviews.append(button)
    }

    private func makeButton(frame: CGRect, action: String, tooltip: String,
                            up: NSImage?, down: NSImage?) -> NSButton {
        let b = NSButton(frame: frame)
        b.title = ""
        b.isBordered = false
        b.setButtonType(.momentaryChange)
        b.imagePosition = .imageOnly
        b.imageScaling = .scaleAxesIndependently
        if let img = up   { b.image          = img }
        if let img = down { b.alternateImage = img }
        if !tooltip.isEmpty { b.toolTip = tooltip }
        b.identifier = NSUserInterfaceItemIdentifier(action)
        b.target = self
        b.action = #selector(buttonPressed(_:))

        // Track play/pause for the toggle; pause starts hidden.
        switch action {
        case "play":  playButton  = b
        case "pause": pauseButton = b; b.isHidden = true
        default: break
        }

        return b
    }

    // MARK: - Slider Rendering

    private func renderSlider(_ s: WMSSlider) {
        let posImg = s.positionImage.isEmpty ? nil : loadImage(s.positionImage)
        var w = CGFloat(s.width), h = CGFloat(s.height)
        if (w == 0 || h == 0), let pos = posImg {
            w = pos.size.width; h = pos.size.height
        }
        if w == 0 { w = 16 }; if h == 0 { h = 100 }
        let frame = CGRect(x: CGFloat(s.left), y: CGFloat(s.top), width: w, height: h)

        if !s.image.isEmpty, let sheet = loadImage(s.image) {
            let sv = WMSSpriteSlider(frame: frame, sheet: sheet, positionImage: posImg,
                                     minValue: s.min, maxValue: s.max)
            sv.identifier = NSUserInterfaceItemIdentifier(s.action)
            if !s.tooltip.isEmpty { sv.toolTip = s.tooltip }
            sv.value = s.min
            sv.onValueChanged = { [weak sv] val in
                guard let sv else { return }
                let action = sv.identifier?.rawValue ?? "unknown"
                ActionLogger.shared.log("Slider '\(action)': \(String(format: "%.2f", val))")
            }
            addSubview(sv)
            interactiveSubviews.append(sv)
            return
        }

        // Fallback: invisible NSSlider for sliders without a sprite sheet
        let sl = NSSlider(frame: frame)
        sl.minValue   = s.min
        sl.maxValue   = s.max
        sl.alphaValue = 0.01
        if !s.tooltip.isEmpty { sl.toolTip = s.tooltip }
        sl.identifier = NSUserInterfaceItemIdentifier(s.action)
        sl.target = self
        sl.action = #selector(sliderChanged(_:))
        addSubview(sl)
        interactiveSubviews.append(sl)
    }

    // MARK: - Text Labels

    private func renderText(_ t: WMSText) {
        let frame = CGRect(x: CGFloat(t.left), y: CGFloat(t.top),
                           width: CGFloat(t.width), height: CGFloat(t.height))
        let label = NSTextField(frame: frame)
        label.isEditable      = false
        label.isBordered      = false
        label.drawsBackground = false
        label.stringValue     = (t.value.hasPrefix("rmattr:") || t.value.hasPrefix("wmpprop:"))
                                ? "" : t.value
        label.textColor = NSColor(hexString: t.fontColor) ?? .white
        label.font      = NSFont(name: t.fontFace, size: CGFloat(t.fontSize))
                       ?? NSFont.systemFont(ofSize: CGFloat(t.fontSize))
        addSubview(label)
    }

    // MARK: - Button / Slider Actions

    @objc private func buttonPressed(_ sender: NSButton) {
        let action = sender.identifier?.rawValue ?? "unknown"
        ActionLogger.shared.log("Button: \(action)")
        switch action {
        case "close", "exit":
            window?.close()
        case "minimize":
            window?.miniaturize(nil)
        case "play":
            // Switch to pause button (we're now "playing")
            playButton?.isHidden  = true
            pauseButton?.isHidden = false
        case "pause", "stop":
            // Switch back to play button
            playButton?.isHidden  = false
            pauseButton?.isHidden = true
        default:
            break
        }
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let action = sender.identifier?.rawValue ?? "unknown"
        ActionLogger.shared.log("Slider '\(action)': \(String(format: "%.2f", sender.doubleValue))")
    }

    // MARK: - Image Helpers

    func loadImage(_ name: String) -> NSImage? {
        guard !name.isEmpty else { return nil }
        let url = resourceDir.appendingPathComponent(name)
        if let img = NSImage(contentsOf: url) { return img }
        let lower = name.lowercased()
        if let items = try? FileManager.default.contentsOfDirectory(
            at: resourceDir, includingPropertiesForKeys: nil
        ), let match = items.first(where: { $0.lastPathComponent.lowercased() == lower }) {
            return NSImage(contentsOf: match)
        }
        return nil
    }

    /// Replace every pixel matching `hexColor` with transparent.
    private func masked(_ image: NSImage, removing hexColor: String) -> NSImage? {
        guard let (tr, tg, tb) = parseHex(hexColor),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: h * w * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        for i in stride(from: 0, to: data.count, by: 4) {
            if data[i] == tr && data[i+1] == tg && data[i+2] == tb {
                data[i] = 0; data[i+1] = 0; data[i+2] = 0; data[i+3] = 0
            }
        }
        guard let newCG = ctx.makeImage() else { return nil }
        let result = NSImage(size: NSSize(width: CGFloat(w), height: CGFloat(h)))
        result.addRepresentation(NSBitmapImageRep(cgImage: newCG))
        return result
    }

    private func cropImage(_ image: NSImage, to rect: CGRect) -> NSImage {
        guard rect.width > 0 && rect.height > 0 else { return image }
        let imgSize = image.size
        let result = NSImage(size: rect.size)
        result.lockFocus()
        let srcRect = CGRect(x: rect.origin.x,
                             y: imgSize.height - rect.origin.y - rect.size.height,
                             width: rect.size.width, height: rect.size.height)
        image.draw(in: CGRect(origin: .zero, size: rect.size),
                   from: srcRect, operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    // MARK: - Color Mapping

    private func buttonRect(forHex hexColor: String, in image: NSImage) -> CGRect? {
        guard let (pixels, imgW, imgH) = rasterize(image),
              let (r, g, b) = parseHex(hexColor) else { return nil }
        var minX = imgW, minY = imgH, maxX = 0, maxY = 0
        var found = false
        for y in 0..<imgH {
            for x in 0..<imgW {
                let i = (y * imgW + x) * 4
                if pixels[i] == r && pixels[i+1] == g && pixels[i+2] == b {
                    if x < minX { minX = x }; if x > maxX { maxX = x }
                    if y < minY { minY = y }; if y > maxY { maxY = y }
                    found = true
                }
            }
        }
        guard found else { return nil }
        return CGRect(x: CGFloat(minX), y: CGFloat(minY),
                      width: CGFloat(maxX - minX + 1), height: CGFloat(maxY - minY + 1))
    }

    private func rasterize(_ image: NSImage) -> (pixels: [UInt8], width: Int, height: Int)? {
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

    private func parseHex(_ hex: String) -> (UInt8, UInt8, UInt8)? {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6,
              let r = UInt8(s.prefix(2), radix: 16),
              let g = UInt8(s.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(s.dropFirst(4), radix: 16) else { return nil }
        return (r, g, b)
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hexString: String) {
        let s = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        guard s.count == 6,
              let r = UInt8(s.prefix(2), radix: 16),
              let g = UInt8(s.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(s.dropFirst(4), radix: 16) else { return nil }
        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}
