import SwiftUI

/// Extensions. iOS is WebKit-only (App Store 2.5.6), so Chromium extensions cannot
/// run here; the phone's equivalent is WebKit content blockers. The panel says
/// exactly that instead of pretending an extension store exists.
struct ExtensionsSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                GlassPane(cornerRadius: 0, plate: true).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.panelMuted)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Brows Ad Blocker")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.panelInk)
                                    Text("\(model.settings.blockAds ? "On" : "Off") · \(model.settings.blockTrackers ? "trackers blocked" : "trackers allowed")")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.panelMuted)
                                }
                                Spacer(minLength: 0)
                                Toggle("", isOn: Binding(
                                    get: { model.settings.blockAds },
                                    set: { model.settings.blockAds = $0; model.saveSettings() }
                                ))
                                .labelsHidden()
                                .tint(Theme.toggleTint)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.rowFill))

                        Text("WEBKIT, NOT CHROMIUM")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(Theme.panelMuted)

                        Text("iPhone apps must use WebKit, so the desktop's Chromium extensions cannot load here. The blocker above is a real WebKit content-rule list; that is the same mechanism Safari extensions use.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.panelMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Extensions")
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
