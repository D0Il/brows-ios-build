import SwiftUI
import WebKit

/// Hosts the WKWebView that belongs to one tab. Web views live in the model so
/// tab switching keeps each page's history and scroll position. This is also where
/// downloads, target=_blank windows and the content blocker are attached.
struct WebViewContainer: UIViewRepresentable {
    let tabId: UUID
    @ObservedObject var model: BrowserModel

    func makeUIView(context: Context) -> WKWebView {
        // A popup's web view was built by WebKit around the opener's configuration;
        // adopting it (instead of creating a second one) is what keeps the page's
        // WindowProxy alive. It is already loading, so it gets no initial load here.
        let supplied = model.takeSuppliedWebView(tabId)
        let webView = model.webView(for: tabId)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        let owner = model
        // The tab pane names the page; WebKit sets the title after load, and SPAs
        // change it later, so track it instead of only reading it at didFinish.
        let tabId = context.coordinator.tabId
        context.coordinator.titleObservation = webView.observe(\.title, options: [.new]) { [weak owner] view, _ in
            let title = view.title ?? ""
            guard !title.isEmpty else { return }
            let url = view.url
            DispatchQueue.main.async {
                owner?.update(tabId) { tab in
                    tab.title = title
                }
                owner?.retitleVisit(url, title: title)
            }
        }
        context.coordinator.observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak owner] view, _ in
            let progress = view.estimatedProgress
            let loading = view.isLoading
            DispatchQueue.main.async {
                owner?.update(tabId) { tab in
                    tab.progress = progress
                    tab.isLoading = loading
                }
            }
        }

        if supplied {
            context.coordinator.sync(webView)
        }
        if webView.url == nil, !supplied, let url = model.tabs.first(where: { $0.id == tabId })?.url {
            if url == BrowserModel.home {
                if let start = StartPage.write(bookmarks: model.bookmarks) {
                    webView.loadFileURL(start, allowingReadAccessTo: start.deletingLastPathComponent())
                }
            } else {
                webView.load(URLRequest(url: url))
            }
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model, tabId: tabId)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.observation?.invalidate()
        coordinator.titleObservation?.invalidate()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        weak var model: BrowserModel?
        let tabId: UUID
        var observation: KVOObservation?
        var titleObservation: KVOObservation?

        private var downloadIds: [ObjectIdentifier: UUID] = [:]
        private var destinations: [ObjectIdentifier: URL] = [:]
        private var progressObservations: [ObjectIdentifier: KVOObservation] = [:]

        init(model: BrowserModel, tabId: UUID) {
            self.model = model
            self.tabId = tabId
        }

        // MARK: Navigation

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { sync(webView) }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { sync(webView) }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            sync(webView, finished: true)
            model?.didFinishHTTPAuth(url: webView.url, tabId: tabId)
            model?.autofillCredential(for: webView, url: webView.url, tabId: tabId)
            samplePageBackground(webView)
        }

        /// Basic and Digest challenges belong to the browser: the model answers from
        /// the Keychain or opens its own sheet. Everything else (server trust and
        /// client certificates) stays with WebKit.
        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if model?.handleHTTPAuth(challenge, webView: webView, tabId: tabId, completion: completionHandler) == true {
                return
            }
            completionHandler(.performDefaultHandling, nil)
        }

        /// The page runs under the top inset; paint that area with the document's own
        /// background instead of the app backdrop, so a light article does not sit
        /// below a dark band. Transparent documents leave the backdrop alone.
        private func samplePageBackground(_ webView: WKWebView) {
            let js = """
            (function(){
              var c = getComputedStyle(document.body).backgroundColor || '';
              var m = c.match(/\\d+/g);
              if (!m || m.length < 3) { return ''; }
              if (m.length > 3 && +m[3] === 0) { return ''; }
              function h(v){ var s = (+v).toString(16); return s.length < 2 ? '0' + s : s; }
              return '#' + h(m[0]) + h(m[1]) + h(m[2]);
            })();
            """
            webView.evaluateJavaScript(js) { result, _ in
                guard let hex = result as? String, let color = Self.color(hex: hex) else { return }
                DispatchQueue.main.async { webView.underPageBackgroundColor = color }
            }
        }

        private static func color(hex: String) -> UIColor? {
            let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { sync(webView) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { sync(webView) }

        /// `finished` is passed from the delegate rather than derived from
        /// `isLoading`: a visit is recorded only when the document is done, because
        /// at commit WebKit has the new URL but the previous document's title.
        func sync(_ webView: WKWebView, finished: Bool = false) {
            // The local start page is HTML, so WebKit reports it as about:blank.
            // Map that back to the start tab so the pill keeps its placeholder.
            let rawURL = webView.url
            let isStart = rawURL == nil
                || rawURL?.absoluteString == "about:blank"
                || rawURL?.isFileURL == true
            let url = isStart ? BrowserModel.home : rawURL
            let title = isStart ? "New Tab" : (webView.title ?? rawURL?.host ?? "New Tab")
            let loading = webView.isLoading
            let canBack = webView.canGoBack
            let canForward = webView.canGoForward
            let secure = url?.scheme == "https"

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.model?.update(self.tabId) { tab in
                    tab.title = title.isEmpty ? "New Tab" : title
                    if let url { tab.url = url }
                    tab.isLoading = loading
                    tab.canGoBack = canBack
                    tab.canGoForward = canForward
                    tab.isSecure = secure
                }
                if finished, let url, url != BrowserModel.home {
                    self.model?.recordVisit(url, title: title)
                }
                self.model?.scheduleSave()

                // The page runs full-bleed under the glass, but its text must start
                // below the status bar and the tab pane, and stop above the rail.
                if isStart {
                    webView.scrollView.contentInset = .zero
                } else {
                    let safe = webView.safeAreaInsets
                    // The rail is 52pt of controls plus the home-indicator area;
                    // text must stop above it, never under the last row.
                    webView.scrollView.contentInset = UIEdgeInsets(
                        top: safe.top + 32,
                        left: 0,
                        bottom: safe.bottom + 60,
                        right: 0
                    )
                }
            }
        }

        // MARK: Policy — downloads and new windows

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
            // mailto:, tel: and every other scheme the web view cannot render go
            // to the system. Cancelling first is what leaves the page untouched:
            // letting WebKit try would replace it with an error page.
            if let url = navigationAction.request.url, model?.routeExternalLink(url) == true {
                decisionHandler(.cancel)
                return
            }
            // A new window is not decided here: WebKit follows this with
            // `createWebViewWith`, which is the only place a popup can be given a
            // real web view. Cancelling here is what used to make `window.open()`
            // return null for OAuth and share flows.
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            begin(download)
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            begin(download)
        }

        // MARK: WKDownloadDelegate

        private func begin(_ download: WKDownload) {
            download.delegate = self
            let key = ObjectIdentifier(download)
            let model = self.model
            progressObservations[key] = download.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                let id = self?.downloadIds[key]
                DispatchQueue.main.async {
                    guard let id else { return }
                    model?.updateDownload(id, progress: progress.fractionCompleted)
                }
            }
        }

        func download(_ download: WKDownload,
                      decideDestinationUsing response: URLResponse,
                      suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {
            let key = ObjectIdentifier(download)
            guard let model else {
                completionHandler(nil)
                return
            }

            let folder = BrowserModel.downloadsDirectory(private: model.isPrivateTab(tabId))
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            var destination = folder.appendingPathComponent(suggestedFilename)
            var counter = 1
            while FileManager.default.fileExists(atPath: destination.path) {
                let base = (suggestedFilename as NSString).deletingPathExtension
                let ext = (suggestedFilename as NSString).pathExtension
                let suffix = ext.isEmpty ? "" : ".\(ext)"
                destination = folder.appendingPathComponent("\(base)-\(counter)\(suffix)")
                counter += 1
            }

            let id = model.beginDownload(
                filename: suggestedFilename,
                source: response.url?.absoluteString ?? "",
                isPrivate: model.isPrivateTab(tabId)
            )
            downloadIds[key] = id
            destinations[key] = destination
            model.registerCancel(id) { download.cancel(nil) }
            completionHandler(destination)
        }

        func downloadDidFinish(_ download: WKDownload) {
            let key = ObjectIdentifier(download)
            progressObservations[key]?.invalidate()
            progressObservations[key] = nil
            let path = destinations[key]?.path
            let id = downloadIds[key]
            downloadIds[key] = nil
            destinations[key] = nil
            DispatchQueue.main.async { [weak self] in
                guard let id else { return }
                self?.model?.updateDownload(id, progress: 1, finished: true, path: path)
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            let key = ObjectIdentifier(download)
            progressObservations[key]?.invalidate()
            progressObservations[key] = nil
            let id = downloadIds[key]
            DispatchQueue.main.async { [weak self] in
                guard let id else { return }
                self?.model?.updateDownload(id, failed: true)
            }
        }

        // MARK: JavaScript panels

        /// A page's dialogs are answered by the browser's own card. Without these
        /// three methods WebKit draws nothing at all and answers the page itself:
        /// `confirm()` returns false, so the action the user asked for silently
        /// does not happen.
        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            guard let model else { completionHandler(); return }
            let dialog = PendingScriptDialog(kind: .alert, message: message, host: Self.host(for: webView))
            model.presentScriptDialog(dialog) { _ in completionHandler() }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            guard let model else { completionHandler(false); return }
            let dialog = PendingScriptDialog(kind: .confirm, message: message, host: Self.host(for: webView))
            model.presentScriptDialog(dialog) { answer in
                if case .ok = answer { completionHandler(true) } else { completionHandler(false) }
            }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            guard let model else { completionHandler(nil); return }
            let dialog = PendingScriptDialog(
                kind: .prompt,
                message: prompt,
                host: Self.host(for: webView),
                defaultText: defaultText ?? ""
            )
            model.presentScriptDialog(dialog) { answer in
                if case .text(let value) = answer { completionHandler(value) } else { completionHandler(nil) }
            }
        }

        private static func host(for webView: WKWebView) -> String {
            webView.url?.host ?? ""
        }

        // MARK: WKUIDelegate

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = navigationAction.request.url, let model else { return nil }
            // The page's window request is routed by the same rules as a typed
            // address (`AddressResolver`, Foundation only, executed on Windows too).
            switch AddressResolver.popup(url) {
            case .newTab:
                return model.adoptPopup(configuration, url: url)
            case .handoff:
                // A scheme this browser cannot render leaves the page exactly where
                // it was and either hands off or says so in the app's card.
                _ = model.routeExternalLink(url)
                return nil
            }
        }
    }
}

/// Type alias so the KVO token is stored without spelling the generic type.
typealias KVOObservation = NSKeyValueObservation
