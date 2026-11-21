import SwiftUI

/// app.css `.brows-bookmark`: favourites are chips inside the toolbar row, never a
/// second row. Each chip is 28px tall, 7px radius, max 118px wide, 0/8px padding,
/// 12px text in rgba(74,84,102,.72), on a transparent chip with a 6px gap.
struct BookmarksStrip: View {
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.bookmarks.filter { $0.folder == Bookmark.defaultFolder }) { bookmark in
                    Button {
                        model.navigate(to: bookmark.url)
                    } label: {
                        Text(bookmark.title)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.chipInk)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .frame(maxWidth: 118, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bookmark.chip")
                    .accessibilityValue(bookmark.title)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 28)
    }
}
