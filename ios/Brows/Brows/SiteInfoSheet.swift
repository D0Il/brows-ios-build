import SwiftUI

/// Site information, the desktop panel's phone form: connection, cookies,
/// storage, what the page loaded, blocked requests, and per-site data clearing.
struct SiteInfoSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.ignoresSafeArea().browsGlass(cornerRadius: 0)

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
                                    .font(.system(size: 14, weight: .semibold))
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
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.plateInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .panelButtonPlate(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("No page loaded.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.panelMuted)
                                .padding(.top, 24)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Site information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { model.loadSiteInfo() }
        }
        .navigationViewStyle(.stack)
    }

    private func header(_ info: SiteInfo) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.rowFill)
                Image(systemName: info.scheme == "https:" ? "lock.fill" : "exclamationmark.triangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.panelMuted)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(info.host)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.panelInk)
                Text(info.scheme == "https:" ? "Connection is encrypted" : "Connection is not encrypted")
                    .font(.system(size: 11))
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
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.57)
                .foregroundColor(Theme.panelMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.bottom, 3)

            ForEach(rows, id: \.0) { pair in
                HStack(spacing: 10) {
                    Text(pair.0)
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.panelInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(pair.1)
                        .font(.system(size: 10.5))
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
