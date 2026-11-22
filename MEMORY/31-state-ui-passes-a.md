# Pass log 2026-11-10 → 2026-11-12 (design passes 1–13)

Moved verbatim out of `30-state.md` on 2026-11-13 (recovery gate: window-cap 50 KB).

## 2026-11-10 — in-flight detail (moved out of the IN-FLIGHT block)
**2026-11-10 23:56 — FAME UI RUNS ON CHROMIUM 156 (build + installer CHAIN_DONE, 0 failures).** The port built
clean and the FAME surfaces were exercised on the real binary, not just compiled:
`out\Fame156\chrome.dll` = 176,130,560 B @ 23:46:29, `chrome.exe` = 1,632,768 B @ 21:55:27, both
`ProductName: Brows` / `CompanyName: Z7` / `FileVersion: 156.0.8078.80`; `mini_installer.exe` and
`releases\Brows-156-Setup.exe` are byte-identical 688,623,616 B @ 23:56:24, SHA-256
`79449338766A78A3CA23DE807B64C426E6E6954472B981E9B6E912009B9CEF54`, `releases\latest.json` carries the same
version+hash; the 152 `out\FameComponent\chrome.dll` is untouched (169,639,424 B / Nov 3 15:46).
Headless smoke (`--headless=new --dump-dom`) exited 0, rendered `<title>fame156-h</title>`, and wrote **zero**
ERROR/FATAL lines. Offscreen CDP probe (fresh profile, window at -32000,-32000, no screen capture): the
toolbar target `chrome://webui-toolbar.top-chrome/` mounts `toolbar-app` with 13 shadow children —
`#back #forward #reload #home #split-tabs #location-bar #extensions #pinnedToolbarActions #battery-saver
#performance-intervention #fame-workspaces #app-menu` — i.e. the FAME workspace button is in the row and the
favourites container is present (`chipCount 0` only because the probe profile has no bookmarks); clicking
`#app-menu` opened `chrome://fame-surface.top-chrome/` (title `Brows`, 390x448, `readyState complete`) listing
Site information / Bookmark / Password / History / Downloads / Extensions / Settings / zoom / Fullscreen / Find
/ Print / Save PDF / Reopen tab / Vertical tabs / Reader mode / New window / Private window. So the FAME
toolbar, its workspace button and the FAME app-menu surface all render on 156.
Fixes that made that happen in this session (all compiled into the 23:46 dll): `WebUIAppMenuControl::RunMenu`
was declared in the header but never defined (the first 156 link died with the undefined symbol) — it now
delegates to `HandleContextMenu`, the FAME bubble toggle; `chrome_web_ui_configs.cc` was missing
`#include "chrome/browser/ui/webui/fame_surface/fame_surface_ui.h"` for `FameSurfaceUIConfig`;
`WebUIPinnedToolbarActions::GetContainerView()` returned nullptr behind NOTIMPLEMENTED and now returns
`delegate_->GetView()`, with `IsOverflowed`/`ShouldAnyButtonsOverflow` given real bodies (preferred width vs
available width) instead of NOTIMPLEMENTED; `tab_strip_collection_controller.cc` now ORs
`fame::glass::IsWindowGlassEnabled()` into `is_glass_frame_`, which is how FAME glass reaches 156's
`horizontal_tab_style_views.cc`; and `webui_toolbar_ui.cc` had lost 156's `enableGlicButton` and
`enableMediaButton` load-time booleans in the merge — their absence crashed the toolbar page in `app.ts`
(`Assertion failed: Could not find value for …`) and left `toolbar-app` with an empty shadow root, so the
toolbar rendered nothing at all until both were restored.
**NOT done, remaining:** favourites chips with real bookmarks on 156 (fresh probe profile has none), the
workspace and tab-search surfaces on 156 (only the app-menu surface was opened), the glass look checked
visually, the updater (`CheckFameUpdates`) exercised against a live feed, and `releases\Brows-156-Setup.exe`
not executed. The port is still uncommitted.

Last updated 2026-11-10 17:26 (156 BRANDED build+installer COMPLETED: the earlier 15:57 chain produced Chromium-branded artifacts; after restoring the Brows/Z7 `BRANDING`, the 152 FAME icons/logos and Brows product strings, an incremental 10-worker rebuild finished `CHAIN_DONE`. Now `out\Fame156\chrome.exe` (1,632,768 B @ 17:17) and `chrome.dll` (175,813,120 B @ 17:23) report `ProductName: Brows`, `CompanyName: Z7`, `FileDescription: Brows`, `FileVersion: 156.0.8078.80`; `mini_installer.exe` and `releases\Brows-156-Setup.exe` are byte-identical 685,621,248 B @ 17:26, SHA-256 `C657D7011BD1ECF76004624504FF187DCA864D47938BFA4EBA8B0A3C3B640BDD`, and report `Brows Installer` / `Z7`. Headless smoke on the branded binary exited 0 and rendered `<title>fame156-branded-ok</title>`. The 152 `out\FameComponent\chrome.dll` is untouched (169,639,424 B / Nov 3 15:46). Updater still undelivered; port uncommitted; palette stashed)
- **Chromium 156 (2026-11-05):** `fame-156-port` holds the full FAME patch on 156.0.8078.80 (42 conflict files resolved to the FAME side, 0 markers, 0 unmerged); `gclient sync` finished `GCLIENT_EXIT=0`. The port is uncommitted because git on D: is the bottleneck. `gn gen` initially failed because the 156 tree pins `SDK_VERSION` to 10.0.28000.0 while only 10.0.26100.0 is installed; both `build/toolchain/win/setup_toolchain.py` and `build/vs_toolchain.py` now pin 10.0.26100.0 and `gn gen out\Fame156` succeeds (36,273 targets, `GN_EXIT=0`). The 156 full build + installer chain started at `-j 2`, BelowNormal, `-k 0` (`D:\FAME-Chromium\logs\fame-156-build.stdout.log`) and failed after 1h41m: 1,384 compile actions hit `unknown type name 'FILE_INFO_BY_HANDLE_CLASS'` because the 156 tree sets `NTDDI_VERSION=NTDDI_WIN11_BR` (`build/config/win/BUILD.gn:308`) while SDK 10.0.26100.0 only defines `NTDDI_WIN11_GE`. That line is now `NTDDI_WIN11_GE`; the chain restarted as PID 4508 and ran 10h15m, then stopped with `../../base/win/windows_version.cc(31,2): error: Windows 10.0.28000.0 SDK or higher required.` — 26,472 done, 1 failed, 32,808 remaining; no `chrome.dll`/`mini_installer`. The `NTDDI_WIN11_GE` workaround is insufficient because `windows_version.cc` hard-requires SDK 10.0.28000.0; the installed SDK is 26100. SDK 10.0.28000.0 is installed; `vswhere` confirms the component in VS 18 Community and `C:\Program Files (x86)\Windows Kits\10\Include\10.0.28000.0` exists. Both pins are restored (`NTDDI_WIN11_BR` at `build/config/win/BUILD.gn:308`; `SDK_VERSION='10.0.28000.0'` in `setup_toolchain.py` and `vs_toolchain.py`). `wait-sdk-28000-and-build.sh` launched `scripts/start-fame-156-build.ps1 -Jobs 2`; the full build+installer chain is running (PID in `D:\FAME-Chromium\logs\fame-156-build.pid`, log `D:\FAME-Chromium\logs\fame-156-build.stdout.log`); no `chrome.dll` yet. The 156 first build is an entire rebuild: `build-fame-156.cmd` and the installer chain default to 2 workers, BelowNormal, `-k 0` — the setting of the last full component build that produced `out\FameComponent` (`FAMEBROWZ.md:89`); the 10-worker rule is incremental-only. A long build must run in a window the user chooses, never unannounced while they are awake. Palette remains stashed on `fame-152-final`.
- **Command palette (2026-11-04):** same-bubble `main.surface` in `fame_surface`, opened from the
  app menu, searches `BrowserCommand`; `fameResize(520,420)`. HTML/TS/CSS + probe/runner edited.
  Full chrome rebuild stopped at 6,641/61,886 (manifest regen); 15:46 DLL current; pack old.
  `build-fame-resource.cmd` targets `resources.pak`; 09:16 TS preprocessed; build not running.

- **2026-11-03 work** (bookmark strip, favicon import, vertical tabs, sidebar rejection, Opera import) is preserved in the dated section below; none of it is open.

## 2026-11-11 — design-regression fixes (moved out of the IN-FLIGHT block)
- **2026-11-11 (second pass, user-reported regressions, all fixed + re-verified on the INSTALLED binary):**
  (1) *no Google API keys infobar* — its creation was removed from `chrome/browser/ui/startup/infobar_utils.cc`;
  the content viewport on the installed build is 723 px in an 800 px window, leaving no infobar band.
  (2) *no Chromium first-run scene* — `IsFirstRunEligibleProcess()` in
  `chrome/browser/ui/startup/first_run_service.cc` now returns false; a fresh-profile launch produced only
  `example.com` + `webui-toolbar` + omnibox-popup targets, no welcome page and no profile picker.
  (3) *glass tabs* — FAME's `PaintTab` glass block (translucent top-lit wash + 1px white hairline) was ported
  into `chrome/browser/ui/views/tabs/common/horizontal_tab_style_views.cc`, and `TabStrip::IsGlassFrame()`
  plus `TabStrip::SetIsGlassFrame()` now OR `fame::glass::IsWindowGlassEnabled()`; the 156 window is
  transparent via `WS_EX_NOREDIRECTIONBITMAP` (exstyle 0x200000). Measured on the installed binary:
  tab strip **0 pure-white pixels** (242 before), samples R159/R160 grey; pixel proof in
  `D:\FAME-Chromium\logs\fame-glass-check.png`.
  (4) *no AI mode / Glic entry point* — `kShowAiModeOmniboxButton` now registers false in
  `components/omnibox/browser/omnibox_prefs.cc` and `enableGlicButton` is hard false in
  `webui_toolbar_ui.cc`; the toolbar has zero ai/glic elements and its only page action is id 27
  ("Bookmark this tab").
  (5) the `BookmarkBar::SHOW` override in `browser_view.cc` was removed so Chromium cannot add a second
  bookmarks row under the FAME chips.
  Install note: `mini_installer` exits **7** if a Brows/chrome process is holding `chrome.dll`; closing every
  `chrome.exe` under `Z7\FAME Browser` first made it exit 0 and the installed DLL hash then equalled the build
  DLL hash (`1D3254DA9F91BF78…`).

## 2026-11-11 (third pass) — pill focus, site-info glyph, workspaces entry point
Verified on the INSTALLED binary (`installer exit=0`; installed `chrome.dll` hash == build hash
`1d3254da9f91bf78…`). The build was resource-only, so `chrome.dll` did NOT relink (01:02) while
`out\Fame156
esources.pak` rebuilt at 02:04 and `mini_installer.exe` at 02:21 — resource fixes
ship in the pak + bundled JS, not the DLL.
1. **Address pill no longer turns solid white when selected.** Cause: `location_bar.css`
   `:host(#location-bar):has(> readonly-omnibox:focus-within)` set
   `--location-bar-background: var(--color-omnibox-results-background)` (opaque) plus Chromium's blue
   focus outline. Both original rules were rewritten in place (a second copy of the same selector is
   rejected by `no-duplicate-selectors` — that is what failed the 02:00 build): the focus state now keeps
   the glass gradient and applies the original `.address-bar input:focus` treatment
   (`border-color rgba(225,155,193,.82)`, `box-shadow 0 0 0 2px rgba(225,155,193,.20)`) with
   `outline: none`. `readonly_omnibox.css:148` paints the inner field from the same
   `--color-location-bar-background`, so the inside is translucent too. Probed focused state:
   `bgColor rgba(255,255,255,0.04)`, gradient `0.22→0.08`, border `rgba(225,155,193,0.82)`,
   shadow `rgba(225,155,193,0.2) 0 0 0 2px`.
2. **Site-info glyph is the original padlock again.** `location_icon.html.ts` no longer renders
   `icon-from-table` (Chromium shows `omnibox::kChromeProductIcon` on internal pages — the "Google
   symbol"); it renders `#fame-lock`, the exact `<symbol id="icon-lock">` geometry from
   the shipped toolbar CSS (`rect 5,10 14x10 r2` + `M8 10V7a4 4 0 0 1 8 0v3`), stroked
   `1.7` at `--location-bar-leading-icon-size` (`location_icon.css`). Probe on the installed binary:
   `lock {w:16, stroke:rgb(31,31,31)}`, `legacyChip:false`. The chip keeps Chromium's click →
   page-info (cookies/permissions) control panel.
3. **Workspaces moved out of the toolbar into the hamburger menu** (user: "this new random profile
   button … SHOULD be in the hamburger menu / settings"). The only trailing control besides the
   hamburger was `#fame-workspaces` (two-card glyph, popup rows with circular initials — reads as a
   profile chip); no avatar/identity element exists in the toolbar DOM (`fameWorkspaces:false`).
   `webui_toolbar/app.html.ts` no longer renders `<fame-workspace-button>`; `fame_surface.html` gained a
   `Workspaces` row (glyph `#workspace-glyph`, renamed so it cannot collide with `<main id="workspaces">`)
   and `fame_surface.ts` gained `showSurface()` plus a `commandName === 'workspaces'` branch that switches
   the popup to the workspaces page and re-runs `loadWorkspaces()`. Probed: toolbar ids end at
   `performance-intervention, app-menu`; menu `{rowFound:true, label:"Workspaces"}`; after the click
   `{visible:["workspaces"], cards:["MA Main 1 tab"], add:true}`.
**NOT done / caveats:** the PrintWindow pixel count for the pill is not a usable measure (glass over a
dark page plus `WS_EX_NOREDIRECTIONBITMAP` gives a flat grey capture; `pure-white=400` came from the
capture, not the pill) — the DOM computed-style probe is the evidence for (1). The chain's own
`copy mini_installer.exe → releases\Brows-156-Setup.exe` step failed with "The system cannot find the
file specified." after the pak/installer build; the installer was staged by hand to both
`D:\FAME-Chromium
eleases\` and `FAMEBROWZ
eleases\` (688,621,056 B, sha256 `9644582d3f1ad65b…`).
The 156 port is still uncommitted; the updater is still unexercised against a live feed.

## 2026-11-11 (fourth pass) — CORRECTION: workspaces move reverted, real profile button found
- **The workspaces move was not requested and is reverted.** The user: "YOU MOVED THE WORKSPACES BUTTON
  INTO THE HAMBURGER WHEN I NEVER SAID TO". A broad/misread complaint is not permission to relocate a
  control (`AGENTS.md`: ask which noun when the object is ambiguous). Restored:
  `webui_toolbar/app.html.ts` renders `<fame-workspace-button id="fame-workspaces">` again (line 138,
  before the app-menu block); `fame_surface.html` lost the `Workspaces` row and `#workspace-glyph`;
  `fame_surface.ts` lost `showSurface()` and the `commandName === 'workspaces'` branch.
- **The real profile button is a NATIVE view, invisible to every WebUI DOM probe.**
  `chrome/browser/ui/views/toolbar/toolbar_view.cc:622`:
  `if (!features::IsWebUIAvatarButtonEnabled()) { avatar_ = AddChildView(std::make_unique<AvatarToolbarButton>(browser_)); ... avatar_->SetVisible(CanShowForProfile(...)); }`
  — and `CanShowForProfile()` returns true for `IsRegularProfile()`. **Probe methodology error that hid
  it:** every probe was launched with `--enable-features=...,WebUIAvatarButton`, which takes the OTHER
  branch and never creates the native avatar, so `AVATAR count 0` was an artefact of the flags, not proof
  the button was absent. Probe with DEFAULT features when checking native chrome. Fix: the view is still
  created (raw pointers reference it) but `avatar_->SetVisible(false)` unconditionally, with a comment.
- **The padlock was inert because of Chromium's clickability rule, not the glyph swap.**
  `chrome/browser/ui/views/location_bar/webui_location_bar.cc:544` was
  `bool is_clickable = !is_editing_or_empty;` — on the new-tab page the omnibox is empty, so the leading
  chip is intentionally inert (Chromium also forces it false for the Google G logo, line 570). The old
  `#securitybutton` opened Site information on every page, so FAME now sets `is_clickable = true`.
**Verification still owed for this pass:** padlock opens the page-info panel on an empty omnibox
(`location-icon.state.isContextMenuVisible` after a real click), and the trailing cluster shows only
Workspaces + hamburger on a DEFAULT-feature launch. `PrintWindow` captures the glass window black on the
default-feature launch (the 01:56 capture worked only with the WebUI-avatar feature set), so the avatar
absence is code-verified; retry `pwFlags=2`/`0` after the build for a visual check.

## 2026-11-11 (fifth pass) — no site-info chip on internal pages, home button off the strip
User: "why the hell would i want it to say 'You're viewing a secure chromium page' instead of just
hiding the lock when its not needed … THEN INSTEAD OF SHOWING FILLER BLOAT. also remove the home button
off the strip".
- **Chip hidden on chrome:// pages and its filler text dropped.** `webui_location_bar.cc`
  `UpdateLhsChipsState()`: `location_bar::GetSecurityChipText()` returns `IDS_SHORT_PRODUCT_NAME` for
  `content::kChromeUIScheme` pages (`location_icon_state_helper.cc:45-49`), which is the filler the user
  objected to. Added `is_internal_page` (`chrome` + `chrome-untrusted`) → `security_chip_text.clear()`
  and a new `is_chip_visible = !is_internal_page && !ShouldChipOverrideLocationIcon()` passed as the
  SecurityChipState `is_visible` argument (previously the bare `!ShouldChipOverrideLocationIcon()`), so the
  lock no longer exists on the new-tab page or any other chrome:// page. `#include
  "content/public/common/url_constants.h"` was added (landed at the top of the include block, line 5 —
  harmless but not alphabetised).
- **Home button removed from the toolbar.** `chrome/browser/resources/webui_toolbar/app.html.ts` no
  longer renders the `${this.isHomeButtonEnabled_ ? html`<home-button id="home" …>` : ''}` block, so the
  row is page controls from Back to Reload, then the address pill.

## 2026-11-11 (sixth pass) — refresh control in the strip, no home button, back/forward hide, no lock on blank/internal pages
User: "move the refresh button up and to right beside the minimize button on its left. so it goes
rehresh, minimize, maximize, exit." and "the back and forwards < > page buttons, those should be hidden
unless there is actively something to go back or forwards to".
- **Refresh moved out of the toolbar into the strip, flush left of minimize.** The toolbar WebUI reload
  block is gone from `webui_toolbar/app.html.ts`; a native `fame::FameReloadButton` (anonymous namespace in
  `chrome/browser/ui/views/frame/horizontal_tab_strip_region_view.cc`) is added as the LAST child of
  `HorizontalTabStripRegionViewOld`, so FlexLayout puts it against the caption buttons: measured on the
  installed probe `Reload x=-30940 w=35` → `Minimize x=-30905` → `Maximize x=-30870` → `Close x=-30835`,
  one row (y≈-32000, h=37/38). It paints `fame::glass::PaintRailBubble` (3px/2px inset, radius 8) and a
  35x38 hit target; the ring is stroked as 24 segments because this tree's `SkPath` has no mutation API
  (builder-only), and the glyph colour tweens `#68717F` → `#1B1F27` like the caption buttons. Pressing it
  through UIA `InvokePattern` changes `performance.timeOrigin`, so it reloads for real.
- **Adding any child to that region requires three things, or the browser crashes at window init:**
  1. `GetChildrenInZOrder()` is a hand-maintained list — omit the new child and
     `View::ReorderChildLayers`' `DCHECK_EQ(children_.size(), children.size())`
     (`ui/views/view.cc:2838`) aborts inside `BrowserWidget::InitBrowserWidget` (minidump stack showed
     `ReorderChildLayers` → `AddChildViewAtImpl` → `NonClientView::ViewHierarchyChanged`). The button is
     now stored in `raw_ptr<views::View> fame_reload_button_` (header) and appended in that list.
  2. `AddChildView<T>` static_asserts that `T` has metadata — wrap it as
     `std::unique_ptr<views::View>` (or add `METADATA_HEADER`) instead.
  3. `BrowserView::browser()` returns `BrowserWindowInterface*` and `Browser::command_controller()` no
     longer exists; reload is `chrome::ExecuteCommand(browser_, IDC_RELOAD)`
     (`chrome/browser/ui/browser_commands.h:54`).
- **Home button removed** from `app.html.ts` (the `${this.isHomeButtonEnabled_ ? html`<home-button id="home">
  `}` block).
- **Back/forward hidden unless navigable**: `#back` and `#forward` now bind `.hidden` to
  `!…State.enabled` (forward also keeps `!shouldBeShown`). Verified: fresh tab `backHidden:true,
  forwardHidden:true`; after navigating to example.com `backHidden:false`.
- **Lock hidden on blank and internal pages.** `webui_location_bar.cc` now hides the security chip when
  `is_editing_or_empty`, when the URL is `chrome://`/`chrome-untrusted`, and clears the product-name filler
  text (`location_icon_state_helper.cc:45-49` returns `IDS_SHORT_PRODUCT_NAME` for chrome://). The mojom
  field order is `icon, security_level, text, tooltip, accessibility_state, is_clickable,
  is_text_dangerous, is_visible, is_context_menu_visible`
  (`components/browser_apis/ui_controllers/toolbar/toolbar_ui_api_data_model.mojom:845`), so `is_visible`
  is the 8th argument.
- **Toolchain traps hit tonight:** (a) a PowerShell `Stop-Process` filter that matches on
  `CommandLine -like '*fame-…*'` also matches the agent's own bash command line and kills the shell —
  always add `-and $_.Name -eq 'chrome.exe'`; (b) `mini_installer_archive` fails with
  `PermissionError: [WinError 32]` if ANY chrome.exe is running, so close them before packing;
  (c) `Start-Process -RedirectStandardError` blocks until the child exits — never use it for probes;
  (d) a stale `siso.exe` holding the build lock makes the next chain sit at "waiting for lock holder".

## 2026-11-11 (seventh pass) — omnibox placeholder is SEARCH
User: 'change ""Ask Google or type a URL"" to "SEARCH"'.
- Done in the WebUI layer, **not** the .grd: `chrome/browser/resources/webui_toolbar/readonly_omnibox.ts`
  `getInputPlaceholder_()` now returns `'SEARCH'` instead of `this.omniboxViewState.placeholder?.text`.
  Editing `IDS_WEBUI_OMNIBOX_PLACEHOLDER_TEXT` in `chrome/app/generated_resources.grd` was tried first and
  **reverted**: a value change regenerates `generated_resources.h`, which re-compiles the whole tree
  (36k+ grit edges) for one word — the TS override is a resource-only rebuild (pak + installer, ~5 min).
- Verified on the installed build via CDP: `placeholderText:"SEARCH"`, inner input
  `placeholder` attribute and property both `"SEARCH"`; fresh tab still has no home button, no toolbar
  reload, `chipPresent:false`, back/forward hidden, and the strip still measures
  Reload -30940 / Minimize -30905 / Maximize -30870 / Close -30835.

## 2026-11-11 (eighth pass) — real reload glyph, glass dropdown without trending, ink focus ring, restored profile data
User: the moved refresh used "some ENTIRELY RANDOM DROP SYMBOL"; the search dropdown is a "giant solid white
popup" with "trending searching" he does not want; the search bar "outlined pink when selected, black or
white is fine"; and "WHERE IS ALL MY SADED BOOKMARKS, TABS, INFO".
- **Reload glyph is now Chromium's own** `vector_icons::kReloadChromeRefreshOldIcon` (16 px, via
  `gfx::CreateVectorIcon`) — the earlier hand-drawn segments + chevron read as a droplet. Drawn centred in
  the 35x38 button and tinted `#68717F` -> `#1B1F27` on hover.
- **Dropdown is no longer an opaque white slab**: `omnibox_popup_document_style.css` overrides
  `--color-omnibox-results-background` to `rgba(243,247,252,0.86)` plus a lighter hover overlay. It is a
  `:root` variable override only — stylelint rejects a second `body` selector in that file
  (`no-duplicate-selectors`), and that failed a whole build.
- **Trending searches removed** by deleting the `GROUP_TRENDS` group block from `NtpZpsSection` in
  `components/omnibox/browser/autocomplete_grouper_sections.cc` (the `kOmniboxNumNtpZpsTrendingSearches`
  group). History/recent suggestions are untouched.
- **No pink focus ring**: `location_bar.css` focus state now uses the rail ink
  (`border-color: rgba(27,31,39,.55)`, `box-shadow: 0 0 0 2px rgba(27,31,39,.14)`); `toolbar_button.css`
  `:focus-visible` outline is ink too.
- **Why his bookmarks/tabs/history were missing:** the installed browser opens
  `%LOCALAPPDATA%/Z7/FAME Browser/User Data/Default`, which had **no Bookmarks at all**, while the imported
  profile lives in `D:/FAME-Chromium/profiles/fame-main/Default` (Bookmarks 9713 B — 17 entries in the bar
  including VIA / MUSIC / PIRATE folders, History 3.3 MB, Login Data 311 KB, Favicons, Session/Tabs pairs).
  `temp/restore-profile.sh` backs up the installed profile, copies Bookmarks (+bak, EncryptedBookmarks2),
  History, Login Data, Web Data, Favicons, SessionStorage, Sessions/* and Preferences, then sets
  `session.restore_on_startup=1` and `bookmark_bar.show_on_all_tabs=true`.
- **The favourites strip was empty for a second, deeper reason**: copying `EncryptedBookmarks2` from
  `D:/FAME-Chromium/profiles/fame-main/Default` into the installed user-data-dir makes Chromium reject the
  whole bookmark store (the encrypted container is keyed to the profile that wrote it), so the model loaded
  with 0 nodes and `getFameBookmarks()` returned `{"bookmarks":[]}` even though the plaintext `Bookmarks`
  file had 3 bar children. Deleting `EncryptedBookmarks2`/`.bak` from the installed `Default` and re-copying
  the plaintext `Bookmarks` fixed it: the mojom call now returns the three bar entries (zexy.tv, youtube,
  folder) and the toolbar renders them as chips.

## 2026-11-11 (ninth pass) — favourite Edit, star ink, hover ink, tab-search surface, ad blocker
User: right-click → Edit on a favourite did nothing; the bookmark star "should not turn pink just black or white";
the new-tab and tab-search buttons "turn BLUE on hover"; "the tab search popup also looks not good";
searching/navigating is "SO SLOW AND LAGGY"; and there "should be a built in ad blocker somehow".
- **Edit did nothing** — `WebUIAppMenuControl::ShowFameBookmarkEditorForNode()` treated a live editor bubble as a
  toggle: `if (manager && manager->GetBubbleWidget()) { CloseBubble(); return; }` closed the old editor and
  returned, so the first Edit click looked dead. It now closes any live editor and always opens a fresh one, with
  `force_load_on_create = true` so the surface does not wait for a `Ready()` that never comes.
- **Star was pink** — page-action glyphs inherit `currentColor`, and the chip took the accent. `page_action_icon.css`
  `#button` now pins `color: var(--color-toolbar-button-icon)`; the live toolbar reports the bookmark star as
  `rgb(104, 113, 127)` (#68717F rail ink), not pink.
- **Blue hover** — `material_tab_strip_color_mixer.cc` mapped `kColorTabStripControlButtonInkDrop` and the inactive
  tab hover to `ui::kColorSysStateHeaderHover` (Material accent = blue). Those, the ripple, and the inactive-frame
  hover are now `SkColorSetA(SK_ColorBLACK, 0x10..0x12)` ink.
- **Tab search surface** — `chrome/browser/resources/tab_search/app.css` `:host` now sets
  `--mwb-background-color: rgba(240,244,250,0.94)`, ink selected pill and ink hover/selected list rows instead of
  the accent. Verified live: `div#searchField bg=rgba(240, 244, 250, 0.94)`.
- **Speed** — measured on the installed build: `example.com` navigation `load 200 ms / DOMContentLoaded 170 ms`
  (115 ms in an earlier pass), so the browser is not slow on a trivial page; the build itself is
  `is_component_build = true` (dev layout, ~100 DLLs), which is the standing structural cost. A static
  `is_official_build` build is the real fix and is a full-tree rebuild.
- **Ad blocker** — a bundled host blocklist + a `blink::URLLoaderThrottle` (`chrome/common/fame_ad_blocker.h`, list of
  ~60 ad/tracker domains with suffix matching, top-level navigations always allowed) and a
  `network::SelfDeletingURLLoaderFactory` added to the renderer's factory chain in
  `ChromeContentBrowserClient::WillCreateURLLoaderFactory` (`chrome/browser/fame_ad_blocker_factory.h`,
  `fame::MaybeBlockRequests`). The first two builds blocked nothing: the gate was
  `request.is_outermost_main_frame`, which is **true for every request the main frame makes**, so the
  ad fetches were skipped. Gating on `destination != kDocument` instead (document navigations always
  pass) fixed it. Verified on installed build `2704d11b`:
  `ADBLOCK3 {"analytics":"blocked","doubleclick":"blocked","taboola":"blocked","control":"allowed"}` and
  `NETFAILS ["net::ERR_BLOCKED_BY_CLIENT","...","..."]`. Navigation `load 143 ms / dom 135 ms`.

- **Why the favourite Edit is not clicked through:** `Input.dispatchMouseEvent` right-click on a `.fame-bookmark`
  chip produces **no DOM `contextmenu` event** in the `webui-toolbar` page (listener count stayed `[]`), so the
  views menu never opens and UIA has no `MenuItem|Edit` to invoke (`EDIT_NOT_FOUND`; the probe window's UIA tree is
  tab strip + window controls only). Driving it would need real OS-level mouse input, which the 2026-11-01 rule
  forbids ("no OS-level or global input, never taking over the desktop"). Verification of that one item therefore
  needs either the user's own click or a temporary test hook in the browser process.

### The bookmark editor popup was opening below the window (2026-11-11, tenth pass)
User, verbatim: *"so the fucking problem is that the edit bookmark popup is opening BELOW THE WINDOW, SO
WHEN ITS FULLSCREEN THE POPUP IS JUST SIMPLY NOT VISIBLE AT ALL."* Correct, and it was not the open logic.
- **Cause** — `chrome/browser/ui/views/toolbar/webui_app_menu_control.cc`, chip menu `ExecuteCommand`,
  `case kFameBookmarkEdit: case kFameBookmarkMove:` asked for the editor with
  `browser_view->GetBoundsInScreen()` — the **whole window rect**. `ShowSurfaceBubble()` hands that to
  `manager->ShowBubble(anchor_bounds, views::BubbleBorder::TOP_RIGHT)`, which lays the bubble out *below*
  the anchor rect. Anchored to the window, "below" is below the window bottom; in fullscreen the window
  rect is the screen, so the editor was placed entirely off-screen and could not be seen at all. The
  earlier "Edit does nothing" report and this are the same bug seen with and without fullscreen.
- **Fix** — the chip's screen point is now remembered when its menu opens
  (`fame_bookmark_menu_anchor_ = gfx::Rect(screen_point, gfx::Size(1, 1))` in
  `ShowFameBookmarkMenuInternal`), and the editor is anchored to that 1x1 chip rect, with a top-centre
  window fallback only when the anchor is genuinely empty. The `switch` case gained braces because the
  declaration cannot jump past the following case label (clang error "cannot jump from switch statement").
- **Build** — installed build `ed5ebe1a06101a4e` (build dll == installed dll), user's browser relaunched.
- **NOT verified by a click, remaining:** the chain "right-click chip → Edit → bubble under the chip" needs
  real input. CDP mouse events are dropped for the off-screen probe window (`CLICKS 0`, `CTX []`), UIA can
  invoke a menu item only if a menu exists, and `browserProxy_.onChipMousePressed(id,false)` (the chip's own
  handler, `onLhsChipMousePressed`) did not surface a views menu in the probe window's UIA tree
  (`MENUITEMS` empty, `EDIT_NOT_FOUND`). The placement fix itself is deterministic from the anchor rect.

### Chip saturation 0% still drew the site's colour (2026-11-11, eleventh pass)
User: *"its saying its saturation zero but i can clearl see the red of the youtube logo"*.
- **Two causes, both real.** (1) `chrome/browser/ui/views/toolbar/webui_toolbar_web_view.cc`
  `GetFameBookmarks()` read `fame_saturation` **only inside the custom-icon branch**, so a chip drawing the
  cached favicon kept the mojom default `saturation = 100` and the editor's 0% never reached it.
  The read is now above the icon branch, for every URL chip. (2) `app.html.ts` applied
  `filter: saturate(bookmark.saturation / 100)` to the custom-image and glyph branches but **not** to the
  favicon `<img>`, so even a correct 0 was never applied. The favicon branch carries the filter now too.
- **Measured before** (build `ed5ebe1a`): both URL chips `img.fame-bookmark-favicon`,
  `inlineFilter: "(none)"`, `computedFilter: "none"`. **Measured after** (build `2706517d`, installed =
  build): youtube chip `saturate(0)`, zexy.tv chip `saturate(1)`, folder `(none)`.
- Stored meta confirmed in the live profile: the youtube bar child carries `fame_saturation: "0"`.
- Resource-only rebuilds do not change `chrome.dll`, only `mini_installer.exe` — a runner that waits for a
  new DLL will hang on a `.ts`/CSS-only change; wait on the installer instead.

### Pink star and the "ASK" chip in the search bar (2026-11-11, twelfth pass)
User: *"the star still becomes pink when favourite a page"* and *"why the fuck is there an ASK button that
shows on the search bar"*.
- **Pink star.** The glyph itself is `currentColor`, and `toolbar_chip_button.css:15` paints with
  `var(--toolbar-chip-fg-color, ...)`. `page_action_icon.css` set that variable to
  `--color-omnibox-icon-foreground-tonal` for a **labelled** chip, and
  `omnibox_color_mixer.cc` `ApplyCR2023OmniboxIconColors()` mapped the tonal pair to
  `ui::kColorSysTonalContainer` / `ui::kColorSysOnTonalContainer` — the Material accent. Favouriting a page
  puts the star into its labelled state, so it took the accent and read pink.
  Fixed in both layers: the mixer's tonal pair is now `SK_ColorTRANSPARENT` + `ui::kColorSysOnSurface`, and
  `#button[has-label]` in `page_action_icon.css` pins `--toolbar-chip-bg-color: transparent` and
  `--toolbar-chip-fg-color: var(--color-toolbar-button-icon)`.
- **ASK chip.** It is Chromium's AI-mode page action (`kActionAiMode`,
  `AiModePageActionController::ShouldShowPageAction`). That function now returns false outright; the
  upstream body was **removed** rather than left behind an early return, because clang fails the build with
  `-Werror,-Wunreachable-code` (hit once, build aborted at
  `ai_mode_page_action_controller.cc(190,8)`).
- **Verified on installed build `cbb13796`** (build dll == installed dll): the star glyph reads
  `fill: rgb(0,0,0)` / `color: rgb(0,0,0)`, and a walk of every shadow root in the toolbar finds **no**
  element whose text is "Ask" (`ASKCHIP []`).
- Lesson recorded: `chips.mjs`/`star.mjs` style probes must look for this build's real DOM — the star is
  `g#star-filled` inside an SVG in `page-action-icons`, not a `page-action-icon` custom element.

## Thirteenth pass — Ask chip killed, star confirmed black, hamburger redesigned (2026-11-12 ~21:05)
- The chip that renders "Ask" is NOT kActionAiMode: it is `kActionLensOverlayHomework` (mojom PageActionId 4) —
  read `page_action_id` off the real `page-action-icon.state` in the toolbar DOM, never guess the id.
  `webui_page_action_control.cc` GetState() now returns nullptr for both kActionAiMode and
  kActionLensOverlayHomework. Verified on installed `ead4b35d53dbffad`: toolbar state list = only id 27
  (`Bookmark this tab`), no Ask.
- Star pink is gone: CDP `Page.captureScreenshot` of the bookmark chip rect on `e3487c3a` shows a solid
  black star on white (temp_shots/star.png). CSS colour never showed it; only the baked icon pixels did.
- Hamburger menu (fame_surface `#menu`) redesigned: 336px wide, 281px tall (was 390 x ~430). Kept
  Bookmarks/History/Downloads list + zoom row + one icon strip (find/print/PDF/reader/reopen) + new window/
  private + Settings tile. Removed from the menu as duplicates already present in Settings: Passwords,
  Extensions, Site information. Vertical tabs moved into Settings (Appearance group, data-command
  toggle-vertical-tabs). Old `.navigation-grid`/`.action-grid` CSS deleted.
- Verify the surface without clicking: open `chrome://fame-surface.top-chrome/?surface=menu` as a CDP
  target (Target.createTarget takes no width/height unless newWindow) and screenshot. No input needed.

## Fourteenth pass — folder popup is a FAME WebUI surface with real drag (2026-11-12 ~12:15)

## 2026-11-11 — installed on 156 (moved out of IN-FLIGHT 2026-11-13)
- `releases\Brows-156-Setup.exe` 688,623,616 B @ 23:56 (sha256 7944933…9CEF54) ran with
  `--do-not-launch-chrome`, exit 0, and registered
  `HKCU:\Software\Clients\StartMenuInternet\Brows.S43N7J5LM4OXSV3FWJWCNW6CKI` ->
  `C:\Users\xjpma\AppData\Local\Z7\FAME Browser\Application\chrome.exe`, payload in
  `Application\156.0.8078.80\`. The installed binary was probed offscreen: the toolbar rendered its
  13 children incl. `fame-workspaces`/`app-menu`, and the hamburger opened
  `chrome://fame-surface.top-chrome/` (title `Brows`, 390 px, 19 menu buttons). Workspace delete was
  proven (2 cards -> Delete -> 1 card, tabs moved to Main) and tab search filtered real tabs.
  A second pass fixed the four reported regressions (no Google API-keys infobar, no first-run scene,
  glass tabs with 0 pure-white px, no AI/Glic entry, no second bookmarks row).
