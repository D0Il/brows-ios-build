import Foundation
import UIKit
import WebKit

// MARK: - Settings

enum SearchEngine: String, Codable, CaseIterable, Identifiable {
    case google, duckduckgo, bing, brave

    var id: String { rawValue }

    var name: String {
        switch self {
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        case .bing: return "Bing"
        case .brave: return "Brave Search"
        }
    }

    func searchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch self {
        case .google: return URL(string: "https://www.google.com/search?q=" + encoded)
        case .duckduckgo: return URL(string: "https://duckduckgo.com/?q=" + encoded)
        case .bing: return URL(string: "https://www.bing.com/search?q=" + encoded)
        case .brave: return URL(string: "https://search.brave.com/search?q=" + encoded)
        }
    }
}

/// The settings the desktop app keeps; every one of these changes real behaviour here.
struct BrowserSettings: Codable, Equatable {
    var addressBarBottom = true
    var blockAds = true
    var blockTrackers = true
    var searchEngine: SearchEngine = .google
    var restoreSession = true
    var defaultZoom = 1.0
}

// MARK: - Records

struct Workspace: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String

    var initials: String { String(name.prefix(2)).uppercased() }
}

struct Tab: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var title: String
    var isLoading: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var progress: Double
    var zoom: Double
    var isPrivate: Bool
    var workspaceId: UUID
    var isSecure: Bool

    init(id: UUID = UUID(), url: URL? = nil, workspaceId: UUID, isPrivate: Bool = false) {
        self.id = id
        self.url = url
        self.title = url?.host ?? "New Tab"
        self.isLoading = false
        self.canGoBack = false
        self.canGoForward = false
        self.progress = 0
        self.zoom = 1
        self.isPrivate = isPrivate
        self.workspaceId = workspaceId
        self.isSecure = url?.scheme == "https"
    }
}

/// One row in the address pill's completion list: a bookmark or a page from
/// history, ranked the way a browser ranks them — a title match outranks a URL
/// match, and a bookmark outranks history at the same strength.
struct AddressSuggestion: Identifiable, Equatable {
    enum Source: Equatable { case bookmark, history }

    var id: String { "\(source == .bookmark ? "b" : "h"):\(url.absoluteString)" }
    var source: Source
    var title: String
    var url: URL
    var detail: String
}

struct Bookmark: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: String
}

struct ClosedTab: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: String
    let workspaceId: UUID
}

struct HistoryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var url: String
    var title: String
    var date: Date
    var workspace: String
}

struct DownloadItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var filename: String
    var source: String
    var progress: Double
    var finished: Bool
    var failed: Bool
    var localPath: String?
    var date = Date()
    /// Optional so rows written before this flag existed still decode. A private
    /// download's row names the URL it fetched, so it is never persisted.
    var isPrivate: Bool? = nil
}

struct Credential: Identifiable, Codable, Equatable {
    var id = UUID()
    var host: String
    var username: String
    /// HTTP auth protection space. Form credentials carry nil, which keeps every
    /// older saved entry decodable; they are never silently sent to a Basic realm.
    var realm: String? = nil
}

struct ReaderContent: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var url: String
    var text: String
    var html: String
}

struct SiteInfo: Equatable {
    var host: String
    var scheme: String
    var path: String
    var cookies: Int
    var localStorageBytes: Int
    var sessionStorageBytes: Int
    var scripts: Int
    var images: Int
    var serviceWorkers: Int
    var blockedAds: Int
}

struct FindState: Equatable {
    var current = 0
    var total = 0
}

struct ExportFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

struct PendingCredential: Identifiable, Equatable {
    var id = UUID()
    var host: String
    var username: String
    var secret: String
    var realm: String? = nil
    /// Set when the origin already has a saved password. Different username means
    /// the offer is a save-new/update choice; same username means update.
    var existingID: UUID? = nil
    var existingUsername: String? = nil

    var isSecondAccount: Bool {
        guard let existingUsername else { return false }
        return existingUsername.caseInsensitiveCompare(username) != .orderedSame
    }
}

/// A Basic/Digest challenge the browser owns. The completion lives in the model,
/// not the view, so dismissing the sheet cancels the challenge exactly once.
struct PendingHTTPAuth: Identifiable, Equatable {
    var id = UUID()
    var host: String
    var realm: String
    var username: String = ""
    var isPrivate = false
    var failed = false
}

/// A page's JavaScript `alert`, `confirm` or `prompt`, owned by the browser.
/// WebKit suppresses these panels entirely when the UI delegate does not
/// implement them, so a page's `confirm()` silently returns false and the
/// action the user just agreed to never happens.
struct PendingScriptDialog: Identifiable, Equatable {
    enum Kind: Equatable { case alert, confirm, prompt }
    var id = UUID()
    var kind: Kind
    var message: String
    var host: String
    var defaultText = ""
}

enum ScriptDialogAnswer: Equatable {
    case ok
    case cancel
    case text(String?)
}

/// A link the browser could not take anywhere: the system refused the scheme or
/// nothing on the device handles it. It is still an answer — the page stays
/// exactly where it was and the browser says why, in its own card.
struct PendingLinkNotice: Identifiable, Equatable {
    var id = UUID()
    var url: String
    var scheme: String
}

private struct HTTPAuthAttempt {
    var hostKey: String
    var realm: String
    var username: String
    var secret: String
    var isPrivate: Bool
}

/// A panel the menu asked for. The menu closes first, then the panel opens, so two
/// sheets never fight over the same presentation.
enum PanelTarget {
    case siteInfo, bookmarks, history, downloads, passwords, extensions, workspaces, settings
    case reader, pdf, print
}

// MARK: - Model

final class BrowserModel: NSObject, ObservableObject, WKScriptMessageHandler {
    static let home = URL(string: "https://brows.dev")!

    @Published var tabs: [Tab] = []
    @Published var activeTabId: UUID = UUID()
    @Published var addressText: String = "" { didSet { refreshSuggestions() } }
    @Published var bookmarks: [Bookmark] = []
    @Published var workspaces: [Workspace] = []
    @Published var activeWorkspaceId: UUID = UUID()
    @Published var history: [HistoryEntry] = []
    @Published var recentlyClosed: [ClosedTab] = []
    @Published var downloads: [DownloadItem] = []
    @Published var credentials: [Credential] = []
    @Published var settings = BrowserSettings()
    /// `-BrowsAppearance light|dark` pins one appearance for CI captures; nil
    /// follows the system, which is what the shipped app does.
    @Published var launchAppearance: String?
    /// Result of the token contrast audit, exposed for the UI test only.
    @Published var contrastAudit = ""
    /// `-BrowsFocusPill` opens with the pill in its selected state for capture.
    @Published var focusPillOnLaunch = false
    @Published var siteInfo: SiteInfo?
    @Published var readerContent: ReaderContent?
    @Published var findQuery = ""
    @Published var findState = FindState()
    /// A page command that could not complete, shown in the app's own card. A
    /// system alert would speak in a voice the browser does not use anywhere else.
    @Published var pageNotice: PageNotice?
    @Published var pdfFile: ExportFile?
    @Published var pendingPanel: PanelTarget?
    /// While the user is typing in the address field, navigation updates must not
    /// overwrite what they are typing.
    @Published var isEditingAddress = false {
        didSet {
            if isEditingAddress { refreshSuggestions() } else { suggestions = [] }
        }
    }
    @Published var suggestions: [AddressSuggestion] = []
    @Published var pendingCredential: PendingCredential?
    @Published var pendingHTTPAuth: PendingHTTPAuth?
    @Published var pendingScriptDialog: PendingScriptDialog?
    @Published var pendingLinkNotice: PendingLinkNotice?
    /// The last routing decision, exposed to the UI tests: a link that vanishes
    /// and a link that was handed off look identical from inside the page.
    @Published var lastRoute = ""
    /// Tabs whose web view WebKit built for a popup. The container adopts them
    /// instead of creating one from the tab's settings.
    private var suppliedWebViews: Set<UUID> = []
    /// WebKit expects exactly one answer per panel; the closure is taken out
    /// before it runs so a second answer can never reach the same page.
    private var scriptDialogCompletion: ((ScriptDialogAnswer) -> Void)?
    /// Why the last password write failed, shown by the Passwords sheet.
    @Published var credentialError: String?
    /// Test-only trace of the save path; never contains a password.
    @Published var credentialDebug = "idle"
    @Published var blockerExceptions: [String] = []

    @Published var showingTabSwitcher = false
    @Published var showingBookmarks = false
    @Published var showingHistory = false
    @Published var showingMenu = false
    @Published var showingSiteInfo = false
    @Published var showingWorkspaces = false
    @Published var showingDownloads = false
    @Published var showingPasswords = false
    @Published var showingExtensions = false
    @Published var showingSettings = false
    @Published var showingFind = false
    /// The page as the popups' glass sees it. `UIVisualEffectView` cannot sample a
    /// WKWebView, so a pane over the page gets this blurred snapshot instead.
    @Published var panelBackdrop: UIImage?

    private var webViews: [UUID: WKWebView] = [:]
    private var cancelHandlers: [UUID: () -> Void] = [:]
    private var httpAuthCompletion: ((URLSession.AuthChallengeDisposition, URLCredential?) -> Void)?
    private var httpAuthAttempt: HTTPAuthAttempt?
    /// A page can finish more than once around an authenticated load. Only the last
    /// scheduled offer may present, or a second alert appears right after Save and
    /// the sheet looks like it never dismissed.
    private var credentialOfferToken = 0
    /// Host|username of offers the user just answered, so a second finished
    /// navigation cannot immediately re-open the same alert.
    private var handledCredentialOffers: [String: Date] = [:]
    /// A save offer that arrived while the auth prompt was still up. The prompt
    /// owns the overlay layer until it is answered, so the offer waits its turn.
    private var deferredCredentialOffer: PendingCredential?
    /// Realms already answered automatically from the Keychain this launch. A second
    /// challenge after a saved answer means it was rejected, so the prompt opens.
    private var autoAnsweredRealms: Set<String> = []
    private var websiteDataStore: WKWebsiteDataStore { .default() }
    private let blocker = AdBlocker()

    private let tabsKey = "brows.tabs"
    private let bookmarksKey = "brows.bookmarks"
    private let workspacesKey = "brows.workspaces"
    private let historyKey = "brows.history"
    private let downloadsKey = "brows.downloads"
    private let credentialsKey = "brows.credentials"
    private let settingsKey = "brows.settings"
    private let activeKey = "brows.activeTab"

    var contentRuleList: WKContentRuleList?

    override init() {
        super.init()
        if CommandLine.arguments.contains("-BrowsUITestReset") {
            // The saved list lives in defaults, the secrets in the Keychain. A reset
            // that only clears defaults would leave orphaned Keychain rows and let
            // one test's password answer the next test's challenge.
            Vault.deleteAll()
            for key in [tabsKey, bookmarksKey, workspacesKey, historyKey,
                        downloadsKey, credentialsKey, settingsKey, activeKey,
                        "brows.blockerExceptions"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        load()
        // Before any surface can read the download state: files from a private session
        // that was killed (no cleanup hook ran) are gone now.
        sweepPrivateDownloads()
        loadCredentials()
        blockerExceptions = UserDefaults.standard.stringArray(forKey: "brows.blockerExceptions") ?? []
        rebuildBlocker()
        if !settings.restoreSession {
            // A cold start opens one tab, like the desktop with session restore off.
            tabs = []
            newTab()
        }
        // `-BrowsOpenURL <url>`: open straight to a page, used by the CI capture of
        // a text-heavy page. It is a launch argument, never a page-controlled route.
        if let index = CommandLine.arguments.firstIndex(of: "-BrowsOpenURL"),
           index + 1 < CommandLine.arguments.count,
           let url = URL(string: CommandLine.arguments[index + 1]) {
            newTab(url)
        }

        applyCaptureArguments()
    }

    /// Launch-only hooks used by the screenshot pass. They never change a page
    /// and are never reachable from web content.
    private func applyCaptureArguments() {
        let arguments = CommandLine.arguments

        if let index = arguments.firstIndex(of: "-BrowsAppearance"),
           index + 1 < arguments.count {
            let value = arguments[index + 1]
            if value == "light" || value == "dark" { launchAppearance = value }
        }

        if arguments.contains("-BrowsContrastAudit") {
            contrastAudit = Theme.contrastAudit()
        }

        if arguments.contains("-BrowsCaptureSeed") {
            seedCaptureData()
        }

        if arguments.contains("-BrowsFocusPill") {
            focusPillOnLaunch = true
            isEditingAddress = true
            if addressText.isEmpty { addressText = "brows.dev" }
        }

        if let index = arguments.firstIndex(of: "-BrowsSheet"),
           index + 1 < arguments.count {
            presentLaunchSheet(arguments[index + 1])
        }
    }

    private func seedCaptureData() {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("sample.bin")
        try? "brows download fixture\n".write(to: file, atomically: true, encoding: .utf8)

        bookmarks = [
            Bookmark(title: "Brows", url: "https://brows.dev"),
            Bookmark(title: "The shape of a browser", url: "http://localhost:8000/article.html")
        ]
        history = [
            HistoryEntry(url: "https://brows.dev", title: "Brows — the browser", date: Date(), workspace: activeWorkspace?.name ?? "Main"),
            HistoryEntry(url: "http://localhost:8000/article.html", title: "The shape of a browser", date: Date().addingTimeInterval(-3600), workspace: activeWorkspace?.name ?? "Main")
        ]
        downloads = [
            DownloadItem(filename: "sample.bin", source: "http://localhost:8000/sample.bin", progress: 1, finished: true, failed: false, localPath: file.path)
        ]
        if workspaces.count < 2 {
            workspaces.append(Workspace(name: "Work"))
        }
        if credentials.isEmpty {
            _ = addCredential(host: "brows.dev", username: "brows", secret: "fixture-password")
        }
    }

    private func presentLaunchSheet(_ name: String) {
        // Present after the first layout so the sheet is not dropped by the
        // presentation system during launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            switch name {
            case "menu": self.showingMenu = true
            case "bookmarks": self.showingBookmarks = true
            case "downloads": self.showingDownloads = true
            case "history": self.showingHistory = true
            case "workspaces": self.showingWorkspaces = true
            case "passwords": self.showingPasswords = true
            case "extensions": self.showingExtensions = true
            case "settings": self.showingSettings = true
            case "tabs": self.showingTabSwitcher = true
            case "auth":
                self.pendingHTTPAuth = PendingHTTPAuth(
                    host: "localhost:8000",
                    realm: "Brows Fixture",
                    username: "browsuser"
                )
            case "suggest":
                self.isEditingAddress = true
                self.refreshPanelBackdrop()
                self.addressText = "shape"
                self.suggestions = [
                    AddressSuggestion(
                        source: .history,
                        title: "The shape of a browser",
                        url: URL(string: "http://localhost:8000/article.html")!,
                        detail: "localhost:8000"
                    ),
                    AddressSuggestion(
                        source: .bookmark,
                        title: "Brows",
                        url: URL(string: "https://brows.dev")!,
                        detail: "brows.dev"
                    )
                ]
            case "notice":
                // The failure card Reader mode shows on a page with no article text.
                self.pageNotice = PageNotice(
                    title: "Reader mode",
                    message: "This page has no article text to show in Reader."
                )
            case "linknotice":
                self.pendingLinkNotice = PendingLinkNotice(
                    url: "mailto:someone@brows.dev",
                    scheme: "mailto"
                )
            case "dialog":
                self.pendingScriptDialog = PendingScriptDialog(
                    kind: .confirm,
                    message: "Remove this bookmark from the shelf?",
                    host: "brows.dev"
                )
            case "authsave":
                self.pendingCredential = PendingCredential(
                    host: "localhost:8000",
                    username: "otheraccount",
                    secret: "othersecret",
                    realm: "Brows Fixture 2",
                    existingID: UUID(),
                    existingUsername: "browsuser"
                )
            case "siteinfo":
                self.showingSiteInfo = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.loadSiteInfo() }
            default:
                break
            }
        }
    }

    // MARK: Derived

    var activeTab: Tab? { tabs.first { $0.id == activeTabId } }
    var activeWorkspace: Workspace? { workspaces.first { $0.id == activeWorkspaceId } }
    var activeHost: String? {
        guard let url = activeTab?.url, url != BrowserModel.home else { return nil }
        return url.host
    }

    func existingWebView(for id: UUID) -> WKWebView? { webViews[id] }

    /// Refresh the blurred page behind the popups. Called as a panel opens, so the
    /// snapshot is the page as the user left it. The snapshot is asynchronous; the
    /// pane redraws when it lands and keeps the material until then.
    func refreshPanelBackdrop() {
        guard let tab = activeTab else { return }
        PanelBackdrop.capture(webViews[tab.id]) { [weak self] image in
            guard let self, let image else { return }
            self.panelBackdrop = image
        }
    }

    /// True while any popup is on screen. A page that finishes after its panel
    /// opened must re-snapshot: the panel's `.onAppear` capture happens before the
    /// first paint, so a launch-hook sheet photographed the New Tab wallpaper and
    /// kept that gradient behind its glass for the rest of the session.
    var hasOpenPanel: Bool {
        showingTabSwitcher || showingBookmarks || showingHistory || showingMenu
            || showingWorkspaces || showingSiteInfo || showingDownloads
            || showingPasswords || showingExtensions || showingSettings
            || isEditingAddress || pendingScriptDialog != nil
            || pendingLinkNotice != nil || pendingHTTPAuth != nil
            || pendingCredential != nil || pageNotice != nil
    }

    /// Called when a page has finished loading. The snapshot is retaken only with a
    /// panel up, and a beat later so WebKit has painted the frame it will hand back.
    func pageDidRender() {
        guard hasOpenPanel, !isEditingAddress else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.hasOpenPanel else { return }
            self.refreshPanelBackdrop()
        }
    }
    var addressBarBottom: Bool { settings.addressBarBottom }
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: Web views

    func webView(for id: UUID) -> WKWebView {
        if let existing = webViews[id] { return existing }

        let tab = tabs.first { $0.id == id }
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        if tab?.isPrivate == true {
            configuration.websiteDataStore = .nonPersistent()
        }
        let host = tab?.url?.host ?? ""
        let excepted = blockerExceptions.contains(host)
        if let list = contentRuleList, (settings.blockAds || settings.blockTrackers), !excepted {
            configuration.userContentController.add(list)
        }
        configuration.userContentController.add(self, name: "browsCredentials")
        configuration.userContentController.add(self, name: "browsStart")
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: PageTools.credentialScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.underPageBackgroundColor = UIColor(Theme.backdropBottom)
        webView.pageZoom = tab?.zoom ?? settings.defaultZoom
        webView.allowsLinkPreview = true
        webViews[id] = webView
        return webView
    }

    // MARK: Navigation

    /// Completion for the pill, from the same stores the desktop omnibox reads:
    /// bookmarks and history. Nothing is fetched and nothing is guessed, so a row
    /// always names a page this browser has actually visited or saved.
    func refreshSuggestions() {
        guard isEditingAddress else { return }
        let query = addressText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            if !suggestions.isEmpty { suggestions = [] }
            return
        }

        func score(_ title: String, _ raw: String, base: Int) -> Int {
            let loweredTitle = title.lowercased()
            let loweredURL = raw.lowercased()
            if loweredTitle.hasPrefix(query) { return base + 12 }
            if loweredTitle.contains(query) { return base + 8 }
            if loweredURL.contains(query) { return base + 3 }
            return 0
        }

        var ranked: [(suggestion: AddressSuggestion, score: Int)] = []
        var seen = Set<String>()

        for bookmark in bookmarks {
            guard let url = URL(string: bookmark.url) else { continue }
            let value = score(bookmark.title, bookmark.url, base: 40)
            guard value > 0, seen.insert(bookmark.url).inserted else { continue }
            ranked.append((AddressSuggestion(
                source: .bookmark,
                title: bookmark.title.isEmpty ? bookmark.url : bookmark.title,
                url: url,
                detail: url.host ?? bookmark.url
            ), value))
        }

        for entry in history {
            guard let url = URL(string: entry.url) else { continue }
            let value = score(entry.title, entry.url, base: 20)
            guard value > 0, seen.insert(entry.url).inserted else { continue }
            ranked.append((AddressSuggestion(
                source: .history,
                title: entry.title.isEmpty ? entry.url : entry.title,
                url: url,
                detail: url.host ?? entry.url
            ), value))
        }

        ranked.sort { $0.score > $1.score }
        suggestions = ranked.prefix(6).map(\.suggestion)
    }

    /// A tapped row is a navigation the user already chose: the list closes and
    /// the keyboard goes away before the page changes.
    func openSuggestion(_ suggestion: AddressSuggestion) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isEditingAddress = false
        suggestions = []
        navigate(to: suggestion.url.absoluteString)
    }

    func navigate(to input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let id = activeTab?.id else { newTab(); return }

        // The rules live in `AddressResolver` (Foundation only) so they are compiled
        // and executed on Windows as well as in the simulator. What the user types is
        // routed the way a tapped link is: a scheme the web view cannot render
        // belongs to the system, and prefixing `https://` onto `mailto:` used to
        // build a nonsense host instead.
        guard let route = AddressResolver.route(for: trimmed, search: { settings.searchEngine.searchURL(for: $0) }) else {
            // An address the browser cannot even build a URL from used to return in
            // silence: the pill kept the text and the page never moved.
            pageNotice = PageNotice(
                title: "Address",
                message: "Brows could not open that address, so the page was left where it was."
            )
            return
        }

        switch route {
        case .open(let url):
            isEditingAddress = false
            addressText = url.absoluteString
            webViews[id]?.load(URLRequest(url: url))
        case .handoff(let url):
            isEditingAddress = false
            _ = routeExternalLink(url)
        }
    }

    func goBack() { webViews[activeTab?.id ?? UUID()]?.goBack() }
    func goForward() { webViews[activeTab?.id ?? UUID()]?.goForward() }

    func reloadOrStop() {
        guard let tab = activeTab, let webView = webViews[tab.id] else { return }
        if webView.isLoading { webView.stopLoading() } else { webView.reload() }
    }

    /// A link that asked for a new window keeps its own page and adds one tab.
    /// The popup path itself goes through `adoptPopup`, which hands the page a real
    /// window instead of the `null` that makes OAuth flows think they were blocked.
    func openLinkInNewTab(_ url: URL) {
        newTab(url, private: activeTab?.isPrivate ?? false)
    }

    func openInNewTab(_ url: URL) { openLinkInNewTab(url) }

    /// WebKit's own popup window, adopted as a tab. The configuration comes from
    /// WebKit (it already carries the opener's content blocker, injected scripts
    /// and data store), and returning this web view from `createWebViewWith` is
    /// what gives the page a live WindowProxy. Window features such as width and
    /// height have no meaning in a tabbed shell - the tab is the window, on every
    /// phone browser - so they are honoured by opening the tab itself.
    func adoptPopup(_ configuration: WKWebViewConfiguration, url: URL) -> WKWebView {
        let tab = Tab(url: url, workspaceId: activeWorkspaceId, isPrivate: activeTab?.isPrivate ?? false)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.underPageBackgroundColor = UIColor(Theme.backdropBottom)
        webViews[tab.id] = webView
        suppliedWebViews.insert(tab.id)
        tabs.append(tab)
        activeTabId = tab.id
        isEditingAddress = false
        suggestions = []
        addressText = displayAddress(url)
        lastRoute = "popup \(url.host ?? url.absoluteString)"
        save()
        return webView
    }

    /// True once: WebKit is already loading this web view, so the container must
    /// not start a second load of its own.
    func takeSuppliedWebView(_ id: UUID) -> Bool {
        suppliedWebViews.remove(id) != nil
    }

    /// True when the navigation has been taken away from the web view. A page
    /// that links to `mailto:` or `tel:` must reach the system and leave the page
    /// untouched; a scheme nothing handles must say so rather than swallow the tap.
    func routeExternalLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              !AddressResolver.renderableSchemes.contains(scheme) else { return false }
        lastRoute = "\(scheme) handed off"
        // A scheme nothing declares is refused synchronously. Waiting for the
        // open callback left the tap looking swallowed: the callback for an
        // unknown scheme can arrive late or never, and no notice was drawn.
        if !UIApplication.shared.canOpenURL(url) {
            lastRoute = "\(scheme) refused"
            pendingLinkNotice = PendingLinkNotice(url: url.absoluteString, scheme: scheme)
            return true
        }
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            DispatchQueue.main.async {
                guard let self else { return }
                if opened {
                    self.lastRoute = "\(scheme) opened"
                } else {
                    self.lastRoute = "\(scheme) refused"
                    self.pendingLinkNotice = PendingLinkNotice(url: url.absoluteString, scheme: scheme)
                }
            }
        }
        return true
    }

    // MARK: Zoom

    func adjustZoom(by delta: Double) {
        guard let tab = activeTab, let webView = webViews[tab.id] else { return }
        let next = min(5.0, max(0.25, tab.zoom + delta))
        webView.pageZoom = next
        update(tab.id) { $0.zoom = next }
    }

    func resetZoom() {
        guard let tab = activeTab, let webView = webViews[tab.id] else { return }
        webView.pageZoom = 1
        update(tab.id) { $0.zoom = 1 }
    }

    // MARK: Tabs

    func newTab(_ url: URL? = nil, private isPrivate: Bool = false) {
        isEditingAddress = false
        let tab = Tab(url: url ?? BrowserModel.home, workspaceId: activeWorkspaceId, isPrivate: isPrivate)
        tabs.append(tab)
        activeTabId = tab.id
        addressText = displayAddress(tab.url)
        save()
    }

    func select(_ tab: Tab) {
        isEditingAddress = false
        activeTabId = tab.id
        activeWorkspaceId = tab.workspaceId
        addressText = displayAddress(tab.url)
        save()
    }

    func close(_ tab: Tab) {
        if let webView = webViews[tab.id] {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webViews[tab.id] = nil
        }
        if let url = tab.url, !tab.isPrivate {
            recentlyClosed.insert(ClosedTab(title: tab.title, url: url.absoluteString, workspaceId: tab.workspaceId), at: 0)
            recentlyClosed = Array(recentlyClosed.prefix(15))
        }
        tabs.removeAll { $0.id == tab.id }
        if tab.isPrivate, !tabs.contains(where: { $0.isPrivate }) {
            purgePrivateDownloads()
        }
        if tabs.isEmpty {
            newTab()
            return
        }
        if activeTabId == tab.id {
            activeTabId = tabs[tabs.count - 1].id
            addressText = displayAddress(activeTab?.url)
        }
        save()
    }

    func restoreClosed(_ closed: ClosedTab) {
        activeWorkspaceId = closed.workspaceId
        newTab(URL(string: closed.url))
    }

    func closeAllPrivate() {
        let privateIds = tabs.filter { $0.isPrivate }.map { $0.id }
        for id in privateIds {
            webViews[id]?.stopLoading()
            webViews[id] = nil
        }
        tabs.removeAll { $0.isPrivate }
        purgePrivateDownloads()
        if tabs.isEmpty {
            newTab()
            return
        }
        if !tabs.contains(where: { $0.id == activeTabId }) {
            activeTabId = tabs[tabs.count - 1].id
            activeTextSync()
        }
        save()
    }

    private     func activeTextSync() {
        addressText = displayAddress(tabs.first(where: { $0.id == activeTabId })?.url)
    }

    /// A start tab has no address to show; the pill shows its placeholder instead.
    private func displayAddress(_ url: URL?) -> String {
        guard let url, url != BrowserModel.home else { return "" }
        return url.absoluteString
    }

    func rankedTabs(_ query: String) -> [Tab] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return tabs }

        func score(_ tab: Tab) -> Int {
            var value = 0
            if tab.title.lowercased().contains(trimmed) { value += 3 }
            if (tab.url?.host?.lowercased().contains(trimmed) ?? false) { value += 2 }
            if (tab.url?.absoluteString.lowercased().contains(trimmed) ?? false) { value += 1 }
            return value
        }

        var scored: [(tab: Tab, score: Int)] = []
        for tab in tabs {
            let value = score(tab)
            if value > 0 {
                scored.append((tab: tab, score: value))
            }
        }
        scored.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.tab.title < rhs.tab.title
            }
            return lhs.score > rhs.score
        }
        return scored.map { $0.tab }
    }

    func workspaceName(for tab: Tab) -> String {
        workspaces.first { $0.id == tab.workspaceId }?.name ?? "Main"
    }

    // MARK: Workspaces

    func addWorkspace(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let workspace = Workspace(name: trimmed)
        workspaces.append(workspace)
        switchWorkspace(workspace)
    }

    func renameWorkspace(_ workspace: Workspace, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index].name = trimmed
        save()
    }

    func deleteWorkspace(_ workspace: Workspace) {
        guard workspaces.count > 1, let target = workspaces.first(where: { $0.id != workspace.id }) else { return }
        for index in tabs.indices where tabs[index].workspaceId == workspace.id {
            tabs[index].workspaceId = target.id
        }
        workspaces.removeAll { $0.id == workspace.id }
        if activeWorkspaceId == workspace.id { activeWorkspaceId = target.id }
        save()
    }

    func switchWorkspace(_ workspace: Workspace) {
        activeWorkspaceId = workspace.id
        if let first = tabs.first(where: { $0.workspaceId == workspace.id }) {
            activeTabId = first.id
            addressText = first.url?.absoluteString ?? ""
        } else {
            let tab = Tab(url: BrowserModel.home, workspaceId: workspace.id)
            tabs.append(tab)
            activeTabId = tab.id
            addressText = BrowserModel.home.absoluteString
        }
        save()
    }

    // MARK: Bookmarks

    func currentURL() -> URL? {
        guard let tab = activeTab else { return nil }
        return webViews[tab.id]?.url ?? tab.url
    }

    func isBookmarked(_ url: URL?) -> Bool {
        guard let value = url?.absoluteString else { return false }
        return bookmarks.contains { $0.url == value }
    }

    func toggleBookmark() {
        guard let url = currentURL() else { return }
        let value = url.absoluteString
        if let index = bookmarks.firstIndex(where: { $0.url == value }) {
            bookmarks.remove(at: index)
        } else {
            let title = activeTab?.title ?? (url.host ?? value)
            bookmarks.append(Bookmark(title: title, url: value))
        }
        save()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    // MARK: History

    /// WebKit publishes a page's title after `didFinish`, but the visit is already
    /// recorded by then with the host standing in for the title. The entry is
    /// corrected the moment the real title arrives, so history and the pill never
    /// call a page "localhost".
    func retitleVisit(_ url: URL?, title: String) {
        guard let url, !title.isEmpty else { return }
        guard let index = history.firstIndex(where: { $0.url == url.absoluteString }) else { return }
        guard Date().timeIntervalSince(history[index].date) < 30 else { return }
        guard history[index].title != title else { return }
        history[index].title = title
        save()
    }

    func recordVisit(_ url: URL, title: String) {
        guard !(activeTab?.isPrivate ?? false) else { return }
        guard url.scheme == "http" || url.scheme == "https" else { return }
        // A revisit refreshes the entry's title instead of adding a second row, so
        // a page that was first seen before its <title> parsed is corrected rather
        // than searched forever by the wrong name.
        if let index = history.firstIndex(where: { $0.url == url.absoluteString }),
           Date().timeIntervalSince(history[index].date) < 5 {
            if !title.isEmpty, history[index].title != title {
                history[index].title = title
                save()
            }
            return
        }
        let entry = HistoryEntry(
            url: url.absoluteString,
            title: title.isEmpty ? (url.host ?? url.absoluteString) : title,
            date: Date(),
            workspace: activeWorkspace?.name ?? "Main"
        )
        history.insert(entry, at: 0)
        if history.count > 500 { history.removeLast(history.count - 500) }
        save()
    }

    func removeHistory(_ entry: HistoryEntry) {
        history.removeAll { $0.id == entry.id }
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    // MARK: Downloads

    func beginDownload(filename: String, source: String, isPrivate: Bool) -> UUID {
        let id = UUID()
        downloads.insert(DownloadItem(
            id: id,
            filename: filename,
            source: source,
            progress: 0,
            finished: false,
            failed: false,
            isPrivate: isPrivate ? true : nil
        ), at: 0)
        return id
    }

    func isPrivateTab(_ id: UUID) -> Bool {
        tabs.first { $0.id == id }?.isPrivate ?? false
    }

    /// A private tab's download belongs to that session: the row carries the URL
    /// the page fetched, so it is never written to disk, and it leaves with its file
    /// when the last private tab closes - the same promise `save()` makes for tabs.
    func purgePrivateDownloads() {
        for item in downloads where item.isPrivate == true {
            cancelHandlers[item.id] = nil
            if let path = item.localPath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        downloads.removeAll { $0.isPrivate == true }
        // A transfer can leave a file with no row (cancelled, or interrupted), so the
        // directory itself is emptied - never the normal one.
        sweepPrivateDownloads()
        save()
    }

    /// Private downloads live in their own directory, so a launch can tell from the
    /// file system alone which files must not outlive the private session. The
    /// normal `Downloads` folder is the parent and is never swept.
    static func downloadsDirectory(private isPrivate: Bool) -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        return isPrivate ? base.appendingPathComponent("Private", isDirectory: true) : base
    }

    /// Files only: the normal folder contains the private one, and a directory is not
    /// a download.
    static func downloadFileCount(private isPrivate: Bool) -> Int {
        let folder = downloadsDirectory(private: isPrivate)
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let entries = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
        return entries.filter { (try? $0.resourceValues(forKeys: Set(keys)).isRegularFile) == true }.count
    }

    /// A kill runs no cleanup hook, so the next launch is the only place that can still
    /// keep the promise. Runs before anything reads the download state.
    func sweepPrivateDownloads() {
        let folder = BrowserModel.downloadsDirectory(private: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func updateDownload(_ id: UUID, progress: Double? = nil, finished: Bool? = nil, failed: Bool? = nil, path: String? = nil) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        if let progress { downloads[index].progress = progress }
        if let finished { downloads[index].finished = finished }
        if let failed { downloads[index].failed = failed }
        if let path {
            downloads[index].localPath = path
            downloads[index].filename = (path as NSString).lastPathComponent
        }
        if finished == true { downloads[index].progress = 1 }
        // Progress ticks are frequent; only terminal changes are worth writing.
        if finished == true || failed == true { save() }
    }

    func removeDownload(_ id: UUID) {
        cancelHandlers[id] = nil
        if let item = downloads.first(where: { $0.id == id }), let path = item.localPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        downloads.removeAll { $0.id == id }
        save()
    }

    /// The web view owns the WKDownload; it registers the cancel closure here so the
    /// panel's Cancel button reaches the real transfer.
    func registerCancel(_ id: UUID, handler: @escaping () -> Void) {
        cancelHandlers[id] = handler
    }

    func cancelDownload(_ id: UUID) {
        cancelHandlers[id]?()
        cancelHandlers[id] = nil
        updateDownload(id, failed: true)
    }

    func retryDownload(_ item: DownloadItem) {
        guard let url = URL(string: item.source), url.scheme == "http" || url.scheme == "https" else { return }
        removeDownload(item.id)
        navigate(to: url.absoluteString)
    }

    func clearDownloads() {
        for item in downloads {
            if let path = item.localPath { try? FileManager.default.removeItem(atPath: path) }
        }
        downloads.removeAll()
        save()
    }

    // MARK: Credentials (secrets in the Keychain, never in defaults)

    func loadCredentials() {
        if let data = UserDefaults.standard.data(forKey: credentialsKey),
           let decoded = try? JSONDecoder().decode([Credential].self, from: data) {
            credentials = decoded
        }
    }

    /// Returns whether the credential was actually written, so callers can show a
    /// truthful status instead of guessing from the list.
    @discardableResult
    func addCredential(host: String, username: String, secret: String, realm: String? = nil) -> Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, !trimmedUser.isEmpty, !secret.isEmpty else {
            credentialError = "Not saved: a site, a username and a password are all required."
            return false
        }
        // One entry per site + username; a later save replaces its secret instead
        // of leaving two rows that reveal to the same account.
        if let existing = credentials.first(where: {
            $0.host.caseInsensitiveCompare(trimmedHost) == .orderedSame && $0.username == trimmedUser
        }) {
            return updateCredential(existing, secret: secret, realm: realm)
        }
        let credential = Credential(host: trimmedHost, username: trimmedUser, realm: realm)
        let status = Vault.save(secret, id: credential.id)
        credentialDebug = "vault \(status)"
        guard status == errSecSuccess else {
            credentialError = "Keychain error \(status)"
            return false
        }
        credentialError = nil
        credentials.append(credential)
        persistCredentials()
        return true
    }

    /// Replace the saved username/secret for an existing entry, keeping its id so the
    /// Keychain item is rotated rather than orphaned.
    @discardableResult
    func updateCredential(_ credential: Credential, username: String? = nil, secret: String, realm: String? = nil) -> Bool {
        let status = Vault.save(secret, id: credential.id)
        credentialDebug = "update vault \(status)"
        guard status == errSecSuccess else {
            credentialError = "Keychain error \(status)"
            return false
        }
        credentialError = nil
        if let index = credentials.firstIndex(where: { $0.id == credential.id }) {
            if let username { credentials[index].username = username.trimmingCharacters(in: .whitespacesAndNewlines) }
            credentials[index].realm = realm
        }
        persistCredentials()
        return true
    }

    /// The save offer for a submitted login or a completed HTTP auth. When the
    /// origin already has a password for another account, the offer becomes a
    /// save-new/update choice instead of silently adding or overwriting.
    func offerCredentialSave(host: String, username: String, secret: String, realm: String?, isPrivate: Bool) {
        guard !isPrivate, !secret.isEmpty, pendingCredential == nil else { return }
        let offerKey = "\(host)|\(username)"
        if let handled = handledCredentialOffers[offerKey], Date().timeIntervalSince(handled) < 8 {
            return
        }
        let sameOrigin = credentials.filter { $0.host.caseInsensitiveCompare(host) == .orderedSame }
        let existing = sameOrigin.first { $0.username == username } ?? sameOrigin.first
        if let existing, existing.username == username, self.secret(for: existing) == secret {
            return
        }
        let pending = PendingCredential(
            host: host,
            username: username,
            secret: secret,
            realm: realm,
            existingID: existing?.id,
            existingUsername: existing?.username
        )
        credentialDebug = "offered \(host) \(username) existing=\(existing?.username ?? "-")"
        deferredCredentialOffer = pending
        presentDeferredCredentialOffer()
    }

    private func presentDeferredCredentialOffer() {
        guard let pending = deferredCredentialOffer, pendingCredential == nil else { return }
        guard pendingHTTPAuth == nil else { return }
        deferredCredentialOffer = nil
        credentialOfferToken += 1
        let token = credentialOfferToken
        credentialDebug = "presenting \(pending.host) \(pending.username)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, token == self.credentialOfferToken,
                  self.pendingCredential == nil, self.pendingHTTPAuth == nil else { return }
            self.pendingCredential = pending
        }
    }

    /// Save the new account alongside the one already on the origin. The offer is
    /// passed explicitly: the alert's presented-binding is torn down around the
    /// button action, and reading the published value made the save a race.
    func confirmPendingCredential(_ pending: PendingCredential) {
        credentialOfferToken += 1
        handledCredentialOffers["\(pending.host)|\(pending.username)"] = Date()
        credentialDebug = "confirm \(pending.username)"
        _ = addCredential(host: pending.host, username: pending.username, secret: pending.secret, realm: pending.realm)
        if pendingCredential?.id == pending.id { pendingCredential = nil }
        if pendingHTTPAuth != nil { pendingHTTPAuth = nil }
    }

    /// Replace the existing entry with the account just used.
    func updatePendingCredential(_ pending: PendingCredential) {
        credentialOfferToken += 1
        handledCredentialOffers["\(pending.host)|\(pending.username)"] = Date()
        credentialDebug = "update \(pending.username)"
        guard let id = pending.existingID,
              let existing = credentials.first(where: { $0.id == id }) else {
            confirmPendingCredential(pending)
            return
        }
        _ = updateCredential(existing, username: pending.username, secret: pending.secret, realm: pending.realm)
        if pendingCredential?.id == pending.id { pendingCredential = nil }
        if pendingHTTPAuth != nil { pendingHTTPAuth = nil }
    }

    func secret(for credential: Credential) -> String? {
        Vault.read(id: credential.id)
    }

    func deleteCredential(_ credential: Credential) {
        Vault.delete(id: credential.id)
        credentials.removeAll { $0.id == credential.id }
        persistCredentials()
    }

    func exportCredentials() -> String {
        let rows = credentials.map { ["host": $0.host, "username": $0.username, "password": secret(for: $0) ?? ""] }
        if let data = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "[]"
    }

    @discardableResult
    func importCredentials(from json: String) -> Int {
        guard let data = json.data(using: .utf8),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return 0 }
        var added = 0
        for row in rows {
            guard let host = row["host"], let username = row["username"], let password = row["password"], !password.isEmpty else { continue }
            let exists = credentials.contains {
                $0.host.caseInsensitiveCompare(host) == .orderedSame &&
                $0.username == username
            }
            guard !exists else { continue }
            if addCredential(host: host, username: username, secret: password) {
                added += 1
            }
        }
        return added
    }

    private func persistCredentials() {
        if let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: credentialsKey)
            // The relaunch proof terminates the app right after the save. Defaults
            // writes are otherwise coalesced, which lost the list even though the
            // Keychain row was already there.
            UserDefaults.standard.synchronize()
        }
    }

    // MARK: JavaScript dialogs

    func presentScriptDialog(_ dialog: PendingScriptDialog,
                             completion: @escaping (ScriptDialogAnswer) -> Void) {
        if scriptDialogCompletion != nil { finishScriptDialog(.cancel) }
        scriptDialogCompletion = completion
        pendingScriptDialog = dialog
    }

    /// OK/Cancel from the card, or a cancel when the page goes away. Answering
    /// releases the page's JavaScript thread, which is blocked until this runs.
    func finishScriptDialog(_ answer: ScriptDialogAnswer) {
        guard let completion = scriptDialogCompletion else {
            pendingScriptDialog = nil
            return
        }
        scriptDialogCompletion = nil
        pendingScriptDialog = nil
        completion(answer)
    }

    // MARK: Page tools — found in the desktop menu

    func loadSiteInfo() {
        guard let webView = webViews[activeTabId] else { return }
        webView.evaluateJavaScript(PageTools.siteInfoJS) { [weak self] result, _ in
            guard let self else { return }
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let info = SiteInfo(
                host: dict["host"] as? String ?? "",
                scheme: dict["protocol"] as? String ?? "",
                path: dict["path"] as? String ?? "/",
                cookies: dict["cookies"] as? Int ?? 0,
                localStorageBytes: dict["local"] as? Int ?? 0,
                sessionStorageBytes: dict["session"] as? Int ?? 0,
                scripts: dict["scripts"] as? Int ?? 0,
                images: dict["images"] as? Int ?? 0,
                serviceWorkers: dict["serviceWorkers"] as? Int ?? 0,
                blockedAds: dict["blockedAds"] as? Int ?? 0
            )
            DispatchQueue.main.async { self.siteInfo = info }
        }
    }

    func loadReader() {
        guard let webView = webViews[activeTabId] else { return }
        webView.evaluateJavaScript(PageTools.readerJS) { [weak self] result, _ in
            guard let self else { return }
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = dict["text"] as? String, text.count > 200 else {
                DispatchQueue.main.async {
                    self.readerContent = nil
                    self.pageNotice = PageNotice(
                        title: "Reader mode",
                        message: "This page has no article text to show in Reader."
                    )
                }
                return
            }
            let content = ReaderContent(
                title: dict["title"] as? String ?? "Reader",
                url: dict["url"] as? String ?? "",
                text: text,
                html: dict["html"] as? String ?? ""
            )
            DispatchQueue.main.async { self.readerContent = content }
        }
    }

    func startFind() {
        showingFind = true
        findQuery = ""
        findState = FindState()
    }

    /// `newQuery` counts the matches and jumps to the first; otherwise this steps
    /// forward or backward through them, which is what the desktop find bar does.
    func runFind(backwards: Bool = false, newQuery: Bool = false) {
        guard let webView = webViews[activeTabId], !findQuery.isEmpty else {
            findState = FindState()
            return
        }

        if newQuery {
            webView.evaluateJavaScript(PageTools.findCountJS(query: findQuery)) { [weak self] result, _ in
                guard let self else { return }
                let total = (result as? NSNumber)?.intValue ?? 0
                DispatchQueue.main.async {
                    self.findState = FindState(current: total > 0 ? 1 : 0, total: total)
                    if total > 0 {
                        webView.evaluateJavaScript(PageTools.findStepJS(query: self.findQuery, backwards: false))
                    }
                }
            }
            return
        }

        let total = findState.total
        guard total > 0 else {
            runFind(backwards: backwards, newQuery: true)
            return
        }
        let next = backwards ? (findState.current - 2 + total) % total + 1 : findState.current % total + 1
        webView.evaluateJavaScript(PageTools.findStepJS(query: findQuery, backwards: backwards))
        findState.current = next
    }

    func endFind() {
        showingFind = false
        findQuery = ""
        findState = FindState()
        webViews[activeTabId]?.evaluateJavaScript("window.getSelection().removeAllRanges();")
    }

    /// Print, and Save as PDF — the desktop menu's two output commands.
    func printPage() {
        guard let webView = webViews[activeTabId] else { return }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = activeTab?.title ?? "Brows"
        info.outputType = .general
        controller.printInfo = info
        controller.printFormatter = webView.viewPrintFormatter()
        controller.present(animated: true, completionHandler: nil)
    }

    func savePDF() {
        guard let webView = webViews[activeTabId] else { return }
        let configuration = WKPDFConfiguration()
        webView.createPDF(configuration: configuration) { [weak self] result in
            guard let self else { return }
            // A PDF that was not written is not saved, and it says so. The old
            // path reported this with the Reader copy, in a system alert.
            guard case let .success(data) = result else {
                DispatchQueue.main.async {
                    self.pageNotice = PageNotice(
                        title: "Save as PDF",
                        message: "This page could not be turned into a PDF. Nothing was saved."
                    )
                }
                return
            }
            let raw = self.activeTab?.title ?? (self.activeTab?.url?.host ?? "Brows")
            let name = raw.replacingOccurrences(of: "/", with: "-").prefix(60)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
            do {
                try data.write(to: url)
                DispatchQueue.main.async { self.pdfFile = ExportFile(url: url) }
            } catch {
                DispatchQueue.main.async {
                    self.pageNotice = PageNotice(
                        title: "Save as PDF",
                        message: "The PDF could not be written to disk. Nothing was saved."
                    )
                }
            }
        }
    }

    // MARK: Data

    func clearWebsiteData(completion: (() -> Void)? = nil) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        websiteDataStore.removeData(ofTypes: types, modifiedSince: .distantPast) {
            DispatchQueue.main.async {
                self.history.removeAll()
                self.downloads.removeAll()
                self.recentlyClosed.removeAll()
                self.save()
                completion?()
            }
        }
    }

    func clearSiteData(for host: String) {
        websiteDataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let matching = records.filter { $0.displayName.contains(host) }
            self.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: matching) {
                DispatchQueue.main.async { self.loadSiteInfo() }
            }
        }
    }

    func openPendingPanel() {
        guard let target = pendingPanel else { return }
        pendingPanel = nil
        switch target {
        case .siteInfo: showingSiteInfo = true
        case .bookmarks: showingBookmarks = true
        case .history: showingHistory = true
        case .downloads: showingDownloads = true
        case .passwords: showingPasswords = true
        case .extensions: showingExtensions = true
        case .workspaces: showingWorkspaces = true
        case .settings: showingSettings = true
        case .reader: loadReader()
        case .pdf: savePDF()
        case .print: printPage()
        }
    }

    // MARK: Settings

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
        applySettingsToOpenTabs()
    }

    private func applySettingsToOpenTabs() {
        if let tab = activeTab, let webView = webViews[tab.id] {
            webView.pageZoom = tab.zoom
        }
        applyBlockerToOpenTabs()
    }

    /// Turning the blocker off has to reach pages that are already open, not only
    /// the next tab.
    private func applyBlockerToOpenTabs() {
        for (id, webView) in webViews {
            let host = tabs.first { $0.id == id }?.url?.host ?? ""
            let excepted = blockerExceptions.contains(host)
            let controller = webView.configuration.userContentController
            controller.removeAllContentRuleLists()
            if (settings.blockAds || settings.blockTrackers), !excepted, let list = contentRuleList {
                controller.add(list)
            }
        }
    }

    private func rebuildBlocker() {
        blocker.prepare(excepting: blockerExceptions) { [weak self] list in
            DispatchQueue.main.async {
                self?.contentRuleList = list
                self?.applyBlockerToOpenTabs()
            }
        }
    }

    // MARK: Blocking, per site

    func isBlockingCurrentSite() -> Bool {
        guard let host = activeHost else { return true }
        return !blockerExceptions.contains(host)
    }

    func toggleBlockingForCurrentSite() {
        guard let host = activeHost, !host.isEmpty else { return }
        if let index = blockerExceptions.firstIndex(of: host) {
            blockerExceptions.remove(at: index)
        } else {
            blockerExceptions.append(host)
        }
        UserDefaults.standard.set(blockerExceptions, forKey: "brows.blockerExceptions")
        rebuildBlocker()
    }

    // MARK: Saving credentials from the page

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "browsStart", let query = message.body as? String {
            navigate(to: query)
            return
        }
        guard message.name == "browsCredentials",
              let body = message.body as? [String: Any],
              let host = body["host"] as? String,
              let username = body["username"] as? String,
              let secret = body["password"] as? String,
              !host.isEmpty, !secret.isEmpty else { return }
        offerCredentialSave(
            host: host,
            username: username,
            secret: secret,
            realm: nil,
            isPrivate: activeTab?.isPrivate == true
        )
    }

    // MARK: HTTP authentication (Basic/Digest) — the browser owns the challenge

    /// Returns true when this delegate owns the challenge. A Basic/Digest prompt is
    /// never left to the web view's empty default: every path either answers from
    /// the Keychain or opens the in-app sheet, and Cancel cancels the challenge.
    func handleHTTPAuth(_ challenge: URLAuthenticationChallenge,
                        webView: WKWebView,
                        tabId: UUID,
                        completion: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Bool {
        let method = challenge.protectionSpace.authenticationMethod
        guard method == NSURLAuthenticationMethodHTTPBasic
                || method == NSURLAuthenticationMethodHTTPDigest else { return false }

        let hostKey = httpHostKey(for: challenge.protectionSpace)
        let realm = challenge.protectionSpace.realm ?? ""
        let key = "\(hostKey)|\(realm)"
        let isPrivate = tabs.first { $0.id == tabId }?.isPrivate ?? false
        let saved = credentials.first {
            $0.host.caseInsensitiveCompare(hostKey) == .orderedSame && ($0.realm ?? "") == realm
        }
        let knownUser = saved?.username
            ?? credentials.first { $0.host.caseInsensitiveCompare(hostKey) == .orderedSame }?.username
            ?? ""

        if challenge.previousFailureCount > 0 || autoAnsweredRealms.contains(key) {
            // The server rejected what WebKit sent. Never loop the same credential;
            // re-open the prompt with the failure visible.
            autoAnsweredRealms.remove(key)
            httpAuthAttempt = nil
            presentHTTPAuth(PendingHTTPAuth(
                host: hostKey,
                realm: realm,
                username: pendingHTTPAuth?.username ?? knownUser,
                isPrivate: isPrivate,
                failed: true
            ), completion: completion)
            return true
        }

        // Private tabs must not read the Keychain or write to it.
        if !isPrivate, let saved, let secret = secret(for: saved) {
            autoAnsweredRealms.insert(key)
            completion(.useCredential, URLCredential(
                user: saved.username,
                password: secret,
                persistence: .forSession
            ))
            return true
        }

        presentHTTPAuth(PendingHTTPAuth(
            host: hostKey,
            realm: realm,
            username: knownUser,
            isPrivate: isPrivate
        ), completion: completion)
        return true
    }

    private func presentHTTPAuth(_ auth: PendingHTTPAuth,
                                 completion: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let previous = httpAuthCompletion { previous(.cancelAuthenticationChallenge, nil) }
        httpAuthCompletion = completion
        pendingHTTPAuth = auth
    }

    func submitHTTPAuth(username: String, password: String) {
        guard let completion = httpAuthCompletion, let auth = pendingHTTPAuth,
              !username.isEmpty, !password.isEmpty else { return }
        httpAuthCompletion = nil
        httpAuthAttempt = HTTPAuthAttempt(
            hostKey: auth.host,
            realm: auth.realm,
            username: username,
            secret: password,
            isPrivate: auth.isPrivate
        )
        autoAnsweredRealms.insert("\(auth.host)|\(auth.realm)")
        // Answer the challenge and put the prompt away. The page's own load proves
        // the credential worked, and the save card then takes the same overlay
        // layer; nothing is presented inside a sheet, so no presentation container
        // can swallow the card's first tap.
        pendingHTTPAuth = nil
        completion(.useCredential, URLCredential(
            user: username,
            password: password,
            persistence: .forSession
        ))
    }

    /// Dismissing the sheet is an explicit Cancel: answer the challenge instead of
    /// leaving the page waiting on a completion that never arrives.
    func cancelHTTPAuth() {
        guard let completion = httpAuthCompletion else { return }
        httpAuthCompletion = nil
        pendingHTTPAuth = nil
        httpAuthAttempt = nil
        completion(.cancelAuthenticationChallenge, nil)
    }

    /// After the protected page finishes, offer to save the credential that opened
    /// it. The same offer handles a second account on the origin with Save new /
    /// Update saved instead of overwriting silently.
    func didFinishHTTPAuth(url: URL?, tabId: UUID) {
        if let url, let key = siteKey(for: url) {
            // A committed page proves this origin's auto answer worked; a later
            // challenge may use the Keychain again instead of being treated as a
            // rejection just because it is no longer the first request this launch.
            autoAnsweredRealms = autoAnsweredRealms.filter { !$0.hasPrefix("\(key)|") }
        }
        guard let attempt = httpAuthAttempt, let url, let key = siteKey(for: url),
              key.caseInsensitiveCompare(attempt.hostKey) == .orderedSame else { return }
        httpAuthAttempt = nil
        offerCredentialSave(
            host: attempt.hostKey,
            username: attempt.username,
            secret: attempt.secret,
            realm: attempt.realm,
            isPrivate: attempt.isPrivate
        )
    }

    private func httpHostKey(for space: URLProtectionSpace) -> String {
        if space.port == 0 || space.port == 80 || space.port == 443 {
            return space.host
        }
        return "\(space.host):\(space.port)"
    }

    /// The save alert's outcome, so a failure is visible instead of assumed.
    var pendingCredentialSaved: Bool {
        credentialError == nil
    }

    func discardPendingCredential() {
        credentialOfferToken += 1
        if let pending = pendingCredential {
            handledCredentialOffers["\(pending.host)|\(pending.username)"] = Date()
        }
        pendingCredential = nil
        if pendingHTTPAuth != nil { pendingHTTPAuth = nil }
    }

    func fillCredential(_ credential: Credential) {
        guard let secret = secret(for: credential) else { return }
        webViews[activeTabId]?.evaluateJavaScript(PageTools.fillJS(username: credential.username, password: secret))
    }

    /// The key a credential is filed under: `location.host` from the page, which
    /// includes a non-default port (the fixture server runs on :8000).
    private func siteKey(for url: URL) -> String? {
        guard let host = url.host else { return nil }
        if let port = url.port { return "\(host):\(port)" }
        return host
    }

    /// Autofill on navigation: when a page on a saved origin finishes loading and
    /// has an empty login form, put the stored username and password in it.
    func autofillCredential(for webView: WKWebView, url: URL?, tabId: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabId }), !tab.isPrivate else { return }
        guard let url, let key = siteKey(for: url) else { return }
        guard let credential = credentials.first(where: { $0.host.caseInsensitiveCompare(key) == .orderedSame }),
              let secret = secret(for: credential) else { return }
        webView.evaluateJavaScript(PageTools.autofillJS(username: credential.username, password: secret))
    }

    // MARK: Tab state

    func update(_ tabId: UUID, _ mutate: (inout Tab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        mutate(&tabs[index])
        if tabId == activeTabId, let url = tabs[index].url, !isEditingAddress {
            addressText = displayAddress(url)
        }
    }

    // MARK: Persistence

    private struct PersistedTab: Codable {
        var url: String
        var workspaceId: UUID
    }

    private var pendingSave: DispatchWorkItem?

    /// Navigation fires several state changes per page; collapse them into one write.
    func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func save() {
        // Private tabs are never written to disk: closing the app must leave no trace
        // of them, the same as closing a private window on the desktop.
        let rows = tabs.filter { !$0.isPrivate }.compactMap { tab in
            tab.url.map { PersistedTab(url: $0.absoluteString, workspaceId: tab.workspaceId) }
        }
        if let data = try? JSONEncoder().encode(rows) {
            UserDefaults.standard.set(data, forKey: tabsKey)
        }
        UserDefaults.standard.set(activeTabId.uuidString, forKey: activeKey)
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: workspacesKey)
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        if let data = try? JSONEncoder().encode(downloads.filter { $0.isPrivate != true }) {
            UserDefaults.standard.set(data, forKey: downloadsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(BrowserSettings.self, from: data) {
            settings = decoded
        }
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = decoded
        }
        if let data = UserDefaults.standard.data(forKey: workspacesKey),
           let decoded = try? JSONDecoder().decode([Workspace].self, from: data),
           !decoded.isEmpty {
            workspaces = decoded
        } else {
            workspaces = [Workspace(name: "Main"), Workspace(name: "Work"), Workspace(name: "Read")]
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            history = decoded
        }
        if let data = UserDefaults.standard.data(forKey: downloadsKey),
           let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            downloads = decoded
        }
        if let first = workspaces.first {
            activeWorkspaceId = first.id
        }

        var restored: [Tab] = []
        let fallbackWorkspace = workspaces.first?.id ?? UUID()
        let knownWorkspaces = Set(workspaces.map { $0.id })
        if let data = UserDefaults.standard.data(forKey: tabsKey),
           let rows = try? JSONDecoder().decode([PersistedTab].self, from: data) {
            restored = rows.compactMap { row in
                guard let url = URL(string: row.url) else { return nil }
                let workspace = knownWorkspaces.contains(row.workspaceId) ? row.workspaceId : fallbackWorkspace
                return Tab(url: url, workspaceId: workspace)
            }
        } else if let stored = UserDefaults.standard.stringArray(forKey: tabsKey) {
            restored = stored.compactMap { URL(string: $0) }.map {
                Tab(url: $0, workspaceId: fallbackWorkspace)
            }
        }
        if restored.isEmpty {
            restored = [Tab(url: BrowserModel.home, workspaceId: activeWorkspaceId)]
        }
        tabs = restored
        if let stored = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: stored),
           restored.contains(where: { $0.id == id }) {
            activeTabId = id
        } else {
            activeTabId = restored[0].id
        }
        addressText = displayAddress(tabs.first(where: { $0.id == activeTabId })?.url)
    }
}
