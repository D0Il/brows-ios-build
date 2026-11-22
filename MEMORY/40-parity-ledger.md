# 40 — THE EQUAL-OR-BETTER LEDGER

The standing bar is *"EVERYTHING MUST BE EQUAL TO OR BETTER THAN NATIVE CHROMIUM"*. A claim of parity
is worth nothing without evidence, so every row carries one: **runtime** (exercised in a running
build, and by whom), **source** (`file:line` read), or **none** (not yet established).

Rules for this file:
- A row may say **parity** only with runtime evidence or a source line that implements the same
  behaviour. Otherwise it says **unverified** in that column.
- Adding a Brows affordance does not close the row; the Chromium affordance must be enumerated first.
- When the user reports a defect, the row it belongs to drops to "defect" until re-exercised.

Last audited: 2026-11-13 (source pass; no runtime pass this date).

## Zoom

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Page-action chip in the omnibox: appears when zoom ≠ 100%, live %, opens −/+/reset | `BrowsZoomButton` cluster in the tab-strip row: mark stays visible, press opens `− 100% +`, same press folds it, % is the reset button, `ZoomObserver` follows the active tab (ctrl+wheel, keyboard, menu); Chromium's chip is force-hidden | Brows is *more* than Chromium here (chip location is Brows' own, and Chromium's duplicate cannot appear) | runtime: user confirmed "the extention and zoom is finally fixed"; source: `horizontal_tab_strip_region_view.cc:666`, `zoom_view_controller.cc:105` |
| Keyboard: Ctrl +/-/0 | same (Chromium accelerators untouched) | none | source: untouched upstream commands |

## Extensions

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| One puzzle button; its menu lists extensions, pin, manage | Same one button — the Brows chip is deleted and `ToggleExtensionsMenu()` opens the Brows pane instead | Brows replaces Chromium's menu with its own pane | runtime: user confirmed; source: `webui_toolbar_extensions_container.cc` |
| Per-extension: options, pin, reload, remove, manage, site access (4 states), warnings | Pane row `…` menu carries all of those, including host-access requests (allow/dismiss) | none known | source: `brows_surface.mojom` (`BrowsExtension`), `webui_toolbar_extensions_container.cc`; host-access section **unverified at runtime** (needs an extension that requests host access) |
| Manager page (`chrome://extensions`) | `Manage extensions` command opens Chromium's manager | none | source |

## Tab search

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Popup from the strip chevron; title search; recently closed; device tabs | Brows surface (`?surface=tab-search`): relevance ranking, `<mark>` on matches, "N of M tabs", ↑↓/Enter/Esc hints, Recently closed from `TabRestoreService`, per-row close | no other-device tabs (no sync) | runtime: 11 real tabs listed, filtering works (2026-11-02); keyboard hint verified by string only |
| Full keyboard driving | ↑↓/Enter/Esc implemented; **now** also one tab stop + Home/End via the shared roving helper | none known | source: `brows_surface.ts` `setupRovingList`; runtime: none yet |

## Bookmarks (strip, folder flyout, editor)

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Bar chips + overflow; folder opens a native menu; right-click → Edit/Move/Delete/Open all | Chips inline in the toolbar row; folder opens a Miller-column flyout (`?surface=folder`); row right-click opens the same pearl action popup as the strip chips, as its own bubble | Flyout is a WebUI page rather than a native menu | runtime: chips reorder/drop-into-folder verified 2026-11-03; right-click **verified 2026-11-13** on a real folder (bubble `?surface=bookmarkactions&id=22`, rows Open / Open in new tab / Open in new window / Edit / Move / Delete) |
| Editor: title/URL/folder/delete | Editor surface: URL, folder select, Delete/Cancel/Save, icon text + saturation, `Automatic` reset | Brows adds the text icon and saturation (from the old design) | runtime: editor verified 2026-11-01 |
| Keyboard in menus | rows are focusable; Enter/Space activate; arrows/Home/End added this pass; Escape closes | none known | source; runtime: none yet |

## Downloads

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Bubble with rows, open/show-in-folder/pause/cancel/remove, search | Brows `#downloads` panel with rows and the same actions | none known | source: `brows_surface.ts` download rows, `RenameDownload` handler; runtime: panel mount only |

## Site information

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Chip opens a bubble: permissions, cookies/site data, connection | `#siteinfo` panel: connection state + transport, cookie names/count, per-type storage sizes, permission rows with reset, Clear site data | none known; sizes come from the same `BrowsingDataModel` chrome://settings uses | source: `brows_surface.mojom` `SiteCookie`/`SiteStorage`, `webui_app_menu_control.cc` `GetBrowsSiteCookies`/`GetBrowsSiteData`; runtime: all four sections render in the installed build (2026-11-13), **numbers on a live site unverified** — the panel needs the site tab active and the menu bubble cannot be driven from outside |

## Settings

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| `chrome://settings` full surface, search, deep pages | Brows `#settings` groups + search + logo colour + `Full settings` escape hatch to Chromium's page | Brows settings is a curated subset; the full page is one click away | source: `brows_surface.html` `#settings`; runtime: `#settings-logo-colour` read `auto` with options `auto/white/black` |

## Passwords

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Password manager page; reveal/copy/edit/delete/export | `#passwords` rows with inline edit, reveal, export/import (`ExportBrowsPasswords`/`ImportBrowsPasswords`) | none known | source; runtime: panel mount only (the 2026-11-13 DCHECK was in these deferred replies and is fixed) |

## History

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| History page with search and per-day grouping | `#history` panel with rows | grouping/search depth unconfirmed | source; runtime: none |

## Workspaces (Brows-only)

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| no equivalent (tab groups are the nearest) | Workspace cards, create/edit/delete, switch, move tab into workspace, membership survives restart | Brows is more than Chromium | runtime: delete verified end-to-end 2026-11-02; membership across restart verified (export 1728/2705) |

## Private window

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Incognito: dark window, incognito icon, "you're incognito" NTP | `PRIVATE` mark in the strip, private entry in the menu, monochrome accents | none known | runtime: mark renders (2026-11-13 pass) |

## Page tools

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Find, Print, Save as PDF, Reader mode, Reopen closed tab live in the app menu | same five in the Brows menu's tool strip, driven by the same commands | none | source: `brows_surface.html` tool strip |

## Window controls

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Minimize/maximize/close in the caption; **hovering maximize shows the Windows Snap Layouts flyout** (frame answers `HTMAXBUTTON`) | Same three buttons, but the caption container was only consulted after the client view had already answered, so `HTMAXBUTTON` never reached DWM — no flyout | defect, fixed 2026-11-13 by testing the caption buttons first | source: `browser_frame_view_win.cc` `NonClientHitTest`; runtime: **36 sampled points answer `HTMAXBUTTON`** on the installed window (`check_snap_hittest.py`); the hover flyout itself was not hovered |

## Glass, colour, motion

| Chromium | Brows | Delta | Evidence |
|---|---|---|---|
| Native opaque bubbles | Brows glass plates, no pink anywhere, rail mono ink | Brows is more, but the colours were literals; now they ride `--plate-rgb` / `--ink` / `--muted` tokens so dark mode flips them | runtime (emulated dark): surface `rgba(24,28,35,.94)`, ink `#f2f4f8`, plate `34,38,45`, `color-scheme: dark` |

| Crash / "restore pages" | Native Chromium dialog: text "Chromium didn't shut down correctly.", opaque, blue filled button | Brows surface `?surface=restore`: "Brows didn't shut down correctly.", glass plate, mono ink button, Restore / Start fresh | Installed build, startup crash target read through CDP (text + `rgba(27,31,39,.92)`) |

| Extensions pane row | Chromium: row runs the action — popup when the extension declares one | Brows row calls the same `ExecuteExtensionAction` the toolbar button uses; popup bubble opens, surface closes, no tab | Installed build + probe extension with `default_popup`: popup.html target, zero chrome://extensions tabs (`check_extension_popup.py`, `CHECK_EXIT=0`) |
