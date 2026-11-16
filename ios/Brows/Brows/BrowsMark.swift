import SwiftUI

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
            Circle()
                .fill(Color.white.opacity(0.16))
            if let host, let icon = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                AsyncImage(url: icon) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().clipShape(Circle())
                    } else {
                        Text(String(host.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.muted)
                    }
                }
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted)
            }
        }
        .frame(width: 26, height: 26)
    }
}
