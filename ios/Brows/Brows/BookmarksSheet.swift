import SwiftUI

/// The desktop's edit dialog files a bookmark into a folder
/// (`port/site/popups/bookmark.html:51-58`) and its bar is the "Bookmarks bar"
/// folder; the phone list groups by the same names instead of staying flat.
struct BookmarksSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PanelBar(title: "Bookmarks") {
                Button("Done") { dismiss() }
            }
            ZStack {
                List {
                    Section {
                        HStack {
                            Text("Folder")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.panelInk)
                            Spacer(minLength: 12)
                            Menu {
                                ForEach(model.bookmarkFolders, id: \.self) { folder in
                                    Button(folder) {
                                        model.settings.bookmarkFolder = folder
                                        model.saveSettings()
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(model.newBookmarkFolder)
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.panelInk)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(Theme.panelMuted)
                                }
                            }
                            .accessibilityIdentifier("bookmarks.folder")
                            .accessibilityValue(model.newBookmarkFolder)
                        }
                        .listRowBackground(Theme.rowFill)
                    } footer: {
                        Text("New bookmarks are filed here.")
                    }

                    if model.bookmarks.isEmpty {
                        Text("No bookmarks yet. Tap the star in the address pill to save a page.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.panelMuted)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(model.bookmarkFolders, id: \.self) { folder in
                        let items = model.bookmarks.filter { $0.folder == folder }
                        if !items.isEmpty {
                            Section(folder) {
                                ForEach(items) { bookmark in
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
                                    .accessibilityIdentifier("bookmark.row")
                                    .listRowBackground(Theme.rowFill)
                                }
                                .onDelete { indexSet in
                                    // Indices are per section, so delete by identity.
                                    for index in indexSet { model.removeBookmark(items[index]) }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
