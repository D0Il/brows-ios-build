import SwiftUI
import UIKit
import WebKit
import CoreImage

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
        light: UIColor(white: 1, alpha: 0.28),
        dark: UIColor(red: 34 / 255, green: 38 / 255, blue: 45 / 255, alpha: 0.45)
    )
    static let rowBorder = adaptive(
        light: UIColor(white: 1, alpha: 0.70),
        dark: UIColor(white: 1, alpha: 0.12)
    )
    /// `.siteinfo-section` is separated from the section above by a 1 px rule, not by a plate:
    /// `border-top: 1px solid rgba(71,82,96,.10)` (`brows_surface.css:2191`), and the dark block
    /// carries the same hairline as white .10.
    static let sectionRule = adaptive(
        light: UIColor(red: 71 / 255, green: 82 / 255, blue: 96 / 255, alpha: 0.10),
        dark: UIColor(white: 1, alpha: 0.10)
    )

    /// The plate fill itself. `brows_surface.css:9` sets `--plate-rgb: 255,255,255` and
    /// `:876-880` sets `--plate-rgb: 34,38,45` in the dark block, where every plate at
    /// alpha >= .5 is `rgba(var(--plate-rgb),alpha)`. A literal white fill in dark is a
    /// plate the desktop never paints: it is why the dark tab card, tab search field,
    /// workspace row and site-info card read as white slabs beside their desktop pairs.
    static let plateBase = adaptive(
        light: UIColor(white: 1, alpha: 1),
        dark: UIColor(red: 34 / 255, green: 38 / 255, blue: 45 / 255, alpha: 1)
    )
    /// A plate inside a sheet is `rgba(var(--plate-rgb),.62)` (`brows_surface.css`):
    /// at .95 it read as a white slab on top of the sheet's own glass.
    static let plate = plateBase.opacity(0.30)
    /// The pane's own tint. Light glass must stay see-through over a page;
    /// the dark block keeps the desktop's heavier plate.
    static let plateAlpha = 0.30
    /// What actually makes glass glass: the page behind is blurred, not just tinted.
    static let glassBlur: CGFloat = 22
    /// The wash a control's glass takes. Only a tint, never a fill: the phone's
    /// controls sit on the page and the page must read through them.
    static let railPlate = Color.white.opacity(0.22)

    /// Ink for text and glyphs on a plate. The plate is adaptive now (`plate`), so the
    /// ink follows it: `--ink` is #20242b in light and #f2f4f8 in the dark block, and
    /// `--muted` is #657080 / #aab2be (`brows_surface.css:877-879`). Pairing the dark
    /// captures against port/site showed white plates carrying light-mode ink; fixing
    /// the plate without the ink would only invert the bug.
    static let plateInk = adaptive(light: panelInkLight, dark: panelInkDark)
    static let plateMuted = adaptive(light: panelMutedLight, dark: panelMutedDark)
    static let fieldPlaceholder = adaptive(light: panelMutedLight, dark: panelMutedDark)

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
    /// The surface rim: `rgba(255,255,255,.76)` in light, `rgba(255,255,255,.14)` in the
    /// desktop's dark block (`brows_surface.css:882`). A .72 rim in dark is a bright
    /// outline the desktop never draws.
    static let glassStroke = adaptive(
        light: UIColor(white: 1, alpha: 0.76),
        dark: UIColor(white: 1, alpha: 0.14)
    )
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
    /// A tint, not a coat of paint: at .90 the rail was a white slab and the page
    /// below it was invisible. Glass has to show what is behind it.
    static let railBaseAlpha = 0.30

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
    /// A popup plate, not the rail band: `brows_surface.css` paints plates with
    /// `rgba(var(--plate-rgb),.62)`, and the dark block's `--plate-rgb` is
    /// `34,38,45`. The rail band stays the desktop's light tint in both
    /// appearances; a sheet must not, or dark mode gets a near-white slab.
    var plate: Bool = false
    /// The page as a blurred image (see `PanelBackdrop`). A popup over web content
    /// must be given this: `BackdropBlur` cannot sample a WKWebView, so with no
    /// snapshot the pane falls back to a flat material and reads as a slab again.
    var backdrop: UIImage? = nil
    /// A pane placed by an overlay's `offset` reports the frame it had before that
    /// offset, so the glass would crop the page from where the pane is not. The
    /// owner passes the same offset here and it is added to the crop's origin.
    var backdropOffset: CGSize = .zero

    private var tint: Color { plate ? Theme.plateBase : Theme.railBase }
    private var tintAlpha: Double { plate ? Theme.plateAlpha : Theme.railBaseAlpha }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The desktop pane is `backdrop-filter: blur(var(--glass-blur))`
                // under its tint. Paint alone is a slab with a little transparency,
                // not glass: the page behind it must be blurred through the pane.
                backdropLayer(geo)

                tint.opacity(tintAlpha)

                if !plate {
                    LinearGradient(
                        colors: [Theme.railRampTop, Theme.railRampBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                // brows_glass.h: transparent at 52% of the gradient's reach,
                // not at the end of it.
                if !plate {
                    RadialGradient(
                        stops: [
                            Gradient.Stop(color: Theme.railSheen, location: 0),
                            Gradient.Stop(color: .clear, location: 0.52)
                        ],
                        center: UnitPoint(x: 0.18, y: -0.20),
                        startRadius: 0,
                        endRadius: max(geo.size.width * 1.4, geo.size.height * 0.95)
                    )
                }

                if cornerRadius > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Theme.glassStroke, lineWidth: 1)
                }
            }
        }
    }

    /// The blurred page, cropped to exactly where this pane sits, so a card shows
    /// the part of the page it covers and a full-screen panel shows all of it.
    @ViewBuilder
    private func backdropLayer(_ geo: GeometryProxy) -> some View {
        if let backdrop {
            // Crop the snapshot to this pane's own rect, then draw that crop. The
            // frame-and-offset pair this replaces laid a screen-sized image inside
            // a smaller pane's frame; for the address completions — a card placed
            // by an overlay offset — the page ended up squeezed into the card, and
            // every line averaged into one flat wash (captures suggest-dark and
            // pill-dark, run 44896216566). A crop cannot be re-laid-out by a parent.
            let frame = geo.frame(in: .global).offsetBy(dx: backdropOffset.width, dy: backdropOffset.height)
            if let cropped = PanelBackdrop.crop(backdrop, to: frame) {
                // Blur the page, then tint it. Without this the crop was drawn sharp
                // under a white wash — milk, not glass (the light captures showed a
                // white slab over a grey page).
                Image(uiImage: cropped)
                    .resizable()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: Theme.glassBlur)
                    .clipped()
            } else {
                BackdropBlur()
            }
        } else {
            BackdropBlur()
        }
    }
}

/// The page as a pane sees it.
///
/// `UIVisualEffectView` cannot sample a WKWebView: the web content is composited
/// out of process, so the effect view paints its material alone. Measured on run
/// 44866110895, a dark popup was a uniform 82 across the whole screen — the
/// article behind it, the white pill and the rail all left no trace — which is
/// the flat slab the desktop's backdrop-filter never produces. So the same
/// operation is done here on a snapshot: the blur and the
/// `saturate(165%) brightness(1.055)` from `webui.css:804`.
enum PanelBackdrop {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// `webui.css:804` is `--glass-blur: 28px` on the desktop. Taken literally on a
    /// 402 pt phone it is 7% of the viewport instead of the desktop's 2.2% of a
    /// 1280 px window, and it wipes the page to a flat wash: run 44873932003's
    /// downloads-dark measured 114 with a standard deviation of 1.5 across the whole
    /// pane, so the headline and paragraphs behind it vanished and the glass read as
    /// the slab the user rejected. Keeping only the desktop's share of the viewport
    /// (28 × 402/1280 ≈ 9 pt) still left a 1.8 standard deviation on run 44881986234:
    /// the page's blocks were gone and the pane was a slab with a little transparency
    /// again. What matters on a phone is the page still being visible under the
    /// plate, so the radius is the largest one that leaves the article's structure
    /// readable through the glass: 6 pt. At 4 pt the body text itself becomes
    /// legible through the plate, which is a window, not glass.
    private static let blurPoints: Double = 6

    /// Snapshot the page and hand back its blurred image on the main queue.
    static func capture(_ webView: WKWebView?, completion: @escaping (UIImage?) -> Void) {
        guard let webView, webView.bounds.width > 0, webView.bounds.height > 0 else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        webView.takeSnapshot(with: configuration) { image, _ in
            let blurred = image.flatMap(blur)
            DispatchQueue.main.async { completion(blurred) }
        }
    }

    /// The part of the page a pane covers, in the image's own pixels. The pane's
    /// rect is in screen points and the snapshot is the screen at the device's
    /// scale, so scaling the rect by the image's scale gives the crop. A pane that
    /// covers the whole screen returns the snapshot itself, uncopied.
    static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cg = image.cgImage, image.size.width > 0, image.size.height > 0 else { return nil }
        let sx = CGFloat(cg.width) / image.size.width
        let sy = CGFloat(cg.height) / image.size.height
        let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let pixels = CGRect(
            x: rect.minX * sx, y: rect.minY * sy,
            width: rect.width * sx, height: rect.height * sy
        ).integral
        let clipped = pixels.intersection(bounds)
        guard clipped.width >= 1, clipped.height >= 1 else { return nil }
        if clipped == bounds { return image }
        guard let cropped = cg.cropping(to: clipped) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    static func blur(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let source = CIImage(cgImage: cg)
        let scale = Double(cg.width) / Double(max(image.size.width, 1))
        guard let blurred = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: source.clampedToExtent(),
            kCIInputRadiusKey: blurPoints * scale
        ])?.outputImage else { return nil }
        let adjusted = blurred
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.65])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.055, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1.055, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1.055, w: 0)
            ])
        guard let result = context.createCGImage(adjusted, from: source.extent) else { return nil }
        return UIImage(cgImage: result, scale: image.scale, orientation: image.imageOrientation)
    }
}

/// The backdrop of a glass pane: a real blur of whatever is behind it, for panes
/// over native content (the rail, the strips). It cannot see a WKWebView — see
/// `PanelBackdrop` — so panes over a page must be handed a snapshot instead.
struct BackdropBlur: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.effect = UIBlurEffect(style: style)
    }

    private var style: UIBlurEffect.Style {
        colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight
    }
}

/// A panel's own top bar. SwiftUI's NavigationView paints its hosting background,
/// which is opaque, so a panel built on it can never be glass: the page behind it
/// disappears. This carries the same title and controls on the panel's own surface.
struct PanelBar<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.panelInk)
                .accessibilityIdentifier("panel.title")
            HStack(spacing: 8) {
                leading
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }
}

extension PanelBar where Leading == EmptyView {
    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, leading: { EmptyView() }, trailing: trailing)
    }
}

/// toolbar_button.css: every rail control is a glass bubble with an 8px radius, a
/// 1px `rgba(255,255,255,.30)` hairline, the `.18 → .035` lit gradient over
/// `rgba(247,250,253,.025)`, plus the two insets and two soft drops. The desktop
/// bubble is 30px; on a phone the touch frame is 36 so it stays tappable.
struct GlassCircleButtonStyle: ButtonStyle {
    var enabled: Bool = true
    var glyph: Color = Theme.plateMuted
    /// The bubble fill. Rail controls keep `Theme.railPlate` (the desktop's white
    /// circular control); plates *inside* a sheet pass `Theme.plate` so they go dark
    /// with the desktop's dark block instead of punching a white hole in the sheet.
    var plate: Color = Theme.railPlate
    private let bubbleRadius: CGFloat = 8
    private let drop = Color(red: 24 / 255, green: 31 / 255, blue: 44 / 255)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(enabled ? glyph : glyph.opacity(0.4))
            .frame(width: 36, height: 36)
            // No plate: the control is a glyph on the glass it sits on, the way
            // system bars draw their symbols. Only a press wash, no fill.
            .background(
                RoundedRectangle(cornerRadius: bubbleRadius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.20 : 0.001))
            )
    }
}

/// Overlay panels are not presentations, so `@Environment(\.dismiss)` cannot close
/// them. They read their close action from here instead; the name `dismiss` is kept
/// in each panel so its call sites do not change.
private struct PanelDismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var panelDismiss: () -> Void {
        get { self[PanelDismissKey.self] }
        set { self[PanelDismissKey.self] = newValue }
    }
}

extension View {
    /// The desktop's plate for a button: the plate fill plus the hairline rim that
    /// keeps it visible on a sheet that is also white. Without the rim the OK /
    /// Save / Export buttons were white rectangles on a white card and read as
    /// plain centred text (captures notice-light, passwords-light, siteinfo-light).
    func panelButtonPlate(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.plateBase.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.rowBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }

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


/// Apple's Liquid Glass as a UIKit background view. This is the documented hybrid
/// path: `UIGlassEffect` in a `UIVisualEffectView`. SwiftUI's `glassEffect` around
/// the app's hosted `UITextField` hits a known iOS 26 mixed SwiftUI/UIKit bug
/// (FB20969772) where tapping the field to raise the keyboard stalls or loses
/// focus, and an empty `.glassEffect` layer renders nothing at all.
struct GlassBackground: UIViewRepresentable {
    var cornerRadius: CGFloat = 0

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        if #available(iOS 26.0, *) {
            view.effect = UIGlassEffect()
        } else {
            view.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
    }
}

/// iOS 26's own Liquid Glass. Apple's current material is the design target, so
/// every Brows pane asks the system for it; the app's rail pane is only the
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

/// Glass as a sibling layer behind card content. A glass *background* under a
/// control takes that control's tap; a sibling layer does not.
struct GlassLayer: View {
    var cornerRadius: CGFloat
    var body: some View {
        Color.clear
            .browsGlass(cornerRadius: cornerRadius)
            .allowsHitTesting(false)
    }
}
