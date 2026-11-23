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
# state and a page scrolled under the top strip. These are launch-only hooks
# (`-BrowsSheet`, `-BrowsAppearance`, `-BrowsFocusPill`, `-BrowsScrollPage`)
# and never reachable from a page.
mkdir -p captures
for mode in light dark; do
  for sheet in menu bookmarks downloads history workspaces passwords siteinfo extensions settings tabs auth authsave dialog notice linknotice suggest pill scrolled; do
    xcrun simctl terminate "$DEVICE" dev.brows.ios > /dev/null 2>&1 || true
    args=(-BrowsUITestReset -BrowsCaptureSeed -BrowsAppearance "$mode" -BrowsOpenURL http://localhost:8000/article.html)
    if [ "$sheet" = "pill" ]; then
      args+=(-BrowsFocusPill)
    elif [ "$sheet" = "scrolled" ]; then
      # The article scrolled under the top strip: the one frame that shows
      # whether a scroll-edge pocket veils the first line at the status bar.
      args+=(-BrowsScrollPage)
    else
      args+=(-BrowsSheet "$sheet")
    fi
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
    sleep 3
    xcrun simctl io "$DEVICE" screenshot "captures/${sheet}-${mode}.png"
  done
done
fi
