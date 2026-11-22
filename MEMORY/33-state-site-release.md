# brows.dev publication, the release chain, and the 156 installer

Moved verbatim out of `30-state.md` on 2026-11-13 (recovery gate: window-cap 50 KB).


- **Zoom cluster now collapses**: `FameZoomButton::Kind::kToggle` draws a magnifier-plus glyph
  (`PaintButtonContents`), `SetFameZoomExpanded(bool)` shows/hides −/100%/+ and the toggle,
  `ToggleFameZoom()` bound into the toggle's closure; toggle registered in `GetChildrenInZOrder`.
  Collapsed is the default state.
- **Icon size**: the supplied art is 2:1, so in a square icon the eyes were 50% of the height
  (measured: 32px icon, art bbox height 15px). `install_mark.py` now uses a square focus window
  centred on the eyes for sizes ≤48 and the whole mark for ≥64: the 32px icon measures 100% × 84%.
  The source PNG is untouched; nothing is recoloured or redrawn, but the outer lash tips fall outside
  the small-size window.
- **Reopen icon** no longer carries the clock hands, so it is not the history glyph.
- **Private button**: `.window-row .private` pink (#a63c77/#b2477f) removed; the tab-search close
  hover pink removed too.
- **Tab search**: ARIA-ish arrow-key selection (`moveTabSelection`, `activateSelectedTab`), Enter opens
  the selected row, Escape closes, meta line shows hostname · workspace, glass hover instead of pink.
- **Hamburger downloads dot**: `WebUIAppMenuControl` now observes `download::AllDownloadItemNotifier`;
  a completed or interrupted download sets a dot (`OnPaintBackground`, 3.5px, #1B1F27 at 9px/9px);
  opening the menu clears it.
- Still nothing compiled.

## 2026-11-12 — brows.dev published (Cloudflare) and the release chain that feeds it

**Do not rediscover any of this.** Identifiers, live objects and the exact publish paths:

- **Cloudflare account** `ede1e7633dd439375ff7a143c1c9b512` (user xjpman@gmail.com), **zone `brows.dev`**
  `cc2abce517a566ddafe474dc1bccd2c0`. Wrangler auth is an OAuth grant from `npx wrangler login`, stored
  at `%APPDATA%\xdg.config\.wrangler\config\default.toml`. Its scope list has **no DNS write and no
  API-token creation** (`/user/tokens` → 9109, `/zones/{id}/dns_records` → 10000 Authentication
  error), so DNS records and R2 S3 keys cannot be created with it.
- **The site is a Worker, not Pages.** `brows-site` (`tools/site-worker/wrangler.toml`:
  `main = worker.js`, `[assets] directory = "../../port/site"`, `run_worker_first = true`), attached
  with `[[routes]] pattern = "brows.dev", custom_domain = true`. A Worker **Custom Domain** is what
  creates the apex DNS record and certificate (Workers docs: "Cloudflare will create DNS records and
  issue necessary certificates on your behalf") — that is why the apex works although the OAuth grant
  has no DNS permission. Deploy: `cd tools/site-worker && npx wrangler deploy`. Also reachable at
  `https://brows-site.xjpman.workers.dev`.
- **Pages project `brows-dev` still exists but does not serve the domain** — its `brows.dev` custom
  domain attach was deleted on 2026-11-12 so the Worker Custom Domain could take the apex.
  `scripts/publish-site.ps1` is now the **one release path**: it writes `port/site/latest.json`
  through `write-release-feed.ps1`, uploads the installer as `Brows-<version>-Setup.exe` (direct
  `wrangler r2 object put` under 300 MiB, `tools/r2upload` multipart above it), deploys `brows-site`,
  then reads the live feed back and compares the served installer length. `-DryRun` prints the
  resolved version, hash, feed JSON and upload route without touching R2 or Cloudflare. Nothing
  deploys to Pages any more.
- **Password gate** (`tools/site-worker/worker.js`, server-side): HMAC-SHA256 of `SITE_PASSWORD`
  (secret = `BR0WZ`) keyed with `SITE_SECRET`, compared against cookie `brows_gate` (HttpOnly,
  SameSite=Lax, 30 days). 401 + gate page when locked, 401 on a wrong password, 303 to `/` on success.
  Open paths: `/__unlock`, `/latest.json`, `/assets/brows-mark-ink.png` (the gate page needs the mark).
  Per-IP throttle, 6 attempts/minute. **`/latest.json` is deliberately not gated** so the browser's
  updater keeps working while the site is locked. Remove the gate only when the user says it is ready.
- **Installer** is in R2 bucket `brows-releases`, key `Brows-156.0.8078.80-Setup.exe`, 688,638,464 B,
  SHA-256 `5a17ce7e8977aff0518679e59c95ac68ee56e4f6d2998596d3e392b2b6b96a81`, served at
  `https://downloads.brows.dev/Brows-156.0.8078.80-Setup.exe` (R2 custom domain, added with
  `npx wrangler r2 bucket domain add brows-releases --domain downloads.brows.dev --zone-id <zone>`).
  Verified by downloading the whole object back and matching the hash.
- **Anything over 300 MiB needs the multipart route.** `wrangler r2 object put` refuses >300 MiB
  ("Wrangler only supports uploading files up to 300 MiB"); the Cloudflare REST upload endpoint
  (`PUT /accounts/{id}/r2/buckets/{bucket}/objects/{key}`) is capped at 300 MB and 413s on a raw body
  because it wants multipart/form-data. Working method used on 2026-11-12: deploy a throwaway Worker
  with an R2 binding (`tools/r2upload/worker.js` + `upload.py`, 64 MiB parts through
  `createMultipartUpload` / `uploadPart` / `complete`), upload, then `npx wrangler delete`. Cloudflare
  blocks Python's default User-Agent on `*.workers.dev` (error 1010) — send a `user-agent` header.
  The 657 MB installer completed in ~95 s at ~7 MiB/s.
- **Site source of truth is `port/site/`**: `index.html` (BROWS / by Z, one glass plate on a metal
  bezel; hero, plate and footer fill one screen — the viewport-high hero and the 01/02/03
  statements were removed on 2026-11-12), `download.html`, `privacy.html`, `styles.css` (**strict greyscale** — the
  user rejected every tint: "there should be no colour"), `latest.json`, `_headers`, `_redirects`,
  `assets/brows-mark-ink.png` (ink art, alpha taken from the original's alpha channel, trimmed to the
  art) and `assets/brows-mark.png`. Design bar in the user's words: "EXTREMELY WELL MADE AND
  REALISTIC GLASS, concrete, metal" and "BEAUTIFUL, BRUTALIST, MINIMALISTIC, SLEEK, RICH, WEALTHY".
  Hero copy is exactly `BROWS` / `by Z` — no lede, no button row, no version micro-line, no marketing.
- **Feed audit (2026-11-12).** Default feed URL is `https://brows.dev/latest.json`
  (`chrome/browser/prefs/browser_prefs.cc:1996`), pref key `brows.update_feed`
  (`chrome/browser/prefs/brows_pref_names.h:17`). The pref is read in exactly one place —
  `chrome/browser/ui/views/toolbar/webui_app_menu_control.cc:1921` — which reports "No update feed is
  configured." when it is empty and never falls back to a local path. `brows_updater.cc` can still read
  `file://` URLs and absolute paths by design (`IsRemote` / `ResolveLocation`), but no code path
  defaults to one. The one-time rename migration (`browser_prefs.cc:2619-2626`) copies a non-empty
  legacy `fame.update_feed` onto `brows.update_feed`, so a profile once pointed at a local feed would
  keep it; neither live profile has any `brows.*` or `fame.*` update key, so both use the https default.
- **Build paths renamed to Brows (2026-11-12).** `scripts/build-fame.cmd`,
  `scripts/build-baseline.cmd` (variable `BROWS_CHROMIUM_OUT`) and `scripts/launch-baseline.ps1`, plus
  the comments in `build-fame-component.cmd` and `build-fame-156-installer.cmd:6`, now use
  `out\BrowsBaseline`. `out\FameBaseline` does not exist on disk (the `out\` trees are `FAME`,
  `Fame156`, `FameComponent`, `FameRelease`), so the rename orphaned nothing. Still FAME-named on
  purpose or untouched: `out\Fame156` in `package-fame.ps1:4-5`, `capture-webui-toolbar.ps1:3` and
  `run-fame-surface-probe.ps1:8`, and the local mirror `D:\FAME-Chromium\releases\latest.json`
  written by `build-fame-156-installer.cmd:40`, which is never served. The comments in
  `chrome/browser/prefs/brows_pref_names.h` and `chrome/browser/ui/views/toolbar/brows_updater.h` now
  describe the https feed (`https://brows.dev/latest.json`) rather than a local path or file:// URL.
- **Two installer copies exist and they differ.** `D:\FAME-Chromium\releases\Brows-156-Setup.exe`
  is 688,638,464 B and is the object in R2 and the file the feed hashes; `releases\Brows-156-Setup.exe`
  in this repo is 688,658,944 B — a different build that is **not** published. `publish-site.ps1`
  defaults to the D: copy. Publishing the repo copy needs a new upload and a new hash.
- **Local verification gotcha:** this machine's resolver kept a negative cache for `brows.dev` after the
  first attach; `curl --resolve brows.dev:443:172.64.80.1` is the reliable probe. `ipconfig /flushdns`
  is not permitted without elevation.
- **2026-11-12 — the publish path was exercised end to end.** `scripts/publish-site.ps1`
  (no flags, `D:\FAME-Chromium\releases\Brows-156-Setup.exe`) wrote the feed, uploaded 11 × 64 MiB
  parts through the temporary `brows-upload` Worker at 8.2-9.8 MiB/s (complete: size 688,638,464 B,
  etag `cebbf205f0b7361af1b44061df09d00a-11`), deleted that Worker (`Successfully deleted brows-upload`),
  deployed `brows-site` (version `623f08b4-01c6-4e8a-9a91-f9c34e3e7e6f`), read the live feed back
  (version and SHA-256 matched) and confirmed `Content-Length: 688638464` on
  `https://downloads.brows.dev/Brows-156.0.8078.80-Setup.exe`. `brows.dev` resolved locally this time,
  so the negative-cache `--resolve` workaround was not needed.
- **First build attempt on 2026-11-12 exposed a real break: the FAME→Brows rename stopped at the
  mojom.** `chrome/browser/ui/webui/webui_toolbar/toolbar_ui_service.{h,cc}` is fully Brows-named
  (`GetBrowsBookmarks`, `ShowBrowsBookmarkMenu`, `MoveBrowsBookmark`, `ShowBrowsExtensions`,
  `toolbar_ui_api::mojom::BrowsBookmarkPtr`) and the toolbar TS imports `BrowsBookmark` from
  `/shared/toolbar_ui_api.mojom-webui.js`, but
  `components/browser_apis/ui_controllers/toolbar/toolbar_ui_api.mojom` still declared
  `FameBookmark`, `OnFameBookmarksChanged`, `ShowFameBookmarkMenu`, `ShowFameBookmarkContextMenu`,
  `MoveFameBookmark`, `GetFameBookmarks`, `OpenFameBookmark`, `ShowFameExtensions`. Fixed by renaming
  those eight identifiers in the mojom (0 `Fame` identifiers left in that file). Also fixed
  `chrome/browser/resources/brows_surface/brows_surface.ts`: 13 `dataset.foo` dot accesses became
  `dataset['foo']` (Chromium's tsconfig sets `noPropertyAccessFromIndexSignature`) and the drop-slot
  loop now iterates `items.entries()` so `items[i]` is not possibly-undefined.
  `chrome/browser/resources/brows_surface/brows_surface.css` was formatted with the project's own
  `stylelint --fix` (5 `rule-empty-line-before` / `semicolon-newline-after` errors at 1886-1889).
  Rebuild after the fixes: `brows_surface:build_ts`, `brows_surface:lint_css` and
  `webui_toolbar:build_ts` all pass and no `FAILED:` lines are emitted. Note for reading the log:
  siso prints `S` for a target starting and `F` for it finishing, so only `E` lines and `FAILED:`
  blocks are failures.

- **156 build started 2026-11-12 17:55** with `scripts/build-fame-156-installer.cmd` (`-j 2`, output
  `out\Fame156`), log `D:\FAME-Chromium\logs\brows-156-build.log`. It runs `build-fame-156.cmd`,
  then `autoninja -C out\Fame156 mini_installer`, then copies to
  `D:\FAME-Chromium\releases\Brows-156-Setup.exe` and rewrites `releases\latest.json` via
  `write-release-feed.ps1`. After it finishes, `publish-site.ps1` must be re-run to put that build on
  the feed; nothing publishes automatically.

- **NOT done for any of this:** no Chromium build, so `brows_updater.cc` (https fetch + SHA-256 check)
  has never been compiled or exercised against the live feed, and the installer is unsigned, so
  SmartScreen warns once.

### 156 chain that produced the 11-12 installer (superseded 2026-11-13)
- **156 chain GREEN 2026-11-12 23:02/23:24 (measured):** the six API breaks from the 11-12 failure plus the
  twelve in `webui_app_menu_control.cc` (never compiled on 156) are fixed. `out\Fame156\chrome.dll`
  176,957,440 B @ 23:02 = `Brows`/`Z7`/`156.0.8078.80`; `mini_installer.exe` and
  `releases\Brows-156-Setup.exe` 688,811,008 B @ 23:24; local feed rebuilt, sha256
  `2e9f83d3f5099d96b83cd6d26e1df2137f71d4171607c030d537dec1e45663d6`. NOT published (R2 still serves the
  05:24 build, sha `5a17ce…`), installer not executed, and no runtime pass has been run on this dll.
  aborted the moment the passwords surface opened:
  `FATAL … brows_surface.mojom.cc:12213 DCHECK failed: !connected. PageHandler::GetPasswordsCallback
  was destroyed without first either being run or its corresponding binding being closed.` Cause and
  fix are in `MEMORY/20-domain-rules.md` §"Async mojom replies must be wrapped". Rebuilt:
  `out\Fame156\chrome.dll` 176,961,536 B @ 00:05 (sha256 `2fbee6df99…`), `mini_installer.exe` =
  `D:\FAME-Chromium
  `d304253a96a4b351f7448543514a3031940cc0030d3985b85e060998414cc370`), chain feed
  `D:\FAME-Chromium
  Runtime pass (`tools/oneoff/probe_156_surfaces.py`, offscreen, throwaway profile, CDP only):
  toolbar mounts 11 ids incl. `app-menu`; surfaces `menu` (title Brows, 13 surfaces, 11 buttons),
  `passwords` (mounts, 1 button, no rows on a fresh profile, **no abort**), `siteinfo` ("Site
  settings"), `settings` and `downloads` (mount, browser alive). Remaining log noise is upstream:
  `WebUIPinnedToolbarActions::GetDownloadButton()` and `WebUIReadOnlyOmnibox::ApplyCaretVisibility()`
  are `NOTIMPLEMENTED()`, log-only, call sites nullptr-guarded.
  NOT done, remaining: the new setup has not been installed (`--do-not-launch-chrome`), and nothing is
  published — R2 still serves sha `5a17ce7e…`, so `port/site/latest.json` was left untouched to keep
  the live feed consistent with the served object.

## 2026-11-13 — what the published release actually serves
- R2 bucket `brows-releases`, two keys per release: `Brows-<version>-Setup.exe` (named by
  `latest.json`) and the stable alias `Brows-156-Setup.exe` that `index.html` and `download.html`
  link. The alias used to be left behind on every release, so the site's own button served the
  previous build; `scripts\publish-site.ps1` now uploads both.
- Both keys are 688,808,960 B (sha256 `d304253a96a4b351f7448543514a3031940cc0030d3985b85e060998414cc370`)
  and `https://brows.dev/latest.json` names the same hash.
- Upload route for files over 300 MiB: the `tools\r2upload` Worker (R2 multipart in 64 MiB parts).
  It 404s for a few seconds after `wrangler deploy` while the workers.dev route propagates, and a
  redeploy of the same Worker name mid-upload invalidates the other upload's `OBJECT_KEY`, so never
  run two releases at once. `upload.py` now waits for the route and retries each part.
- The live-feed check in `publish-site.ps1` retries for about two minutes; the custom domain can lag
  the Worker subdomain, so a first-read mismatch is propagation, not a failed publish.
- `download.html` carries the installer size as text; it said 656.7 MiB after the
  11-13 build (688,808,960 B = 656.9 MiB). Corrected and the Worker redeployed
  (`52fac7c4`). Any release that changes the installer size must update that cell.
