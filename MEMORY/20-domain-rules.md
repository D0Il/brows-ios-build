

## The mark is an asset, never a drawing (2026-11-16)

`port/branding/brows-mark-1024.png` is the Brows mark. The shipped browser replaced **all 20 product
logo assets** with it (export 8842–8846: `default_100/200` product logos, `product_logo_16…1024`, the
mono mark, `product_logo.svg`), so any surface that needs the mark copies that art — it is never
redrawn from a description. The prose "two eyes with two eyebrows" (export 3288) is a summary of the
art, not a spec: the real mark has lash spikes, and drawing capsules from the sentence produced a
logo that is not Brows at all (2026-11-16, iOS icon).

Rules this costs:
- Before building any icon/splash/logo, read `port/branding/` first; if the art exists, copy it.
- A generator script that draws the mark must not exist in the repo (one did for an afternoon:
  `tools/oneoff/make_brows_icon.py`, deleted).
- Branding text (`BRANDING`, AGENTS) carries names and words; the art carries the logo.

## The product rename splits the profile (2026-11-13)

Chromium derives the user-data directory from the install directory, so the FAME → Brows rename moved
it:

- `%LOCALAPPDATA%\Z7\FAME Browser\User Data` — the real profile: 13 bookmarks, 2,276 history URLs
  (last visit 2026-11-12 03:18), **365 saved logins**, 1.2 GB, `Local State` written 11-12 15:38.
- `%LOCALAPPDATA%\Z7\Brows Browser\User Data` — created empty by the first install of the renamed
  product: no `Default\Bookmarks` at all, 0 history, 0 logins.

Installing and launching the renamed build therefore opens a browser with none of the user's data and
looks like data loss. What was done on 2026-11-13:

1. closed the empty instance (17 processes force-stopped, no user tabs existed in it);
2. renamed it `Brows Browser\User Data.fresh-20261113` (kept, harmless);
3. **copied** `FAME Browser\User Data` → `Brows Browser\User Data` with `cp -a` (1.2 GB; `Local State`
   comes along, which is what keeps the DPAPI-wrapped login key valid, so the 365 passwords decrypt);
4. relaunched; the running browser reports 13 bookmarks, 2,276 history rows, 365 logins, 0 FATAL.

Rules this costs:

- Never move or delete a user's profile to "tidy" a rename; copy, verify counts, keep the original.
- `robocopy` under Git Bash is unsafe here: MSYS rewrites `/E`-style switches into paths, and the copy
  silently does nothing (exit 16, then a bogus 0). Use `cp -a`, or `MSYS_NO_PATHCONV=1` with explicit
  `C:\...` arguments.
- Any future rename must migrate `User Data` in the same release, or the first launch looks like data
  loss to the user.

### Old FAME install removed, profile kept in place (2026-11-13)

`%LOCALAPPDATA%\Z7\FAME Browser` now holds only `User Data`. Deleted: `FAME Browser\Application`
(1.7 GB, the previous build) and the orphaned `HKCU\...\Uninstall\Z7 FAME Browser` entry whose
`UninstallString` pointed at the deleted `Application\156.0.8078.80\Installer\setup.exe`.
`User Data` was not touched: still 1.2 GB, 13 bookmarks, 2,276 history URLs, 365 logins, and it
remains at `C:\Users\xjpma\AppData\Local\Z7\FAME Browser\User Data`. No registry key under HKCU
references the old path any more, and the running install `Z7\Brows Browser` (sha256 `2fbee6df99…`)
is unaffected.

### Preserved FAME profile deleted after a row-level parity check (2026-11-13)

`Z7\FAME Browser\User Data` and the then-empty `Z7\FAME Browser` are gone; `%LOCALAPPDATA%\Z7\Brows
Browser\User Data` is now the only profile. Deleted only after comparing the two profiles as sets,
not just as counts (`tools/oneoff/compare_profiles.py`):

- bookmarks — 13 URLs each, preserved-only 0; the `Bookmarks` files are byte-identical
  (sha256 `7fc97e8009cd…`);
- history — 2,276 URL rows / 5,224 visits each, preserved-only 0, identical newest
  `last_visit_time` (13438945125779056);
- logins — 365 each by `(signon_realm, username)`, preserved-only 0;
- also equal: 9 extension directories, 1,010 `autofill` rows, cookie store 327,680 B with an empty
  journal. `Preferences` and `Web Data` differ in bytes because the live browser rewrote them at
  launch — expected, not a gap.

Two traps this cost: `select url, visit_count, max(last_visit_time)` silently returns ONE row (the
aggregate), which briefly made both profiles look like they had a single history entry — never mix an
aggregate into a per-row comparison. And a running browser's `Network\Cookies` cannot be hashed
(open denied), so compare size/journal there, or close the browser first.

After deletion: 17 GB → 19 GB free on C:, live profile still reads 13 bookmarks / 2,276 history URLs /
365 logins, browser still running.

## 2026-11-13 — four rules the bookmark-flyout menu cost (export 17931-18103)

1. **A menu drawn inside a WebUI bubble's own page is clipped by that bubble.** The folder flyout is a
   `WebUIBubbleManager` page (`?surface=folder`); an absolutely positioned `.folder-context` inside it
   was cut off and rendered as an unstyled white plate. Cross-surface menus must be their **own**
   `WebUIBubbleManager` anchored at a screen point — `webui_app_menu_control.cc`
   `ShowBrowsBookmarkMenuInternal(..., /*context_menu=*/true)` is the canonical pearl menu path.
2. **`BookmarkModel` has no `GetNodeByID` in 156.** Use `bookmarks::GetBookmarkNodeByID(model, id)`
   (`webui_app_menu_control.cc:1495` and seven other sites).
3. **Delegate virtuals may not carry a body in a header** — `[chromium-style] virtual methods with
   non-empty bodies shouldn't be declared inline` is a `-Werror`. Declare in the header, define in the
   `.cc` (`brows_surface_ui.cc` `BrowsSurfaceUI::Delegate::ShowBrowsBookmarkActionsAt`), and mark the
   override `override` in the implementing class.
4. **stylelint on `brows_surface.css` is part of the chain** (`ui/webui/resources/tools/stylelint.config_base.mjs`);
   one-line rule bodies fail `rule-empty-line-before` / `@stylistic/declaration-block-semicolon-newline-after`
   with exit 1, which fails `lint_css` before the build. Run it on the source file directly:
   `third_party/node/win/node.exe third_party/node/node_modules/stylelint/bin/stylelint.mjs --config ui/webui/resources/tools/stylelint.config_base.mjs chrome/browser/resources/brows_surface/brows_surface.css`.

## 2026-11-13 — Snap Layouts, dark mode, and how to test both (measured)

1. **Snap Layouts needs the caption buttons to answer `HTMAXBUTTON` first.** Brows' glass frame returns
   the client-view hit result early (`browser_frame_view_win.cc`), and that path never reached the
   caption container, so DWM never saw `HTMAXBUTTON` and the hover flyout never appeared. The caption
   check now runs before the client-view branch. Measured: `tools/oneoff/check_snap_hittest.py` sends
   `WM_NCHITTEST` at sampled points and counts `9`.
2. **`--force-dark-mode` does not reach WebUI in this build** (measured: `color-scheme` stayed
   `light`, plate stayed `255,255,255`). Test dark with CDP
   `Emulation.setEmulatedMedia {prefers-color-scheme: dark}` — `tools/oneoff/diag_ui.py` does exactly
   that and prints the light and dark computed values.
3. **Colour is tokens now, not literals.** `brows_surface.css` exposes `--ink`, `--muted` and
   `--plate-rgb`; every background plate at alpha ≥ .5 is `rgba(var(--plate-rgb),α)` and every white
   wash below that stays literal so hover feedback survives a dark plate. The dark media block sets
   `--plate-rgb: 34,38,45` so plates sit just above the `rgba(24,28,35,.94)` surface.
4. **Roving lists need selectors that exist.** A first pass wired `#menu` to `.menu-list > button`;
   the menu has no `.menu-list` (it is `menu-quick`/`tool-strip`/`window-row`/`settings-tile`), so the
   handler was dead until it targeted `button`. Measure with `diag_ui.py` `ARROWS` before believing a
   keyboard claim.

## 2026-11-13 — two verification rules this pass cost

1. **A probe that accepts placeholder text proves nothing.** The Settings panel starts on
   "Updates have not been checked yet."; a wait loop that stops on "not Checking" returns that
   placeholder as if it were an answer, which is how "the auto check does not run" survived one
   round too long. Wait for a value that is neither the placeholder nor a progress string.
2. **A UI panel's initial content is not its behaviour.** The module-scope `runUpdateCheck()` ran
   before `proxy.handler.ready()`, so it silently did nothing while the markup looked normal. Any
   handler call belongs after `ready()` resolves.


## 2026-11-14 — what the media control and the pin flush cost (era 1011, 1083, 1358)

1. **A parked window cannot be used for pixels or for media.** `PrintWindow(hwnd, dc, 2)` on a window at
   `-32000,-32000` returns `ok=1` with a **uniformly black** frame: DWM never composites an off-screen
   window. Worse, the renderer **defers media loading** there — an `<audio src>` stays at
   `readyState 0` / `networkState 2` and the HTTP request is never issued, so no media session, no
   audio indicator, no media button. Every runtime check that needs either must be **one short visible
   pass** (one process, one script, ~25 s, then close) — still no desktop capture and no OS input.
2. **An `<audio>` element alone creates no media session.** Chrome only publishes a notification when
   the page sets `navigator.mediaSession.metadata`, so a probe page must set `MediaMetadata` (and the
   action handlers) or `HasActiveNotificationsForWebContents` stays false and there is nothing to show.
3. **Emptying `Show()` does not hide a WebUI toolbar button.** The button's visibility comes from the
   `MediaControlState` message: `WebUIMediaToolbarButton::UpdateState()` sends
   `state->should_be_shown = should_be_shown_`. With a no-op `Show()`, the state still reported
   `should_be_shown=true` and the button painted at `1157,40 34x34`. Set the field itself.
4. **`MediaNotificationService` is created on demand.** Sampling it from the `Tab` constructor finds
   `nullptr`, so an observer attached only there never fires. Re-check visibility from
   `Tab::OnTabDataChanged` (media start co-occurs with an alert-state change) and `Observe()` the item
   manager the first time it exists.
5. **`SessionServiceBase::SetPinnedState` has no caller in this tree.** `grep -F SetPinnedState chrome/
   components/` returns only its declaration and definition, so a pin reached disk only through the
   clean-exit full-session build (`kCommandSetPinnedState` is written by nothing incremental). Measured
   consequence: pin → kill 0.58 s later → restore lost the pin, and the session file's mtime/size were
   unchanged at pin time. The flush therefore belongs **inside** `SetPinnedState`, immediately after
   `ScheduleCommand` — the earlier `OnTabPinnedStateChanged` hook ran before anything was recorded.

## 2026-11-15 — autoninja refuses a directory that carries Siso state (measured)

1. **`autoninja` exits 1 in under a minute, compiling nothing, when `out\Fame156` holds Siso state**
   (`.siso_deps` 191 MB, `.siso_config`, `.siso_fs_state`) **while `build.ninja` was last written by
   the Ninja generator.** Message: "You're still using Ninja. Please run 'gn clean out\Fame156' when
   convenient to upgrade this output directory to Siso …" then "Run gn clean before switching from
   siso to ninja in out\Fame156". Measured 2026-11-15: `scripts/build-fame-156-installer.cmd` ended
   `EXIT:1` with `build-now-156.log` holding only that text, and `.ninja_log` was 76 B (a failed ninja
   probe) against a 191 MB `.siso_deps` written by the successful 2026-11-14 19:20 build — the tree is
   a **siso** tree.
2. **`gn clean` is the expensive wrong turn** — it discards a first build's object files. Reconcile by
   re-running `gn gen out/Fame156` (existing `args.gn`, GN default `use_siso=true`) so `build.ninja`
   matches the siso state, using the script's own environment: `DEPOT_TOOLS_WIN_TOOLCHAIN=0`,
   `vs2026_install=C:\Program Files\Microsoft Visual Studio\18\Community`, depot_tools on PATH, and
   `INCLUDE`/`LIB`/`LIBPATH` cleared exactly as the script does.
3. **A missing `build/win_toolchain.json` was not the real blocker.** `vs_toolchain.py
   get_toolchain_dir` fails only outside that environment; with `DEPOT_TOOLS_WIN_TOOLCHAIN=0` and
   `vs2026_install` set, GN resolves the toolchain itself.
4. **Never run plain `ninja` in `out\Fame156`.** It writes a 16-byte `.ninja_deps` and a 76-byte
   `.ninja_log`, and `autoninja.py:352-360` reads `.ninja_deps` as "this is a ninja build", flips
   `use_siso` to False, then refuses because the real 191 MB `.siso_deps` exists. That 16-byte file
   alone blocks the whole chain (measured 2026-11-15 20:56 → 21:2x). Fix: move `.ninja_deps` and
   `.ninja_log` aside, then run the chain; no `gn gen` and no `gn clean` needed.

## 2026-11-15 — what the five 156 compile errors of build-now-156i cost

1. **`BubbleDialogDelegateView::BddvPassKey` cannot be forged.** `base::PassKey` has a private
   constructor, so a new class — even a subclass — cannot call the 156 ctor; the private
   `BubbleDialogDelegateView(anchor, arrow)` is reserved for the fixed friend list
   (`page_info_bubble_view_base.cc:55` is a friend; new code is not). Introducing a hand-rolled
   bubble is therefore a hard compile error, twice measured: `page_specific_site_data_dialog.cc`
   and `page_info_main_view.cc` `SecureDetailsBubbleView`. Explain text with the row's own tooltip
   or a label instead of inventing a bubble.
2. **`METADATA_HEADER` placed first in a `public:` block leaves the members after it private.** The
   follow-up error is not about metadata: libc++ reports
   `unique_ptr.h(708,30): calling a private constructor` for both view classes. If a View subclass
   needs no metadata, do not add it — construct it as
   `AddChildView(std::unique_ptr<views::View>(std::make_unique<T>(…)))`, which sidesteps the
   `kHasClassMetadata` static assert in `views/view.h:471,493`.
3. **There is no `BrowserList` in this 156 tree.** `chrome/browser/ui/browser_list.h` does not exist
   and nothing declares the class; `webui_app_menu_control.cc` was the only file referencing it.
   Refresh through the `Browser*` already in hand (`browser->window()->UpdateTitleBar()`).
4. **`IDS_PAGE_INFO_RESET_PERMISSIONS` does not exist in 156.** The existing string is
   `IDS_SETTINGS_RESET_TO_DEFAULT` (`out/Fame156/gen/chrome/grit/generated_resources.h:1034`);
   `GetPluralStringFUTF16` also needs a plural message, so a singular id must be read with
   `GetStringUTF16`.
5. **`SetSkipSubpixelRenderingOpacityCheck` takes a bool** (`label->SetSkipSubpixelRenderingOpacityCheck(true)`).
6. **Two settings eslint rules bite templates, not CSS:** `@webui-eslint/inline-event-handler`
   rejects `@click="${(e: Event) => e.stopPropagation()}"` (bind a class method instead — six
   occurrences across `a11y_page` and `languages_page`), and
   `@webui-eslint/web-component-missing-deps` rejects a `cr-button` used by
   `manage_profile.html.ts` unless `manage_profile.ts` imports
   `chrome://resources/cr_elements/cr_button/cr_button.js`.
7. **`git grep` over `D:\FAME-Chromium\checkout\src` can exceed four minutes.** Read the single
   file, or grep one generated header (`out/Fame156/gen/chrome/grit/generated_resources.h`), instead
   of a repository-wide search.

## 2026-11-15 — NOTHING GETS BUILT UNTIL EVERYTHING IS DONE

The rule, in the user's words: *"WHY THE FUCK WOULD YOU BE FUCKING STARTING ANYTHING IF UR NOT DONE
EVERYTHING"* and *"NOTHING GETS BUILT UNTIL *EVERYTHING* IS DONE"*.

1. **A build is the last step of a pass, never a checkpoint inside one.** On 2026-11-15 a six-item
   report (tray-icon crash, snap layouts, pinned tabs, blank tabs on reopen, tab search on one tab,
   white search popup) had two fixes written when the build was started "while I dig into the
   remaining three". That is the named failure; the build was stopped.
2. **Never build a subset and plan the rest for a second build.** A second 25-minute link is not a
   saving, it is a second chance to ship half a pass and call it done.
3. **A new defect arriving mid-build stops the build.** Do not let it finish "since it is running";
   stop the process tree, write the new fix, then build once with everything in it.
4. **Verify after the single build, in one pass** (see the one-visual-pass rule), then report
   "NOT done, remaining: …" for anything that could not be fixed — never end a pass by declaring a
   subset shipped.

## 2026-11-17 — iOS: the system's own AutoFill save sheet is what blocks a browser's credential UI

1. **iOS Password AutoFill, not a SwiftUI sheet, was eating every tap.** After an HTTP auth prompt
   built from a native `TextField` + `SecureField` left the hierarchy, iOS raised its own modal
   sheet — its own `UIWindow`, label `Save Password?`, buttons `Not Now` / `Save` — above the
   app. Every tap on the browser's save card went to that window: the card was `hittable`, the
   model never changed (`credentialDebug` stayed `presenting`, saved count 0), and a later
   address-pill tap failed with “Neither element nor any descendant has keyboard focus” (run
   `44131988911`; the same symptom in `44103887854`, `44117628840`, `44124575443`). WWDC18 session
   204 states the trigger: AutoFill reads a login pair when it is removed from the view hierarchy.
   The opt-out is `UITextField.textContentType = .oneTimeCode` on the credential fields (Apple
   Developer Forums thread 108085: “the only solution … otherwise iOS uses PasswordAutofill for any
   secure field”). The prompt now uses `AuthField`, a UIKit-backed field that sets it on both
   fields, and both auth tests assert `app.sheets["Save Password?"]` never exists.
2. **A `Button` inside a `ScrollView` inside a `.sheet` is also unreliable** (Apple Developer Forums
   thread 763436, Xcode 16 → iOS 18+; `UIScrollView.delaysContentTouches` on Stack Overflow
   69367905). That is a real second failure mode, but it was not this one: the card failed
   identically with no ScrollView and no sheet at all. Keep user decisions out of a sheet's scroll
   view regardless.
3. **One save surface, drawn once.** When the prompt's surface and the root overlay both rendered the
   card, `save.new` existed twice and the rear copy was unhittable (run `44103887854`). The overlay
   is a single `if/else` on `pendingHTTPAuth` / `pendingCredential`
   (`BrowserView.swift:80`), and the offer is queued through
   `presentDeferredCredentialOffer` (`BrowserModel.swift:851`).
4. **Basic/Digest belongs to `WKNavigationDelegate`, never `URLSession`.**
   `webView(_:didReceive:completionHandler:)` is the only callback that can answer a page's
   challenge (Apple docs, `WKNavigationDelegate`,
   `NSURLAuthenticationMethodHTTPBasic`/`HTTPDigest`). `.useCredential` with
   `URLCredential(persistence: .forSession)`; `.cancelAuthenticationChallenge` on Cancel so the page
   is answered rather than left spinning; `previousFailureCount > 0` re-opens the prompt with the
   failure visible instead of replaying the same credential. `.performDefaultHandling` is the wrong
   answer for a browser that owns its credential UI — it hands the user WebKit's blank system
   challenge.
