import SwiftUI

struct BookmarksSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                GlassPane(cornerRadius: 0).ignoresSafeArea()

                List {
                    if model.bookmarks.isEmpty {
                        Text("No bookmarks yet. Tap the star in the address pill to save a page.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.panelMuted)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(model.bookmarks) { bookmark in
                        Button {
                            model.navigate(to: bookmark.url)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(bookmark.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.panelInk)
                                Text(bookmark.url)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.panelMuted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.rowFill)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            model.removeBookmark(model.bookmarks[index])
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
