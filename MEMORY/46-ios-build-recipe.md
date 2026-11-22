# 46 — iOS BUILD + LAUNCH RECIPE (verified 2026-11-16)

The app is no longer uncompiled. This is how it gets built and how a launch is proven,
including the four traps that cost a run each.

## Where

- Private build repo: `github.com/D0Il/brows-ios-build` (created with the signed-in `gh`
  account, `repo` + `workflow` scopes). It contains **only** `ios/Brows` and
  `.github/workflows/ios-build.yml`, so the Chromium checkout is never pushed (838 KB total).
- Working copy used to push: `.freebuff/tmp/ios-build-repo`. Sync a change with:

```
cp ios/Brows/Brows/<File>.swift .freebuff/tmp/ios-build-repo/ios/Brows/Brows/<File>.swift
cd .freebuff/tmp/ios-build-repo && git add -A \
  && git -c user.email=build@z7.local -c user.name="Z7 Build" commit -qm "<what changed>" \
  && git push -q origin master
```

A push touching `ios/Brows/**` or the workflow triggers `ios-build` automatically.

## What the runner does

`macos-15`, Xcode 26.3, iOS 26.2 SDK, deployment target 16.0:
1. `xcodegen generate` in `ios/Brows`.
2. Release device build, unsigned → `Payload/Brows.app` → `Brows.ipa` (858 KB; contains
   `Brows`, `Info.plist`, `Assets.car`).
3. Debug simulator build, boot the **newest** iOS runtime, install, launch, screenshot,
   process check, crash-report dump. Artifacts: `Brows-ipa`, `Brows-simulator`.

Check a run:

```
gh run watch <id> --repo D0Il/brows-ios-build --exit-status --interval 10
gh run download <id> --repo D0Il/brows-ios-build -n Brows-simulator -D .freebuff/tmp/sim
```

## Traps, each one verified by a failed run

1. **No scene manifest** → the app installs, launches and is gone in under a second; the
   simulator screenshot is the home screen. `UIApplicationSceneManifest`
   (`UIApplicationSupportsMultipleScenes: false`) must be in `project.yml`'s `info.properties`.
2. **iOS 18.5 simulator runtime has no `libswiftWebKit.dylib`** → dyld aborts at launch
   (`Library not loaded ... /usr/lib/swift/libswiftWebKit.dylib`). Pick the newest runtime,
   not the first device in `simctl` output (iOS 26.2 iPhone 17 Pro works).
3. **`simctl launch --console-pty` kills the app when the client is killed.** It returned a
   live pid but the process was `NOT RUNNING` after the console attach was terminated. Verify
   with a plain `simctl launch` + `simctl spawn <dev> launchctl list | grep dev.brows.ios`,
   which shows `UIKitApplication:dev.brows.ios[...]` while it is alive.
4. **YAML block scalars:** a multi-line `python3 -c "..."` inside `run: |` with its lines at
   column 0 ends the block and invalidates the workflow. Keep inline helpers on one line.

## Runtime defects found by looking at the launched screen

- Local start page is HTML, so WebKit reports `about:blank`; the pill showed that instead of
  `SEARCH`. `WebViewContainer.sync` now maps `about:blank`/nil to the start tab and skips
  history for it.
- Forcing `.preferredColorScheme(.dark)` makes SwiftUI's own TextField placeholder light grey
  on the white pill — effectively invisible. The pill draws its own muted `SEARCH` placeholder.
- The top strip was labelling the workspace; the desktop tab strip names the **tab**. It now
  shows the active tab's title (workspace stays the rail button).

## Verified state (2026-11-16)

- Device build: **success**, unsigned ipa uploaded.
- Simulator: **running**, pid alive, start page rendered — screenshot
  `.freebuff/tmp/sim7/brows-launch.png` (1206×2622), rail shows glass badge + muted `SEARCH` +
  star + workspace initials + tab count + menu, no back/forward on a fresh tab, no home button.
- **UI tests run on the simulator, and pass** (run 43897090460):
  `BrowsUITests.testRailAndMenuPanels` — 29.1 s, opens the menu, Site information, Done,
  reopens the menu, Downloads, Passwords, the tab gallery, Workspaces, and asserts the rail
  returns — plus `testStartPageSearchField`. `Executed 2 tests, with 0 failures`,
  `** TEST SUCCEEDED **`. Identifiers the test relies on: `rail.address`, `rail.menu`,
  `rail.tabs`, `rail.workspace`.
- Artifacts kept: `artifacts/ios-launch-2026-11-16.png` (full 1206×2622) and `.jpg` preview.
## The identity mistake, corrected 2026-11-16

The first running build was rejected: *"that literally looks nothing like brows"*. Cause: the
start page was invented (blue gradient, "Where to?" headline) instead of the documented new tab.
`FAMEBROWZ.md:42` records the real thing — **the concrete texture ported byte-for-byte, with the
glass search bubble**; the texture is `port/site/assets/concrete.png` (2048×1147).

What changed:
- `concrete.png` is a bundle resource and the start page is written to a temp folder and loaded as
  a **file URL** beside it (WebKit will not resolve bundle-relative images in `loadHTMLString`).
- Start page = concrete, full-bleed, glass bubble (blur + 30% white + hairline) with the muted
  `SEARCH` placeholder, shortcuts from the bookmarks with favicons. No invented headline.
- The page runs **under** the chrome, so the tab pane and rail are glass over the page, as on the
  desktop; the tab pane is one translated pane with a `.72` white stroke, not a full-width slab.
- Glass is not approximated any more; the values are read out of the fork and ported one-for-one.
  Source of truth: `chrome/browser/ui/views/frame/brows_glass.h` and
  `chrome/browser/ui/views/tabs/common/horizontal_tab_style_views.cc:361`. The checkout root is
  `D:/FAME-Chromium/checkout/src` (the directory one level up holds only `src/`), and
  `brows_glass.cc` itself is just the shared tint holder.
  - rail pane: base `rgb(240,245,250)` at clarity alpha — foggy `0x7B` (0.48), clear `0x2E`,
    even-foggier `0xB8`; over it the white ramp `rgba(255,255,255,.31)` → `rgba(228,236,244,.13)`;
    over that the sheen `radial(140% 95% at 18% -20%, rgba(255,255,255,.58), transparent 52%)`.
  - rail bubbles (`PaintRailBubble` + `toolbar_button.css`): fill
    `rgba(255,255,255,.18)` → `.035` over `rgba(247,250,253,.025)`, 1px border
    `rgba(255,255,255,.30)`, **8px radius**, 30px on the desktop (36pt touch frame on the phone),
    two insets (`white .56`, `rgba(34,44,60,.075)`) and two drops (`0 1 2 rgba(24,31,44,.075)`,
    `0 4 12 rgba(24,31,44,.045)`). Translucent rounded bubbles — not solid white discs.
  - address pill (`location_bar.css`): **not solid white.** `linear-gradient(180deg,
    rgba(255,255,255,.18), rgba(255,255,255,.065))` over `rgba(255,255,255,.035)`, 1px
    `rgba(255,255,255,.42)` hairline, `--border-radius: 10px`, `padding-inline: 12px`. AGENTS.md's
    older "solid white pill" line is superseded by this file's own comment ("the last .address-bar
    input rule wins … not the earlier, heavier glass pass").
  - site-info glyph (`location_icon.css`): `background-color: transparent` on the pill — a filled
    chip reads as a white circle at the start of the omnibox.
  - rail band (`app.css`): height 38, `padding: 3px 8px`, `gap: 5px`, transparent background,
    `border-top: 1px rgba(72,84,102,.07)`, `box-shadow: inset 0 -1px 0 rgba(67,78,96,.14)`.
  - favourite chips (`app.css .brows-bookmark`): 28px tall, 7px radius, 6px gap, max-width 118px,
    `padding: 0 8px`, 12px text in `rgba(74,84,102,.72)`, transparent fill, 16px favicon.
  - active tab: fill white `0x4F` → `0x23` (0.31 → 0.137), border white `0x6B` (0.42). Inactive
    selected tab is the same at `0x30` → `0x15`.
  `.ultraThinMaterial` is gone; it collapsed the concrete into a uniform grey slab. Status bar is
  `UIStatusBarStyleDarkContent` over the light texture.
- On a 402 pt phone the zoom cluster folds into the menu; reload stays in the row and the pill
  keeps `minWidth: 126` (the first attempt at showing every control squeezed `SEARCH` into two
  lines — seen in the screenshot, fixed in the next build).

Latest suite (run 44003412651, after the address-pill editor): **13/13 pass**, `** TEST SUCCEEDED **` — menu/panels, start page
search, navigation from the pill, private badge, bookmark star, tab-gallery search, closing a tab,
find in page, per-site blocking toggle, workspace switch, reader mode on a Wikipedia article.
Two real defects the tests found and fixed: the star read `activeTab.url` while writing
`currentURL()` (so it never showed as bookmarked), and session restore persisted **private tabs to
disk**. Private tabs are now filtered out of `save()`.

`testDownloadStarts` exercises a real transfer end-to-end: the workflow's *Serve fixtures* step
writes `sample.bin` and serves it with `python3 -m http.server 8000`, the test navigates to
`http://localhost:8000/sample.bin`, and asserts the name appears in Downloads. A `swipeUp()` before
tapping the Downloads row scrolls that row away — the menu's second section is already above the
fold.

`testPasswordSaveAndAutofill` is the password manager end-to-end, against `login.html` on the same
server: type `browsuser` / `browssecret`, submit, tap **Save** in the alert, see the credential in
Passwords under `localhost:8000`, leave the origin in a fresh tab (`other.html`), return in another
fresh tab, and assert the username field is `browsuser` plus the page mirror reads
`U=browsuser P=browssecret` (the fixture echoes both field values on `input`, so the password is
checked by value, not by the prompt appearing). The server step writes the three fixture pages with
heredocs; the test leaves via `tab.add` because tapping the pill a second time puts the caret
mid-text and concatenates URLs.

Keychain on an unsigned simulator build returns **-34018 (errSecMissingEntitlement)**: with
`CODE_SIGNING_ALLOWED=NO` the app has no keychain access group, so `SecItemAdd` rejects every save.
The simulator and UI-test builds are therefore ad-hoc signed (`CODE_SIGN_IDENTITY=-`) with
`Brows/Brows.entitlements` (`application-identifier` and `keychain-access-groups` =
`dev.brows.ios`). The device ipa stays unsigned — that build still passes `CODE_SIGNING_ALLOWED=NO`.

`brows-article.png` is captured in the same fixtures step: the app is relaunched with
`-BrowsOpenURL http://localhost:8000/article.html` (a launch argument handled in `BrowserModel.init`)
and screenshotted after 8 s. Commit it to `artifacts/ios-article-2026-11-16.png`/`.jpg`. Text pages
get `contentInset` of safe-area top + 32 and bottom 68 so the copy starts below the status bar and
the tab pane and stops above the rail; `underPageBackgroundColor` is sampled from the document's
`getComputedStyle(document.body).backgroundColor` so the inset area matches the article instead of
the dark app backdrop.

Earlier tests (run 43907511722): **3/3 pass** — menu/panels, start page web view, and
`testNavigationFromAddressPill`, which types `example.com` into the pill and asserts the pill and
web view take the navigation.

- **Not yet exercised:** password add/reveal/fill, a real download transfer, Reader, Find,
  per-site blocking, private tabs and their badge, bookmark chips, and the zoom cluster on a
  wide device. The unsigned ipa still needs AltStore/AltServer signing to reach a physical phone.
