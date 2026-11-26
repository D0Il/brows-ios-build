import SwiftUI
import UIKit

struct BrowserView: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.scenePhase) private var scenePhase
    /// Observed only for the two probe texts below: `focus` changes on a focus
    /// transition, never on every redraw.
    @ObservedObject private var trace = AddressTrace.shared
    /// The probe counters must be published: a static read would freeze at the
    /// value the rail first laid out with.
    @ObservedObject private var debugCounters = DebugCounters.shared

    /// Which layer is up, as one value per layer. SwiftUI animates a transition
    /// only when the change that inserts or removes the view is animated, and
    /// every panel here is a plain conditional over the page rather than a
    /// presentation. These two values animate every open and close without
    /// animating layout: the dock's own re-flow stays instant, because a tap
    /// that lands during that re-flow is delivered to a view being replaced.
    private var anyPanelOpen: Bool {
        model.showingTabSwitcher || model.showingBookmarks || model.showingHistory
            || model.showingMenu || model.showingWorkspaces || model.showingSiteInfo
            || model.showingDownloads || model.showingPasswords || model.showingExtensions
            || model.showingSettings
    }

    /// The cards over the page: one at a time, all owned by the model.
    private var anyCardOpen: Bool {
        model.showingVoice || model.pendingScriptDialog != nil || model.pendingLinkNotice != nil
            || model.pendingHTTPAuth != nil || model.pendingCredential != nil || model.pageNotice != nil
    }



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
            // A full-screen Liquid Glass layer is far too heavy for a panel and
            // delayed the popup and notice flows (shards 2 and 3, run 44947410477);
            // the panel keeps the app's own pane, the dock and pill keep Apple's.
            .background(
                GlassPane(cornerRadius: 0, plate: true, backdrop: model.panelBackdrop)
                    .ignoresSafeArea()
            )
            // The app has no iOS-blue accent: Done and every other control in a
            // panel uses the desktop's ink, never the system tint.
            .tint(Theme.panelInk)
            // A panel arrives over the page it belongs to: a fade with a tiny rise
            // in scale, never a slide from the side (there is no navigation stack
            // to slide with). Reduce Motion collapses it to one frame in `Motion`.
            //
            // Removal is deliberate and instant. A fading full-screen pane is still
            // on screen and still takes taps, so tapping Done and then the dock's
            // menu button delivered the second tap to the ghost of the first panel
            // (`testRailAndMenuPanels`, both devices, run 45483923747).
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .center)),
                removal: .identity
            ))
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
                    BottomRail()
                }
                Spacer(minLength: 0)
                if model.settings.addressBarBottom {
                    BottomRail()
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
                .transition(.asymmetric(insertion: .opacity, removal: .identity))
            }
        }
        .animation(Motion.panel, value: anyPanelOpen)
        .animation(Motion.card, value: model.showingFind)
        .sheet(item: $model.readerContent) { content in
            ReaderSheet(content: content).environmentObject(model)
        }
        .sheet(item: $model.pdfFile) { file in
            ActivityView(url: file.url)
        }
        .sheet(isPresented: $model.showingScan) {
            CodeScannerSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showingTranslate) {
            TranslateSheet().environmentObject(model)
        }
        .overlay {
            // Both credential surfaces live in the browser's own hierarchy, never in
            // a sheet: a sheet that dismisses can swallow the tap that follows it.
            // Exactly one of them exists at a time.
            //
            // The animation sits on this group, not with the panel's: an overlay is
            // applied after the view it decorates, so a modifier earlier in the
            // chain would not animate a card inserted here.
            Group {
                if model.showingVoice {
                    VoiceSearchCard().environmentObject(model)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)), removal: .identity))
                } else if let dialog = model.pendingScriptDialog {
                    ScriptDialogCard(dialog: dialog).environmentObject(model)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)), removal: .identity))
                } else if let notice = model.pendingLinkNotice {
                    LinkNoticeCard(notice: notice).environmentObject(model)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)), removal: .identity))
                } else if let auth = model.pendingHTTPAuth {
                    HTTPAuthCard(auth: auth).environmentObject(model)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)), removal: .identity))
                } else if let pending = model.pendingCredential {
                    CredentialSaveOverlay(pending: pending).environmentObject(model)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)), removal: .identity))
                } else if let notice = model.pageNotice {
                    PageNoticeCard(notice: notice).environmentObject(model)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)), removal: .identity))
                }
            }
            .animation(Motion.card, value: anyCardOpen)
        }
        // The cards are plates over the page, and a plate without the page's
        // blurred snapshot behind it is a window: the article's letters stay crisp
        // through the .62 fill and compete with the card's own text (dialog-light,
        // notice-light, linknotice-light, suggest-light, auth-light, authsave-light,
        // run 45756292542). Panels snapshot on their own `.onAppear`; the cards did
        // not, and a launch hook presents one before any panel has.
        .onChange(of: anyCardOpen) { open in
            if open { model.refreshPanelBackdrop() }
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
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("audit.downloadfiles")
                    .accessibilityLabel("private \(BrowserModel.downloadFileCount(private: true)) normal \(BrowserModel.downloadFileCount(private: false))")
                if !model.contrastAudit.isEmpty {
                    Text("audit")
                        .scaledFont(1)
                        .opacity(0.01)
                        .accessibilityIdentifier("audit.contrast")
                        .accessibilityLabel(model.contrastAudit)
                }
                // Test-only probe: proves the saved list and the Keychain row agree
                // across a relaunch without exposing any password.
                Text("credentials")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.credentials")
                    .accessibilityLabel("\(model.credentials.count)")
                Text("credentialstate")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.credentialstate")
                    .accessibilityLabel(model.credentialDebug)
                // A link that vanishes and a link that was handed off look the
                // same from inside the page, so the tests read this instead.
                Text("history")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.history")
                    .accessibilityLabel("\(model.history.count)|\(model.history.first?.title ?? "-")")
                Text("lastroute")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.lastroute")
                    .accessibilityLabel(model.lastRoute)
                // The tab gallery is a sheet, so reading the count through it
                // means a sheet sits over the page between taps. The model's tab
                // list is the same fact with nothing in front of the page.
                Text("tabs")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.tabs")
                    .accessibilityLabel("\(model.tabs.count)|\(model.activeTab?.url?.absoluteString ?? "-")")
                // The haptics cannot be felt on a simulator; the moments that ask
                // for one can be counted, and that is what the suite asserts.
                Text("haptics")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.haptics")
                    .accessibilityLabel(debugCounters.haptics)
                // A real touch on a railway control enters the style's pressed
                // branch; the count proves the wash is wired to the finger.
                Text("press")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.press")
                    .accessibilityLabel("\(debugCounters.presses)")
                // The resolved size of the 13 pt chrome token at the current
                // system text size. 13 at the default setting, larger at AX sizes.
                TypeProbe()
                // What the page says it is: mobile or desktop name, light or dark
                // filter, visible consent banners, title. The page tools are proved
                // through this, not through a picture of a button.
                // (The address-pill probes are above this group's own texts.)
                Text("page")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.page")
                    .accessibilityLabel(model.pageProbe.label)
                // The pill's own state: typing needs this field to be first
                // responder, so the tests wait for that fact instead of sleeping
                // and hoping. `focused=1` is set by the field, not by the tap.
                Text("addressfocus")
                    .scaledFont(1)
                    .opacity(0.01)
                    .accessibilityIdentifier("debug.addressfocus")
                    .accessibilityLabel(trace.focus)
                if AddressTrace.enabled {
                    Text("addresstrace")
                        .scaledFont(1)
                        .opacity(0.01)
                        .accessibilityIdentifier("debug.addresstrace")
                        .accessibilityLabel(trace.summary)
                }
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
                // The active tab is the desktop's translucent white pane in
                // both appearances (tab strip order, `.72` white stroke), so
                // its ink is fixed like the dock's: the system glass resolved
                // this chip's whole subtree against the opposite appearance in
                // authsave-light/dark and notice-light (run 45184392996), white
                // text on a white chip, and `GlassPane` is the pane the rest of
                // the chrome already uses.
                Text(model.activeTab?.title ?? "New Tab")
                    .scaledFont(11, .medium)
                    .lineLimit(1)
                    .foregroundColor(Theme.ink)

                if model.activeTab?.isPrivate == true {
                    Text("PRIVATE")
                        .scaledFont(8, .bold)
                        .tracking(1)
                        .foregroundColor(Theme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                // The app's pane, with its fill carrying what the desktop's blur
                // hides. iOS cannot blur the page under a pane: `glassEffect`
                // over a WKWebView draws a flat tint with no page in it
                // (scrolled stills, run 45780486551), and a snapshot backdrop
                // renders nothing visible over the page — a card with one and a
                // card without measured pixel-identical (runs 45762465464 and
                // 45867547477). At the rail band's .30 the article's own line
                // read straight through the chip's title, so the chip's pane is
                // nearly opaque and keeps the ramp and hairline that make it a
                // chip rather than a slab. A non-hit-testing sibling: a glass
                // *background* under these controls took the dock's taps and the
                // pill's focus before (runs 44928536766, 44940653563, 44949151192).
                GlassPane(cornerRadius: 9, paneAlpha: 0.92)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: 230, alignment: .leading)

            Spacer(minLength: 0)

            if let progress = model.activeTab?.progress, model.activeTab?.isLoading == true {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 56)
                    .tint(Theme.panelInk)
                    // The page's own loading state, named for assistive technology
                    // and visible to the UI tests. A cold runner spent 24-31 s
                    // launching WebKit's networking and content processes (run
                    // 45036456881), so the tests must not type a new address until
                    // this element is gone: the submission otherwise waits behind
                    // the launch and the old page's late finish resets the pill.
                    .accessibilityIdentifier("rail.progress")
                    .accessibilityValue("\(Int(progress * 100))%")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

/// The phone dock, not the desktop rail's row. The address pill is the centre;
/// back (and forward, when there is somewhere to go) sits at the leading edge;
/// the two places a thumb actually reaches for — tabs and the menu — sit at the
/// trailing edge, under the hand. Reload, zoom, workspaces and the favourite
/// chips are not pressed often enough to spend dock width on and live in the
/// menu and the sheets instead. Every control is a 44 pt target with room to
/// breathe, and the page runs under the capsule into the home-indicator inset.
struct BottomRail: View {
    @EnvironmentObject var model: BrowserModel
    private var canBack: Bool { model.activeTab?.canGoBack == true }
    private var canForward: Bool { model.activeTab?.canGoForward == true }

    /// The dock spends only the arrows it has. A fixed 96 pt pair left a
    /// fresh tab's pill 163 pt wide and its field 35 pt, so the URL read
    /// `http:…` under every non-editing capture of run 45177700804 (auth,
    /// dialog, notice, linknotice and the plain article shot). With no
    /// arrows the pill takes those 96 pt; with one it takes 44. The tabs and
    /// the menu stay pinned to the trailing edge — the pill is the flexible
    /// child — so a workspace switch never moves them under a thumb.
    private var navSlotWidth: CGFloat {
        if model.isEditingAddress { return 0 }
        switch (canBack, canForward) {
        case (true, true): return 96
        case (false, false): return 0
        default: return 44
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // The slots are always there, even when there is nowhere to go. A
            // workspace switch changes canGoBack/canGoForward, and with the old
            // conditional buttons the whole row re-flowed under a thumb that was
            // already on its way down: the tap landed in the slot the menu button
            // had occupied a frame earlier and did nothing (trace, shard 2,
            // run 44956470184: tap synthesized, app idle, no panel).
            // While the address is being typed the pill takes the whole dock,
            // the way a phone browser's editing bar does: at 26 pt the field
            // showed only `http:/` and at 50 pt only `://locall` — never the
            // host (captures pill-light/dark, runs 45095272714 and 45100747363).
            // The slots come back on blur. Workspace switches still keep their
            // fixed slots, which is the re-flow that mattered (run 44956470184);
            // focusing is not a workspace switch and the field is the tap target.
            // The slots stay in the tree while editing and collapse to zero
            // width, rather than being removed: an `if` around a sibling changes
            // the HStack's child structure, which rebuilt the AddressField and
            // dropped first responder mid-typing. Three address-pill navigations
            // then stayed on the start page ("SEARCH") in run 45168968759
            // (testDockKeepsTabsAndMenuAfterThePill, testFindInPage,
            // testHistoryListsVisitedPagesAndRemovesOne).
            // The group also closes to the arrows it has, so a tab with no
            // history hands its 96 pt to the pill instead of to empty glass.
            HStack(spacing: canBack && canForward ? 8 : 0) {
                if canBack {
                    railButton("chevron.left", id: "rail.back", label: "Back") { model.goBack() }
                } else {
                    Color.clear.frame(width: 0, height: 44)
                }
                if canForward {
                    railButton("chevron.right", id: "rail.forward", label: "Forward") { model.goForward() }
                } else {
                    Color.clear.frame(width: 0, height: 44)
                }
            }
            .frame(width: navSlotWidth, height: 44)
            .clipped()
            .opacity(navSlotWidth == 0 ? 0 : 1)
            .allowsHitTesting(navSlotWidth > 0)
            .accessibilityHidden(navSlotWidth == 0)

            HStack(spacing: 6) {
                Button {
                    model.loadSiteInfo()
                    model.showingSiteInfo = true
                } label: {
                    SiteBadge(host: model.activeHost)
                }
                .buttonStyle(.plain)
                // The lock glyph was the button's whole name. Name the panel it
                // opens; the host is the value, not the label, so VoiceOver does
                // not read "Lock" for a control that shows site information.
                .accessibilityLabel("Site information")
                .accessibilityValue(model.activeHost ?? "")
                .accessibilityIdentifier("rail.siteInfo")
                .frame(width: model.isEditingAddress ? 0 : 26, height: 26)
                .clipped()
                .opacity(model.isEditingAddress ? 0 : 1)
                .allowsHitTesting(!model.isEditingAddress)
                .accessibilityHidden(model.isEditingAddress)

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

                // Reload/stop is a primary bar control in every mobile browser, not a
                // menu row. Chromium's own toolbar spec lists Reload beside Back/Forward
                // and its toolbar manager owns stopOrReloadCurrentTab; Chrome's Android
                // bar keeps it one tap away, Vivaldi puts Reload on the address bar, and
                // Safari's bottom address bar carries the reload button inside it.
                Button {
                    model.reloadOrStop()
                } label: {
                    Image(systemName: model.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise")
                        .scaledFont(13, .semibold)
                        .foregroundColor(Theme.ink)
                }
                .buttonStyle(.plain)
                // The glyph is small like an in-field control; the target is the pill's
                // full height and a thumb's width, so reload is not a lucky tap.
                .frame(width: 34, height: 40)
                .contentShape(Rectangle())
                .accessibilityLabel(model.activeTab?.isLoading == true ? "Stop" : "Reload")
                .accessibilityIdentifier("rail.reload")

                // While the address is being typed the star closes with it: the
                // 34 pt its slot was keeping is what the URL needs to fit whole
                // (the pill capture read `article.h…` with the slot held open,
                // run 45184392996). The field grows into that space and no
                // control appears under the focusing tap. Nothing is inserted
                // or removed: the button stays in the tree for the pill's whole
                // life, named `rail.star.typing`, hidden from VoiceOver and out
                // of the hit test while editing, so the field's UIView and its
                // first responder survive the state change.
                Button {
                    model.toggleBookmark()
                } label: {
                    Image(systemName: model.isBookmarked(model.currentURL()) ? "star.fill" : "star")
                        .scaledFont(14, .semibold)
                        .foregroundColor(Theme.ink)
                }
                .buttonStyle(.plain)
                .frame(width: 34, height: 40)
                .contentShape(Rectangle())
                .opacity(model.isEditingAddress ? 0 : 1)
                .allowsHitTesting(!model.isEditingAddress)
                .accessibilityHidden(model.isEditingAddress)
                .accessibilityIdentifier(model.isEditingAddress ? "rail.star.typing" : "rail.star")
                .accessibilityValue(model.isBookmarked(model.currentURL()) ? "bookmarked" : "not bookmarked")
                .frame(width: model.isEditingAddress ? 0 : 34, height: 40)
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            // 96, not 126: a floating capsule spends ~32 pt of row width on its own
            // margins, and at 126 the row overflowed and squeezed the field's tap
            // target (runs 44928536766, 44930532421, 44931912138).
            .frame(minWidth: 96, maxWidth: .infinity)
            // Glass, not a white plate: nothing in this rail may paint a white
            // slab over the page. The pane is a background layer, so it never sees
            // the field's taps; focusing the field only brightens the rim.
            .background(GlassPane(cornerRadius: Theme.pillRadius))
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

            Button {
                model.showingTabSwitcher = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "square.on.square")
                    Text("\(model.tabs.count)").scaledFont(12, .bold)
                }
            }
            .buttonStyle(GlassCircleButtonStyle(glyph: Theme.ink))
            // Tabs and the menu are the two destinations a thumb reaches without
            // moving the hand, so they sit last, nearest the trailing edge.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Tabs")
            .accessibilityValue("\(model.tabs.count) open")
            .accessibilityIdentifier("rail.tabs")

            Button {
                model.openMenu()
            } label: {
                Image(systemName: "line.3.horizontal")
            }
            .buttonStyle(GlassCircleButtonStyle(glyph: Theme.ink))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Menu")
            .accessibilityIdentifier("rail.menu")
        }
        // No implicit animation on canBack or the tab count: both re-lay the dock
        // out, and a tap that lands during that animation is delivered to a view
        // that is being replaced (the "menu did not open" signature across runs
        // 44928536766, 44956470184, 45026104953).
        // One floating capsule over the page: the page keeps running underneath it
        // and into the home-indicator inset.
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        // The app's pane, not `glassEffect`: every run with the system glass under
        // these controls lost their taps (typing focus, a menu that never opened —
        // runs 44928536766, 44940653563, 44949151192). The pane is the proven layer.
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
        // Only the appearance and disappearance of the card is animated; rows
        // arriving while the user types keep the card anchored, and the dock's
        // layout is never animated.
        .animation(Motion.card, value: model.suggestions.isEmpty)
    }

    @ViewBuilder private var completions: some View {
        if model.isEditingAddress && !model.suggestions.isEmpty {
            let shift = CGFloat(model.suggestions.count) * 52 + 16
            AddressSuggestionsPanel(
                backdropOffset: CGSize(width: 0, height: model.settings.addressBarBottom ? -shift : shift)
            )
            .environmentObject(model)
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)), removal: .identity))
            .frame(height: CGFloat(model.suggestions.count) * 52 + 8)
        }
    }

    private func railButton(_ symbol: String, id: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(GlassCircleButtonStyle(glyph: Theme.ink))
        // The plate stays 36 pt; the target is 44, so the capsule's breathing room
        // is part of the button rather than dead glass.
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

/// Reports the type size the chrome actually resolves for a 13 pt token, at
/// whatever text size the system is set to.
private struct TypeProbe: View {
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        Text("type")
            .scaledFont(1)
            .opacity(0.01)
            .accessibilityIdentifier("debug.type")
            .accessibilityLabel("\(ScaledFont.size(13, category: sizeCategory))")
    }
}
