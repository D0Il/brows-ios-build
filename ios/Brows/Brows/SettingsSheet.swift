import SwiftUI

/// Settings, in the desktop's groups: appearance, search, privacy, data, about.
struct SettingsSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss

    @State private var cleared = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.ignoresSafeArea().browsGlass(cornerRadius: 0)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        section("Appearance") {
                            ToggleRow(title: "Address bar at the bottom", subtitle: "Safari, Chrome and Opera all default to this", isOn: Binding(
                                get: { model.settings.addressBarBottom },
                                set: { model.settings.addressBarBottom = $0; model.saveSettings() }
                            ), identifier: "settings.addressBarBottom")
                        }

                        section("Search") {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Search engine", selection: Binding(
                                    get: { model.settings.searchEngine },
                                    set: { model.settings.searchEngine = $0; model.saveSettings() }
                                )) {
                                    ForEach(SearchEngine.allCases) { engine in
                                        Text(engine.name).tag(engine)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))
                        }

                        section("Privacy") {
                            ToggleRow(title: "Block ads", subtitle: "WebKit content rules", isOn: Binding(
                                get: { model.settings.blockAds },
                                set: { model.settings.blockAds = $0; model.saveSettings() }
                            ))
                            ToggleRow(title: "Block trackers", subtitle: "Third-party requests to known trackers", isOn: Binding(
                                get: { model.settings.blockTrackers },
                                set: { model.settings.blockTrackers = $0; model.saveSettings() }
                            ))
                            ToggleRow(title: "Restore tabs on launch", subtitle: "Off starts with one blank tab", isOn: Binding(
                                get: { model.settings.restoreSession },
                                set: { model.settings.restoreSession = $0; model.saveSettings() }
                            ))
                        }

                        section("Data") {
                            Button {
                                model.clearWebsiteData { cleared = true }
                            } label: {
                                HStack {
                                    Text("Clear history, cookies and site data")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.panelInk)
                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.plateBase.opacity(0.9)))
                            }
                            .buttonStyle(.plain)
                            if cleared {
                                Text("Cleared.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.panelMuted)
                            }
                        }

                        section("About") {
                            infoRow("Brows", model.appVersion)
                            infoRow("Engine", "WebKit (WKWebView)")
                            infoRow("Desktop build", "Chromium fork, Windows")
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// `.settings-group` in `brows_surface.css`: a card of `rgba(plate,.59)`, a `.74` rim, radius 14,
    /// 12 px of padding and a `0 4px 13px` lift; its title is 13 px at weight 720 in the panel ink,
    /// sentence case — not the muted, tracked capitals a plain iOS form would use.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.panelInk)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.plateBase.opacity(0.59)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.glassStroke, lineWidth: 1))
        .shadow(color: Color(red: 37 / 255, green: 47 / 255, blue: 60 / 255).opacity(0.09), radius: 6.5, x: 0, y: 4)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Theme.panelMuted)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.panelInk)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var identifier: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                                    .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.panelInk)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.panelMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.toggleTint)
                .accessibilityIdentifier(identifier ?? "settings.toggle.\(title)")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.rowFill))
    }
}
