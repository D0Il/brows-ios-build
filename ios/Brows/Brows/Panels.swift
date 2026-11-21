import SwiftUI

/// Workspaces, the desktop cards arranged as a sheet. Switching moves the tab set;
/// deleting a workspace moves its tabs to the neighbour instead of closing them,
/// exactly as the desktop rail does.
struct WorkspacesSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        NavigationView {
            ZStack {
                GlassPane(cornerRadius: 0, plate: true).ignoresSafeArea()

                VStack(spacing: 12) {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(model.workspaces) { workspace in
                                workspaceRow(workspace)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("", text: $newName, prompt: Text("New workspace").foregroundColor(Theme.fieldPlaceholder))
                            .textFieldStyle(.plain)
                            .accessibilityLabel("New workspace")
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(Theme.panelInk)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(Capsule().fill(Theme.plateBase))

                        Button {
                            model.addWorkspace(named: newName)
                            newName = ""
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(GlassCircleButtonStyle(glyph: Theme.plateMuted, plate: Theme.plate))
                        .accessibilityIdentifier("workspace.add")
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Workspaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func workspaceRow(_ workspace: Workspace) -> some View {
        let count = model.tabs.filter { $0.workspaceId == workspace.id }.count
        let active = workspace.id == model.activeWorkspaceId

        return Button {
            model.switchWorkspace(workspace)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(workspace.initials)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Theme.panelMuted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.plateBase.opacity(0.9)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(active ? Theme.panelInk : Theme.panelInk)
                    Text("\(count) tab\(count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(active ? Theme.panelMuted : Theme.panelMuted)
                }

                Spacer(minLength: 0)

                if active {
                    Text("CURRENT")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(active ? Theme.panelMuted : Theme.panelMuted)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(active ? Theme.plate : Theme.rowFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(Theme.glassStroke, lineWidth: active ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workspace.row.\(workspace.initials)")
        .contextMenu {
            Button("Delete workspace", role: .destructive) {
                model.deleteWorkspace(workspace)
            }
        }
    }
}

/// History as the desktop panel lists it: newest first, grouped by day, with a
/// per-row delete and a clear-all.
struct HistorySheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss
    @State private var query = ""

    private var entries: [HistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return model.history }
        return model.history.filter {
            $0.title.lowercased().contains(trimmed) || $0.url.lowercased().contains(trimmed)
        }
    }

    private var days: [(String, [HistoryEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        var order: [String] = []
        var buckets: [String: [HistoryEntry]] = [:]
        for entry in entries {
            let key = Calendar.current.isDateInToday(entry.date) ? "Today" : formatter.string(from: entry.date)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(entry)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                GlassPane(cornerRadius: 0, plate: true).ignoresSafeArea()

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(Theme.panelMuted)
                        TextField("", text: $query, prompt: Text("Search history").foregroundColor(Theme.fieldPlaceholder))
                            .textFieldStyle(.plain)
                            .accessibilityLabel("Search history")
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(Theme.panelInk)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Capsule().fill(Theme.plateBase))

                    if entries.isEmpty {
                        Text(model.history.isEmpty ? "Nothing in history yet." : "No matches.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.panelMuted)
                            .padding(.top, 20)
                        Spacer(minLength: 0)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(days, id: \.0) { bucket in
                                    let day = bucket.0
                                    let items = bucket.1
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(day.uppercased())
                                            .font(.system(size: 10, weight: .semibold))
                                            .tracking(1.2)
                                            .foregroundColor(Theme.panelMuted)
                                        ForEach(items) { entry in
                                            row(entry)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear", role: .destructive) { model.clearHistory() }
                        .accessibilityIdentifier("history.clear")
                        .disabled(model.history.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func row(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.panelInk)
                    .lineLimit(1)
                Text(entry.url)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.panelMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(entry.workspace.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(Theme.panelMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            model.navigate(to: entry.url)
            dismiss()
        }
        .contextMenu {
            Button("Remove", role: .destructive) { model.removeHistory(entry) }
        }
    }
}
