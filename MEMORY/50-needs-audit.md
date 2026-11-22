# 50 — THE NEEDS AUDIT (against the whole chat record)

Source: `C:/Users/xjpma/Desktop/thread-BROWS-10b62df0-7db.md`, all **286** user messages
extracted (`.freebuff` history tool). Every technical demand is listed with what the tree
actually contains. `YES` means code shipped and was exercised at some point; `NO` means it is
missing or was never exercised, and is named as such.

## Branding / logo
- Two eyes, two eyebrows, no white outline, auto black/white by surface + a settings toggle.
  YES — `brows.logo_colour` (auto/white/black) rewrites `User Data\Brows.ico`, retargets the
  desktop and Start-menu shortcuts, `WM_SETICON` for the running taskbar button; `chromium.ico`
  and `chromium_white.ico` both packed.
- Product name Brows / company Z7 in all visible strings. YES — `FAME` survives only in the
  profile directory and legacy COM ids.

## Chrome UI replaced by Brows
- Favourites as chips inside the toolbar row, no second bar. YES.
- Folder flyout (Miller columns), right-click actions on rows and on bookmarks inside folders.
  YES — verified 2026-11-13 (bubble `?surface=bookmarkactions&id=22`, six actions) and popup
  geometry measured at three pointer positions.
- Extensions: one Brows entry point with the full `...` menu (options, pin, reload, remove,
  manage, site access, host-access allow/dismiss); Chromium's puzzle must not duplicate it. YES
  in source; host-access rows never exercised with a real extension (**NO** evidence).
- Zoom cluster in the tab strip that folds/unfolds and follows ctrl+wheel. YES (user confirmed
  "the extention and zoom is finally fixed").
- Tab search: own popup, real tabs, ranking, `<mark>`, "N of M", recently closed, keyboard. YES.
- Hamburger toggle, workspaces (create/rename/delete/switch, survives restart, no pink). YES.
- Private window monochrome. YES.
- Snap Layouts on maximize hover. Hit-test YES (`HTMAXBUTTON` at 36 points); the flyout itself
  was never hovered (**NO** evidence).
- No sidebar. Correctly not built (explicitly rejected).

## Settings / site info / panels
- Settings panel covering the old form + real controls instead of `chrome://settings` jumps. YES
  — no `chrome://settings` navigation is left in the surface.
- Settings update check must run on open. YES — fixed 2026-11-13, measured without a click.
- Site panel: permissions with reset, Clear site data, plus **connection state + TLS, cookie
  names/count, per-type storage sizes** (this pass). Code YES, installed YES, all four sections
  render; the numbers on a live page are **NO** evidence (needs the site tab active, and the menu
  bubble cannot be driven from CDP or UIA).
- Downloads / Passwords / History panels. Code YES; end-to-end actions **NO** evidence.
- Passkeys appear in the passwords list with a badge and Remove — same treatment Chromium gives
  them in its password manager. YES.

## Website (brows.dev)
- Own domain, Cloudflare Worker, installer in R2, `latest.json` feed, password gate BR0WZ until
  the user says it is ready. YES — gate returns 401 with the "not public yet" page by design,
  feed serves the current installer sha `f0e447af…`.
- Design: concrete + glass, no colour, "by Z", preview that matches the browser (no extensions
  button, zoom cluster, download button, privacy as a glass popup, `© 2026 Brows`). YES in the
  site source; the live pages are behind the gate, so their rendering was not re-checked today.
- Ad exports 1:1, 4:5, 9:16. YES — `artifacts/brows-ad-1080.png`, `-1080x1350.png`, `-1080x1920.png`.

## Release chain / data
- One publish path: versioned R2 key + alias + Worker deploy + feed check; the temp-worker delete
  must never abort the run; only a feed-sha mismatch fails it. YES — measured, including a run
  whose delete genuinely failed and still finished `PUBLISH_EXIT=0`.
- Updater reads `https://brows.dev/latest.json`. YES — check proven in the installed build; the
  install half (replacing the app) never run (**NO** evidence).
- User data preserved through the rename, old FAME install removed with its profile verified
  first. YES.

## Build discipline
- Component/incremental builds, parallel workers, one build at a time, browser closed during the
  link, verify via `resources.pak` for WebUI changes. YES — all followed in this pass (three
  compile rounds, one relink, `CHAIN_EXIT=0`).

## Standing gaps that are not code
- No sync (so no other-device tabs) — deliberate.
- Settings panel is a curated subset with a link to the full Chromium page — deliberate.
