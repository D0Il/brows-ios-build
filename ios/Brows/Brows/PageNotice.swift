import SwiftUI

/// A page command that could not be carried out, said in the app's own surface.
/// A system alert here would borrow chrome the browser already draws itself — the
/// same mistake as the desktop's generic Chromium popup — so this is the shared
/// plate on a scrim, with the app's fixed ink and a single OK.
struct PageNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct PageNoticeCard: View {
    let notice: PageNotice
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            card.offset(y: -48)
        }
        .onAppear { model.refreshPanelBackdrop() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notice.card")
    }

    private var card: some View {
        ZStack {
            // A material pane, not a fill: the desktop alert is a glass plate and the
            // page behind it is still the backdrop. A plain fill reads as a slab and
            // an empty glassEffect renders nothing, letting the article's lines
            // through unblurred (captures notice-light, dialog-light, linknotice-light).
            GlassBackground(cornerRadius: 18, backdrop: model.panelBackdrop)
            VStack(alignment: .leading, spacing: 14) {
            Text(notice.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.panelMuted)

            Text(notice.message)
                .font(.system(size: 15))
                .foregroundColor(Theme.panelInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("notice.message")

            Button {
                model.pageNotice = nil
            } label: {
                Text("OK")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.panelInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .panelButtonPlate()
            .accessibilityIdentifier("notice.ok")
            }
            .padding(20)
        }
        .frame(maxWidth: 340)
        // Hug the content: the scrim beside it fills the screen, and the glass took
        // the full height, so the notice was a screen-sized pane (capture
        // notice-dark, run 44656125222).
        .fixedSize(horizontal: false, vertical: true)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.rowBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        .padding(24)
    }
}
