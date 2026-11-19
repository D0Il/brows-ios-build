import SwiftUI
import UIKit

// Brows palette and the glass recipe, taken from the fork's own paint code:
//   chrome/browser/ui/views/frame/brows_glass.h  (rail pane, rail bubbles)
//   chrome/browser/ui/views/tabs/common/horizontal_tab_style_views.cc:361 (tab glass)
// The desktop rail is not a flat tint and not a blurred material: it is a cool
// white pane at a clarity alpha, a white ramp over it, and a corner sheen.
enum Theme {
    static let ink = Color(red: 0.055, green: 0.075, blue: 0.11)
    static let muted = Color(red: 0.408, green: 0.443, blue: 0.498) // #68717f

    // brows_surface.css:6-8,102-113 (light) and :876-882 (dark). The surface is
    // the desktop's glass plate; on a phone sheet it is nearly opaque so the page
    // behind cannot change its meaning. Ink and muted are the desktop tokens.
    static let panelInkLight = UIColor(red: 32 / 255, green: 36 / 255, blue: 43 / 255, alpha: 1) // #20242b
    static let panelInkDark = UIColor(red: 242 / 255, green: 244 / 255, blue: 248 / 255, alpha: 1) // #f2f4f8
    static let panelMutedLight = UIColor(red: 101 / 255, green: 112 / 255, blue: 128 / 255, alpha: 1) // #657080
    static let panelMutedDark = UIColor(red: 170 / 255, green: 178 / 255, blue: 190 / 255, alpha: 1) // #aab2be
    static let surfaceLight = UIColor(red: 247 / 255, green: 250 / 255, blue: 253 / 255, alpha: 0.97)
    static let surfaceDark = UIColor(red: 24 / 255, green: 28 / 255, blue: 35 / 255, alpha: 0.94)

    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static let surface = adaptive(light: surfaceLight, dark: surfaceDark)
    static let panelInk = adaptive(light: panelInkLight, dark: panelInkDark)
    static let panelMuted = adaptive(light: panelMutedLight, dark: panelMutedDark)

    /// Rows and plates inside a sheet: the desktop's rgba(var(--plate-rgb),.5)
    /// with its .7 border in light, and the dark block's white washes in dark.
    static let rowFill = adaptive(
        light: UIColor(white: 1, alpha: 0.5),
        dark: UIColor(white: 1, alpha: 0.10)
    )
    static let rowBorder = adaptive(
        light: UIColor(white: 1, alpha: 0.70),
        dark: UIColor(white: 1, alpha: 0.12)
    )

    /// White fields and action plates keep the desktop light-mode ink in BOTH
    /// appearances; using the adaptive panel ink here is what made a white plate
    /// carry white text in dark. The placeholder is the light muted token for the
    /// same reason: the field itself is white in both modes.
    static let plateInk = Color(panelInkLight)
    static let fieldPlaceholder = Color(panelMutedLight)

    /// Desktop `--accent: #3f4753` is the monochrome switch fill; it must not flip
    /// to near-white in dark or the white knob disappears into the track.
    static let toggleTint = Color(red: 63 / 255, green: 71 / 255, blue: 83 / 255)

    /// WCAG ratios for the sheet tokens in both appearances. A sheet that writes
    /// ink failing this is a bug, not a taste call; the launch argument
    /// `-BrowsContrastAudit` surfaces the result for the UI test.
    static func contrastAudit() -> String {
        func luminance(_ color: UIColor) -> CGFloat {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            func channel(_ value: CGFloat) -> CGFloat {
                value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        }
        func ratio(_ a: UIColor, _ b: UIColor) -> CGFloat {
            let first = luminance(a), second = luminance(b)
            return (max(first, second) + 0.05) / (min(first, second) + 0.05)
        }

        let pairs: [(String, UIColor, UIColor)] = [
            ("light ink", panelInkLight, surfaceLight),
            ("light muted", panelMutedLight, surfaceLight),
            ("dark ink", panelInkDark, surfaceDark),
            ("dark muted", panelMutedDark, surfaceDark)
        ]
        let failures = pairs.filter { ratio($0.1, $0.2) < 4.5 }
        if failures.isEmpty { return "PASS" }
        let detail = failures.map { "\($0.0)=\(String(format: "%.1f", ratio($0.1, $0.2)))" }.joined(separator: " ")
        return "FAIL " + detail
    }
    static let glassStroke = Color.white.opacity(0.72)
    static let backdropTop = Color(red: 0.09, green: 0.16, blue: 0.28)
    static let backdropBottom = Color(red: 0.03, green: 0.05, blue: 0.10)

    /// location_bar.css: the address pill is a whiter glass capsule, not a solid
    /// white bar — `linear-gradient(180deg, rgba(255,255,255,.18),
    /// rgba(255,255,255,.065)), rgba(255,255,255,.035)`, 1px `rgba(255,255,255,.42)`
    /// hairline, `--border-radius: 10px`, `padding-inline: 12px`.
    static let pillTop = Color.white.opacity(0.18)
    static let pillBottom = Color.white.opacity(0.065)
    static let pillWash = Color.white.opacity(0.035)
    static let pillBorder = Color.white.opacity(0.42)
    static let pillRadius: CGFloat = 10

    /// location_bar.css:29-31 — the pill's two insets and its soft drop.
    static let pillInnerTop = Color.white.opacity(0.42)
    static let pillInnerBottom = Color(red: 47 / 255, green: 58 / 255, blue: 75 / 255).opacity(0.045)
    static let pillDrop = Color(red: 38 / 255, green: 47 / 255, blue: 61 / 255).opacity(0.035)

    /// location_bar.css:115-120 — selected pill: a lighter wash (.22 → .08 over
    /// .04) and the rail's own ink as the edge, never a pink focus ring.
    static let pillFocusTop = Color.white.opacity(0.22)
    static let pillFocusBottom = Color.white.opacity(0.08)
    static let pillFocusWash = Color.white.opacity(0.04)
    static let pillFocusBorder = Color(red: 27 / 255, green: 31 / 255, blue: 39 / 255).opacity(0.55)

    /// app.css `.brows-bookmark` — 28px tall, 7px radius, 6px gap, max 118px,
    /// 2px/8px padding, 12px text in `rgba(74,84,102,.72)`, no chip fill.
    static let chipInk = Color(red: 74 / 255, green: 84 / 255, blue: 102 / 255).opacity(0.72)

    /// brows_glass.h: `SkColorSetRGB(0xF0, 0xF5, 0xFA)` at the clarity alpha.
    /// Default clarity is "foggy" = 0x7B (0.48) — but that alpha composites over
    /// the desktop's own window background. On the phone the rail floats over the
    /// page itself, so the same foggy pane at 0.48 let article text read through the
    /// bar. The pane is the same colour and the ramp/sheen are unchanged; only the
    /// backing is raised to the desktop's opaque-chrome result.
    static let railBase = Color(red: 240 / 255, green: 245 / 255, blue: 250 / 255)
    static let railBaseAlpha = 0.90

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

                // brows_glass.h: transparent at 52% of the gradient's reach,
                // not at the end of it.
                RadialGradient(
                    stops: [
                        Gradient.Stop(color: Theme.railSheen, location: 0),
                        Gradient.Stop(color: .clear, location: 0.52)
                    ],
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

/// toolbar_button.css: every rail control is a glass bubble with an 8px radius, a
/// 1px `rgba(255,255,255,.30)` hairline, the `.18 → .035` lit gradient over
/// `rgba(247,250,253,.025)`, plus the two insets and two soft drops. The desktop
/// bubble is 30px; on a phone the touch frame is 36 so it stays tappable.
struct GlassCircleButtonStyle: ButtonStyle {
    var enabled: Bool = true
    var glyph: Color = Theme.muted
    private let bubbleRadius: CGFloat = 8
    private let drop = Color(red: 24 / 255, green: 31 / 255, blue: 44 / 255)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(enabled ? glyph : glyph.opacity(0.4))
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    // Rail styling: white circular controls. The bubble gradient
                    // and its hairline still ride on top; the white plate is what
                    // keeps the glyph legible when the rail floats over a page.
                    RoundedRectangle(cornerRadius: bubbleRadius, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                    RoundedRectangle(cornerRadius: bubbleRadius, style: .continuous)
                        .fill(Theme.bubbleWash)
                    RoundedRectangle(cornerRadius: bubbleRadius, style: .continuous)
                        .fill(
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
                RoundedRectangle(cornerRadius: bubbleRadius, style: .continuous)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.19 : 0.30), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: bubbleRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.56), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.45)
                        )
                    )
            }
            // toolbar_button.css:36-40 — inset 0 -1px rgba(34,44,60,.075),
            // 0 1px 2px rgba(24,31,44,.075), 0 4px 12px rgba(24,31,44,.045).
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: bubbleRadius, style: .continuous)
                    .stroke(Color(red: 34 / 255, green: 44 / 255, blue: 60 / 255).opacity(0.075), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .white],
                            startPoint: UnitPoint(x: 0.5, y: 0.55),
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: drop.opacity(0.075), radius: 2, x: 0, y: 1)
            .shadow(color: drop.opacity(0.045), radius: 12, x: 0, y: 4)
            .opacity(enabled ? 1 : 0.55)
    }
}

/// iOS 26's own Liquid Glass. Apple's current material is the design target, so
/// every Brows card asks the system for it; the app's rail pane is only the
/// fallback for a pre-26 runtime. The flat surface fill is gone: a sheet is the
/// platform's glass, a card is a glass effect over the page.
extension View {
    @ViewBuilder
    func browsGlass(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(
                GlassPane(cornerRadius: cornerRadius)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        }
    }
}

extension View {
    /// A sheet's platform background is opaque; Brows sheets are glass, so the
    /// system fill is cleared and the sheet's own pane is the only surface.
    @ViewBuilder
    func browsSheetBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.clear)
        } else {
            self
        }
    }
}
