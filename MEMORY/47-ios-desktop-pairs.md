# 47 — iOS ↔ desktop surface pairs (measured, not asserted)

Every in-scope surface is listed once per appearance, naming the desktop capture, the iOS capture and
the verdict. A verdict is either **proven** — the pair agrees on the structure — or a **bound** with
the capture that shows why the comparison cannot be made. There is no third verdict.

## Where each side comes from

- Desktop, static surfaces: `port/site/popups` served on :8765 and shot by
  `node tools/oneoff/shoot-desktop-surfaces.mjs docs/parity/desktop 9240` — headless Chromium,
  `Emulation.setEmulatedMedia` for the appearance, 3 CSS px/pt, clipped to `.surface`.
- Desktop, app-rendered surfaces: `chrome://brows-surface.top-chrome` in the built binary, shot by
  `node tools/oneoff/shoot-desktop-app.mjs docs/parity/desktop 9241 http://127.0.0.1:8790`, same
  appearance emulation and scale, clipped to the sheet. Profile `.freebuff/tmp/desk3/prof`, seeded:
  three visits (`select count(*) from urls` → 3, `from visits` → 4), a `Bookmarks` bar with `Brows`,
  `The shape of a browser` and a `Reading` folder plus `Sign in` under Other bookmarks, and the
  build's own `Contextual Tasks` / `Brows PDF Viewer` extensions.
- iOS: the capture set of record run **44684721575** on **`20103c6`** (37 tests, 0 failures,
  1045.211 s, 34 captures, every one inspected), in
  `.freebuff/tmp/record-44684721575/Brows-simulator/captures/`.
- Pairs: `docs/parity/pairs/`, written by `python tools/oneoff/pair-desktop-ios.py <captures dir>`
  at 01:37 local, after the last Swift fix commit (`20103c6`, 01:00:06 local).

## Verdicts

| Surface | Appearance | Desktop capture | iOS capture | Verdict |
|---|---|---|---|---|
| Menu | light | `desktop/menu-light.png` | `menu-light.png` | **proven** — `.95` plate, `#20242b` ink, `#657080` muted, 8 px bubbles, hairline rows |
| Menu | dark | `desktop/menu-dark.png` | `menu-dark.png` | **proven** — `rgba(34,38,45,.95)` plate, `#f2f4f8` ink, `.14` rim (was a white plate before `fdd9b1e`) |
| Tab search / gallery | light | `desktop/tabs-light.png` | `tabs-light.png` | **proven** — search well, hairline, row plate and active marking agree |
| Tab search / gallery | dark | `desktop/tabs-dark.png` | `tabs-dark.png` | **proven** — dark well and dark active card (were white before `fdd9b1e`) |
| Workspaces | light | `desktop/workspaces-light.png` | `workspaces-light.png` | **proven** — row card on `rgba(plate,.5)`, `.70` rim, avatar disc, muted count |
| Workspaces | dark | `desktop/workspaces-dark.png` | `workspaces-dark.png` | **proven** — active row is the dark plate, not a white slab |
| Site information | light | `desktop/siteinfo-light.png` | `siteinfo-light.png` | **proven** — `.siteinfo-section` rule above each section, 9.5 px/660 uppercase head at `.06em`, 11.5/10.5 px rows, header card |
| Site information | dark | `desktop/siteinfo-dark.png` | `siteinfo-dark.png` | **proven** — same structure in the dark block; wells removed in `20103c6` |
| Settings | light | `desktop/settings-light.png` | `settings-light.png` | **proven** — `.settings-group` card, 13 px/720 sentence-case title, `.settings-toggle` 14×14 checkbox at `--accent` in an 18 px gutter (`ea0e802`, `20103c6`) |
| Settings | dark | `desktop/settings-dark.png` | `settings-dark.png` | **proven** — same card and checkbox on `34,38,45`; the search-engine row now draws the desktop `<select>` (`brows_surface.css:636-650`) instead of a segmented control |
| Bookmark list | light | `desktop/bookmarks-list-light.png` | `bookmarks-light.png` | **proven** — seeded rows (`Brows`, `The shape of a browser`, `Reading`), hairline separators and plate agree |
| Bookmark list | dark | `desktop/bookmarks-list-dark.png` | `bookmarks-dark.png` | **proven** — same rows on the dark plate |
| Extensions | light | `desktop/extensions-light.png` | `extensions-light.png` | **not a pair** — iOS is WebKit-only (App Store 2.5.6) and has no Chromium extensions at all; the phone surface is the content-blocker panel that says so, so there is nothing of the desktop's installed-extension rows to compare it with |
| Extensions | dark | `desktop/extensions-dark.png` | `extensions-dark.png` | **not a pair** — same platform fact; the dark capture is the same blocker panel |
| History | light | `desktop/history-light.png` | `history-light.png` | **proven** — the seeded profile lists three rows under `TODAY` (`The shape of a browser`, `Login Fixture`, `Other page`) with host chips and the range chips; rows, hairlines and muted url line agree with the phone |
| History | dark | `desktop/history-dark.png` | `history-dark.png` | **proven** — the same three rows on the dark plate |
| Downloads | light | `desktop/downloads-light.png` | `downloads-light.png` | **proven** — the panel lists the completed `sample.bin` with its `23B` size and the `Open / Folder / Rename / Always open / ×` row actions under `Clear completed`, from a profile whose only download is the seeded row (`downloads` table count 1) |
| Downloads | dark | `desktop/downloads-dark.png` | `downloads-dark.png` | **proven** — the same row and actions on the dark plate |
| Passwords | light | `desktop/passwords-light.png` | `passwords-light.png` | **proven** — the panel lists the saved credential (`https://brows.dev/`, `browseruser`, masked value) with `Show / Copy / User / Edit / ×`, above the `Export / Show file / Import / Check passwords` tools and the add form |
| Passwords | dark | `desktop/passwords-dark.png` | `passwords-dark.png` | **proven** — the same credential and controls on the dark plate; the desktop panel is also a `Site / Username / Password / Save` table vs a grouped phone form |
| Article | light | `desktop/article-light.png` | `brows-article.png` | **proven by construction** — the same `article.html`; the desktop capture is the page area only because headless has no frame, and the page does not branch on appearance |
| Article | dark | `desktop/article-dark.png` | `brows-article.png` | **proven by construction** — identical page pixels in both appearances; only the chrome around it changes |

## Surfaces with no comparable pair

- **Bookmark editor** — `desktop/bookmarks-{light,dark}.png` is the editor; the phone exposes the star
  only, so there is no iOS capture to compare.
- **Rail, circular controls, omnibox, suggestion dropdown** — native views (`brows_glass.h`), and
  `chrome://omnibox-popup.top-chrome/` / `chrome://webui-toolbar.top-chrome/` never commit their
  navigation headless. Out of scope for this pass.
- **Loading / skeleton** — the set carries `brows-launch.png`, the start page, not a loading state;
  the desktop progress band is native. Out of scope for this pass.

## Deviations the pairs forced

- `fdd9b1e` — plates were literal white and ink pinned light in dark: `Theme.plate`/`plateBase`
  (`34,38,45`), adaptive `plateInk`/`plateMuted`/`fieldPlaceholder`, adaptive `glassStroke`
  (`.76`/`.14`), `rowFill` dark `rgba(34,38,45,.55)`, `GlassCircleButtonStyle(plate:)` with the rail
  keeping `Theme.railPlate` (`PaintRailBubble` has no scheme argument). 29 fills, 24 ink uses, 11 files.
- `ea0e802` — settings sections were muted tracked capitals over borderless rows; the section helper
  now draws `.settings-group`'s card.
- `20103c6` — settings booleans were iOS switches and site info grouped rows into wells; now
  `DesktopCheckboxStyle` draws the 14×14 checkbox and `SiteInfoSheet.group` draws `.siteinfo-section`'s
  rule and head (`Theme.sectionRule`).

## 2026-11-21 — the pane surface itself (the verdicts above are structure, this is material)

The verdict table was written against the **capture set of record 44684721575** (`20103c6`). The
surface material changed afterwards and the captures of record are now run **44903582381** on
**`43f9559`** (34 sheets + 2 page shots, `docs/parity/ios/after/`). The structural verdicts still
hold — no row, plate or glyph moved — but each of the 17 surfaces is now one `.62` plate over a
blurred, cropped snapshot of the page instead of a sheet or a wash. The old iOS line above
(`20103c6`, `.freebuff/tmp/record-44684721575/`) must not be used for pane material.

- The plate value is the desktop's own light `.surface`, `rgba(var(--plate-rgb),.62)`
  (`brows_surface.css:199`); the dark `.surface` is `rgba(24,28,35,.94)` (`:881`). This is the one
  place the phone deliberately differs: the dark plate stays at `.62` so the page is actually visible
  through it, which is what the user asked for ("every popup must be real glass").
- Therefore the dark desktop crop (panel only, no page behind) reads ~28 where the phone reads
  ~111 over the white article. The light pairs (240–255) remain directly comparable and agree.
- `pill` / `suggest` now have iOS captures. They still have **no desktop pair**: the omnibox popup is
  native (`chrome://omnibox-popup` never commits headless), so they stay in "Surfaces with no
  comparable pair" and the phone is judged against `brows_glass.h`'s own recipe.
- Numbers per surface, and the address-pill / dock-strip defects: `docs/parity/ios/report.md`.
