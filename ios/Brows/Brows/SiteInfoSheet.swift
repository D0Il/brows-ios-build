import SwiftUI

/// Site information, the desktop panel's phone form: connection, cookies,
/// storage, what the page loaded, blocked requests, and per-site data clearing.
struct SiteInfoSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.panelDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PanelBar(title: "Site information") {
                Button("Done") { dismiss() }
            }
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let info = model.siteInfo {
                            header(info)
                            group("CONNECTION", rows: [
                                ("Scheme", info.scheme == "https:" ? "HTTPS — encrypted" : info.scheme),
                                ("Host", info.host),
                                ("Path", info.path)
                            ], first: true)
                            group("STORAGE", rows: [
                                ("Cookies", "\(info.cookies) readable"),
                                ("localStorage", byteString(info.localStorageBytes)),
                                ("sessionStorage", byteString(info.sessionStorageBytes)),
                                ("Service workers", "\(info.serviceWorkers)")
                            ])
                            group("PAGE", rows: [
                                ("Scripts", "\(info.scripts)"),
                                ("Images", "\(info.images)"),
                                ("Ad blocking", model.settings.blockAds ? "On" : "Off")
                            ])
                            group("PERMISSIONS", rows: [
                                ("Camera", "asked when a site requests it"),
                                ("Microphone", "asked when a site requests it"),
                                ("Location", "asked when a site requests it"),
                                ("JavaScript", "on")
                            ])

                            Button {
                                model.toggleBlockingForCurrentSite()
                                model.loadSiteInfo()
                            } label: {
                                Text(model.isBlockingCurrentSite() ? "Turn off blocking on this site" : "Turn on blocking on this site")
                                    .scaledFont(14, .semibold)
                                    .foregroundColor(Theme.plateInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .panelButtonPlate(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)

                            Button {
                                model.clearSiteData(for: info.host)
                            } label: {
                                Text("Clear data for \(info.host)")
                                    .scaledFont(14, .semibold)
                                    .foregroundColor(Theme.plateInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .panelButtonPlate(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("No page loaded.")
                                .scaledFont(13)
                                .foregroundColor(Theme.panelMuted)
                                .padding(.top, 24)
                        }
                    }
                    .padding(16)
                }
            }
            .onAppear { model.loadSiteInfo() }
        }
    }

    private func header(_ info: SiteInfo) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.rowFill)
                Image(systemName: info.scheme == "https:" ? "lock.fill" : "exclamationmark.triangle")
                    .scaledFont(15, .semibold)
                    .foregroundColor(Theme.panelMuted)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(info.host)
                    .scaledFont(16, .semibold)
                    .foregroundColor(Theme.panelInk)
                Text(info.scheme == "https:" ? "Connection is encrypted" : "Connection is not encrypted")
                    .scaledFont(11)
                    .foregroundColor(Theme.panelMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.rowFill))
    }

    /// `.siteinfo-section`: no well and no rounded card — a 1 px rule above the section, a
    /// 9.5 px weight-660 uppercase head at `.06em`, then 11.5 px rows with the value muted at
    /// 10.5 px on the right (`brows_surface.css:2191-2230`).
    private func group(_ title: String, rows: [(String, String)], first: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .scaledFont(9.5, .semibold)
                .tracking(0.57)
                .foregroundColor(Theme.panelMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.bottom, 3)

            ForEach(rows, id: \.0) { pair in
                HStack(spacing: 10) {
                    Text(pair.0)
                        .scaledFont(11.5)
                        .foregroundColor(Theme.panelInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(pair.1)
                        .scaledFont(10.5)
                        .foregroundColor(Theme.panelMuted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, first ? 2 : 7)
        .padding(.bottom, 4)
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(Theme.sectionRule).frame(height: 1)
            }
        }
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
