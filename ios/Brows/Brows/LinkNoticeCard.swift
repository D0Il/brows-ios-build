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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("linknotice.card")
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(notice.scheme)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.panelMuted)

            Text("No app on this iPhone opens \(notice.scheme) links. Brows left the page where it was.")
                .font(.system(size: 15))
                .foregroundColor(Theme.panelInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("linknotice.message")

            Button {
                model.pendingLinkNotice = nil
            } label: {
                Text("OK")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .accessibilityIdentifier("linknotice.ok")
        }
        .padding(20)
        .frame(maxWidth: 340)
        .browsGlass(cornerRadius: 18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.rowBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        .padding(24)
    }
}
