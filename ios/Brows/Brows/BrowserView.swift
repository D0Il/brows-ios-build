import SwiftUI
import UIKit

struct BrowserView: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.scenePhase) private var scenePhase

    private var compactRail: Bool { UIScreen.main.bounds.width < 430 }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.backdrop.ignoresSafeArea()

            if model.settings.addressBarBottom {
                VStack(spacing: 0) {
                    TopStrip()
                    page
                    BottomRail(compact: compactRail)
                }
            } else {
                VStack(spacing: 0) {
                    TopStrip()
                    BottomRail(compact: compactRail)
                    page
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
                DispatchQueue.main.async { model.openPendingPanel() }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { model.save() }
        }
        .preferredColorScheme(.dark)
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
            // The desktop tab strip's job: name the tab you are on. The workspace is
            // the button at the end of the rail, not a second label here.
            Text(model.activeTab?.title ?? "New Tab")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.white.opacity(0.9))

            if model.activeTab?.isPrivate == true {
                Text("PRIVATE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
            }

            Spacer(minLength: 0)

            if let progress = model.activeTab?.progress, model.activeTab?.isLoading == true {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 64)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(GlassPane().ignoresSafeArea(edges: .top))
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

    var body: some View {
        HStack(spacing: 6) {
            if canBack {
                railButton("chevron.left") { model.goBack() }
            }
            if canForward {
                railButton("chevron.right") { model.goForward() }
            }

            HStack(spacing: 6) {
                Button {
                    model.loadSiteInfo()
                    model.showingSiteInfo = true
                } label: {
                    SiteBadge(host: model.activeHost)
                }
                .buttonStyle(.plain)

                ZStack(alignment: .leading) {
                    // The app runs dark, so SwiftUI's own placeholder would be light
                    // grey on the white pill. This is the desktop's muted ink instead.
                    if model.addressText.isEmpty {
                        Text("SEARCH")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.muted)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $model.addressText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.ink)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .onTapGesture { model.isEditingAddress = true }
                        .onSubmit {
                            model.isEditingAddress = false
                            model.navigate(to: model.addressText)
                        }
                }

                Button {
                    model.toggleBookmark()
                } label: {
                    Image(systemName: model.isBookmarked(model.activeTab?.url) ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 9)
            .frame(height: 40)
            .background(Capsule().fill(Theme.pill))
            .layoutPriority(2)

            if !model.bookmarks.isEmpty {
                BookmarksStrip()
                    .frame(maxWidth: chipWidth)
                    .layoutPriority(0)
            }

            if !compact {
                railButton(model.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise") {
                    model.reloadOrStop()
                }
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

            Button {
                model.showingTabSwitcher = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "square.on.square")
                    Text("\(model.tabs.count)").font(.system(size: 12, weight: .bold))
                }
            }
            .buttonStyle(GlassCircleButtonStyle())

            Button {
                model.showingMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
            }
            .buttonStyle(GlassCircleButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(GlassPane().ignoresSafeArea(edges: model.settings.addressBarBottom ? .bottom : .top))
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
            }
            Button { model.adjustZoom(by: 0.1) } label: {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
            }
        }
        .buttonStyle(CompactControlStyle())
        .foregroundColor(Theme.muted)
    }

    private func railButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(GlassCircleButtonStyle())
    }
}

/// Small square glass control for the folded cluster.
struct CompactControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 22, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.7 : 0.9))
            )
    }
}
