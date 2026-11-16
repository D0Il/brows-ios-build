import SwiftUI

// Brows palette. The desktop rail uses a solid white omnibox pill, translucent
// white glass panes with a .72 white stroke, and the muted glyph #68717f.
enum Theme {
    static let ink = Color(red: 0.055, green: 0.075, blue: 0.11)
    static let muted = Color(red: 0.408, green: 0.443, blue: 0.498) // #68717f
    static let glassStroke = Color.white.opacity(0.72)
    static let backdropTop = Color(red: 0.09, green: 0.16, blue: 0.28)
    static let backdropBottom = Color(red: 0.03, green: 0.05, blue: 0.10)
    static let pill = Color.white

    static var backdrop: LinearGradient {
        LinearGradient(
            colors: [backdropTop, backdropBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Translucent see-through pane, the same material treatment the desktop rail
/// uses for tab glass and the floating chrome.
struct GlassPane: View {
    var cornerRadius: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle().fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.glassStroke, lineWidth: cornerRadius > 0 ? 1 : 0)
            )
    }
}

/// White circular control, mirroring the desktop rail's white nav buttons.
struct GlassCircleButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            // Rail glyphs are the muted #68717f ink; the star is the one black glyph.
            .foregroundColor(enabled ? Theme.muted : Theme.muted.opacity(0.4))
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.7 : 0.92))
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.6), lineWidth: 0.5)
            )
            .opacity(enabled ? 1 : 0.55)
    }
}
