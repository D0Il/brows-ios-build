import SwiftUI

/// The phone's app menu — the desktop menu's row list, arranged as a sheet.
/// Website panels first, then page tools, then tab commands and the zoom cluster.
struct AppMenu: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PanelBar(title: "Menu") {
                Button("Done") { dismiss() }
            }
            ZStack {
                List {
                    Section {
                        row("Site information", "lock.shield") {
                            model.loadSiteInfo()
                            model.pendingPanel = .siteInfo
                        }
                        row("Bookmarks", "book") { model.pendingPanel = .bookmarks }
                        row("History", "clock") { model.pendingPanel = .history }
                        row("Downloads", "arrow.down.circle") { model.pendingPanel = .downloads }
                        row("Passwords", "key") { model.pendingPanel = .passwords }
                        // No puzzle piece and no "Extensions" row: iOS is WebKit-only (App Store
                        // 2.5.6), so a row that implies installable extensions would be fake chrome.
                        // The row names what the phone actually has.
                        row("Content blockers", "shield.lefthalf.filled") { model.pendingPanel = .extensions }
                        row("Workspaces", "square.grid.2x2") { model.pendingPanel = .workspaces }
                        row("Settings", "gear") { model.pendingPanel = .settings }
                    }

                    Section {
                        zoomRow
                        row("Reload page", "arrow.clockwise") { model.reloadOrStop() }
                        row("Find in page", "magnifyingglass") { model.startFind() }
                        row("Reader mode", "doc.plaintext") { model.pendingPanel = .reader }
                        row("Print", "printer") { model.pendingPanel = .print }
                        row("Save as PDF", "doc.richtext") { model.pendingPanel = .pdf }
                        row("Reopen closed tab", "arrow.uturn.backward") {
                            if let closed = model.recentlyClosed.first {
                                model.restoreClosed(closed)
                            }
                        }
                    }

                    Section {
                        row("New tab", "plus") { model.newTab() }
                        row("New private tab", "eyeglasses") { model.newTab(private: true) }
                        row("Close private tabs", "xmark.circle") { model.closeAllPrivate() }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    /// Zoom cluster, same behaviour as the desktop strip control: −, the % is the
    /// reset, +, and it follows the active tab.
    private var zoomRow: some View {
        HStack(spacing: 10) {
            Text("Zoom")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.panelInk)
                .frame(width: 70, alignment: .leading)

            Spacer(minLength: 0)

            Button { model.adjustZoom(by: -0.1) } label: { Image(systemName: "minus") }
                .buttonStyle(GlassCircleButtonStyle(glyph: Theme.plateInk, plate: Theme.plate))
            Button { model.resetZoom() } label: {
                Text("\(Int(((model.activeTab?.zoom ?? 1) * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(GlassCircleButtonStyle(glyph: Theme.plateInk, plate: Theme.plate))
            Button { model.adjustZoom(by: 0.1) } label: { Image(systemName: "plus") }
                .buttonStyle(GlassCircleButtonStyle(glyph: Theme.plateInk, plate: Theme.plate))
        }
        .listRowBackground(Theme.rowFill)
    }

    private func row(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundColor(Theme.panelMuted)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.panelInk)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action()
            dismiss()
        }
        .listRowBackground(Theme.rowFill)
    }
}
