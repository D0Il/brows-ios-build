import SwiftUI

/// Settings, in the desktop's groups: appearance, search, privacy, data, about.
struct SettingsSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss

    @State private var cleared = false

    var body: some View {
        VStack(spacing: 0) {
            PanelBar(title: "Settings") {
                Button("Done") { dismiss() }
            }
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        section("Appearance") {
                            ToggleRow(title: "Address bar at the bottom", subtitle: "Safari, Chrome and Opera all default to this", isOn: Binding(
                                get: { model.settings.addressBarBottom },
                                set: { model.settings.addressBarBottom = $0; model.saveSettings() }
                            ), identifier: "settings.addressBarBottom")
                        }

                        section("Search") {
                            // `.settings-select` (`brows_surface.css:636-650`): the label and its
                            // note stack above a 34 px field with a `.66` plate fill, a
                            // `rgba(72,83,97,.17)` rim and radius 9. The desktop draws a select,
                            // not a segmented control.
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Search engine")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.panelInk)
                                Text("Used by the pill when you type words")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.panelMuted)
                                Menu {
                                    ForEach(SearchEngine.allCases) { engine in
                                        Button(engine.name) {
                                            model.settings.searchEngine = engine
                                            model.saveSettings()
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(model.settings.searchEngine.name)
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.panelInk)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(Theme.panelMuted)
                                    }
                                    .padding(.horizontal, 10)
                                    .frame(height: 34)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.plateBase.opacity(0.66)))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(
                                        Color(red: 72 / 255, green: 83 / 255, blue: 97 / 255).opacity(0.17),
                                        lineWidth: 1
                                    ))
                                }
                                .accessibilityIdentifier("settings.searchEngine")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                            ToggleRow(title: "Block cookie banners", subtitle: "Hides the consent banner a site puts over its own page", isOn: Binding(
                                get: { model.settings.blockCookieBanners },
                                set: { _ in model.toggleCookieBanners() }
                            ), identifier: "settings.blockCookieBanners")
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
                                .padding(.vertical, 6)
                                .padding(.horizontal, 7)
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
        }
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
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.rowFill))
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
        .padding(.vertical, 6)
        .padding(.horizontal, 7)
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var identifier: String? = nil

    var body: some View {
        // `.settings-toggle`: an 18 px gutter holding a 14×14 checkbox with `margin-top: 2px`,
        // then the copy — the desktop draws a checkbox, not an iOS switch
        // (`brows_surface.css:590-600`). The Toggle keeps the switch accessibility role the
        // suite asserts while the body draws the desktop control.
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.panelInk)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.panelMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(DesktopCheckboxStyle())
        .accessibilityIdentifier(identifier ?? "settings.toggle.\(title)")
    }
}

/// The desktop's checkbox: a 14×14 rounded square, `.settings-toggle input`
/// (`brows_surface.css:596-600`), filled with `--accent` when on.
struct DesktopCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(configuration.isOn ? Theme.toggleTint : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(configuration.isOn ? Theme.toggleTint : Theme.glassStroke, lineWidth: 1))
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(configuration.isOn ? 1 : 0)
                )
                .frame(width: 14, height: 14)
                .padding(.top, 2)
                .contentShape(Rectangle())
                .onTapGesture { configuration.isOn.toggle() }
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}
