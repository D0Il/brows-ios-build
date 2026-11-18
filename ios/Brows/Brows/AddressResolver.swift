import Foundation

/// What the address pill decided to do with the text the user submitted.
enum AddressRoute: Equatable {
    /// The web view renders it.
    case open(URL)
    /// The system owns the scheme, exactly like a tapped `mailto:` link.
    case handoff(URL)
}

/// The pill's routing rules, with nothing but Foundation in them.
///
/// They live here rather than inside `BrowserModel` because `BrowserModel` imports
/// UIKit and WebKit, which no machine without an Apple SDK can compile. This file
/// is compiled and executed on Windows by `npm run swift:check`, so a wrong rule
/// costs seconds there instead of a simulator round trip.
enum AddressResolver {
    /// Schemes the web view renders itself. Anything else belongs to the system.
    static let renderableSchemes: Set<String> = [
        "http", "https", "about", "file", "data", "blob", "javascript"
    ]

    /// A typed address with its own scheme, `mailto:`-style. `host:port` is not a
    /// scheme, so text whose colon is followed by a digit stays a host.
    static func typedSchemeURL(_ text: String) -> URL? {
        guard let colon = text.firstIndex(of: ":") else { return nil }
        let scheme = String(text[text.startIndex..<colon]).lowercased()
        guard scheme.range(of: "^[a-z][a-z0-9+.\\-]*$", options: .regularExpression) != nil else {
            return nil
        }
        let rest = text[text.index(after: colon)...]
        guard let first = rest.first, !first.isNumber else { return nil }
        return URL(string: text)
    }

    /// `nil` means no address could be built at all: the caller says so in the
    /// app's own card rather than leaving the submission unanswered.
    static func route(for input: String, search: (String) -> URL?) -> AddressRoute? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let typed = typedSchemeURL(trimmed),
           let scheme = typed.scheme?.lowercased(),
           !renderableSchemes.contains(scheme) {
            return .handoff(typed)
        }

        let target: URL?
        if trimmed.contains("://") {
            target = URL(string: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            target = URL(string: "https://" + trimmed)
        } else {
            target = search(trimmed)
        }
        guard let url = target else { return nil }
        if let scheme = url.scheme?.lowercased(), !renderableSchemes.contains(scheme) {
            return .handoff(url)
        }
        return .open(url)
    }
}
