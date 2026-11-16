import SwiftUI

// Brows palette and the glass recipe, taken from the fork's own paint code:
//   chrome/browser/ui/views/frame/brows_glass.h  (rail pane, rail bubbles)
//   chrome/browser/ui/views/tabs/common/horizontal_tab_style_views.cc:361 (tab glass)
// The desktop rail is not a flat tint and not a blurred material: it is a cool
// white pane at a clarity alpha, a white ramp over it, and a corner sheen.
enum Theme {
    static let ink = Color(red: 0.055, green: 0.075, blue: 0.11)
    static let muted = Color(red: 0.408, green: 0.443, blue: 0.498) // #68717f
    static let glassStroke = Color.white.opacity(0.72)
    static let backdropTop = Color(red: 0.09, green: 0.16, blue: 0.28)
    static let backdropBottom = Color(red: 0.03, green: 0.05, blue: 0.10)
    static let pill = Color.white

    /// brows_glass.h: `SkColorSetRGB(0xF0, 0xF5, 0xFA)` at the clarity alpha.
    /// Default clarity is "foggy" = 0x7B (0.48).
    static let railBase = Color(red: 240 / 255, green: 245 / 255, blue: 250 / 255)
    static let railBaseAlpha = 0.48

    /// brows_glass.h: kRailRampTopAlpha 0x4F (0.31) → kRailRampBottomAlpha 0x21
    /// (0.13) of rgb(228, 236, 244).
    static let railRampTop = Color.white.opacity(0.31)
    static let railRampBottom = Color(red: 228 / 255, green: 236 / 255, blue: 244 / 255).opacity(0.13)

    /// brows_glass.h: kRailSheenAlpha 0x94 (0.58), radius 1.4×0.95, centre 18%/-20%,
    /// opaque until 52% then transparent.
    static let railSheen = Color.white.opacity(0.58)

    /// horizontal_tab_style_views.cc:384 — active tab fill 0x4F → 0x23 (0.31 → 0.137),
    /// border 0x6B (0.42).
    static let tabActiveTop = Color.white.opacity(0.31)
    static let tabActiveBottom = Color.white.opacity(0.137)
    static let tabBorder = Color.white.opacity(0.42)

    /// brows_glass.h PaintRailBubble — rest fill 0.18 → 0.035 over rgb(247,250,253) 0.025,
    /// border 0.30; pressed 0.10 → 0.02, border 0.19.
    static let bubbleTop = Color.white.opacity(0.18)
    static let bubbleBottom = Color.white.opacity(0.035)
    static let bubbleWash = Color(red: 247 / 255, green: 250 / 255, blue: 253 / 255).opacity(0.025)
    static let bubbleBorder = Color.white.opacity(0.30)

    static var backdrop: LinearGradient {
        LinearGradient(
            colors: [backdropTop, backdropBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// The rail pane. Values are the desktop's, in the desktop's order: base at
/// clarity alpha, white ramp, then the top-left sheen.
struct GlassPane: View {
    var cornerRadius: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.railBase.opacity(Theme.railBaseAlpha)

                LinearGradient(
                    colors: [Theme.railRampTop, Theme.railRampBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [Theme.railSheen, .clear],
                    center: UnitPoint(x: 0.18, y: -0.20),
                    startRadius: 0,
                    endRadius: max(geo.size.width * 1.4, geo.size.height * 0.95)
                )

                if cornerRadius > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Theme.glassStroke, lineWidth: 1)
                }
            }
        }
    }
}

/// `PaintRailBubble`: a translucent white bubble, not a solid white disc.
struct GlassCircleButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(enabled ? Theme.muted : Theme.muted.opacity(0.4))
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    Circle().fill(Theme.bubbleWash)
                    Circle().fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(configuration.isPressed ? 0.10 : 0.18),
                                Color.white.opacity(configuration.isPressed ? 0.02 : 0.035)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            )
            .overlay(
                Circle().stroke(
                    Color.white.opacity(configuration.isPressed ? 0.19 : 0.30),
                    lineWidth: 1
                )
            )
            .opacity(enabled ? 1 : 0.55)
    }
}
