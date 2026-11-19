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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notice.card")
    }

    private var card: some View {
        ZStack {
            GlassLayer(cornerRadius: 18)
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
                    .foregroundColor(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .accessibilityIdentifier("notice.ok")
            }
            .padding(20)
        }
        .frame(maxWidth: 340)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.rowBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        .padding(24)
    }
}
