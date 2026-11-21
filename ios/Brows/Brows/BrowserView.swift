import SwiftUI
import UIKit

struct BrowserView: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.scenePhase) private var scenePhase

    private var compactRail: Bool { UIScreen.main.bounds.width < 430 }

    /// A desktop-style popup: the panel itself, over the page, with the close
    /// action its Done button and rows call.
    ///
    /// This background is the panel's one and only plate. A panel must not paint
    /// a second `GlassPane` of its own: two 0.62 plates stack and a dark pane over
    /// a white page lands near 66 instead of the desktop's 118 — a fat slab again.
    @ViewBuilder
    private func panel<V: View>(_ content: V, close: @escaping () -> Void) -> some View {
        content
            .environmentObject(model)
            .environment(\.panelDismiss, close)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                GlassPane(cornerRadius: 0, plate: true, backdrop: model.panelBackdrop)
                    .ignoresSafeArea()
            )
            .transition(.opacity)
            .zIndex(2)
            .onAppear { model.refreshPanelBackdrop() }
    }

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

            // The desktop's popups are panels over the page, never presentations in
            // their own window: a sheet's backdrop is opaque, so its glass has
            // nothing to be see-through to. These are the same panels, in the
            // browser's own hierarchy, over the page they belong to.
            if model.showingTabSwitcher {
                panel(TabSwitcher()) { model.showingTabSwitcher = false }
            }
            if model.showingBookmarks {
                panel(BookmarksSheet()) { model.showingBookmarks = false }
            }
            if model.showingHistory {
                panel(HistorySheet()) { model.showingHistory = false }
            }
            if model.showingMenu {
                panel(AppMenu()) { model.showingMenu = false }
            }
            if model.showingWorkspaces {
                panel(WorkspacesSheet()) { model.showingWorkspaces = false }
            }
            if model.showingSiteInfo {
                panel(SiteInfoSheet()) { model.showingSiteInfo = false }
            }
            if model.showingDownloads {
                panel(DownloadsSheet()) { model.showingDownloads = false }
            }
            if model.showingPasswords {
                panel(PasswordsSheet()) { model.showingPasswords = false }
            }
            if model.showingExtensions {
                panel(ExtensionsSheet()) { model.showingExtensions = false }
            }
            if model.showingSettings {
                panel(SettingsSheet()) { model.showingSettings = false }
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
        .sheet(item: $model.readerContent) { content in
            ReaderSheet(content: content).environmentObject(model)
        }
        .sheet(item: $model.pdfFile) { file in
            ActivityView(url: file.url)
        }
        .overlay {
            // Both credential surfaces live in the browser's own hierarchy, never in
            // a sheet: a sheet that dismisses can swallow the tap that follows it.
            // Exactly one of them exists at a time.
            if let dialog = model.pendingScriptDialog {
                ScriptDialogCard(dialog: dialog).environmentObject(model)
            } else if let notice = model.pendingLinkNotice {
                LinkNoticeCard(notice: notice).environmentObject(model)
            } else if let auth = model.pendingHTTPAuth {
                HTTPAuthCard(auth: auth).environmentObject(model)
            } else if let pending = model.pendingCredential {
                CredentialSaveOverlay(pending: pending).environmentObject(model)
            } else if let notice = model.pageNotice {
                PageNoticeCard(notice: notice).environmentObject(model)
            }
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
            VStack(spacing: 0) {
                // Test-only probe: the two download directories by file count, so a
                // relaunch can prove a private file was swept and a normal one stayed.
                Text("downloads")
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .accessibilityIdentifier("audit.downloadfiles")
                    .accessibilityLabel("private \(BrowserModel.downloadFileCount(private: true)) normal \(BrowserModel.downloadFileCount(private: false))")
                if !model.contrastAudit.isEmpty {
                    Text("audit")
                        .font(.system(size: 1))
                        .opacity(0.01)
                        .accessibilityIdentifier("audit.contrast")
                        .accessibilityLabel(model.contrastAudit)
                }
                // Test-only probe: proves the saved list and the Keychain row agree
                // across a relaunch without exposing any password.
                Text("credentials")
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.credentials")
                    .accessibilityLabel("\(model.credentials.count)")
                Text("credentialstate")
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.credentialstate")
                    .accessibilityLabel(model.credentialDebug)
                // A link that vanishes and a link that was handed off look the
                // same from inside the page, so the tests read this instead.
                Text("history")
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.history")
                    .accessibilityLabel("\(model.history.count)|\(model.history.first?.title ?? "-")")
                Text("lastroute")
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.lastroute")
                    .accessibilityLabel(model.lastRoute)
                // The tab gallery is a sheet, so reading the count through it
                // means a sheet sits over the page between taps. The model's tab
                // list is the same fact with nothing in front of the page.
                Text("tabs")
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.tabs")
                    .accessibilityLabel("\(model.tabs.count)|\(model.activeTab?.url?.absoluteString ?? "-")")
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
                    .foregroundColor(Theme.panelInk)

                if model.activeTab?.isPrivate == true {
                    Text("PRIVATE")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Theme.panelMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .browsGlass(cornerRadius: 9)
            .frame(maxWidth: 230, alignment: .leading)

            Spacer(minLength: 0)

            if let progress = model.activeTab?.progress, model.activeTab?.isLoading == true {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 56)
                    .tint(Theme.panelInk)
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
                // The pill is 40 pt; a 24 pt field put the selection handles on the
                // rail outside the plate. The field takes the pill's inner height.
                .frame(height: 34)

                Button {
                    model.toggleBookmark()
                } label: {
                    Image(systemName: model.isBookmarked(model.currentURL()) ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.plateInk)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rail.star")
                .accessibilityValue(model.isBookmarked(model.currentURL()) ? "bookmarked" : "not bookmarked")
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            // 96, not 126: a floating capsule spends ~32 pt of row width on its own
            // margins, and at 126 the row overflowed and squeezed the field's tap
            // target (runs 44928536766, 44930532421, 44931912138).
            .frame(minWidth: 96)
            .background(
                ZStack {
                    // The desktop rail's omnibox is a solid white pill; the glass
                    // gradient rides on that plate. On the phone the rail floats
                    // over the page, so without the plate the address and the
                    // selection handles sat directly on article text.
                    RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                        .fill(model.isEditingAddress ? Color.white : Color.white.opacity(0.95))
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

            if !model.bookmarks.isEmpty && !model.isEditingAddress {
                // Typing owns the row: the favourites fold away so the full address
                // is visible, and return on blur. They are never on a second row.
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
        // The dock is a floating glass pill over the page, not a full-width band:
        // the controls keep the desktop order inside one continuous capsule, and
        // the page keeps running underneath it and into the home-indicator inset.
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        // GlassPane, not `.glassEffect`: the system glass layer under these controls
        // swallowed the pill's focus (no keyboard, run 44930532421), which is the
        // same failure the menu buttons hit — glass never sits on or under a control.
        .background(
            GlassPane(cornerRadius: 28)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        // The pill's completions ride on the rail and are pushed clear of it by
        // their own height. An overlay is drawn on top and is not squeezed by the
        // page's stack, which is what had put the last row under the glass.
        .overlay(alignment: .top) {
            if model.settings.addressBarBottom {
                completions.offset(y: -(CGFloat(model.suggestions.count) * 52 + 16))
            }
        }
        .overlay(alignment: .bottom) {
            if !model.settings.addressBarBottom {
                completions.offset(y: CGFloat(model.suggestions.count) * 52 + 16)
            }
        }
    }

    @ViewBuilder private var completions: some View {
        if model.isEditingAddress && !model.suggestions.isEmpty {
            let shift = CGFloat(model.suggestions.count) * 52 + 16
            AddressSuggestionsPanel(
                backdropOffset: CGSize(width: 0, height: model.settings.addressBarBottom ? -shift : shift)
            )
            .environmentObject(model)
            .frame(height: CGFloat(model.suggestions.count) * 52 + 8)
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
        .foregroundColor(Theme.panelMuted)
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
