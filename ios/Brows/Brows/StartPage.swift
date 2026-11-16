import Foundation

/// The phone's start page. A fresh tab shows the workspace, a search field that
/// feeds the real address bar, and the same favourites that sit in the rail —
/// rendered locally, so it works with no network.
enum StartPage {
    static func html(workspace: String, bookmarks: [Bookmark]) -> String {
        let chips = bookmarks.prefix(8).map { bookmark in
            """
            <a class="chip" href="\(escape(bookmark.url))">\(escape(bookmark.title))</a>
            """
        }.joined()

        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
          :root { color-scheme: dark; }
          * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
          body {
            margin: 0; min-height: 100vh;
            font-family: -apple-system, "SF Pro Text", system-ui, sans-serif;
            background: radial-gradient(120% 90% at 50% 0%, #17294a 0%, #080d18 62%, #05080f 100%);
            color: #eef1f6; padding: 48px 22px 40px;
          }
          .workspace {
            font-size: 11px; letter-spacing: 2px; font-weight: 600;
            color: #9aa3b2; margin-bottom: 26px;
          }
          h1 { font-size: 30px; line-height: 1.15; font-weight: 700; margin: 0 0 22px; letter-spacing: -0.4px; }
          .search {
            display: flex; align-items: center; gap: 10px;
            background: #fff; border-radius: 999px; padding: 0 8px 0 16px;
            height: 50px; box-shadow: 0 10px 30px rgba(0,0,0,0.35);
          }
          .search input {
            flex: 1; border: 0; outline: none; font-size: 16px; color: #0e1320;
            background: transparent; font-family: inherit;
          }
          .search input::placeholder { color: #68717f; }
          .search button {
            border: 0; width: 36px; height: 36px; border-radius: 50%;
            background: #0e1320; color: #fff; font-size: 15px; font-weight: 600;
          }
          .label { margin: 30px 0 10px; font-size: 10px; letter-spacing: 1.6px; color: #8892a3; font-weight: 600; }
          .chips { display: flex; flex-wrap: wrap; gap: 8px; }
          .chip {
            display: inline-block; max-width: 100%;
            padding: 9px 14px; border-radius: 999px; text-decoration: none;
            color: #0e1320; background: rgba(255,255,255,0.92);
            font-size: 13px; font-weight: 500;
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
            border: 0.5px solid rgba(255,255,255,0.7);
          }
          .empty { color: #8892a3; font-size: 13px; }
        </style>
        </head>
        <body>
          <div class="workspace">\(escape(workspace.uppercased()))</div>
          <h1>Where to?</h1>
          <form class="search" onsubmit="event.preventDefault(); var q = document.getElementById('q').value.trim(); if (q) { window.webkit.messageHandlers.browsStart.postMessage(q); }">
            <input id="q" type="search" placeholder="SEARCH" autocomplete="off" autocapitalize="none" spellcheck="false">
            <button type="submit" aria-label="Go">→</button>
          </form>
          <div class="label">FAVOURITES</div>
          <div class="chips">
            \(chips.isEmpty ? "<span class=\"empty\">Star a page to put it here.</span>" : chips)
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
