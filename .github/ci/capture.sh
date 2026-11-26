#!/usr/bin/env bash
# Light/dark capture pass. Needs $DEVICE (a booted simulator) and the fixture
# server already running from .github/ci/fixtures.sh.
set -euo pipefail
cd "${GITHUB_WORKSPACE:-$(pwd)}"
if [ "${SKIP_CAPTURES:-false}" != "true" ]; then
xcrun simctl terminate "$DEVICE" dev.brows.ios || true
xcrun simctl launch "$DEVICE" dev.brows.ios -BrowsOpenURL http://localhost:8000/article.html > /dev/null
sleep 8
xcrun simctl io "$DEVICE" screenshot brows-article.png
# Every text-bearing sheet, in both appearances, plus the pill's selected
# state, a page scrolled under the top strip, and the chrome with Reduce
# Transparency forced. These are launch-only hooks (`-BrowsSheet`,
# `-BrowsAppearance`, `-BrowsFocusPill`, `-BrowsScrollPage`,
# `-BrowsReduceTransparency`) and never reachable from a page.
mkdir -p captures
# The app writes this file when a launch sheet is actually being presented.
# The page request is a second early on a cold runner, so a fixed wait shot
# sheets mid-entrance (menu-light, settings-light, tabs-dark, auth-light) or
# before they appeared (history-dark, downloads-light) in run 45718399985.
DATA_CONTAINER=$(xcrun simctl get_app_container "$DEVICE" dev.brows.ios data 2>/dev/null || true)
for mode in light dark; do
  for sheet in menu bookmarks downloads history workspaces passwords siteinfo extensions settings tabs auth authsave dialog notice linknotice suggest pill scrolled reduced; do
    xcrun simctl terminate "$DEVICE" dev.brows.ios > /dev/null 2>&1 || true
    args=(-BrowsUITestReset -BrowsCaptureSeed -BrowsAppearance "$mode" -BrowsOpenURL http://localhost:8000/article.html)
    if [ "$sheet" = "pill" ]; then
      args+=(-BrowsFocusPill)
    elif [ "$sheet" = "scrolled" ]; then
      # The article scrolled under the top strip: the one frame that shows
      # whether a scroll-edge pocket veils the first line at the status bar.
      args+=(-BrowsScrollPage)
    elif [ "$sheet" = "reduced" ]; then
      # Reduce Transparency forced on: the chip and the dock must be solid over
      # the page, not a blurred snapshot of it. simctl has no key for the
      # setting, so the app's own launch argument states it.
      args+=(-BrowsReduceTransparency)
    else
      args+=(-BrowsSheet "$sheet")
    fi
    if [ -n "$DATA_CONTAINER" ]; then rm -f "$DATA_CONTAINER/Documents/capture-sheet.txt"; fi
    seen=$(grep -c "GET /article.html" fixtures/server.log 2>/dev/null || true)
    xcrun simctl launch "$DEVICE" dev.brows.ios "${args[@]}" > /dev/null
    # The page loads in the same launch as the sheet hook. A flat four
    # seconds once shot suggest-dark with an unpainted black page and a
    # live progress bar (run 44656125222), so wait until the fixture
    # server has this launch's request, then let the page paint.
    for _ in $(seq 1 32); do
      now=$(grep -c "GET /article.html" fixtures/server.log 2>/dev/null || true)
      if [ "${now:-0}" -gt "${seen:-0}" ]; then break; fi
      sleep 0.25
    done
    if [ "$sheet" = "pill" ] || [ "$sheet" = "scrolled" ] || [ "$sheet" = "reduced" ]; then
      # These hooks present no sheet: the page and the chrome are the whole
      # surface and nothing animates after the first paint.
      sleep 4
    else
      for _ in $(seq 1 80); do
        if [ -n "$DATA_CONTAINER" ] && [ -f "$DATA_CONTAINER/Documents/capture-sheet.txt" ]; then break; fi
        sleep 0.25
      done
      # The sheet's 0.35 s entrance, then the keyboard for `suggest`.
      sleep 1.2
    fi
    xcrun simctl io "$DEVICE" screenshot "captures/${sheet}-${mode}.png"
  done
done
fi
