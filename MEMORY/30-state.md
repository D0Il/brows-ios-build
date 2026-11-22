<!-- IN-FLIGHT:BEGIN -->
Last updated 2026-11-21 16:10 UTC (iOS: the extensions "deviation" struck as a platform fact; settings engine row moving to the desktop select).

- **Swift runs here.** `npm run swift:check` parses 28 app files + the UI test, 5 design rules and the
  Foundation-only logic (`AddressResolver`, 16 cases) on Windows. Parse is not typecheck: it passed
  while `browsGlass` was missing and CI failed.
- **iOS is Apple's Liquid Glass.** `Theme.browsGlass(cornerRadius:)` is iOS 26's
  `.glassEffect(.regular, in:)`; `GlassPane` is only the pre-26 fallback. All ten sheets clear the
  platform fill and carry the glass; cards use `browsGlassBackground`; rail, pill and top tab too.
- **Glass on a control eats its tap.** `.glassEffect` inside `GlassCircleButtonStyle` /
  `CompactControlStyle` (even non-hit-testing) made `rail.menu` dead (44566830763, 44571964757,
  44579489323: "menu did not open"). Plates restored -> green. Glass lives on panes/cards/rail/pill.
- **Named window reopens after its popup closed.** Green 44545329527; red 44548334284 on `2b0b83a`;
  fix restored in `0f1f5b5`. `testNamedWindowReopensAfterItsPopupIsClosed` + `named-fresh` fixture.
- **Record `44684721575` on `20103c6`:** 37 tests, 0 failures, 1045.211 s, 34 captures, all
  inspected. Paired against rendered desktop surfaces (`port/site` + `chrome://brows-surface`) with a
  seeded profile (3 visits, 4 bookmarks + folder, the build's extensions). Verdicts and file names:
  `47-ios-desktop-pairs.md`; captures `docs/parity/desktop/`, pairs `docs/parity/pairs/`; drivers
  `tools/oneoff/shoot-desktop-{surfaces,app}.mjs`, `tools/oneoff/pair-desktop-ios.py`. Fixed:
  `fdd9b1e` plates/ink in dark; `ea0e802` settings cards; `20103c6` 14x14 checkbox + site-info rules.
  History now renders: the delegate is set (`webui_app_menu_control.cc:626`) and `getHistory('')`
  returned 3; the panel was throwing on `new Date(BigInt)` because `last_visit_ms` is int64 -
  `tools/oneoff/fix_surface_int64.py` converts it and `resources.pak` was rebuilt, so
  `history-{light,dark}.png` show three rows (proven). Downloads and passwords stay bounds with
  proved the same shape of bug in both: the panels read process-local views, and now fall back to
  `HistoryService::QueryDownloads` / `PasswordStoreInterface::GetAutofillableLogins`
  (`tools/oneoff/fix_surface_persisted.py`), so the seeded download and saved login both render.
- **The ipa is signed now.** CI used to zip the device build unsigned (no keychain group, -34018);
  it ad-hoc signs with `Brows.entitlements` and asserts it. `releases/Brows-ios-44821441476.ipa`.
  Device install still needs a signing identity; keychain on hardware unproven.
- **Five capture defects closed.** Alerts were glass (page text showed through), plate buttons had
  no rim on a white sheet, suggestions clipped their last row, the downloads size line sat under
  the icon. Fixed and re-captured (`docs/parity/ios/after/`); open: passwords form, folders, pill scroll.
- **Two trees.** The captures come from `5fbd41c` in the build mirror `D0Il/brows-ios-build`
  (`.freebuff/tmp/ios-build-repo`), which holds only `ios/Brows/**` + the workflow. This project repo
  is the source of truth; the app code was committed there as `c296977`, and the parity pass is
  built from `fdd9b1e`. The mirror holds only the app + workflow, so its `fdd9b1e` tree must equal
  this repo's `ios/Brows` tree (`diff -r`), and HEAD is the commit carrying this block.
- **Open, named bounds:** none of the seven pairing surfaces is bounded by missing content any more;
  the
  bookmark list has folder tabs on desktop vs a flat phone list; settings' engine row is a segmented
  control vs a `<select>`; rail/pill/omnibox/suggestions
  are native views and their WebUI hosts never commit headless; no loading state in the set.
  Simulator bounds: hardware install/Keychain, Mail, real OAuth, glass over a photograph.
- **Not a deviation: extensions.** iOS is WebKit-only (App Store 2.5.6), so the phone has no
  Chromium extensions at all; the panel states that and its blocker row is a WebKit content-rule
  list. Drawing the desktop's `Enabled` + `⋯` extension row there would fake a feature the platform
  forbids, so that bound is struck rather than "fixed", and it is not a parity gap to close in any
  later pass. The menu row and the panel now name what exists — `Content blockers`, shield icon —
  instead of a puzzle-piece `Extensions` entry that opened on "there are no extensions".
- **Standards:** Apple Liquid Glass for panes; white plates, dark ink on controls; no fake chrome;
  private mode coherent, no sync. Dated passes: `34-state-ios.md`.
<!-- IN-FLIGHT:END -->



## 2026-11-15 — moved out of IN-FLIGHT (dated snapshot, newest first)

- **2026-11-15 21:1x — what the republished 156 build carries, and the extension loss (detail for the
  IN-FLIGHT entry above, all measured on the running browser).**
  The tab-search chevron can only run tab search: `TabSearchOnlyButtonController` on the
  `kActionTabSearch` button in `chrome/browser/ui/views/tabs/shared/tab_strip_combo_button.cc`,
  because that button's action view interface re-installs its own pressed callback on every action
  update, so a bound callback alone was not authoritative. Measured 2→2 and 3→3 tabs with a pinned
  tab, and `ShowTabSearch` → `ShowTabSearchBubble` in the log.
  `UseStringsJs()` was added to `webui_toolbar_ui.cc`, `omnibox_everywhere_ui.cc`,
  `omnibox_popup_ui.cc` and `tab_search_ui.cc`: `strings.m.js` is served only when it is set
  (`content/browser/webui/web_ui_data_source_impl.cc:567`), and without it every one of those pages
  died on `No data. Did you remember to include strings.js?` — that is why `toolbar-app` never
  upgraded and the band looked empty. Measured after: `toolbar-app` mounted with 12 children and
  `#locationBar` at `[8,4,1721,32]` (1209 px in the smaller window). The two `strings.m.js` script
  tags are `type="module"` (as classic scripts they threw `Cannot use import statement outside a
  module`), and `brows_surface.ts` no longer dies on `browsSurfaceChrome.send is not a function`.
  `scripts\publish-site.ps1` fix: the 20:2x run wrote the feed, printed `uploading in parts`, never
  uploaded, and died before the `brows-site` deploy — under `$ErrorActionPreference = 'Stop'`,
  PowerShell 5.1 turns wrangler's stderr into a terminating `NativeCommandError`, so the temp-Worker
  step threw and the `finally` cleanup masked it; R2 kept the previous installer (`83b547c2…`,
  688,826,880 B) while the feed advertised that old sha. Both npx calls now run with `Continue` and
  only their exit codes decide success (`PARSE_ERRORS=0`).
  Extension loss: at **01:38** the profile's `Extension State` was rewritten and `path`/`location`
  were dropped from `Secure Preferences`, after which Chromium's `extension_garbage_collector`
  deleted `Default\Extensions` (folder mtime 01:38:13). All 7 real extensions existed in full in
  `%APPDATA%\Opera GX Stable\Default\Extensions` and were copied back by ID (Tampermonkey 5.5.1,
  Video Downloader Professional 2.1.7, AdBlock 6.53.0, BTRoblox 3.7.1, Video Download Helper
  10.7.1.2, Video Speed Controller 0.11.1, one 3.4.0); they are **not registered** — Chromium only
  adopts folders it has metadata for, no prefs backup exists, and a launch flag is not a durable
  mechanism (the unquoted `--load-extension` list broke both launchers; both were restored to their
  original `--source-shortcut-location=…` argument).


- **Tab-search popup was a 39 px sliver, not a taste complaint — fixed 2026-11-14 (commit
  `1b92f7ceb8`, published installer sha `86ea151a4f8838c8…`).** Measured on the installed build
  with `tools/oneoff/check_tab_search.py`: the chevron *did* open the Brows surface
  (`chrome://brows-surface.top-chrome/?surface=tab-search`) and its accessibility tree did hold
  the four real tabs, but the bubble window itself measured **344x39** — only the search field.
  Cause: `brows_surface.ts` only sent `browsResize` from the workspace (line 128) and folder
  (line 2368) surfaces; tab search never did, so the fixed bubble kept its creation size and clipped
  every row and the footer. Fix: `resizeTabSearchSurface()` sends `browsResize [344, height]` after
  the rows, the empty state and the recently-closed section are laid out. Re-measured: bubble
  **344x270**, capture shows the search field, four rows with favicon/title/host, per-row close, and
  `4 of 4 tabs · ↑↓ move · Enter switch · Esc close`. Probe notes: `band_uia.ps1` takes
  `-Band -ProcId` (PowerShell reserves `$Pid`); the bubble is its own HWND, so it must be captured
  separately from the main window.

- **Media control on the playing tab — DONE and measured 2026-11-14 (installed `chrome.dll
e994754b29c8a6c8`, commit `f51996641c`, published installer
`97953416202e49c57706ec1edb97bece6d509076ab016ec32bafee811c7a281b`).**
  `tools/oneoff/check_media_button.py` → `CHECK_EXIT=0`: strip has no media control, exactly one
  media button, inside the playing tab, opens `MediaDialogView` on click. `tools/oneoff/measure_tab_glyphs.py`
  on a real PrintWindow capture: speaker ink `y 14..23 h=10 c=18.5`, note ink `y 14..23 h=10 c=18.5`,
  close ink `y 15..22 h=8 c=18.5` — same height and centre line, nothing clipped.
  The icon must be passed an explicit size: `ImageModel::FromVectorIcon` defaults `icon_size = 0`
  (native canvas, `ui/base/models/image_model.h:89`), which painted the 24-unit glyph at 24 px into
  a 16 px box — that was the glyph overflowing and clipping at the bottom.
  `brows_music_note.icon` is generated by `tools/oneoff/make_music_icon.py` from upstream
  `queue_music.icon`'s own note subpath (Material's music note), scaled to 10 px of ink and centred;
  the three list lines are dropped. Hand-written paths read as stray strokes at 16 px — do not
  hand-draw this glyph again.
  Runtime notes: a page only plays if the window is visible, so the capture/check scripts launch with
  `--disable-features=CalculateNativeWinOcclusion --disable-backgrounding-occluded-windows
  --disable-renderer-backgrounding`; `Page.setWebLifecycleState` **crashes** this build — never use it.
  UIA rects for this window come back in client coordinates; post clicks with them as-is.

- **Earlier framing of the same work (kept for the trail).**
  The strip's WebUI media button must not exist; the control is a music-note button on the tab that
  is playing, left of that tab's Close, with the tab's existing speaker (audio) indicator untouched.
  In tree: `views::ImageButton` child of `Tab` (`tab.h`/`tab.cc`: `media_button_`,
  `media_item_observation_`, `UpdateMediaButtonVisibility`, `MediaButtonPressed`), unpinned tab with
  an active media session only, opens `MediaDialogView`.
  `webui_media_toolbar_button.cc` sends `should_be_shown=false` from `UpdateState()` — a no-op
  `Show()` alone was not enough (measured: button still painted at 1157,40 34x34).
  First runtime pass on installed `chrome.dll 4c875381…` found no tab button: the tab sampled
  visibility only from its constructor, when `MediaNotificationService` does not exist yet (created
  on demand), so no observation ever started. Fixed by re-checking from `OnTabDataChanged` and
  observing the manager the first time it appears. Rebuild + single pass pending.

- **Pinned tab favicon — verified 2026-11-14.** Blank pinned tabs came from the width guard in
  `tab.cc` (`GetMinimumInactiveWidth()` is 92 px under glass); now skipped when `data().pinned`.
  Installed `chrome.dll 4c875381…`, one visible pass: pinned tab `31,0 64x38` paints 157 distinct
  colours where a blank pane paints 1 (`verify_visual_pass.py`).

- **Pin survives an immediate close — verified 2026-11-14** on installed `chrome.dll 968f733d…`:
  `probe_pin_persist.py` → `CHECK_EXIT=0`, `tab0 pinned after restore: True`. Pin 0.58 s before a crash kill was lost:
  session file byte-identical at pin time, and `SessionServiceBase::SetPinnedState` (only writer of
  `kCommandSetPinnedState`) has **no caller anywhere** in `chrome/`, so pins reached disk only via
  the clean-exit full-session build. Fix: `SetPinnedState` now calls `FlushPendingCommands()`
  straight after `ScheduleCommand`; the earlier `BrowserTabStripController::OnTabPinnedStateChanged`
  flush was removed (measured: it ran before anything was recorded and wrote nothing).
  Probe: `probe_pin_persist.py`.

## 2026-11-14 — moved out of IN-FLIGHT (dated snapshot, newest first)

- **2026-11-14 tab context menu fix.** Every row in the tab right-click popover was dead: rows
  carry `TabStripModel::ContextMenuCommand` ids but activation sent them to
  `chrome::ExecuteCommand` (different id space), and id 0 was rejected by `command_id <= 0`.
  Now `TabStripModel::ExecuteContextMenuCommand` at the popover's tab, after
  `IsContextMenuCommandEnabled`, without activating the tab. Commit `32113bf120`; installed
  `chrome.dll 349f0dfe…`, installer sha `fcdb30f3…` published (`PUBLISH_EXIT=0`).
  `tools/oneoff/check_tab_actions.py CHECK_EXIT=0` (Duplicate 2->3 tabs, Pin flips the row to
  Unpin, Close 3->2). The `&tab=` URL carrier only survives `Page.navigate`, not `/json/new`,
  and `TabMenuModel`'s ctor dereferences its index: pass the resolved one or NOTREACHED in
  `tab_collection.cc:279`.

- **2026-11-14 release state.** Fork commits: `97b457d4e5` (crash plate + Chromium text) and
  `111ae7c557` (extensions pane runs the action; PDF viewer renamed); tree clean. Installed and
  published `chrome.dll 571b0b87…`, installer sha `91b354f9…` — `https://brows.dev/latest.json`
  serves the same sha (`PUBLISH_EXIT=0`). Both checkers pass on the installed build:
  `check_extension_popup.py CHECK_EXIT=0` (popup.html target, no chrome://extensions tab) and
  `check_restore_plate.py CHECK_EXIT=0` (plate visible, mono ink button).

- **2026-11-14 — the extensions pane runs the extension action, not a tab.** User: clicking an
  extension in the Brows extensions pane opened the extension as a full tab instead of its popup.
  Cause: `chrome/browser/resources/brows_surface/brows_surface.ts` (row `open` click) called
  `openExtensionOptions` when the extension had options and `manageExtensions` otherwise — both are
  tabs, and there was no action path in the mojom at all.
  Fix: new `ActivateExtension(string id)` command → `WebUIAppMenuControl::ActivateBrowsExtension`,
  which finds the toolbar view via `views::AsViewClass<WebUIToolbarWebView>(delegate_->GetView())`
  and calls `ExecuteExtensionAction(id, is_pointer_interaction=true)` — the same call the toolbar's
  own extension button makes, so a `default_popup` opens the real `ExtensionPopup` bubble anchored to
  the toolbar and an actionless extension runs its click handler. The surface closes itself on
  success; Options stays an explicit entry in the row menu. `ExecuteUserAction` CHECKs its id, so a
  `HasAction(id)` probe was added through `WebUIToolbarExtensionsContainer` →
  `WebUIToolbarExtensionsContainerWrapper` → `WebUIToolbarWebView::HasExtensionAction`, and the
  surface command returns false for ids with no action instead of crashing.
  Measured on the installed build (`chrome.dll 1e16f886…`) with a probe extension whose manifest has
  `action.default_popup`: `tools/oneoff/check_extension_popup.py` loads it, opens
  `?surface=extensions`, clicks the probe row, then sees
  `chrome-extension://jpmhapnknjlkfbmiobkbinoaaalccekh/popup.html` as a target and **no**
  `chrome://extensions` or `chrome://settings` tab — `CHECK_EXIT=0`, twice.
  Also removed the last hardcoded "Chromium" a user can see: the PDF viewer's name,
  `chrome/browser/pdf/pdf_extension_util.cc:340` (`kExtensionName`), which is substituted into
  `chrome/browser/resources/pdf/manifest.json`'s `<NAME>` tag and showed as "Chromium PDF Viewer"
  in the extensions pane; it is "Brows PDF Viewer" now.

- **2026-11-14 — crash-restore plate is now a Brows surface; "Chromium" swept out of UI text.**
  User report: the restore popup said *Chromium didn't shut down correctly*, was not glass and had
  a blue button.
  Cause, file+line: `components/components_chromium_strings.grd:307-309`
  (`IDS_SESSION_CRASHED_VIEW_MESSAGE` = "Chromium didn't shut down correctly."), and
  `chrome/browser/ui/views/session_crashed_bubble_view.cc:ShowBubble` built a native
  `BubbleDialogModelHost` — native bubbles cannot paint glass and take their action colour from the
  theme accent, which is where the blue came from.
  Fix: the plate is `chrome://brows-surface.top-chrome/?surface=restore`, a normal Brows glass
  surface. `ShowBubble` now creates a `WebUIBubbleManager<BrowsSurfaceUI>` (same path as every other
  Brows bubble), sets the bubble transparent, keeps it non-dismissible by clicking away, and holds
  an `ExitTypeService::CrashedLock` until Restore/Start fresh. New mojom commands
  `RestoreCrashedSession`/`DismissCrashedSession`; the handlers live in `WebUIAppMenuControl` and
  call new statics on `SessionCrashedBubbleView`, which run `SessionRestore::RestoreSessionAfterCrash`
  (or drop the lock for a fresh start).
  Text sweep (user-visible strings only, `desc=` untouched): every "Chromium" in
  `components/components_chromium_strings.grd` message text (24 lines: firewall/network, blocked
  page, payment-method dialogs, flags relaunch, crash reporting, logo alt, secure-page label,
  Bluetooth, debug pages, tips) is now "Brows"; `components/privacy_sandbox_strings.grd` (2 lines,
  Incognito third-party cookie text) likewise. The two credit lines on `chrome://version` keep
  "Chromium" **as the linked open-source project** ("Brows is made possible by the Chromium open
  source project"). No other user-visible occurrence exists: `chrome/app/chromium_strings.grd` has
  zero, `chrome/app/generated_resources.grd` has only `desc=`/`<ex>` text, and the remaining hits in
  `chrome/browser/resources` are source comments.
  Measured after install (`chrome.dll e979e9b5…`): the startup bubble target
  `chrome://brows-surface.top-chrome/?surface=restore` exists with anchor `17,48 931x38`,
  `document.body.innerText` = "Restore pages? / Brows didn't shut down correctly. / Start fresh /
  Restore", primary button `rgba(27, 31, 39, 0.92)` on white — no accent colour. The plate was also
  opened directly as a target to check CSS in isolation before the crash path was fixed.
  Traps paid for here: (1) a `run_terminal_command` heredoc over ~9 kB is silently truncated — write
  the script to a file instead; (2) a mojom command needs **both** a `Delegate` virtual and an
  out-of-line declaration inside `BrowsSurfaceUI` (`brows_surface_ui.h` ~line 336), or the class
  silently becomes abstract and `TopChromeWebUIConfig`'s constructibility static_assert fires;
  (3) `-Wexit-time-destructors` is fatal under `/WX`, so file-scope `std::unique_ptr`s must be
  `base::NoDestructor`; (4) in 156 it is `display::Screen::Get()`, not `GetScreen()`;
  (5) top-chrome surface targets report `type: "browser_ui"`, so a checker must match by URL, not by
  `type == "page"`; (6) `-j 8` on this machine OOMs clang ("LLVM ERROR: out of memory" / "paging
  file is too small") — 4 workers completes.
  (7) Python `io.open(...).read()`/`.write()` normalises CRLF to LF: `brows_surface.ts` and `.css`
  are CRLF in this tree, so the first commit showed 5 407/5 266 lines of bogus churn. Restore the
  previous ending per file (`git show HEAD~1:<path>` and count `
`) before committing; the real
  diff is 229/88.

- **2026-11-13 21:2x — release, backup, cleanup, audit (all measured).**
  Site republished from the installed build: live `latest.json` sha256
  `f0e447af13a42a7de1e5b87c749bab468293a0aefcbc84618432c8e4ff80a8bd` = `sha256sum` of
  `releases\Brows-156-Setup.exe` (688,824,832 B), `PUBLISH_EXIT=0`; the BR0WZ gate still answers
  401 on `/` and `/download` as instructed.
  Source committed: **`bbe0e440e2`** "Brows 156: site panel cookies, storage and connection;
  settings self-check" (169 files, working tree clean afterwards).
  Backups in `D:\FAME-Chromium\backups\20261113\`: installer copy + `SHA256.txt` +
  `latest-feed.json`, and a 1.3 GB profile copy (96 entries in `Default`). Robocopy needs
  `MSYS_NO_PATHCONV=1`, or the `/E` switch is rewritten into `E:/` and it exits 16.
  Cleaned: build/publish logs, dead probe scripts, nine probe profiles and the one-off patch
  scripts. `tools/oneoff` keeps only the checkers that work.
  Audit of the whole record: `MEMORY/50-needs-audit.md` (all 286 user messages).

- **2026-11-13 21:0x — site-info panel: cookies, site data and connection (installed).**
  `GetSiteInfo` now also returns `connection_label`/`connection_detail`; two new calls,
  `GetSiteCookies` (CookieManager `GetCookieList`, names only) and `GetSiteData`
  (`BrowsingDataModel::BuildFromDisk`, per-type sizes), fill the new sections. Build
  `CHAIN_EXIT=0`, installed `chrome.dll 87abe783…` and `resources.pak e3e48a59…` on both sides,
  installer 688,824,832 B @ 21:02.
  Runtime (installed build, surface rendered): CONNECTION / COOKIES / SITE DATA / PERMISSIONS
  sections paint, per-section headers and empty states included.
  **NOT verified:** the numbers on a real site through the product's own path. The panel reads the
  window's ACTIVE tab, and every scripted way of opening it makes the panel itself active
  (tab-hosted surface -> "This page", empty permissions). The real path (Brows menu -> Settings ->
  "Site permissions") is unreachable from outside: the menu bubble exposes neither a CDP target
  (12 s of polling, only toolbar/omnibox targets) nor accessible names to UIA. Needs one human click.
  Traps this cost: `StoragePartition::GetCookieManager` is `GetCookieManagerForBrowserProcess`;
  `GetCookieList`'s C++ callback carries `net::CookieWithAccessResult` (not the mojo `Ptr`);
  `CanonicalCookie::ExpiryDate()` is a `base::Time` whose null value means session;
  `security_state` has no `SECURE_WITH_POLICY_INSTALLED_CERT`; `NavigationEntry::GetSSL()` is non-const;
  `base::StringPrintf` needs a literal format, so the unit branch must be if/switch, not a ternary.

- **2026-11-13 — correction: History/Downloads "empty panel" was my probe, not the product.**
  Both panels showed only static headers because the probe had navigated the only tab to the menu, so
  the window's active tab was a `chrome://` page and `GetBrowsHistory` returned nothing to show. Not a
  defect; not evidence either — those panels still need a pass with the site tab active.

- **2026-11-13 20:0x — Settings auto update check fixed; folder right-click PROVEN (installed).**
  `runUpdateCheck()` moved from module scope into the `ready()` chain's settings branch
  (`brows_surface.ts`): opening `?surface=settings` now answers without a click —
  measured `"Brows is up to date (version 156.0.8078.80)."`, `install_hidden: true`.
  Folder flyout right-click proven against a copy of the real profile's `Bookmarks`
  (`tools/oneoff/check_folder_menu.py`): folder id 6, 3 rows; contextmenu on row id 22 created
  `?surface=bookmarkactions&id=22` as its **own** bubble with `role=menu` and rows
  `Open · Open in new tab · Open in new window · Edit · Move · Delete`; no inline `.folder-context`.
  Installed `resources.pak` `de5ed80e56c0` on both sides, installer 688,789,504 B @ 19:58.

- **2026-11-13 19:5x — updater re-checked: it exists and works (correction).** Clicking
  `#check-updates` in the installed build fetched the live feed and printed "Brows is up to date
  (version 156.0.8078.80).", with `#install-update` staying hidden. Open defect: opening the Settings
  surface does **not** run the check automatically (measured: status stays "Updates have not been
  checked yet") — the module-level call fires before `proxy.handler.ready()` resolves.

- **2026-11-13 19:3x — site republished with the new installer; preview loop measured.**
  `publish-site.ps1` run against `Brows-156-Setup.exe` 688,789,504 B → `PUBLISH_EXIT=0`, feed
  `port/site/latest.json` sha256 `12c658661af25325aed32aced11569d876c26beb303b8e96b0fc2b5db0aa0f7d`
  (equal to the on-disk installer), "Published 156.0.8078.80 to brows.dev", `download.html` size
  re-derived to 656.9 MiB by the script. `scripts\preview-webui.cmd menu --no-launch` measured
  **4m05s** for a no-op pak build (manifest load dominates); a real CSS/TS edit adds only the pak
  regen — no relink, no install, no browser close. Project tree cleaned: 8.4 GB of stale siso logs and
  probe profiles deleted from `D:\FAME-Chromium	emp`, loose root logs removed, and the old
  `reference/electron-ui` tree deleted so nothing can send a future session back to it.

- **2026-11-13 19:0x — dark mode, keyboard/menu semantics, Snap Layouts, ledger, preview loop (installed).**
  `chrome.dll` `4427a765df06`, `resources.pak` `cbe456a67592`, installer 688,789,504 B @ 19:05 (two
  chains: C++/frame change, then the TS selector fix). Verified in the running build, not by eye:
  dark tokens under CDP `Emulation.setEmulatedMedia` flip `.surface` to `rgba(24,28,35,.94)`, ink
  `#f2f4f8`, plate `34,38,45`; `ArrowDown` on `#menu` moves focus 0→1 (`roving=1`, History);
  `#bookmarkactions-list` carries `role=menu`. **Snap Layouts**: 36 sampled points in the top-right
  corner of the installed window answer `WM_NCHITTEST` = `HTMAXBUTTON` (first at 44 px from the right
  edge), so Windows will draw the hover flyout. Still unexercised: the hover itself, and the
  folder-row right-click path. New: `MEMORY/40-parity-ledger.md`, `scripts/preview-webui.cmd`.

- **Bookmark folder flyout right-click 2026-11-13 23:2x (shipped, runtime-unverified).** Rows in
  `?surface=folder` now open the strip's pearl bookmark-action menu as its own bubble:
  `brows_surface.mojom` `ShowBookmarkActionsAt(id,x,y)` → `BrowsSurfaceUI::ShowBookmarkActionsAt` →
  delegate → `WebUIAppMenuControl::ShowBrowsBookmarkActionsAt` → `ShowBrowsBookmarkMenuInternal(..., true)`.
  The inline `.folder-context` menu and its CSS are deleted. Pink folder glyph fixed in
  `brows_surface.css` (`.folder-icon.is-folder` transparent + `#68717f`). Chain `CHAIN_EXIT=0`;
  installer exit 0; installed `resources.pak` = build `6d48da6d8a5f` (`chrome.dll` unchanged at
  `efeb7f9c…`, as expected — CF/TS ship in the pak). **Not exercised:** the right-click itself; the CDP
  probe's seeded profile produced no folder rows, so the click path has no runtime evidence.

Last updated 2026-11-13 00:30. Dated detail: `31-state-ui-passes-a.md`, `32-state-ui-passes-b.md`
(UI passes), `33-state-site-release.md` (brows.dev + installer).
- **156 chain GREEN 2026-11-13 00:05/00:12 + runtime pass (measured).** The 23:24 build aborted on the
  passwords surface (`brows_surface.mojom.cc:12213` DCHECK, dropped `GetPasswordsCallback`); fixed by
  wrapping the three deferred replies (Get/Export/ImportBrowsPasswords) in
  `mojo::WrapCallbackWithDefaultInvokeIfNotRun`. `out\Fame156\chrome.dll` 176,961,536 B @ 00:05;
  `D:\FAME-Chromium\releases\Brows-156-Setup.exe` 688,808,960 B @ 00:12, sha256
  `d304253a96a4b351f7448543514a3031940cc0030d3985b85e060998414cc370`; chain feed @ 00:13;
  `CHAIN_EXIT=0`. Offscreen (`tools/oneoff/probe_156_surfaces.py`): toolbar mounts 11 ids, and
  menu/passwords/siteinfo/settings/downloads all mount with the browser alive.
- **Installed + published 2026-11-13 00:5x (measured).** Setup ran `--do-not-launch-chrome`, exit 0;
  `AppData\Local\Z7\Brows Browser\Application\156.0.8078.80\chrome.dll` = 176,961,536 B, sha256
  `2fbee6df99…` (byte-identical to the build). R2 `brows-releases` holds the installer under both
  `Brows-156.0.8078.80-Setup.exe` and the site's stable alias `Brows-156-Setup.exe` (688,808,960 B
  each); `https://brows.dev/latest.json` serves `d304253a…`; apex still gates at 401 without `BR0WZ`.
  `publish-site.ps1` now uploads both keys and retries the live feed instead of throwing on the first
  read; `tools/r2upload/upload.py` waits for the Worker route and retries each 64 MiB part.
- **User data was NOT in the renamed install (fixed 2026-11-13 01:1x).** The FAME → Brows rename
  moved the profile directory, so the new build opened empty (no `Bookmarks`, 0 history, 0 logins)
  while the real 1.2 GB profile (13 bookmarks, 2,276 history URLs, 365 logins) sat in
  `Z7\FAME Browser\User Data`. Copied it into `Z7\Brows Browser\User Data`, set the empty one aside
  as `User Data.fresh-20261113`, relaunched: 17 processes, `New Tab - Brows`, 0 FATAL, profile counts
  confirmed. See `MEMORY/20-domain-rules.md` §"The product rename splits the profile".
- **Installed build launched 2026-11-13 00:59:** 9 `chrome.exe` processes from
  `Z7\Brows Browser\Application`, window title `New Tab - Brows`, zero `FATAL`. Log noise after a
  clean start: `WebUIReadOnlyOmnibox::ApplyCaretVisibility()` (upstream stub) and
  `new_tab_ui.cc:54 Requested load of chrome://newtab/ for incorrect profile type` — upstream's own
  sanity check that a NORMAL profile must not host the raw `chrome://newtab` URL; not a crash and the
  tab still loads. `download.html` said 656.7 MiB; corrected to 656.9 MiB (688,808,960 B) and the
  `brows-site` Worker redeployed (version `52fac7c4`), verified through the gate: `/download` 200 with
  `656.9 MiB` and the alias link.
- **brows.dev PUBLISHED 2026-11-12; updater feed `https://brows.dev/latest.json`; R2 bucket
  `brows-releases`; installer staged at `D:\FAME-Chromium\releases\`.** Detail in 33.
- **Upstream `NOTIMPLEMENTED` stubs stay as shipped:** `WebUIPinnedToolbarActions::GetDownloadButton()`,
  `WebUIReadOnlyOmnibox::ApplyCaretVisibility()` — log-only, call sites nullptr-guarded.

## 2026-11-03 — shipped and verified (moved out of IN-FLIGHT)
- **Bookmark strip (2026-11-03):** fixed and runtime-verified on the rebuilt `chrome.dll`:
  chips reorder by drag, a chip dropped on a folder's middle moves inside it (the move
  persisted to the test profile's `Bookmarks` after exit), folder clicks open the native
  flyout, folder right-click opens Edit/Move/Delete, and right-clicking a URL or nested-folder
  row inside the flyout opens that node's editor.
- **Favicon correction (2026-11-03):** the earlier YouTube-in-folder capture was invalid
  evidence for the reported bug: it moved a pre-existing YouTube bookmark that already had a
  cached icon into the test folder. The actual imported folder entries had no favicon rows
  because the Opera import omitted the `Favicons` database. Merged 12 exact Opera type-1 icons
  (60 bitmaps, 12 mappings) into `fame-main/Default/Favicons`; existing Brows mappings were not
  replaced. Backup: `D:\FAME-Chromium\temp\fame-main-favicons-backup-20261103-144512.db`.
  Fresh-profile first open of the real folder now renders the VIA icon, and the MUSIC submenu
  renders DISTRO, SPOTIFY, APPLE MUSIC, SOUNDCLOUD, ITUNES, BPM KEY and YT MP3 icons
  (`.freebuff/tmp/real-folder-via.png`, `.freebuff/tmp/real-folder-music.png`). The 14:27 build
  also contains the first-open preload and this cold first open passed. No commit was made.
- **Vertical tabs (2026-11-03):** the native Chromium vertical-tab strip is exposed in
  Brows through the app menu (`Vertical tabs`). `kVerticalTabsLaunch` is enabled by default so
  the command is live; the Mojo command routes to `IDC_TOGGLE_VERTICAL_TABS` (`fame_surface.mojom`,
  `fame_surface.ts`, `fame_surface.html`, `webui_app_menu_control.cc`). Built 14:58; runtime
  round trip verified on the disposable profile: vertical 823 px content / horizontal 1200 px,
  `vertical_tabs.enabled` persisted true then false, toolbar stayed alive with 3 bookmark chips.
  Evidence: `.freebuff/tmp/verify_vertical_tabs*.py`, `vertical-tabs-back.png`.
- **Sidebar:** explicitly rejected by the user on 2026-11-03; not built and not planned. Vertical
  tabs are a separate native tab strip and stay.
- **Completed:** Opera GX -> Brows import into `D:\FAME-Chromium\profiles\fame-main`; Brows relaunched and verified after a real load. Existing Brows data preserved.
- **Bookmarks:** 13/13 Opera bookmarks imported with hierarchy; 14 total incl. the existing Brows bookmark. Checksum validated after load (`e799e26b6280d87714648e30df844741`).
- **History:** all 2,222 Opera URLs represented (2,220 new; 2 already existed) and all 5,583 Opera visits. Final DB: 2,239 URLs / 5,722 visits (includes the 19 original URLs and the post-launch Google visit).
- **Autofill:** 1,017 unique rows; 1,016 new, the one shared row merged.
- **Logins:** all 364 Opera logins represented; 365 total incl. Brows' existing login. Every row was re-encrypted with the Brows DPAPI/AES-GCM key and all 365 decrypt successfully with that key. Brows `Local State` key was not replaced.
- **Backup:** `D:\FAME-Chromium\temp\fame-main-opera-import-backup-20261103-123503` (bookmarks, History, Login Data, Web Data, Local State, Preferences). Opera profile was read-only.
- **Recovery:** `npm run resume` gates 12/12; live era read to EOF. That DB snapshot ended at `run skill` (02:47 UTC) and predates the `14:58` vertical-tabs build; current state is this session's.

## Security status 2026-11-03

- **Brows is Chromium 152.0.7961.0, inside the affected range for the four Chromium CVEs fixed in**
  **156.0.8078.73** (CVE-2026-118306, -118331, -118344, -118348). The first is the 9.6
  out-of-sandbox RCE; the other three are 8.8 inside-sandbox. No matching backport commit exists in
  this tree. A Chromium rebase/security backport is required; this is not a popup/CSS or
  Playwright-package fix.
- The auth gate (`tests/auth-persistence-smoke.mjs`) uses Playwright only as the driver and passes
  `executablePath` to the Brows binary; it does not launch Playwright's bundled Chromium.
  `.codex-tools` pins Playwright 1.61.1 / Chromium 149.0.7827.55; the separately cached
  156.0.8078.4 is not used by this test. System Chrome is 156.0.8078.80. Deleting Playwright does
  not fix the Brows binary.

## Correction 2026-11-02 — quotes from the record, not checks, put work back in the open column
- **Tab search observed 2026-11-02.** One real click on the chevron (UIA finds the native button by the
  name "Tab search" but exposes no InvokePattern, so the click was `SetCursorPos` + `mouse_event` at its
  bounds) opened `chrome://fame-surface.top-chrome/?surface=tab-search`. It listed **11 real tabs** with
  title + workspace name ("Subscriptions - YouTube / Main"), a favicon and a close button per row, the
  active tab marked `active`. Typing `youtube` in `#tab-search-input` filtered 11 rows down to the 2
  YouTube tabs. So the popup is the FAME surface, it lists the real tab strip, and it searches.
- **Tab search, attempt without the user's click (2026-11-02):** `chrome://tab-search.top-chrome/`
  exists as a browser_ui target and is Chromium's own page (title "Tab Search", 22 KB, `cr-iconset`),
  but it is a warm-up page, not evidence that the popup opened: window enumeration showed the same three
  windows before and after the posted accelerator, and no `?surface=tab-search` target was ever created.
  The chevron opens the FAME surface — `TabSearchBubbleHost`'s constructor calls `CreateBubbleManager()`
  (`tab_search_bubble_host.cc:65-85`), which is `WebUIBubbleManager::Create<FameSurfaceUI>` at
  `?surface=tab-search` (`:291-296`). Rows stay unobserved until someone clicks the chevron.
- **Workspace delete proven end-to-end 2026-11-02** (offscreen window, CDP only): toolbar workspace
  button -> `?surface=workspaces` -> `.workspace-add` -> name `Probe` -> `#workspace-save` created it
  ("PR Probe 1 tab"); `Edit Probe` -> `#workspace-delete` removed it. The card list dropped back to just
  "MA Main", the deleted workspace's tab moved into Main (8 -> 9 tabs, which is the intended semantics:
  `fame_workspace_model.cc:458-483` moves tabs to the neighbouring workspace rather than closing them,
  matching the old browser), the model switched to Main, and `fame.workspaces` flushed with only Main.
  Nothing was left behind and Main was never touched.
- The bookmark editor was verified 2026-11-01 through the real native path (export 92267, 92441);
  the pink underline/stroke was removed and compiled before that and was never open.
- Already built and verified, source re-read 2026-11-02 (this bullet used to sit in IN-FLIGHT and put
  finished work back in front of the user): inactive tabs `tab_view.cc:591-596`, site-info
  `location_icon_view.cc:348-355`, new-tab + tab-search chevron `tab_strip_control_button.cc:240-274,361`
  and `tab_strip_flat_edge_button.cc` (export 57742/57762); workspace membership across restart
  (export 1728, 2705); custom bookmark icon across restart (export 86713). Saturation uses the same
  `fame_saturation` meta as the icon (`bookmark_bar_view.cc:1914-1995`,
  `webui_app_menu_control.cc:740-743`).
- I reported "glass surfaces unverified", "workspace membership across restart unproven" and "bookmark
  icon + saturation across restart unproven". All three were false: the code is there and each was
  verified earlier — export 57742/57762 (tab-search chevron is a `TabStripFlatEdgeButton`, now painting
  `PaintRailBubble`; new-tab same), export 1728 and 2705 (workspaces survived restart with correct
  membership and collapsed state), export 86713 (custom icon persisted and rendered after restart).
- Rule this costs: the IN-FLIGHT list is a *dated snapshot*. It may not be quoted to the user as
  current status; re-read the source (`file:line`) first, then the export, then say "not done".

## Verified at runtime 2026-11-01 (offscreen window, CDP only, one pass)
- **Startup abort (the real find of this pass):** every launch with a restored FAME workspace died in
  `tab_group_sync_delegate_desktop.cc:262`, `CHECK(listener_->IsTrackingLocalTabGroup(group_id))`,
  from `InitializeTabGroupSync -> UpdateLocalTabGroup` (export 92100, 92127). Cause: FAME writes its
  workspaces into the tab-strip model as native tab groups and never registers them with
  `TabGroupSyncService`. Fix: return early when the listener does not track the group; relinked
  `04:50:16` (export 92210), relaunched with 0 FATAL (export 92235).
- **This is a recurrence, not a first sighting:** the same CHECK failed at `:235`
  (`ConnectLocalTabGroup`) earlier in the thread (export 66179). That earlier fix was at the wrong
  site, so the root cause — unregistered groups — went unfixed until now.
- **Bookmark editor (real path: chip context menu -> Edit -> 150 ms delayed open):** opens at
  `?surface=bookmark` with the URL prefilled (`youtube.com/feed/subscriptions`), the folder select
  populated with **Bookmarks bar** (selected) and **Other bookmarks**, buttons **Delete · Cancel · Save**
  and **Automatic** (icon reset), the text-icon field (`#bookmark-icon-text`) and a saturation slider.
  That is the folder picker, delete and text icon the audit demanded, exercised, not assumed.
- **Tab search** is the FAME surface by construction (`tab_search_bubble_host.cc:291-295`), not the
  Chromium popup; its runtime open still needs the chevron click, so rows are not yet observed.
- Bookmark chip renders a 16x16 data-URL favicon inside the toolbar row (`#fame-bookmarks` at x=1194,
  next to the star at 1152); the profile's bar holds one bookmark, so one icon-only chip is correct.
- Clicking the chip opens its bookmark in the current tab: omnibox went `about:blank` ->
  `youtube.com/feed/subscriptions`.
- The chip's context menu opens as its own 123x156 window (three entries: Edit, Move, Delete, per
  `webui_app_menu_control.cc:451-456`) and closes on ESC.
- The hamburger toggles `visible -> hidden -> visible` across successive clicks: the deadlock is gone.
- The workspace button opens `?surface=workspaces` and renders the card "MA / Main / 5 tabs" with Switch
  and Edit.


# 30 — WHERE THE WORK STANDS

## What exists
- A component Chromium build (`out\FameComponent`) branded Brows, with a custom `fame_surface` WebUI
  for the app menu/bookmark editor/workspaces, a `FameWorkspaceModel` on native tab groups, a custom
  `webui_toolbar` skin, and window-level glass painting (`fame_glass.h`).
- No older browser build is a reference for this one: work only from the current fork's source and
  the running build.

## What shipped before (verified at some point)
- Google/YouTube/Drive sign-in works and survives restart (52 auth cookies in the profile).
- Brows rename and eyes mark in the resource paks; launcher points at the component build.
- Foggy glass parity within a few RGB units over the controlled checkerboard.

## Where the work stands (2026-11-02)
- Every defect the user named is fixed and was exercised at runtime: favourites chips inside the
  toolbar row, the FAME tab-search surface over real tabs, workspace delete, the hamburger toggle, no
  pink underline, no separate bookmarks row, no PWA install icon, glass on the three surfaces, band
  heights 38/38, move-tab, backup/restore, and fullscreen toolbar removal.
- No known defect remains among the ones the user named. "Perfect" is not something a test establishes;
  the verified list above is the evidence. **Correction 2026-11-04:** this 11-02 snapshot predates the
  replica audit; `FAMEBROWZ.md` Part III, "November 4 — where the record ends", lists the still-divergent surfaces (seven `chrome://` panels, no
  custom bookmarks manager, no private badge, native find/tooltips, global pinned tabs). Read that section, not
  this line, for current parity.
- The static `out\FameBaseline` build stays deleted; it is out of scope.

## 156 upgrade attempt 2026-11-03

- `156.0.8078.80` tag fetched; 152 work is committed as `6efc8b0312` on `fame-152-final` (90 files,
  Reader mode + vertical tabs).
- Per-commit cherry-pick and a single 3-way patch both hit broad conflicts (WebUI toolbar CSS/TS,
  feature flags, browser view/toolbar, WebUI). The source was restored to `fame-152-final`; the
  `out/FameComponent/chrome.dll` 15:46 build is intact.
- The `fame-156` branch remains at the tag with no applied FAME port and no 156 build. The
  installer is not started; `mini_installer` does support component builds (3,478 edges in the
  historical attempt), so a static `out\FameBaseline` is not a prerequisite. There is no updater:
  `checkUpdates`/`installUpdate` remain undelivered.

## 2026-11-03 — overnight outcome
- The user expected a 156 build to run overnight. None was started; the source was restored to 152
  after the port conflicted. This is recorded in `MEMORY/71-compaction-postmortems.md`.

## Split 2026-11-13 — this file is the current state; the dated pass logs live beside it

The recovery gate caps a memory file at 50 KB, so the dated detail moved out verbatim:

- `31-state-ui-passes-a.md` — 2026-11-10 → 2026-11-12, design passes 1–13 (pill, site-info glyph,
  workspaces entry point, strip refresh, omnibox placeholder, reload glyph, favourites, tab search).
- `32-state-ui-passes-b.md` — 2026-11-12, passes 14–24 (bookmark/folder popups, Miller columns,
  extensions popup, settings depth, Downloads panel, tab and bookmark popovers, reported defects,
  the zoom cluster).
- `33-state-site-release.md` — brows.dev publication, `scripts/publish-site.ps1`, the 156 installer.


## 2026-11-13 — 156.0.8078.80 rebuilt with the five reported defects fixed
- Logo: `generate-brows-icons.ps1` no longer fills the eye interiors (that plate read as a white
  outline); every layer of `chromium.ico` is now pure ink with transparent holes, plus a new
  `chromium_white.ico`. Both are packed as `IDR_BROWS_LOGO_ICO_BLACK/_WHITE` in
  `chrome_unscaled_resources.grd`.
- `brows.logo_colour` (auto/white/black) rewrites `User Data\Brows.ico`, retargets the desktop and
  Start-menu shortcuts and fires `SHChangeNotify`; the window icon is set with `WM_SETICON` so the
  running taskbar button follows too. The exe's embedded icon cannot change at runtime.
- Extensions: Chromium's stock puzzle is filtered out of the WebUI container (empty id), the Brows
  chip is the entry point, and each pane row has an `…` menu with options, pin, reload, remove,
  manage, site access (on click / on site / on all sites), warnings and host-access requests
  (allow / dismiss).
- Tab search: relevance ranking, match marking, "N of M tabs", key hints and a Recently closed
  section fed by `TabRestoreService`.
- Zoom bubble anchors to the zoom page action; the private button and slider accents are monochrome.

