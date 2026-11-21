import SwiftUI

/// The address pill's completions. It is the app's own surface, not a system
/// list: same plate, hairline and ink as the other browser-owned panels, one row
/// per page, the title in ink and the host muted underneath.
struct AddressSuggestionsPanel: View {
    @EnvironmentObject var model: BrowserModel
    /// The rail's offset for this panel; see `GlassPane.backdropOffset`.
    var backdropOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // The desktop's row popup is a glass plate over the page, like every
            // other popup: the page behind it is blurred, never legible.
            VStack(spacing: 0) {
            ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    model.openSuggestion(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.source == .bookmark ? "bookmark" : "clock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.panelMuted)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.panelInk)
                                .lineLimit(1)
                            Text(suggestion.detail)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.panelMuted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("suggest.row")
                .accessibilityLabel("\(suggestion.title), \(suggestion.detail)")

                if index < model.suggestions.count - 1 {
                    Rectangle()
                        .fill(Theme.rowBorder)
                        .frame(height: 1)
                        .padding(.leading, 42)
                }
            }
        }
        .padding(.vertical, 4)
        // The panel must take its full height: when it was allowed to compress, the
        // rows drew outside its frame, under the rail, and a row's tap landed on
        // the rail's reload control instead.
        .fixedSize(horizontal: false, vertical: true)
        .browsGlass(cornerRadius: 16)
        }
        
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .layoutPriority(1)
        .zIndex(1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suggest.panel")
        // The page is photographed when the completions are already up, never on
        // the tap that focuses the pill: that tap has to become first responder
        // before anything can wait on a snapshot.
        .onAppear { model.refreshPanelBackdrop() }
    }
}
