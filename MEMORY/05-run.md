# 05 — HOW TO BUILD, LAUNCH AND VERIFY

## Build
```
# Close the browser first; its DLLs are locked and links fail with permission denied.
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { $_.ExecutablePath -like 'D:\FAME-Chromium\*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"

cd C:\Users\xjpma\Documents\FAMEBROWZ
scripts\build-fame-component.cmd 10        # jobs count; 10 on 16 cores / ~8 GB free
```
- Output: `D:\FAME-Chromium\checkout\src\out\FameComponent\chrome.exe`.
- Logs: `D:\FAME-Chromium\logs\build-*.log`; console shows `[done/total]` and `FAILED:` blocks.
- `gn gen` runs only if `build.ninja` is absent; a normal incremental build does not.
- Never propose `out\FameBaseline` (deleted; its link took up to 3h37m).
- `-k 0` keeps completed work after a failed action. Investigate the first `FAILED:` block, not the
  last line.

## Launch
```
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\xjpma\Documents\FAMEBROWZ\scripts\launch-fame.ps1
```
Defaults: binary `out\FameComponent\chrome.exe`, profile `D:\FAME-Chromium\profiles\fame-main`,
`--no-first-run --no-default-browser-check`, URL google.com. The launcher refuses the Electron profile
`C:\Users\xjpma\AppData\Roaming\FAME`.

## Verify identity after a build
- Window title and taskbar should say **Brows**; never **FAME** or Chromium.
- `version_info`/about strings come from `chrome/app/theme/chromium/BRANDING`; confirm the file on disk
  has `COMPANY=Z7`, `PRODUCT=Brows` and that `install_static/chromium_install_modes.h` has `L"Z7"`.
- File properties → Details → Company name should be `Z7`; Product name `Brows`.
- Logo: packed from `default_100_percent/chromium` and `default_200_percent/chromium`.

## Prove a build actually contains the edit (cheap, before launching)
```
cd /d/FAME-Chromium/checkout/src/out/FameComponent
ls -l --time-style=full-iso chrome.dll
cd /d/FAME-Chromium/checkout/src
find chrome/browser/ui/views chrome/browser/resources -newer out/FameComponent/chrome.dll -name '*.cc' -o -newer out/FameComponent/chrome.dll -name '*.ts'
```
`chrome.dll` newer than every edited file = the relink contains them; an edited file newer = not built.
A component build's real code is in `chrome.dll`, not the small `chrome.exe` (2026-11-01: the two tab
files were newer than the 02:12 dll, the 02:33 relink included them — export 88285, 88572).

## One verification pass, never repeated screen grabs
- Queue every pending runtime check into **one** scripted pass, then run it once. The user's order:
  "QUEUE ALL OF THE FUCKING VISUAL CHECKS INTO ONE FUCKING PASS" (export 87790).
- No OS-level mouse/keyboard input, ever. Drive the app with CDP (`D:\FAME-Chromium\temp\devtools_eval.py`)
  and capture offscreen with `printwindow-rail.ps1` (PrintWindow, window parked off-screen).
- The 2026-11-01 pending queue is historical; every item on it was fixed and exercised. Queue only
  the checks for the change you are building, and do not reuse an old list as current status.

## Command palette probe (2026-11-04)
```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-fame-surface-probe.ps1 -Surface command-palette -Browser D:\FAME-Chromium\checkout\src\out\FameComponent\chrome.exe -Profile D:\FAME-Chromium\profiles\fame-probe
```
- Opens the FAME menu, clicks `#open-command-palette`, asserts `#command-palette` is visible,
  >=10 rows, and width 520. Run only after `resources.pak` is newer than the edited
  `fame_surface.{html,ts,css}`.

## Verify the rail (no eyeballing from memory)
- No old-build blueprint. The reference is the current fork's source and the running build.
- Controlled capture: `D:\FAME-Chromium\temp\glass-controlled-test.ps1` — pattern first, window on it,
  both rails at identical coordinates. The harness must stamp pid + exe + foreground HWND and refuse to
  run if `FAME.exe` exists.
- Known geometry target: **38px tab strip** (old CSS: 36px titlebar + 2px) and 38px toolbar, measured
  38/38 on 2026-11-02 via UIA tab rects and the toolbar page's `innerHeight`; the exclusion chain in
  `browser_view_tabbed_layout_impl.cc` decides them.

## Traps
- Running browser → DLL lock → `permission denied` on every `LINK(DLL)`.
- 16 GB RAM: too many clang-cl workers plus the browser can produce
  `LLVM ERROR: out of memory` / "paging file is too small". The user now wants max workers, but close
  the browser and keep ~8 GB free.
- Pagefile must stay on `C:` (NVMe). On `D:` (7200 rpm) the machine freezes.
- Defender exclusions are already set for the tree and the four build tools; a running build must be
  restarted for new exclusions to apply.
- A resource change (BRANDING, `.grd`, `BUILD.gn` data) rebuilds paks and can look like a full graph;
  do not claim "one link" without reading the pending count.

- Edge resize + workspace card (2026-11-03): `python D:\FAME-Chromium\temp\verify_resize_workspaces.py`
  - one offscreen pass; posted drags and CDP workspace card geometry.

- Child resize routing (2026-11-03): `python D:\FAME-Chromium\temp\verify_child_resize.py`
  - offscreen test profile only; checks the render child returns `-1` at each edge and the parent drags
  +60/+40/+30.

- Client resize fallback (2026-11-03): `python D:\FAME-Chromium\temp\verify_client_resize.py`
  - offscreen only; presses 12 px inside each edge via client `WM_LBUTTONDOWN` and asserts
  left +60, right +40, bottom +30.

## 2026-11-13 — two traps that produced wrong conclusions (both measured, export 17931-18103)

- **Never verify a WebUI/CSS/TS change by `chrome.dll` alone.** Those live in `resources.pak`; after
  the bookmark-flyout link the installed `chrome.dll` was still `efeb7f9c…` (byte-identical to the
  previous build) while `resources.pak` changed to `6d48da6d8a5f`. Hash `chrome.dll`, `chrome.exe`,
  `resources.pak` and `resources_100.pak` before saying what shipped.
- **Never start a second ninja/autoninja while the chain is running.** Concurrent siso invocations
  report phantom `F: ACTION //chrome/browser/resources/…:build_min_js` (it later says "no work to do"),
  and the collision kills the running chain (`CHAIN_EXIT=1`). One build at a time; poll the log only.

## 2026-11-13 — the fast WebUI loop and the UI checks

- **`scripts\preview-webui.cmd [surface] [--no-launch]`** — rebuilds only `resources.pak` and runs
  `out\Fame156\chrome.exe` against `D:\FAME-Chromium	emp\webui-preview`, window parked off-screen.
  The installed browser is never closed and `chrome.dll` is never relinked. Use it for CSS/TS work;
  it is not a substitute for the chain when C++ or the installer changes.
- **`tools/oneoff/diag_ui.py`** — one off-screen pass: menu arrow movement (`ARROWS`) and the
  light/dark computed values (`LIGHT` / `DARK`) via CDP media emulation.
- **`tools/oneoff/check_snap_hittest.py`** — sends `WM_NCHITTEST` to the running window and counts
  `HTMAXBUTTON` answers in the top-right corner.
- Log discipline: `rm -f *.log` **once deleted the running chain's log** while it was writing (the
  handle survived, the name did not, so the run had no log and no `CHAIN_EXIT`). Never delete
  `build-*.log` while a chain is alive.

## 2026-11-13 — publish-site.ps1 can exit 1 *after* a good upload

The 19:58 installer publish uploaded both R2 keys and then died deleting the temporary upload
Worker (`A request to the Cloudflare API (/workers/brows-upload) failed`), which aborts the script
**before** the `brows-site` deploy. Result: R2 held the new bytes while `https://brows.dev/latest.json`
still served the previous sha — an updater would have downloaded bytes that fail its own SHA-256
check. Repair: `cd tools\site-worker && npx --yes wrangler@latest deploy` (exit 0), then confirm
`latest.json` sha equals `sha256sum` of `releases\Brows-156-Setup.exe` and the alias
`Content-Length` equals the file size. After that: feed `ca952b2e…`, alias 688,789,504 bytes.
Never treat a publish exit code alone as "the site matches the build".

### 2026-11-13 — publish-site.ps1 hardening (measured)

The temporary upload Worker's delete is now **best effort** and cannot abort the run:
`& cmd /c "npx --yes wrangler@latest delete --name brows-upload --force 1>nul 2>nul"`, then
`$global:LASTEXITCODE = 0`. Two traps found doing it:
- a plain `try { ... } catch { }` around the native command is **not enough** — PowerShell 5.1 turns a
  native command's stderr into a terminating `NativeCommandError` under `$ErrorActionPreference='Stop'`,
  which is what skipped the deploy twice;
- MSYS/Git-Bash rewrites the literal `nul` in command arguments to `/dev/null`, so a `nul` redirect
  written through the shell becomes an invalid path inside `cmd`. Write that line with a file tool, and
  check it with Python `repr`, not with `grep "nul"` (the pattern is rewritten too).

Measured: a run whose delete failed still reached "Deploying the brows-site Worker…", "Checking the
live feed…" and `PUBLISH_EXIT=0`. The only failure left in the script is the feed check
(`if ($feed.sha256 -ne $hash) { throw 'Feed SHA-256 does not match the installer' }`, plus the URL
check); that branch was verified by reading the source, not by publishing a deliberately wrong feed.


## 2026-11-15 — the 156 chain stops at autoninja's siso/ninja guard

`cmd //c "scriptsuild-fame-156-installer.cmd 10"` writes `build-now-156.log` containing only the
autoninja guard text, then `EXIT:1` — no compile, no installer. Repair is `gn gen out\Fame156` from
the script's own env (see `20-domain-rules.md` §2026-11-15); do **not** reach for `gn clean`.

## Build ordering (2026-11-15)

**Nothing gets built until every requested fix is written.** The build is the final action of a pass.
If the user reports a defect while a build runs, stop that build first (`process_stop` on the build
PID, then confirm no `siso`/`autoninja` remains), write the fix, and only then start the one build
that contains the whole pass. Measured on this machine: a `chrome.dll` link is ~16-25 minutes and an
installer rebuild ~11 minutes, so a second build is a real cost, never a shortcut.

## iOS app build (Brows for iPhone) — 2026-11-16

Source lives in `ios/Brows/` (XcodeGen spec + SwiftUI/WKWebView app). It has **never been compiled**;
do not claim it builds until a compiler says so.

- On a Mac with Xcode: `brew install xcodegen`, then in `ios/Brows`: `xcodegen generate` and
  `xcodebuild -project Brows.xcodeproj -scheme Brows -sdk iphoneos -destination "generic/platform=iOS" \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`,
  then `mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/Brows.app Payload/ && zip -qry Brows.ipa Payload`.
- CI equivalent: `.github/workflows/ios-build.yml` (macos-15 runner) uploads `Brows-ipa`.
- Install on the phone: AltServer for Windows + AltStore, sign the unsigned `.ipa` with the user's Apple ID
  (free account = 7-day re-sign). No App Store submission: 2.5.6 requires WebKit, which this app already is.
- The Mac (`xavier@192.168.2.45`, key `~/.ssh/id_ed25519_brows_mac`) is a 2015 Air: Catalina 10.15.7,
  no Xcode, 73 GiB free after the Boot Camp removal. Xcode 26 needs Sequoia 15.6+, so the Mac cannot
  produce an App Store build.


## iOS — local Swift gate (no simulator, no CI)
The official Swift toolchain runs on this Windows machine, so the iOS sources are checked before any
push. Installed once with `winget install --id Swift.Toolchain -e --source winget` (Swift 6.4.2, free,
into `%LocalAppData%ProgramsSwift`); Visual Studio 2026 with the C++ tools was already present.
```
npm run swift:check      # scripts/swift-standards.mjs
```
- Parses all 27 app files + the UI test with the real front end (`swiftc -parse`, ~4-5 s). A brace,
  string or signature typo fails here, not after a 10-minute simulator build.
- Enforces the rules the user already had to report: no system alert (failures use `PageNoticeCard` /
  `LinkNoticeCard`), no material blur, no sidebar or `NavigationSplitView`, no OS-dependent colour
  (`systemBackground`, `UIColor.label`, `Color.primary/secondary`) — the plates and ink are Theme
  tokens — and no `FAME`.
- Exit 1 = code or rule violation, exit 2 = toolchain missing (prints the winget line).
- Stage 3, added 2026-11-18: `AddressResolver.swift` (Foundation only) is compiled with `-sdk
  Windows.sdk` and run against `tools/ios/AddressRouteCheck.swift` — 16 real routing cases, including
  typed `mailto:`/`tel:`/`ftp:`, `host:port` staying a host, search text, and the unbuildable address.
  The runtime DLLs come from the Swift `Runtimes` folder (`Runtimes/<ver>/usr/bin`). A planted
  regression in the routing guard fails this stage (exit 1). Anything touching a view or WebKit still
  needs the simulator: this checks the pure rules only.
