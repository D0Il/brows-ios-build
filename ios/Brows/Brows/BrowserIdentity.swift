import Foundation
import UIKit
import WebKit

/// The name this browser gives websites.
///
/// Google's sign-in refuses browsers it does not recognise. Every browser on
/// this platform is built on the same engine as Safari, and the ones that work
/// with Google present a browser name Google accepts. Brows is new, so it
/// presents the system browser's own name — the truthful description of the
/// engine it runs on — until Google recognises a Brows name of its own.
enum BrowserIdentity {
    /// One source of truth for the app's version, read from the bundle.
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    }

    /// The complete name sent with every request and reported by the page.
    /// Device family and system version come from the running device, so the
    /// string is never a stale copy of one machine's version.
    static var userAgent: String {
        let system = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        let platform = UIDevice.current.userInterfaceIdiom == .pad
            ? "iPad; CPU OS \(system) like Mac OS X"
            : "iPhone; CPU iPhone OS \(system) like Mac OS X"
        return "Mozilla/5.0 (\(platform)) AppleWebKit/605.1.15 (KHTML, like Gecko) "
            + "Version/\(version) Mobile/15E148 Safari/604.1"
    }

    /// Apply the name before the web view's first request.
    static func apply(to webView: WKWebView) {
        webView.customUserAgent = userAgent
    }
}
