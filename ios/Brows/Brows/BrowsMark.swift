import SwiftUI
import UIKit

/// The Brows mark, taken from the canonical brand asset
/// `port/branding/brows-mark-1024.png` (two eyes with lash spikes). It is never
/// redrawn in code: the asset is the only source.
struct BrowsMark: View {
    var body: some View {
        Image("BrowsMark")
            .resizable()
            .scaledToFit()
    }
}

/// Small circular glass badge at the start of the address pill — the site-info
/// button on the desktop, showing the current site's initial (or a lock when no
/// page is open).
struct SiteBadge: View {
    var host: String? = nil

    var body: some View {
        ZStack {
            // location_icon.css: `background-color: transparent` — the glyph sits
            // directly on the glass pill; a filled chip reads as a white circle.
            if let host {
                SiteIcon(host: host)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.ink)
            }
        }
        .frame(width: 26, height: 26)
    }
}

/// The site's icon, or its initial. DuckDuckGo answers for a host it does
/// not know with an HTTP 404 whose body is still a 48×48 PNG — its grey
/// "next" disc — and `AsyncImage` renders any decodable body, status or not:
/// the badge showed a forward chevron for localhost in every capture of run
/// 45177700804. The status is checked here, and a host without an icon keeps
/// the letter the badge already used while the image loaded.
struct SiteIcon: View {
    let host: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
            } else {
                Text(String(host.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    // The badge sits in the address pill, whose pane is the
                    // light rail band in both appearances; adaptive white ink
                    // vanished in dark mode (pill-dark).
                    .foregroundColor(Theme.ink)
            }
        }
        .task(id: host) { image = await SiteIconLoader.icon(for: host) }
    }
}

enum SiteIconLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func icon(for host: String) async -> UIImage? {
        if let cached = cache.object(forKey: host as NSString) { return cached }
        guard let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: host as NSString)
        return image
    }
}
