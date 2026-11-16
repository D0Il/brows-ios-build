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
}

struct Credential: Identifiable, Codable, Equatable {
    var id = UUID()
    var host: String
    var username: String
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
    @Published var addressText: String = ""
    @Published var bookmarks: [Bookmark] = []
    @Published var workspaces: [Workspace] = []
    @Published var activeWorkspaceId: UUID = UUID()
    @Published var history: [HistoryEntry] = []
    @Published var recentlyClosed: [ClosedTab] = []
    @Published var downloads: [DownloadItem] = []
    @Published var credentials: [Credential] = []
    @Published var settings = BrowserSettings()
    @Published var siteInfo: SiteInfo?
    @Published var readerContent: ReaderContent?
    @Published var findQuery = ""
    @Published var findState = FindState()
    @Published var readerFailed = false
    @Published var pdfFile: ExportFile?
    @Published var pendingPanel: PanelTarget?
    /// While the user is typing in the address field, navigation updates must not
    /// overwrite what they are typing.
    @Published var isEditingAddress = false
    @Published var pendingCredential: PendingCredential?
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

    private var webViews: [UUID: WKWebView] = [:]
    private var cancelHandlers: [UUID: () -> Void] = [:]
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
        load()
        loadCredentials()
        blockerExceptions = UserDefaults.standard.stringArray(forKey: "brows.blockerExceptions") ?? []
        rebuildBlocker()
        if !settings.restoreSession {
            // A cold start opens one tab, like the desktop with session restore off.
            tabs = []
            newTab()
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

    func navigate(to input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let id = activeTab?.id else { newTab(); return }

        let target: URL?
        if trimmed.contains("://") {
            target = URL(string: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            target = URL(string: "https://" + trimmed)
        } else {
            target = settings.searchEngine.searchURL(for: trimmed)
        }
        guard let url = target else { return }
        isEditingAddress = false
        addressText = url.absoluteString
        webViews[id]?.load(URLRequest(url: url))
    }

    func goBack() { webViews[activeTab?.id ?? UUID()]?.goBack() }
    func goForward() { webViews[activeTab?.id ?? UUID()]?.goForward() }

    func reloadOrStop() {
        guard let tab = activeTab, let webView = webViews[tab.id] else { return }
        if webView.isLoading { webView.stopLoading() } else { webView.reload() }
    }

    func openInNewTab(_ url: URL) { newTab(url) }

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

        return tabs
            .map { (tab: $0, score: score($0)) }
            .filter { $0.score > 0 }
            .sorted { $0.score == $1.score ? $0.tab.title < $1.tab.title : $0.score > $1.score }
            .map { $0.tab }
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

    func recordVisit(_ url: URL, title: String) {
        guard !(activeTab?.isPrivate ?? false) else { return }
        guard url.scheme == "http" || url.scheme == "https" else { return }
        if let last = history.first, last.url == url.absoluteString,
           Date().timeIntervalSince(last.date) < 5 { return }
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

    func beginDownload(filename: String, source: String) -> UUID {
        let id = UUID()
        downloads.insert(DownloadItem(id: id, filename: filename, source: source, progress: 0, finished: false, failed: false), at: 0)
        return id
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
    func addCredential(host: String, username: String, secret: String) -> Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, !trimmedUser.isEmpty, !secret.isEmpty else { return false }
        let credential = Credential(host: trimmedHost, username: trimmedUser)
        guard Vault.save(secret, id: credential.id) else { return false }
        credentials.append(credential)
        persistCredentials()
        return true
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
        }
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
                    self?.readerContent = nil
                    self?.readerFailed = true
                }
                return
            }
            let content = ReaderContent(
                title: dict["title"] as? String ?? "Reader",
                url: dict["url"] as? String ?? "",
                text: text,
                html: dict["html"] as? String ?? ""
            )
            DispatchQueue.main.async { self?.readerContent = content }
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
            guard let self, case let .success(data) = result else { return }
            let raw = self.activeTab?.title ?? (self.activeTab?.url?.host ?? "Brows")
            let name = raw.replacingOccurrences(of: "/", with: "-").prefix(60)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
            do {
                try data.write(to: url)
                DispatchQueue.main.async { self.pdfFile = ExportFile(url: url) }
            } catch {
                DispatchQueue.main.async { self.readerFailed = true }
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
        let alreadySaved = credentials.contains {
            $0.host.caseInsensitiveCompare(host) == .orderedSame && $0.username == username
        }
        guard !alreadySaved else { return }
        pendingCredential = PendingCredential(host: host, username: username, secret: secret)
    }

    func confirmPendingCredential() {
        guard let pending = pendingCredential else { return }
        addCredential(host: pending.host, username: pending.username, secret: pending.secret)
        pendingCredential = nil
    }

    func discardPendingCredential() {
        pendingCredential = nil
    }

    func fillCredential(_ credential: Credential) {
        guard let secret = secret(for: credential) else { return }
        webViews[activeTabId]?.evaluateJavaScript(PageTools.fillJS(username: credential.username, password: secret))
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
        let rows = tabs.compactMap { tab in
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
        if let data = try? JSONEncoder().encode(downloads) {
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
