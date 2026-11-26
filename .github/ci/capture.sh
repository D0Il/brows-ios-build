#!/usr/bin/env bash
# Light/dark capture pass. Needs $DEVICE (a booted simulator) and the fixture
# server already running from .github/ci/fixtures.sh.
#
# Every sheet is presented by a launch-only hook (`-BrowsSheet`) after the
# article's `didFinish`. On a loaded runner that can be 30 s after launch, so no
# fixed wait is used: the app writes `capture-sheet.txt` into its Documents when
# it presents a sheet, and this pass waits for that file (cleared at launch, so
# a stale one cannot pass for this run's) and then for two identical frames, so
# the entrance cannot be photographed half-faded.
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
DATA_CONTAINER=$(xcrun simctl get_app_container "$DEVICE" dev.brows.ios data 2>/dev/null || true)
echo "capture data container: ${DATA_CONTAINER:-<none>}"

for mode in light dark; do
  for sheet in menu bookmarks downloads history workspaces passwords siteinfo extensions settings tabs auth authsave dialog notice linknotice suggest pill scrolled reduced; do
    xcrun simctl terminate "$DEVICE" dev.brows.ios > /dev/null 2>&1 || true
    args=(-BrowsUITestReset -BrowsCaptureSeed -BrowsAppearance "$mode" -BrowsOpenURL http://localhost:8000/article.html)
    case "$sheet" in
      pill) args+=(-BrowsFocusPill) ;;
      scrolled) args+=(-BrowsScrollPage) ;;
      reduced) args+=(-BrowsReduceTransparency) ;;
      *) args+=(-BrowsSheet "$sheet") ;;
    esac
    if [ -n "$DATA_CONTAINER" ]; then rm -f "$DATA_CONTAINER/Documents/capture-sheet.txt"; fi
    xcrun simctl launch "$DEVICE" dev.brows.ios "${args[@]}" > /dev/null

    case "$sheet" in
      pill|scrolled|reduced)
        # These hooks present no sheet: the page and the chrome are the whole
        # surface, and nothing animates after the first paint.
        sleep 8
        xcrun simctl io "$DEVICE" screenshot "captures/${sheet}-${mode}.png"
        ;;
      *)
        presented=0
        for _ in $(seq 1 400); do
          if [ -n "$DATA_CONTAINER" ] && [ -f "$DATA_CONTAINER/Documents/capture-sheet.txt" ]; then
            presented=1
            break
          fi
          sleep 0.25
        done
        if [ "$presented" = 0 ]; then
          echo "${sheet}-${mode}: the sheet never presented within 100 s"
        fi
        sleep 1
        settled=0
        prev=""
        for i in 1 2 3 4 5 6; do
          cur="captures/.probe-${sheet}-${mode}-${i}.png"
          xcrun simctl io "$DEVICE" screenshot "$cur" > /dev/null 2>&1
          if [ -n "$prev" ] && cmp -s "$prev" "$cur"; then
            cp "$cur" "captures/${sheet}-${mode}.png"
            settled=1
            break
          fi
          prev="$cur"
          sleep 0.6
        done
        rm -f captures/.probe-*.png
        if [ "$settled" = 0 ]; then
          xcrun simctl io "$DEVICE" screenshot "captures/${sheet}-${mode}.png"
        fi
        ;;
    esac
  done
done
fi
