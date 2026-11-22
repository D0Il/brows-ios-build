# 45 — HOW THE REAL MOBILE BROWSERS ARRANGE THEIR APPS (research, 2026-11-16)

Researched before writing any more of `ios/Brows`: how the shipped browsers lay out chrome on a
phone, so the iPhone app can be a **mobile-arranged replica of the desktop Brows rail** rather than an
invention in the same mood. Sources are Apple/Google/Opera documentation and 2026 reporting.

## What each one actually does

| Browser | Address/search bar | Tab access | Menu | Notes |
|---|---|---|---|---|
| **Safari iOS 26/27** | Three layouts, user-chosen: **Top** (bar above the page), **Bottom** (one full-width bar below the page combining URL + tabs), **Compact** (floating rounded bar with back/forward, URL, three-dot). iOS 27 puts **All Tabs** back in the Compact bar in place of the three-dot, long-press for new/private. Bars shrink on scroll and return on scroll-up. | All Tabs icon / swipe on the tab bar | Page menu at the URL (reader, translate, desktop site) | Translucent bars floating over content; controls at the bottom stay at the bottom in every layout |
| **Chrome iOS** | Top or **Bottom** (Settings → Address bar, or long-press the bar); landscape forces top | Tab counter button in the bar → tab switcher | Three-dot → settings/history/downloads | Bottom bar carries back/forward, URL, tabs, menu |
| **Opera iOS** | **Bottom search bar** ("one-handed navigation") | Tabs page with list/grid, **search-tabs icon in the gallery's own bottom bar**, swipe between private / open / synced tabs | Three-dot **inside the address bar** for navigation and page options | **Fast Action Button** (FAB) alternative to the bar; private mode shows a coloured FAB — Brows cannot copy that colour (no pink rule), the PRIVATE badge covers it |
| **Opera GX mobile** | Same Opera bottom bar; GX adds a gaming home feed and themes | Tab workspaces/groups | Menu carries the browser features | Heavier UI; ad blocker is a settings-level toggle |
| **Firefox / Edge / Brave (iOS/Android)** | Bottom toolbar (Edge/Brave expose a bottom address bar option on Android) | Tab grid from the toolbar | Menu sheet with history/downloads/settings/collections | Private mode as a separate tab set with its own indicator |

Common shape, everywhere:

1. The **address/search field lives at the bottom**, in the same bar as page controls, because of
   thumb reach. Nobody puts primary navigation on top on a phone.
2. The **tab control is a counter/icon in that bar**, and it opens a **tab gallery** that has its own
   **search field over open tabs** — exactly Brows' desktop tab-search surface.
3. Browser-level features (history, downloads, bookmarks, settings, private) live in **one menu
   sheet**, not scattered.
4. Bars are **translucent and shrink on scroll**; they float over the page.
5. **Private mode is a mode with a persistent indicator** and its own tab set.
6. Long-press is a second layer for the common actions (new tab, private tab, move the bar).

## What that means for Brows (the arrangement, not a redesign)

The desktop rail order is the spec; the phone only changes where each part sits:

| Desktop rail (fixed order) | iPhone arrangement |
|---|---|
| page controls: back, forward, reload/stop, **no home** | bottom rail, left; back/forward only exist when navigable (desktop rule) |
| address pill: site badge + field (**SEARCH** placeholder) | **bottom rail centre** — the phone norm; solid white pill, glass badge at its start |
| bookmark star | stays at the end of the pill's row |
| `#bookmarkstrip` chips, same row | chips continue in that same row, scrolling; **never a second row** |
| browser actions (zoom cluster) | zoom cluster in the bottom rail, folding `− % +`, % is the reset |
| workspace button | workspace cards as **tab groups**: the tab gallery is grouped by workspace, `+` floating over the corner |
| app menu (hamburger) | bottom-rail menu → **sheet with the desktop menu's own rows**: Site information, Bookmarks, History, Downloads, Passwords, Content blockers (iOS has no Chromium extensions), Settings, Find, Print/Save as PDF, Reader, Reopen closed, New/Private tab |
| tab strip: new tab → tab search → spacer → window controls | tab counter in the bottom rail → gallery with **search over tabs** (ranking, match marking, "N of M", recently closed), + new tab, per-row close |
| window controls / Snap / resize | no phone equivalent — omitted, not faked |

Consequences that are now settled:

- **The pill moves to the bottom.** Putting it on top (as the first iOS draft did) contradicts every
  shipped browser and the one-handed reason those bars exist. The chips ride with it.
- **The tab gallery owns tab search**, with ranking and match marking, mirroring the desktop surface.
- **One menu sheet carries the desktop menu's rows**, so "everything the desktop menu has" is a
  checklist that can be ticked off rather than guessed at.
- **Private uses the ink/PRIVATE treatment**, not Opera's coloured FAB.
- Chrome's precedent justifies offering a **top/bottom address bar setting** later; the default must
  be bottom, as shipped by Safari, Chrome, Opera and Firefox.

## Not copyable

- Opera's colour-coded private FAB (pink) — banned by the rail rules.
- Chromium extensions on iOS — WebKit only, App Store 2.5.6.
- Desktop window controls, Snap Layouts, resize bands — no phone equivalent.
