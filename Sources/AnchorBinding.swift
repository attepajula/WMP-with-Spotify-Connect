import Foundation
import CoreGraphics

/// A detected interactive region in the skin (button hit area or slider track).
struct AnchorPoint {
    enum Kind { case button, slider }

    let key: String           // mappingColor, element id, or fallback "sa-/sl-{action}"
    let frame: CGRect         // SkinView coordinates (flipped, y=0 at top)
    let suggestedAction: String
    let kind: Kind
}
