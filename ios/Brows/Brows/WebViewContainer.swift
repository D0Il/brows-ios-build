import SwiftUI
import WebKit

/// Hosts the WKWebView that belongs to one tab. Web views live in the model so
/// tab switching keeps each page's history and scroll position. This is also where
/// downloads, target=_blank windows and the content blocker are attached.
struct WebViewContainer: UIViewRepresentable {
    let tabId: UUID
    @ObservedObject var model: BrowserModel

    func makeUIView(context: Context) -> WKWebView {
        let webView = model.webView(for: tabId)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        let owner = model
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

        if webView.url == nil, let url = model.tabs.first(where: { $0.id == tabId })?.url {
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
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        weak var model: BrowserModel?
        let tabId: UUID
        var observation: KVOObservation?

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
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { sync(webView) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { sync(webView) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { sync(webView) }

        private func sync(_ webView: WKWebView) {
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
                if let url, url != BrowserModel.home { self.model?.recordVisit(url, title: title) }
                self.model?.scheduleSave()
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
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                model?.openInNewTab(url)
                decisionHandler(.cancel)
                return
            }
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

            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Downloads", isDirectory: true)
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

            let id = model.beginDownload(filename: suggestedFilename, source: response.url?.absoluteString ?? "")
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

        // MARK: WKUIDelegate

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                model?.openInNewTab(url)
            }
            return nil
        }
    }
}

/// Type alias so the KVO token is stored without spelling the generic type.
typealias KVOObservation = NSKeyValueObservation
