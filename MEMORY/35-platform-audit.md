# Platform audit — the app's whole surface inventory, with proof or a named gap

This file exists because "it looked right" is not evidence. Every row names one
thing the app ships, the source that governs it, and the check that proves it in
this repo. Proof types are named: **test** (`BrowsUITests.swift` method),
**capture** (CI light/dark screenshot, 34 per run), **source** (file and line),
**citation** (Apple/WebKit/App Store). A row with none is in **Gaps**, not in the
inventory.

## Sources used for the platform claims

| Short name | Source |
| --- | --- |
| Glass docs | Apple, *Applying Liquid Glass to custom views* — `glassEffect` renders behind the view's content; shapes anchor to the view's bounds |
| WWDC25-323 | Apple, *Build a SwiftUI app with the new design*, 20:15 — "glass can not sample other glass"; `GlassEffectContainer` shares one sampling region |
| HIG Buttons | Apple HIG, *Buttons* — "a button needs a hit region of at least 44x44 pt" |
| HIG Accessibility | Apple HIG, *Accessibility* — iOS default control 44×44 pt, minimum 28×28 pt |
| HIG Layout | Apple HIG, *Layout* — the safe area is the region not covered by hardware or window chrome |
| UIKit effect docs | Apple, `UIVisualEffectView` — effects need the hosting window; a snapshot of the effect view alone contains no effect |
| hCaptcha #50 | hCaptcha iOS SDK issue #50 — a `WKWebView` inside a visual-effect subtree renders grey |
| FB20969772 | iOS 26 bug report — mixed SwiftUI/UIKit + Liquid Glass stalls when a text field raises the keyboard |
| 2.5.6 | App Store Review Guideline 2.5.6 — apps may not use non-WebKit web-rendering engines |

## Chrome and floating surfaces

| Surface | What ships | Source of the rule | Proof |
| --- | --- | --- | --- |
| Dock capsule | One floating capsule, page visible under it, 8 pt side inset, radius 28 | app pane; captures 44933304213, 44956470184 | capture `brows-launch.png`, `pill-light`/`pill-dark` |
| Back / forward | Leading edge, 44 pt targets, slots always reserved (a workspace switch was re-flowing the row under a tap) | HIG Buttons | test `testDockKeepsTabsAndMenuAfterThePill`; trace fix recorded below |
| Address pill | Badge, URL, reload, star; star yields its width to the field while typing | Safari/Chrome in-bar controls; user requirement | test `testDockKeepsTabsAndMenuAfterThePill` (reload in pill, star hidden while typing, page kept) |
| Reload / stop | Inside the pill, swaps glyph with `isLoading` | Chromium toolbar spec, Chrome Android, Vivaldi, Samsung Internet, Safari iOS | test `testDockKeepsTabsAndMenuAfterThePill` |
| Star | Bookmarks the current URL, filled when bookmarked | desktop rail's star | tests `testBookmarkStar`, `testBookmarkFromMenuNavigates`; capture `bookmarks-*` |
| Tabs button + count | Trailing edge, opens the tab gallery | thumb reach order | tests `testCloseTab`, `testTabGallerySearch`, `testDockKeepsTabsAndMenuAfterThePill` |
| Menu button | Trailing edge, opens the app menu | phone dock spec | tests `testBothAppearancesOpenTheMenu`, `testWorkspaceSwitch` |
| Address completions | History/bookmark rows under the pill while editing | desktop omnibox stores (no network) | test `testAddressPillCompletesFromHistory`; capture `suggest-*` |
| Focus state | Pill wash + rim change on focus, no second glass layer | Glass docs (no nested glass) | `AddressField.swift`, `Theme.pillFocusWash`; capture `pill-light` |
| Address bar position | Bottom (default) or top, from Settings | user setting | test `testAddressBarTopSetting` |
| Start page | Search field, wordmark, wallpaper | `StartPage.swift` | tests `testStartPageSearchField`, `testStartPageSearchNavigates`; capture `brows-launch.png` |
| Find bar | In-page find with next/previous | `PageTools.find` | test `testFindInPage` |
| Reader sheet | Reader mode extraction, failure card | `PageTools.reader` | tests `testReaderMode`, `testReaderFailureUsesTheAppsOwnCard` |

## Panels (all on the app's pane with the page snapshot behind them)

| Panel | Content | Proof |
| --- | --- | --- |
| Menu | Site information, bookmarks, history, downloads, passwords, content blockers, workspaces, settings; zoom, reload, find, reader, print, PDF, tab commands | tests `testBothAppearancesOpenTheMenu`, `testRailAndMenuPanels`, `testWorkspaceSwitch`, `testBookmarkFromMenuNavigates`; captures `menu-light`, `menu-dark` |
| Tab gallery | Cards, close, add, search tabs | tests `testCloseTab`, `testTabGallerySearch`, `testDockKeepsTabsAndMenuAfterThePill`; captures `tabs-*` |
| Bookmarks | Folder sections, per-row open, delete | test `testBookmarkFromMenuNavigates`; captures `bookmarks-*` |
| History | Day sections, per-row delete, clear | capture `history-*`; source `Panels.swift` (no direct test — see Gaps) |
| Downloads | Rows, cancel/remove, private sweep | tests `testDownloadStarts`, `testPrivateDownloadIsNotPersisted`, `testPrivateDownloadFileIsSweptOnNextLaunch`, `testClosingPrivateTabsDeletesTheirDownloadFiles`; captures `downloads-*` |
| Passwords | Saved logins, reveal/delete, save errors | tests `testPasswordSaveAndAutofill`, `testHTTPAuthPromptCompletesAndSaves`; captures `passwords-*` |
| Content blockers | Per-site exception list, toggle | test `testSiteBlockingToggle`; captures `extensions-*` |
| Workspaces | Create, switch, delete (tabs move to the neighbour) | tests `testWorkspaceSwitch`, `testWorkspaceDelete`; captures `workspaces-*` |
| Settings | Appearance, address bar position, blocking toggles, defaults | test `testAddressBarTopSetting`; capture `settings-*` |
| Site information | Host, scheme, certificate summary | capture `siteinfo-*`; source `SiteInfoSheet.swift` (no direct test — see Gaps) |

## Cards and sheets over the page

| Card | Trigger | Proof |
| --- | --- | --- |
| `LinkNoticeCard` | a link or popup whose scheme nothing opens | tests `testExternalSchemesHandOffWithoutLeavingThePage`, `testAddressPillExplainsAnAddressItCannotOpen`, `testTypedExternalSchemeRoutesInsteadOfBecomingAPage`, `testRefusedPopupUsesTheAppsCard`; captures `linknotice-*` |
| `PageNoticeCard` | a page command that could not complete | tests `testReaderFailureUsesTheAppsOwnCard`; capture `notice-*` |
| `ScriptDialogCard` | `alert`/`confirm`/`prompt` from a page | test `testJavaScriptDialogsAnswerThePage`; capture `dialog-*` |
| `AuthSheet` (HTTP Basic/Digest) | 401 challenge | tests `testHTTPAuthPromptCompletesAndSaves`, `testHTTPAuthSurvivesRelaunchAndSecondAccountOffersChoice`; capture `auth-*` |
| Credential save card | form submit with a password | tests `testPasswordSaveAndAutofill`, `testHTTPAuthSurvivesRelaunchAndSecondAccountOffersChoice`; capture `authsave-*` |

## Web page interactions

| Behaviour | Implementation | Proof |
| --- | --- | --- |
| Typed address → page / search | `AddressResolver.route` (Foundation-only, run on Windows by `npm run swift:check`) | tests `testNavigationFromAddressPill`, `testStartPageSearchNavigates`; `logic: address routes clean` |
| Typed external scheme | hands off or explains, page untouched | tests `testTypedExternalSchemeRoutesInsteadOfBecomingAPage`, `testAddressPillExplainsAnAddressItCannotOpen` |
| Tapped external scheme | `decidePolicyFor` cancels before WebKit errors | test `testExternalSchemesHandOffWithoutLeavingThePage` |
| Custom-scheme popup | document-start `window.open` guard posts the URL to the app; WebKit does not deliver it to `createWebViewWith` | test `testRefusedPopupUsesTheAppsCard`; source `PageTools.popupGuardScript`, `BrowserModel.userContentController` |
| `window.open` / `target=_blank` | real `WKWebView` from `createWebViewWith`, adopted as a tab | tests `testNewWindowLinksOpenAndSelectANewTab`, `testWindowOpenWithFeaturesOpensOneSelectedTab` |
| Named windows | reuse the named tab instead of duplicating | tests `testWindowOpenReusesTheNamedWindow`, `testNamedWindowReopensAfterItsPopupIsClosed` |
| Private popups | stay private, own data store | test `testNamedPopupFromAPrivateTabStaysPrivate` |
| Private tabs | non-persistent store, badge, sweep on close | tests `testPrivateTabBadge`, `testPrivateDownloadFileIsSweptOnNextLaunch`; `Vault` for secrets |
| Downloads | `WKDownload`, destination, cleanup | tests `testDownloadStarts`, `testPrivateDownloadIsNotPersisted`; captures `downloads-*` |
| Ad/tracker blocking | `WKContentRuleList` compiled in-app, per-site exceptions | test `testSiteBlockingToggle`; source `AdBlocker.swift` |
| Reader mode | DOM extraction into `ReaderSheet` | test `testReaderMode` |
| Find in page | injected find, next/previous, count | test `testFindInPage` |
| Zoom | per-tab `pageZoom`, menu cluster | source `BrowserModel.adjustZoom` (no test — see Gaps) |
| Print / Save as PDF | `UIPrintInteractionController` / render to PDF | source `PageTools` (no test, no capture — see Gaps) |
| Page snapshot for glass | `PanelBackdrop.capture` (6 pt blur), drawn at window size under each pane | captures `menu-light`, `pill-light`, `linknotice-*` |

## Platform, lifecycle, storage

| Concern | Implementation | Proof |
| --- | --- | --- |
| Safe areas | page full-bleed; content inset `safe.top + 32`, `safe.bottom + 60`; dock above home indicator | HIG Layout; source `WebViewContainer.swift`; captures show text clearing the capsule |
| 44 pt targets | every dock control `.frame(minWidth: 44, minHeight: 44)` | HIG Buttons/Accessibility; asserted in `testDockKeepsTabsAndMenuAfterThePill` |
| Appearance | follows system; `-BrowsAppearance` pins one for captures | tests `testBothAppearancesOpenTheMenu`, `testAppearanceTokensPassContrastAudit`; 34 light/dark captures |
| Contrast | WCAG ratio check over the palette tokens | test `testAppearanceTokensPassContrastAudit`; source `Theme.contrastAudit` |
| Persistence | `UserDefaults` for tabs/workspaces/history/settings/bookmarks; Keychain for secrets | tests `testHTTPAuthSurvivesRelaunchAndSecondAccountOffersChoice`, `testPrivateDownloadFileIsSweptOnNextLaunch`; source `Vault.swift` |
| Private data | non-persistent data store, private downloads swept, no history writes | tests `testPrivateTabBadge`, `testPrivateDownloadIsNotPersisted`, `testClosingPrivateTabsDeletesTheirDownloadFiles` |
| WebKit-only | no extension engine; content blockers are the WebKit rule list | citation 2.5.6; source `AdBlocker.swift`; menu says "Content blockers" |
| Keyboard focus | hosted `UITextField` in the dock; focus flag drives star visibility | test `testDockKeepsTabsAndMenuAfterThePill`; see Gaps for keyboard avoidance |

## Liquid Glass touchpoints

| Touchpoint | Treatment | Proof |
| --- | --- | --- |
| Dock | app pane (snapshot + tint + rim), pill tint on it | captures `brows-launch`, `pill-*` |
| Panels | one pane per panel, page snapshot under it | captures `menu-*`, `bookmarks-*`, `settings-*`, `tabs-*` |
| Cards | one pane per card | captures `linknotice-*`, `notice-*`, `dialog-*`, `auth-*` |
| System `UIGlassEffect` | tried on dock/panels/cards; recorded here with results | runs 44952121294, 44954608022 |

### The glass experiment, by run

| Build | Material | Result |
| --- | --- | --- |
| 44933304213 | app pane with page snapshot | 37/37 green, 34 captures |
| 44952121294 | `UIGlassEffect` over the bare web view | shards 2 and 3 red |
| 44954608022 | `UIGlassEffect` over the page snapshot | shards 1, 2 and 3 red |
| 44956470184 | app pane again | shard 3 red: focus, menu, notice card |

**Correction that stays:** the pane build fails the same three signatures
(`Neither element nor any descendant has keyboard focus … rail.address`,
`menu did not open`, `linknotice.message` missing), so those failures are not a
consequence of system glass and the earlier attribution is withdrawn. What the
captures do establish: `UIGlassEffect` over a bare `WKWebView` draws a pale plate
because the material cannot sample out-of-process web content; over the page
snapshot it does show the page, at the cost of a per-load `takeSnapshot`.

## Captures (34 per run)

`auth`, `authsave`, `bookmarks`, `dialog`, `downloads`, `extensions`, `history`,
`linknotice`, `menu`, `notice`, `passwords`, `pill`, `settings`, `siteinfo`,
`suggest`, `tabs`, `workspaces` — each light and dark — plus `brows-launch.png`
and `brows-article.png`.

## Gaps — named, with what would settle each

| Gap | Why it is not proven | What would settle it |
| --- | --- | --- |
| History panel has no direct test | only the `history-*` capture exercises it | a test that visits two pages, opens History, asserts both rows and delete |
| Site information has no direct test | only the `siteinfo-*` capture | a test that opens it on an HTTPS page and asserts host/scheme |
| Zoom has no test | menu cluster only | a test that taps `+`, reads `pageZoom`, taps the reset |
| Print and Save as PDF have no test or capture | system UI, not exercised by CI | a test that asserts `pdfFile` produces a file of non-zero size |
| Keyboard avoidance is unproven | no explicit inset for the dock when the keyboard is up; relies on SwiftUI default | a test that focuses the pill and asserts the dock's frame stays above the keyboard |
| iOS 26 scroll edge effects unverified | `UIScrollView.topEdgeEffect` defaults changed; the app does not set it | a visual capture of a scrolled page under the top strip on an iOS 26 device |
| Dynamic Type / VoiceOver / Reduce Motion | not implemented explicitly, no accessibility test | a UI test at the largest text size, a VoiceOver pass, and a Reduce Transparency capture |
| Landscape and iPad layouts | the suite runs one iPhone portrait destination | a second destination in the CI matrix |
| Physical-device behaviour | every capture comes from the simulator | one run on hardware, especially Dynamic Island and home-indicator overlap |
| App Store submission eligibility | 2.5.6 is respected in the source (WebKit only), but no submission has been made | an actual review submission |

## Defect log for this pass

### `testWorkspaceSwitch` — the second menu tap

Trace (shard 2, job 137011947731, test at t = 17.94 s): the tap on `rail.menu`
is synthesised, the app goes idle at 17.93–18.51 s, and the failure snapshot then
shows the page and the rail buttons with **no panel of any kind**. Fixes applied:
the reserved back/forward slots now keep a fixed 44×44 size (a flexible `Color.clear`
grew the dock in an earlier run and made twelve tests fail), and the dock's menu
button goes through `BrowserModel.openMenu()`, which closes any panel still on
screen before presenting the menu. `testWorkspaceSwitch` passed in runs 45008312328
and 45009918574 and failed again in 45011227761, so the cause is not settled.

### `testRefusedPopupUsesTheAppsCard` — the popup refusal

The fixture calls `window.open('brows-nothing:popup', ...)`. Evidence from three
runs with instrumentation:

- a document-start guard posted `guard:true`: the script runs and the message
  handler works (route showed `popup guard armed`);
- the guard's `window.open` override reported itself installed, both by assignment
  and by `defineProperty`;
- the refused call still produced no message, no navigation delegate call and no
  title change.

Conclusion: in this WKWebView, neither `window.open` for a custom scheme nor any
in-page override of it reaches the app. The guard, the message handler and the
title channel were removed rather than left as dead code. The test is still red and
the real fix has to come from a path WebKit actually reports (for example a
`target="_blank"` anchor, which does reach `createWebViewWith`), or from a
documented WebKit hook not yet found.

### Suite stability

Across eleven runs on unchanged or near-identical code, the failures move between
shards and tests: address-pill focus, `menu did not open`, `linknotice.message`
missing, `download did not start`, HTTP-auth prompt missing. `testDownloadStarts`
and `testFindInPage` failed on builds where neither the dock nor the popup path
changed. The one fully green run in this stretch is 44933304213.
