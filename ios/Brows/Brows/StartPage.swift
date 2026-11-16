import Foundation

/// The start page, carrying the Brows new-tab identity rather than an invented
/// landing page: the concrete texture ported byte-for-byte from
/// `port/site/assets/concrete.png` (FAMEBROWZ.md:42) with the glass search bubble
/// and the profile's search engine. Shortcuts are the same bookmarks the rail shows.
enum StartPage {
    /// The page needs the texture beside it, so it is written to a directory and
    /// loaded as a file URL (WebKit will not resolve bundle-relative images).
    static func write(bookmarks: [Bookmark]) -> URL? {
        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appendingPathComponent("brows-start", isDirectory: true)
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)

        if let source = Bundle.main.url(forResource: "concrete", withExtension: "png") {
            let destination = folder.appendingPathComponent("concrete.png")
            if !manager.fileExists(atPath: destination.path) {
                try? manager.copyItem(at: source, to: destination)
            }
        }

        let url = folder.appendingPathComponent("start.html")
        do {
            try html(bookmarks: bookmarks).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func html(bookmarks: [Bookmark]) -> String {
        let tiles = bookmarks.prefix(8).map { bookmark -> String in
            let host = URL(string: bookmark.url)?.host ?? ""
            return """
            <a class="tile" href="\(escape(bookmark.url))">
              <span class="favicon" style="background-image:url('https://icons.duckduckgo.com/ip3/\(escape(host)).ico')"></span>
              <span class="label">\(escape(bookmark.title))</span>
            </a>
            """
        }.joined()

        let shortcuts = tiles.isEmpty ? "" : """
        <div class="shortcuts">\(tiles)</div>
        """

        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
          :root { color-scheme: dark; }
          * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
          html, body { height: 100%; }
          body {
            margin: 0;
            font-family: -apple-system, "SF Pro Text", system-ui, sans-serif;
            background-color: #6d6f72;
            background-image: url("concrete.png");
            background-size: cover;
            background-position: center;
            background-repeat: no-repeat;
          }
          .page {
            min-height: 100%;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 18vh 20px 40px;
          }
          /* The glass search bubble: translucent pane, real blur, white hairline. */
          .bubble {
            width: 100%;
            max-width: 560px;
            display: flex;
            align-items: center;
            gap: 10px;
            height: 52px;
            padding: 0 16px;
            border-radius: 26px;
            background: rgba(255, 255, 255, 0.30);
            -webkit-backdrop-filter: blur(24px) saturate(160%);
            backdrop-filter: blur(24px) saturate(160%);
            border: 1px solid rgba(255, 255, 255, 0.62);
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.20);
          }
          .bubble svg { flex: 0 0 auto; opacity: 0.62; }
          .bubble input {
            flex: 1;
            min-width: 0;
            border: 0;
            outline: none;
            background: transparent;
            font-family: inherit;
            font-size: 16px;
            color: #1b1f27;
          }
          .bubble input::placeholder { color: #68717f; }
          .shortcuts {
            width: 100%;
            max-width: 560px;
            margin-top: 34px;
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px 10px;
          }
          .tile {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 8px;
            text-decoration: none;
            overflow: hidden;
          }
          .favicon {
            width: 54px;
            height: 54px;
            border-radius: 14px;
            background-color: rgba(255, 255, 255, 0.86);
            background-size: 32px 32px;
            background-position: center;
            background-repeat: no-repeat;
            border: 1px solid rgba(255, 255, 255, 0.60);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.16);
          }
          .label {
            max-width: 100%;
            font-size: 11px;
            font-weight: 500;
            color: #f4f6f8;
            text-shadow: 0 1px 3px rgba(0, 0, 0, 0.45);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
          }
        </style>
        </head>
        <body>
          <div class="page">
            <form class="bubble" onsubmit="event.preventDefault(); var q = document.getElementById('q').value.trim(); if (q) { window.webkit.messageHandlers.browsStart.postMessage(q); }">
              <svg width="17" height="17" viewBox="0 0 17 17" fill="none">
                <circle cx="7.2" cy="7.2" r="5.4" stroke="#1b1f27" stroke-width="1.6"/>
                <path d="M11.4 11.4L15.4 15.4" stroke="#1b1f27" stroke-width="1.6" stroke-linecap="round"/>
              </svg>
              <input id="q" type="search" placeholder="SEARCH" autocomplete="off" autocapitalize="none" spellcheck="false">
            </form>
            \(shortcuts)
          </div>
        </body>
        </html>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
