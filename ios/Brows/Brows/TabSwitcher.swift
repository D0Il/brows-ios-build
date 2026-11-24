import SwiftUI

/// Tab gallery. Mirrors the desktop tab-search surface on a phone: search over
/// open tabs with ranking and a live count, workspace labels on every card, and
/// recently closed tabs underneath.
struct TabSwitcher: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var results: [Tab] { model.rankedTabs(query) }

    var body: some View {
        VStack(spacing: 0) {
            PanelBar(title: "Tabs") {
                if model.tabs.contains(where: { $0.isPrivate }) {
                    Button("Close private") { model.closeAllPrivate() }
                }
            } trailing: {
                Button("Done") { dismiss() }
            }
            ZStack {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(Theme.panelMuted)
                        TextField("", text: $query, prompt: Text("Search tabs").foregroundColor(Theme.fieldPlaceholder))
                            .textFieldStyle(.plain)
                            .accessibilityLabel("Search tabs")
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(Theme.panelInk)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Capsule().fill(Theme.rowFill))

                    HStack {
                        Text(query.isEmpty ? "\(model.tabs.count) open" : "\(results.count) of \(model.tabs.count) tabs")
                            .scaledFont(11, .medium)
                            .foregroundColor(Theme.panelMuted)
                        Spacer(minLength: 0)
                    }

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(results) { tab in
                                tabCard(tab)
                            }
                            addCard
                        }
                        .padding(.bottom, 12)

                        if query.isEmpty && !model.recentlyClosed.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("RECENTLY CLOSED")
                                    .scaledFont(10, .semibold)
                                    .tracking(1.2)
                                    .foregroundColor(Theme.panelMuted)
                                    .padding(.top, 8)

                                ForEach(model.recentlyClosed.prefix(5)) { closed in
                                    Button {
                                        model.restoreClosed(closed)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "arrow.uturn.backward")
                                                .scaledFont(12, .semibold)
                                                .foregroundColor(Theme.panelMuted)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(closed.title)
                                                    .scaledFont(13, .medium)
                                                    .foregroundColor(Theme.panelInk)
                                                    .lineLimit(1)
                                                Text(closed.url)
                                                    .scaledFont(10)
                                                    .foregroundColor(Theme.panelMuted)
                                                    .lineLimit(1)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    private func tabCard(_ tab: Tab) -> some View {
        // The active card is the white plate (active tab glass); the rest are
        // translucent over the dark surface, so their ink flips like the desktop's
        // dark media block.
        let active = model.activeTabId == tab.id
        let primary = active ? Theme.panelInk : Theme.panelInk
        let secondary = active ? Theme.panelMuted : Theme.panelMuted

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                // brows_surface.css: `.tab-search-row.active .tab-search-copy
                // strong { font-weight: 700 }`. The white plate alone is white on
                // white in the light sheet, so the weight is what names the tab
                // you are on.
                titleText(tab)
                    .scaledFont(13, active ? .bold : .semibold)
                    .lineLimit(2)
                    .foregroundColor(primary)
                Spacer(minLength: 0)
                Button {
                    model.close(tab)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .scaledFont(15)
                        .foregroundColor(secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close tab")
                .accessibilityIdentifier("tab.close")
            }

            Text(tab.url?.host ?? "New Tab")
                .scaledFont(11)
                .foregroundColor(secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                if let position = results.firstIndex(where: { $0.id == tab.id }) {
                    Text("\(position + 1)")
                        .scaledFont(8, .bold)
                        .foregroundColor(secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Theme.rowFill))
                }
                Text(model.workspaceName(for: tab).uppercased())
                    .scaledFont(8, .semibold)
                    .tracking(0.8)
                    .foregroundColor(secondary)
                if tab.isPrivate {
                    Text("PRIVATE")
                        .scaledFont(8, .bold)
                        .tracking(0.8)
                        .foregroundColor(secondary)
                }
            }
        }
        .padding(12)
        .frame(height: 118, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(model.activeTabId == tab.id ? Theme.plate : Theme.rowFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.glassStroke, lineWidth: model.activeTabId == tab.id ? 1 : 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            model.select(tab)
            dismiss()
        }
    }

    /// Marks the matched part of the title, the way the desktop tab search does.
    private func titleText(_ tab: Tab) -> Text {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let range = tab.title.range(of: trimmed, options: .caseInsensitive) else {
            return Text(tab.title)
        }
        let before = String(tab.title[tab.title.startIndex..<range.lowerBound])
        let match = String(tab.title[range])
        let after = String(tab.title[range.upperBound...])
        return Text(before) + Text(match).underline().bold() + Text(after)
    }

    private var addCard: some View {
        Button {
            // The gallery stays open on the new tab, as the desktop's tab surface
            // does: you are choosing among tabs, and the new one is now one of them.
            model.newTab()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .scaledFont(20, .semibold)
                Text("New Tab")
                    .scaledFont(12, .medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 118)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.rowFill))
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(Theme.glassStroke, lineWidth: 0.5)
            )
            .foregroundColor(Theme.panelInk)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.add")
    }
}
