import Foundation

// MARK: - Model

struct WMSSkin {
    var views: [WMSView] = []
    var primaryView: WMSView? {
        // Prefer a view named "mainView", else first view with explicit dimensions
        views.first { $0.id == "mainView" }
            ?? views.first { $0.width > 0 && $0.height > 0 }
            ?? views.first
    }
}

struct WMSView {
    var id: String = ""
    var width: Int = 0
    var height: Int = 0
    var backgroundImage: String = ""
    var buttonGroups: [WMSButtonGroup] = []
    var standaloneButtons: [WMSStandaloneButton] = []
    var sliders: [WMSSlider] = []
    var texts: [WMSText] = []
    var images: [WMSImage] = []   // background images from subviews
}

/// A button group whose hit regions are defined by colored pixels in mappingImage.
/// The visual images (upImage, downImage, hoverImage) belong to the group, not
/// the individual button elements.
struct WMSButtonGroup {
    var mappingImage: String = ""
    var upImage: String = ""
    var downImage: String = ""
    var hoverImage: String = ""
    var left: Int = 0
    var top: Int = 0
    var buttons: [WMSMappedButton] = []
}

/// One entry in a BUTTONGROUP — identified by a unique mapping color.
struct WMSMappedButton {
    var mappingColor: String = ""
    var action: String = ""
    var tooltip: String = ""
}

/// A button with an explicit pixel position (standalone <button>, <pausebutton>, etc.)
struct WMSStandaloneButton {
    var id: String = ""
    var left: Int = 0
    var top: Int = 0
    var image: String = ""
    var hoverImage: String = ""
    var downImage: String = ""
    var action: String = ""
    var tooltip: String = ""
    /// Clip dimensions from the enclosing subview (0 = no clip, use image size).
    var clipWidth: Int = 0
    var clipHeight: Int = 0
    var visible: Bool = true
}

struct WMSSlider {
    var id: String = ""
    var left: Int = 0
    var top: Int = 0
    var width: Int = 0
    var height: Int = 0
    var image: String = ""
    var positionImage: String = ""  // mapping image
    var min: Double = 0
    var max: Double = 100
    var action: String = ""
    var tooltip: String = ""
}

struct WMSText {
    var id: String = ""
    var left: Int = 0
    var top: Int = 0
    var width: Int = 100
    var height: Int = 20
    var value: String = ""
    var fontFace: String = "Arial"
    var fontSize: Int = 10
    var fontColor: String = "#FFFFFF"
}

/// Background image from a <subview backgroundImage="...">
struct WMSImage {
    var left: Int = 0
    var top: Int = 0
    var image: String = ""
    var transparencyColor: String = ""
}

// MARK: - Parser

final class WMSParser: NSObject, XMLParserDelegate {

    private var skin = WMSSkin()
    private var currentView: WMSView?
    private var currentGroup: WMSButtonGroup?

    // Subview offset stack — each entry is the absolute (left, top) plus optional clip size.
    // width/height are 0 when the subview doesn't declare them (no clipping).
    private var subviewStack: [(left: Int, top: Int, width: Int, height: Int)] = []
    private var currentOffset: (left: Int, top: Int) {
        subviewStack.last.map { ($0.left, $0.top) } ?? (0, 0)
    }
    private var currentClip: (width: Int, height: Int) {
        subviewStack.last.map { ($0.width, $0.height) } ?? (0, 0)
    }

    func parse(contentsOf url: URL) -> WMSSkin? {
        // Foundation XMLParser detects UTF-16 from the BOM automatically.
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            ActionLogger.shared.log("XML parse error: \(parser.parserError?.localizedDescription ?? "unknown")")
            return nil
        }
        return skin
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes rawAttrs: [String: String]) {

        var a: [String: String] = [:]
        for (k, v) in rawAttrs { a[k.lowercased()] = v }

        let tag = elementName.uppercased()

        switch tag {

        // ── View ──────────────────────────────────────────────────────────────
        case "VIEW":
            var v = WMSView()
            v.id              = a["id"]     ?? ""
            v.width           = Int(a["width"]  ?? "") ?? 0
            v.height          = Int(a["height"] ?? "") ?? 0
            v.backgroundImage = a["backgroundimage"] ?? ""
            currentView  = v
            subviewStack = [(0, 0, v.width, v.height)]

        // ── Subview ───────────────────────────────────────────────────────────
        case "SUBVIEW":
            let left = Int(a["left"] ?? "") ?? 0
            let top  = Int(a["top"]  ?? "") ?? 0
            let absLeft = currentOffset.left + left
            let absTop  = currentOffset.top  + top
            let w = Int(a["width"]  ?? "") ?? 0
            let h = Int(a["height"] ?? "") ?? 0
            subviewStack.append((absLeft, absTop, w, h))

            // Subview background image → add as WMSImage
            if let bg = a["backgroundimage"], !bg.isEmpty {
                var img = WMSImage()
                img.left  = absLeft
                img.top   = absTop
                img.image = bg
                img.transparencyColor = a["transparencycolor"] ?? ""
                currentView?.images.append(img)
            }

        // ── Button group ──────────────────────────────────────────────────────
        case "BUTTONGROUP":
            let left = Int(a["left"] ?? "") ?? 0
            let top  = Int(a["top"]  ?? "") ?? 0
            var g = WMSButtonGroup()
            g.mappingImage = a["mappingimage"] ?? ""
            g.upImage      = a["image"]        ?? a["upimage"]   ?? ""
            g.downImage    = a["downimage"]    ?? ""
            g.hoverImage   = a["hoverimage"]   ?? ""
            g.left = currentOffset.left + left
            g.top  = currentOffset.top  + top
            currentGroup = g

        // ── Mapped button elements ────────────────────────────────────────────
        case "BUTTONELEMENT":
            guard currentGroup != nil else { break }
            var btn = WMSMappedButton()
            btn.mappingColor = a["mappingcolor"] ?? ""
            btn.tooltip      = a["uptoolTip"] ?? a["tooltip"] ?? ""
            btn.action       = extractAction(a["onclick"] ?? a["onmouseup"] ?? "")
            currentGroup!.buttons.append(btn)

        case "PLAYELEMENT":
            guard currentGroup != nil else { break }
            currentGroup!.buttons.append(WMSMappedButton(
                mappingColor: a["mappingcolor"] ?? "",
                action: "play",
                tooltip: a["uptoolTip"] ?? "Play"
            ))

        case "NEXTELEMENT":
            guard currentGroup != nil else { break }
            currentGroup!.buttons.append(WMSMappedButton(
                mappingColor: a["mappingcolor"] ?? "",
                action: "next",
                tooltip: a["uptoolTip"] ?? "Next"
            ))

        case "PREVELEMENT":
            guard currentGroup != nil else { break }
            currentGroup!.buttons.append(WMSMappedButton(
                mappingColor: a["mappingcolor"] ?? "",
                action: "previous",
                tooltip: a["uptoolTip"] ?? "Previous"
            ))

        case "STOPELEMENT":
            guard currentGroup != nil else { break }
            currentGroup!.buttons.append(WMSMappedButton(
                mappingColor: a["mappingcolor"] ?? "",
                action: "stop",
                tooltip: a["uptoolTip"] ?? "Stop"
            ))

        // ── Standalone buttons ────────────────────────────────────────────────
        case "BUTTON", "PAUSEBUTTON":
            guard currentView != nil else { break }
            // Buttons inside a buttongroup are handled by the group — skip them here.
            // (In practice this skin has no <button> children of <buttongroup>.)
            let left = Int(a["left"] ?? a["x"] ?? "") ?? 0
            let top  = Int(a["top"]  ?? a["y"] ?? "") ?? 0
            var btn = WMSStandaloneButton()
            btn.id         = a["id"] ?? ""
            btn.left       = currentOffset.left + left
            btn.top        = currentOffset.top  + top
            btn.image      = a["image"]      ?? a["upimage"] ?? ""
            btn.hoverImage = a["hoverimage"] ?? ""
            btn.downImage  = a["downimage"]  ?? ""
            btn.tooltip    = a["uptoolTip"]  ?? a["tooltip"] ?? ""
            btn.action     = tag == "PAUSEBUTTON"
                ? "pause"
                : extractAction(a["onclick"] ?? a["onmouseup"] ?? "")
            btn.clipWidth  = currentClip.width
            btn.clipHeight = currentClip.height
            btn.visible    = (a["visible"] ?? "true").lowercased() != "false"
            currentView!.standaloneButtons.append(btn)

        // ── Sliders ───────────────────────────────────────────────────────────
        case "SLIDER", "SEEKBAR", "TRACKBAR", "CUSTOMSLIDER":
            guard currentView != nil else { break }
            let left = Int(a["left"] ?? a["x"] ?? "") ?? 0
            let top  = Int(a["top"]  ?? a["y"] ?? "") ?? 0
            var s = WMSSlider()
            s.id            = a["id"]    ?? ""
            s.left          = currentOffset.left + left
            s.top           = currentOffset.top  + top
            s.width         = Int(a["width"]  ?? "") ?? 0
            s.height        = Int(a["height"] ?? "") ?? 0
            s.image         = a["image"]         ?? ""
            s.positionImage = a["positionimage"] ?? ""
            s.min           = Double(a["min"] ?? "") ?? 0
            s.max           = Double(a["max"] ?? "") ?? 100
            s.tooltip       = a["tooltip"] ?? ""
            let onchange = a["onpositionchange"] ?? a["onvaluechange"] ?? a["value_onchange"] ?? ""
            s.action = s.id.isEmpty ? extractAction(onchange) : s.id
            currentView!.sliders.append(s)

        // ── Text labels ───────────────────────────────────────────────────────
        case "TEXT":
            guard currentView != nil else { break }
            let left = Int(a["left"] ?? a["x"] ?? "") ?? 0
            let top  = Int(a["top"]  ?? a["y"] ?? "") ?? 0
            var t = WMSText()
            t.id        = a["id"]    ?? ""
            t.left      = currentOffset.left + left
            t.top       = currentOffset.top  + top
            t.width     = Int(a["width"]  ?? "") ?? 100
            t.height    = Int(a["height"] ?? "") ?? 20
            t.value     = a["value"]    ?? ""
            t.fontFace  = a["fontface"] ?? "Arial"
            t.fontSize  = Int(a["fontsize"] ?? "") ?? 10
            t.fontColor = a["foregroundcolor"] ?? a["fontcolor"] ?? "#FFFFFF"
            currentView!.texts.append(t)

        default:
            break
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {

        switch elementName.uppercased() {
        case "SUBVIEW":
            if !subviewStack.isEmpty { subviewStack.removeLast() }

        case "BUTTONGROUP":
            if let g = currentGroup {
                currentView?.buttonGroups.append(g)
                currentGroup = nil
            }

        case "VIEW":
            if let v = currentView {
                skin.views.append(v)
                currentView = nil
                subviewStack = []
            }

        default:
            break
        }
    }

    // MARK: - Helpers

    private func extractAction(_ expr: String) -> String {
        let lower = expr.lowercased()

        // Match specific WMP JScript patterns — ordered most-specific first.
        // Substring matching is intentional here; all patterns are long enough
        // to be unambiguous (e.g. "controls.play()" won't match "player.*").
        let patterns: [(String, String)] = [
            ("controls.play()",     "play"),
            ("controls.pause()",    "pause"),
            ("controls.stop()",     "stop"),
            ("controls.next()",     "next"),
            ("controls.previous()", "previous"),
            ("settings.mute",       "mute"),
            ("'exitview'",          "exit"),
            ("'minimizeview'",      "minimize"),
            ("openfile()",          "open"),
            ("shuffle",             "shuffle"),
            ("crossfade",           "crossfade"),
            ("previouspreset",      "previouspreset"),
            ("nextpreset",          "nextpreset"),
        ]
        for (pattern, action) in patterns where lower.contains(pattern) { return action }

        // Fall back to extracting the last method name: "foo.bar.baz()" → "baz"
        if let range = expr.range(of: #"\.(\w+)\(\)"#, options: .regularExpression) {
            return String(expr[range]).filter { $0.isLetter || $0.isNumber }
        }
        return expr.isEmpty ? "unknown" : expr
    }
}
