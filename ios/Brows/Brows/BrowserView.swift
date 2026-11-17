import SwiftUI
import UIKit

struct BrowserView: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.scenePhase) private var scenePhase

    private var compactRail: Bool { UIScreen.main.bounds.width < 430 }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.backdrop.ignoresSafeArea()

            // The page runs full-bleed under the chrome, so the tab pane and the
            // rail are glass over the page — the desktop treatment — rather than
            // translucent bars sitting on an app background.
            page.ignoresSafeArea()

            VStack(spacing: 0) {
                TopStrip()
                if !model.settings.addressBarBottom {
                    BottomRail(compact: compactRail)
                }
                Spacer(minLength: 0)
                if model.settings.addressBarBottom {
                    BottomRail(compact: compactRail)
                }
            }

            if model.showingFind {
                VStack {
                    Spacer()
                    FindBar()
                        .padding(.bottom, model.settings.addressBarBottom ? 70 : 8)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $model.showingTabSwitcher) {
            TabSwitcher().environmentObject(model)
        }
        .sheet(isPresented: $model.showingBookmarks) {
            BookmarksSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showingHistory) {
            HistorySheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showingMenu) {
            AppMenu().environmentObject(model)
        }
        .sheet(isPresented: $model.showingWorkspaces) {
            WorkspacesSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showingSiteInfo) {
            SiteInfoSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showingDownloads) {
            DownloadsSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showingPasswords) {
            PasswordsSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showingExtensions) {
            ExtensionsSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showingSettings) {
            SettingsSheet().environmentObject(model)
        }
        .sheet(item: $model.readerContent) { content in
            ReaderSheet(content: content).environmentObject(model)
        }
        .sheet(item: $model.pdfFile) { file in
            ActivityView(url: file.url)
        }
        .alert("Save password?", isPresented: Binding(
            get: { model.pendingCredential != nil },
            set: { if !$0 { model.discardPendingCredential() } }
        )) {
            Button("Save") { model.confirmPendingCredential() }
            Button("Not now", role: .cancel) { model.discardPendingCredential() }
        } message: {
            if let pending = model.pendingCredential {
                Text("Save the password for \(pending.username.isEmpty ? pending.host : pending.username) on \(pending.host)?")
            }
        }
        .alert("Reader mode", isPresented: $model.readerFailed) {
            Button("OK", role: .cancel) { model.readerFailed = false }
        } message: {
            Text("This page has no article text to show in Reader.")
        }
        .onChange(of: model.showingMenu) { open in
            if !open {
                // A sheet cannot present while the menu sheet is still dismissing;
                // presenting on the next runloop drops the panel now and then.
                // Wait out the dismissal animation, then open the queued panel.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    model.openPendingPanel()
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { model.save() }
        }
        // The desktop follows the system (brows_surface.css has a light base and a
        // prefers-color-scheme: dark block); the phone does too. The launch argument
        // pins one appearance for the screenshot pass only.
        .preferredColorScheme(model.launchAppearance == "light" ? .light
                              : model.launchAppearance == "dark" ? .dark : nil)
        .overlay(alignment: .topLeading) {
            if !model.contrastAudit.isEmpty {
                Text("audit")
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .accessibilityIdentifier("audit.contrast")
                    .accessibilityLabel(model.contrastAudit)
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        if let tab = model.activeTab {
            WebViewContainer(tabId: tab.id, model: model)
                .id(tab.id)
                .background(Color.black)
        } else {
            Spacer()
        }
    }
}

/// The phone's stand-in for the desktop tab strip: which workspace you are in,
/// the PRIVATE badge when the active tab is private, and page progress.
struct TopStrip: View {
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        HStack(spacing: 8) {
            // The desktop tab strip's job, at phone scale: the active tab is one
            // translucent glass pane with a .72 white stroke over the page, not a
            // full-width slab. The workspace is the rail button, not a label here.
            HStack(spacing: 7) {
                Text(model.activeTab?.title ?? "New Tab")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(Theme.ink)

                if model.activeTab?.isPrivate == true {
                    Text("PRIVATE")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Theme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.tabActiveTop, Theme.tabActiveBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.tabBorder, lineWidth: 1)
            )
            .frame(maxWidth: 230, alignment: .leading)

            Spacer(minLength: 0)

            if let progress = model.activeTab?.progress, model.activeTab?.isLoading == true {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 56)
                    .tint(Theme.ink)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

/// The toolbar rail, in the desktop order: page controls → white address pill
/// (glass site badge, SEARCH field, star) → favourite chips in the same row →
/// browser actions → workspace button → menu. Back/forward exist only when there
/// is somewhere to go, and there is no home button. On a narrow phone the zoom
/// cluster and reload fold away exactly as the desktop strip folds them; they stay
/// reachable from the menu.
struct BottomRail: View {
    @EnvironmentObject var model: BrowserModel
    var compact: Bool = false

    private var canBack: Bool { model.activeTab?.canGoBack == true }
    private var canForward: Bool { model.activeTab?.canGoForward == true }

    private var chipWidth: CGFloat {
        if canBack || canForward { return 46 }
        return compact ? 92 : 150
    }

    /// On a narrow phone the zoom cluster folds into the menu (the desktop strip
    /// folds it too). Reload stays in the row, because it is the control you reach
    /// for constantly and the pill needs its width more than the cluster does.
    private var showZoom: Bool { !compact }

    var body: some View {
        HStack(spacing: 6) {
            if canBack {
                railButton("chevron.left", id: "rail.back") { model.goBack() }
            }
            if canForward {
                railButton("chevron.right", id: "rail.forward") { model.goForward() }
            }

            // Desktop order, 45-mobile-research: the page controls (back, forward,
            // reload/stop) stay together at the rail's leading edge, before the
            // pill. Reload is a page control, not a trailing browser action.
            railButton(model.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise", id: "rail.reload") {
                model.reloadOrStop()
            }

            HStack(spacing: 6) {
                Button {
                    model.loadSiteInfo()
                    model.showingSiteInfo = true
                } label: {
                    SiteBadge(host: model.activeHost)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rail.siteInfo")

                AddressField(
                    text: $model.addressText,
                    onSubmit: { input in
                        model.isEditingAddress = false
                        model.navigate(to: input)
                    },
                    onFocus: { model.isEditingAddress = true },
                    onBlur: { model.isEditingAddress = false },
                    autoFocus: model.focusPillOnLaunch
                )
                .frame(maxWidth: .infinity)
                .frame(height: 24)

                Button {
                    model.toggleBookmark()
                } label: {
                    Image(systemName: model.isBookmarked(model.currentURL()) ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.ink)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rail.star")
                .accessibilityValue(model.isBookmarked(model.currentURL()) ? "bookmarked" : "not bookmarked")
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(minWidth: 126)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                        .fill(model.isEditingAddress ? Theme.pillFocusWash : Theme.pillWash)
                    RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: model.isEditingAddress
                                    ? [Theme.pillFocusTop, Theme.pillFocusBottom]
                                    : [Theme.pillTop, Theme.pillBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                    .stroke(model.isEditingAddress ? Theme.pillFocusBorder : Theme.pillBorder, lineWidth: 1)
            )
            // location_bar.css:29-31 — inset 0 1px 0 rgba(255,255,255,.42),
            // inset 0 -1px 0 rgba(47,58,75,.045), 0 1px 5px rgba(38,47,61,.035).
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                    .stroke(Theme.pillInnerTop, lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.25)
                        )
                    )
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                    .stroke(Theme.pillInnerBottom, lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .white],
                            startPoint: UnitPoint(x: 0.5, y: 0.75),
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: Theme.pillDrop, radius: 5, x: 0, y: 1)
            .layoutPriority(2)

            if !model.bookmarks.isEmpty {
                // The strip is a real tap target, not a squeezed label: give it a
                // floor width and priority above the trailing controls, otherwise
                // the pill's minWidth pushes it into a clipped, unhittable sliver.
                BookmarksStrip()
                    .frame(minWidth: 56, maxWidth: chipWidth)
                    .layoutPriority(1)
            }

            if showZoom {
                zoomCluster
            }

            Button {
                model.showingWorkspaces = true
            } label: {
                Text(model.activeWorkspace?.initials ?? "M")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
            }
            .buttonStyle(GlassCircleButtonStyle())
            .accessibilityIdentifier("rail.workspace")
            .accessibilityValue(model.activeWorkspace?.name ?? "")

            Button {
                model.showingTabSwitcher = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "square.on.square")
                    Text("\(model.tabs.count)").font(.system(size: 12, weight: .bold))
                }
            }
            .buttonStyle(GlassCircleButtonStyle())
            .accessibilityIdentifier("rail.tabs")

            Button {
                model.showingMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
            }
            .buttonStyle(GlassCircleButtonStyle())
            .accessibilityIdentifier("rail.menu")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(GlassPane().ignoresSafeArea(edges: model.settings.addressBarBottom ? .bottom : .top))
        // app.css: the band's own `border-top: 1px rgba(72,84,102,.07)` and
        // `inset 0 -1px 0 rgba(67,78,96,.14)` edge the glass without filling it.
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(red: 72 / 255, green: 84 / 255, blue: 102 / 255).opacity(0.07))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 67 / 255, green: 78 / 255, blue: 96 / 255).opacity(0.14))
                .frame(height: 1)
        }
    }

    /// Zoom cluster, same fold as the desktop strip: −, the % is the reset, +.
    private var zoomCluster: some View {
        HStack(spacing: 3) {
            Button { model.adjustZoom(by: -0.1) } label: {
                Image(systemName: "minus").font(.system(size: 11, weight: .bold))
            }
            Button { model.resetZoom() } label: {
                Text("\(Int(((model.activeTab?.zoom ?? 1) * 100).rounded()))%")
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            Button { model.adjustZoom(by: 0.1) } label: {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
            }
        }
        .buttonStyle(CompactControlStyle())
        .foregroundColor(Theme.muted)
    }

    private func railButton(_ symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(GlassCircleButtonStyle())
        .accessibilityIdentifier(id)
    }
}

/// Small square glass control for the folded cluster.
struct CompactControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 30, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.7 : 0.9))
            )
    }
}
