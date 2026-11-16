import Foundation
import WebKit

/// The built-in blocker, compiled from a WebKit content-rule list. WebKit has no
/// DNR/extension engine on iOS, so this is what "ad blocker on" actually means here.
/// Sites the user exempted are passed in as `unless-domain`, so one list covers the
/// whole app and still honours per-site exceptions.
final class AdBlocker {
    private var thirdPartyHosts: [String] {
        [
            "doubleclick.net", "googlesyndication.com", "googleadservices.com",
            "adservice.google.com", "adnxs.com", "adsrvr.org", "taboola.com",
            "outbrain.com", "criteo.com", "scorecardresearch.com", "quantserve.com",
            "hotjar.com", "segment.io", "amplitude.com", "mixpanel.com",
            "bat.bing.com", "facebook.net", "analytics.twitter.com",
            "adform.net", "pubmatic.com", "rubiconproject.com", "openx.net",
            "moatads.com", "adsafeprotected.com", "chartbeat.com", "newrelic.com"
        ]
    }

    private func identifier(excepting hosts: [String]) -> String {
        if hosts.isEmpty { return "BrowsAdBlock" }
        return "BrowsAdBlock-" + String(hosts.sorted().joined(separator: ",").hashValue)
    }

    private func rules(excepting hosts: [String]) -> String {
        var list: [[String: Any]] = []

        for host in thirdPartyHosts {
            let escaped = host.replacingOccurrences(of: ".", with: "\\.")
            var trigger: [String: Any] = [
                "url-filter": "^https?://([^/]*\\.)?" + escaped + "/",
                "load-type": ["third-party"]
            ]
            if !hosts.isEmpty { trigger["unless-domain"] = hosts }
            list.append(["trigger": trigger, "action": ["type": "block"]])
        }

        var cosmetic: [String: Any] = ["url-filter": ".*"]
        if !hosts.isEmpty { cosmetic["unless-domain"] = hosts }
        list.append([
            "trigger": cosmetic,
            "action": [
                "type": "css-display-none",
                "selector": "[id^=\"google_ads\"], [id^=\"div-gpt-ad\"], .ad-slot, .adslot, .ad-banner, ins.adsbygoogle, [class*=\"sponsored-ad\"]"
            ]
        ])

        if let data = try? JSONSerialization.data(withJSONObject: list),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "[]"
    }

    func prepare(excepting hosts: [String], completion: @escaping (WKContentRuleList?) -> Void) {
        let name = identifier(excepting: hosts)
        let encoded = rules(excepting: hosts)

        WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: name) { list, _ in
            if let list {
                completion(list)
                return
            }
            self.compile(name: name, encoded: encoded, completion: completion)
        }
    }

    private func compile(name: String, encoded: String, completion: @escaping (WKContentRuleList?) -> Void) {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: name,
            encodedContentRuleList: encoded
        ) { compiled, _ in
            guard compiled == nil else {
                completion(compiled)
                return
            }
            // A stale identifier can fail to compile; drop it and build once more.
            WKContentRuleListStore.default().removeContentRuleList(forIdentifier: name) { _ in
                WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: name,
                    encodedContentRuleList: encoded
                ) { retried, _ in
                    completion(retried)
                }
            }
        }
    }
}
