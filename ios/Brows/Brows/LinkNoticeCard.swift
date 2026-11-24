import SwiftUI

/// A link the browser could not take anywhere. The page stays exactly where it
/// was; this card says which scheme failed, in the app's own surface. A system
/// alert here would be the app borrowing chrome it already draws itself, and it
/// would lose the app's ink and plates.
struct LinkNoticeCard: View {
    let notice: PendingLinkNotice
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            card.offset(y: -48)
        }
        .onAppear { model.refreshPanelBackdrop() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("linknotice.card")
    }

    private var card: some View {
        ZStack {
            // A material pane, not a fill: the desktop alert is a glass plate and the
            // page behind it is still the backdrop. A plain fill reads as a slab and
            // an empty glassEffect renders nothing, letting the article's lines
            // through unblurred (captures notice-light, dialog-light, linknotice-light).
            GlassPane(cornerRadius: 18, plate: true, backdrop: model.panelBackdrop)
            VStack(alignment: .leading, spacing: 14) {
            Text(notice.scheme)
                .scaledFont(12, .semibold)
                .foregroundColor(Theme.panelMuted)

            Text("No app on this iPhone opens \(notice.scheme) links. Brows left the page where it was.")
                .scaledFont(15)
                .foregroundColor(Theme.panelInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("linknotice.message")

            Button {
                model.pendingLinkNotice = nil
            } label: {
                Text("OK")
                    .scaledFont(14, .semibold)
                    .foregroundColor(Theme.panelInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .panelButtonPlate()
            .accessibilityIdentifier("linknotice.ok")
            }
            .padding(20)
        }
        .frame(maxWidth: 340)
        // The scrim beside this card fills the screen, and the glass layer inside
        // takes whatever height it is offered: without this the card stretched to
        // most of the screen with its content floating in the middle (capture
        // linknotice-dark, run 44656125222). A card hugs its own content.
        .fixedSize(horizontal: false, vertical: true)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.rowBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        .padding(24)
    }
}
