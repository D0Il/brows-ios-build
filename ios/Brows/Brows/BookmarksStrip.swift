import SwiftUI

/// Favourites as chips inside the toolbar rail, fed by the same bookmark list
/// the star writes to.
struct BookmarksStrip: View {
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.bookmarks) { bookmark in
                    Button {
                        model.navigate(to: bookmark.url)
                    } label: {
                        Text(bookmark.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.92)))
                            .overlay(Capsule().stroke(Theme.glassStroke, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 30)
    }
}
