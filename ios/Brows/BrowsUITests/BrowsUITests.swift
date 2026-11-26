import XCTest

/// Drives the surfaces the app actually shows: the rail exists, the menu opens,
/// and the panels behind its rows are real.
final class BrowsUITests: XCTestCase {
    /// Each test starts from a clean install state, so tab counts are deterministic.
    /// `reset: false` is the relaunch case: the Keychain row saved by the previous
    /// launch must still answer the challenge.
    private func makeApp(extra: [String] = [], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-BrowsUITestReset"] : []) + extra
        app.launch()
        return app
    }


    /// Returns a menu row that can actually be tapped: opens the menu when it is
    /// not already open, and scrolls the list until the row is on screen. The
    /// menu is longer than the phone now, so a row can exist without being
    /// reachable — a tap on it silently misses.
    @discardableResult
    private func menuRow(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        // The dock re-lays itself out when a page load changes the back control,
        // and a tap that lands during that swap is lost. Retry the tap rather
        // than failing on the known race.
        for attempt in 0..<3 {
            if app.buttons["menu.site-information"].exists { break }
            if attempt == 0 {
                app.buttons["rail.menu"].tap()
            } else if app.buttons["rail.menu"].isHittable {
                app.buttons["rail.menu"].tap()
            }
            _ = app.buttons["menu.site-information"].waitForExistence(timeout: 5)
        }
        XCTAssertTrue(app.buttons["menu.site-information"].exists,
                      "menu did not open for \(identifier)")
        let row = app.buttons[identifier]
        // Rows below the fold are not in the accessibility tree at all, so scroll
        // the menu's own list until the row appears and can be tapped.
        let list = app.collectionViews.firstMatch
        var scrolls = 0
        while !(row.exists && row.isHittable) && scrolls < 8 {
            if list.exists {
                list.swipeUp()
            } else {
                app.swipeUp()
            }
            _ = row.waitForExistence(timeout: 1)
            scrolls += 1
        }
        XCTAssertTrue(row.exists, "\(identifier) missing from the menu")
        // A tap that lands while the list is still decelerating only stops the
        // scroll; let it settle first.
        if scrolls > 0 { Thread.sleep(forTimeInterval: 0.6) }
        return row
    }

    /// The sheet tokens must clear WCAG AA in both appearances, not just look
    /// plausible: Theme computes the ratios at launch when asked.
    func testAppearanceTokensPassContrastAudit() {
        let app = makeApp(extra: ["-BrowsContrastAudit"])
        let audit = app.staticTexts["audit.contrast"]
        XCTAssertTrue(audit.waitForExistence(timeout: 15), "contrast audit did not run")
        XCTAssertEqual(audit.label, "PASS", "contrast audit failed: \(audit.label)")
    }

    /// Both appearances present the same, readable menu (the capture pass covers
    /// the pixels; this keeps the light appearance wired).
    func testBothAppearancesOpenTheMenu() {
        for mode in ["light", "dark"] {
            let app = makeApp(extra: ["-BrowsAppearance", mode])
            app.buttons["rail.menu"].tap()
            XCTAssertTrue(
                app.staticTexts["Site information"].waitForExistence(timeout: 10),
                "menu did not open in \(mode) appearance"
            )
            app.terminate()
        }
    }

    func testRailAndMenuPanels() {
        let app = makeApp()

        let address = app.textFields["rail.address"]
        XCTAssertTrue(address.waitForExistence(timeout: 15), "address pill missing")

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10), "menu did not open")
        // The panel's glass is the page snapshot under a 30% plate. Without the
        // snapshot the live page shows through sharp and the rows lose contrast.
        let backdrop = app.staticTexts["debug.backdrop"]
        XCTAssertTrue(backdrop.waitForExistence(timeout: 3), "no backdrop probe")
        XCTAssertEqual(backdrop.label, "set", "the menu's glass has no page snapshot")

        app.staticTexts["Site information"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10), "site information panel missing")
        app.buttons["Done"].tap()

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Downloads"].waitForExistence(timeout: 10), "menu did not reopen")
        app.staticTexts["Downloads"].tap()
        XCTAssertTrue(app.staticTexts["Downloads"].waitForExistence(timeout: 10), "downloads panel missing")
        app.buttons["Done"].tap()

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Passwords"].waitForExistence(timeout: 10), "menu did not reopen")
        app.staticTexts["Passwords"].tap()
        XCTAssertTrue(app.staticTexts["Passwords"].waitForExistence(timeout: 10), "passwords panel missing")
        app.buttons["Done"].tap()

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 10), "tab gallery missing")
        app.buttons["Done"].tap()

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Workspaces"].waitForExistence(timeout: 10), "menu did not reopen")
        menuRow("menu.workspaces", in: app).tap()
        XCTAssertTrue(app.staticTexts["CURRENT"].waitForExistence(timeout: 10), "workspaces panel missing")
        app.buttons["Done"].tap()

        XCTAssertTrue(address.waitForExistence(timeout: 5), "rail did not come back")
    }

    /// Private is a mode with a persistent mark, as on the desktop.
    func testPrivateTabBadge() {
        let app = makeApp()

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))
        // The tab commands sit below the fold in the menu.
        app.swipeUp()
        let privateRow = app.staticTexts["New private tab"]
        XCTAssertTrue(privateRow.waitForExistence(timeout: 10))
        privateRow.tap()

        XCTAssertTrue(app.staticTexts["PRIVATE"].waitForExistence(timeout: 10), "no PRIVATE badge on a private tab")
    }

    /// The star writes the same bookmark list the rail chips read.
    func testBookmarkStar() {
        let app = makeApp()

        let star = app.buttons["rail.star"]
        XCTAssertTrue(star.waitForExistence(timeout: 15))
        XCTAssertEqual(star.value as? String, "not bookmarked")
        star.tap()

        let deadline = Date().addingTimeInterval(5)
        var value = ""
        while Date() < deadline {
            value = (star.value as? String) ?? ""
            if value == "bookmarked" { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertEqual(value, "bookmarked", "star did not record the bookmark")
    }

    /// The tab gallery searches the real tab list, with a live count.
    func testTabGallerySearch() {
        let app = makeApp()

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 10))
        // With no private tab there is no leading toolbar control at all; an
        // opacity-0 button still painted an empty glass pill here on iOS 26.
        XCTAssertFalse(app.buttons["Close private"].exists, "empty leading toolbar control")

        let search = app.textFields["Search tabs"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "keyboard did not come up")
        search.typeText("New")

        let counted = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS ' of '")
        ).firstMatch
        XCTAssertTrue(counted.waitForExistence(timeout: 8), "tab search count did not update")

        app.buttons["Done"].tap()
    }

    /// A page's alert/confirm/prompt must be answered by the browser. WebKit
    /// suppresses every panel whose delegate method is missing, so without this
    /// surface `confirm()` returns false and the action the user just agreed to
    /// silently never happens.
    func testJavaScriptDialogsAnswerThePage() {
        let app = makeApp()
        open("http://localhost:8000/dialog.html", in: app, expect: "Dialogs")

        // alert: the page blocks until the panel is answered.
        app.webViews.buttons["Alert"].tap()
        XCTAssertTrue(app.buttons["dialog.ok"].waitForExistence(timeout: 10), "alert panel missing")
        XCTAssertEqual(app.staticTexts["dialog.message"].label, "Saved to the shelf.")
        waitUntilHittable(app.buttons["dialog.ok"])
        app.buttons["dialog.ok"].tap()
        XCTAssertTrue(app.webViews.staticTexts["alerted"].waitForExistence(timeout: 10), "alert did not resume the page")

        // confirm, cancelled: the page must see false.
        app.webViews.buttons["Confirm"].tap()
        XCTAssertTrue(app.buttons["dialog.cancel"].waitForExistence(timeout: 10), "confirm panel missing")
        waitUntilHittable(app.buttons["dialog.cancel"])
        app.buttons["dialog.cancel"].tap()
        XCTAssertTrue(app.webViews.staticTexts["cancelled"].waitForExistence(timeout: 10), "confirm cancel did not answer false")

        // confirm, accepted.
        app.webViews.buttons["Confirm"].tap()
        waitUntilHittable(app.buttons["dialog.ok"])
        app.buttons["dialog.ok"].tap()
        XCTAssertTrue(app.webViews.staticTexts["confirmed"].waitForExistence(timeout: 10), "confirm OK did not answer true")

        // prompt, untouched: the page must get the seeded default back, not nil
        // and not the emptied field.
        app.webViews.buttons["Prompt"].tap()
        let field = app.textFields["dialog.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "prompt field missing")
        XCTAssertEqual(field.value as? String, "Work", "prompt did not seed its default text")
        waitUntilHittable(app.buttons["dialog.ok"])
        app.buttons["dialog.ok"].tap()
        XCTAssertTrue(app.webViews.staticTexts["hello Work"].waitForExistence(timeout: 10),
                      "an untouched prompt did not return its default")

        // prompt, typed over: the page receives what the user left in the field.
        app.webViews.buttons["Prompt"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let seeded = (field.value as? String) ?? ""
        if !seeded.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: seeded.count))
        }
        field.typeText("brows")
        waitUntilHittable(app.buttons["dialog.ok"])
        app.buttons["dialog.ok"].tap()
        XCTAssertTrue(app.webViews.staticTexts["hello brows"].waitForExistence(timeout: 10), "prompt text did not reach the page")
        XCTAssertFalse(app.buttons["dialog.ok"].exists, "dialog stayed on screen")
    }

    /// A link that opens a window becomes a real tab in the app, selected, and
    /// closing it leaves the page that opened it intact.
    func testNewWindowLinksOpenAndSelectANewTab() {
        let app = makeApp()
        open("http://localhost:8000/links.html", in: app, expect: "Links")

        app.webViews.links["Open blank"].tap()
        XCTAssertTrue(waitForPopupText("Other page", in: app),
                      "target=_blank did not load its page")
        XCTAssertFalse(app.webViews.staticTexts["Links"].exists,
                       "the new tab was not selected, the opener is still on screen")
        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10),
                      "target=_blank did not create exactly one tab")
        let closes = app.buttons.matching(identifier: "tab.close")
        XCTAssertTrue(closes.firstMatch.waitForExistence(timeout: 10))
        // Tabs are in creation order: the opener is first, the new tab second.
        closes.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["1 open"].waitForExistence(timeout: 10), "closing the new tab did not update the count")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 10),
                      "closing the new tab broke the opener")

        // window.open is the same outcome, not a second copy of it.
        app.webViews.buttons["Open popup"].tap()
        XCTAssertTrue(waitForPopupText("The shape of a browser", in: app),
                      "window.open did not load its page")
        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10),
                      "window.open did not create exactly one tab")
        app.buttons["Done"].tap()
    }

    /// `mailto:`, `tel:` and an unhandled scheme are handed off or explained, and
    /// never replace the page: no blank tab, no error page, no stuck state.
    func testExternalSchemesHandOffWithoutLeavingThePage() {
        let app = makeApp()
        open("http://localhost:8000/links.html", in: app, expect: "Links")

        for (link, scheme) in [("Mail", "mailto"), ("Call", "tel")] {
            let element = app.webViews.links[link]
            waitUntilHittable(element)
            element.tap()
            // iPadOS can answer a supported scheme itself: the simulator's
            // FaceTime takes tel: and its call menu sits over the page, so the
            // browser's own record is only readable after the menu closes. Run
            // 45057825247 showed the menu covering the app on iPad while the
            // iPhone run, where tel: cannot be opened, went straight to the
            // card. Closing the menu changes no browser state; the route is
            // still asserted below.
            let systemHandoff = closeSystemHandoffIfPresent(app, whileWaitingFor: scheme)
            // On iPad the platform takes tel: before WebKit asks the app's
            // navigation delegate (run 45086747875: the call menu appeared and
            // the app's record still said "mailto refused"), so the app cannot
            // report a route it was never handed. Where the system answered,
            // that answer is the handoff; where it did not, the app's own
            // record is still required.
            if !waitForRoute(app, scheme, timeout: systemHandoff ? 3 : 10) {
                XCTAssertTrue(systemHandoff, "\(scheme) was not routed anywhere")
            }
            // A refused handoff explains itself in the app's card; a handled one
            // leaves nothing behind. Either way the page is untouched.
            if app.buttons["linknotice.ok"].waitForExistence(timeout: 3) {
                app.buttons["linknotice.ok"].tap()
                XCTAssertTrue(app.buttons["linknotice.ok"].waitForNonExistence(timeout: 5),
                              "the \(scheme) notice stayed over the page")
            }
            XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 5), "\(scheme) replaced the page")
            // The count comes from the app's own record rather than the gallery,
            // so no sheet is ever open over the page while it is being tapped.
            // Run 44652824094 showed why that matters: this page's scheme links
            // sat at the end of the document, under the bottom rail, and the tap
            // meant for "Unsupported" hit rail.back and went back to the start
            // page. The fixture keeps them at the top for the same reason.
            let tabs = app.staticTexts["debug.tabs"].label
            XCTAssertTrue(tabs.hasPrefix("1|"), "\(scheme) created a tab: \(tabs)")
            XCTAssertTrue(tabs.hasSuffix("links.html"), "\(scheme) navigated the page: \(tabs)")
        }

        waitUntilHittable(app.webViews.links["Unsupported"])
        app.webViews.links["Unsupported"].tap()
        let route = app.staticTexts["debug.lastroute"]
        XCTAssertTrue(app.buttons["linknotice.ok"].waitForExistence(timeout: 7),
                      "an unsupported scheme was swallowed (last route: \(route.exists ? route.label : "none"))")
        XCTAssertTrue(app.staticTexts["linknotice.message"].label.contains("brows-nothing"),
                      "the notice did not name the scheme")
        app.buttons["linknotice.ok"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 5),
                      "the page did not survive the unsupported scheme")
    }

    /// The pill completes from history the way the desktop omnibox does. Before
    /// this every URL had to be typed in full, on every visit.
    func testAddressPillCompletesFromHistory() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")
        open("http://localhost:8000/other.html", in: app, expect: "Other page")

        typeInPill("shape", in: app)
        print("SUGGEST-DEBUG history=\(app.staticTexts["debug.history"].label) pill=\(app.textFields["rail.address"].value ?? "nil")")

        let rows = app.buttons.matching(identifier: "suggest.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10),
                      "the pill offered no completion for a page in history")
        XCTAssertTrue(rows.firstMatch.label.contains("The shape of a browser"),
                      "the suggestion did not name the page: \(rows.firstMatch.label)")
        waitUntilHittable(rows.firstMatch)
        print("SUGGEST-DEBUG row=\(rows.firstMatch.frame) reload=\(app.buttons["rail.reload"].frame)")
        rows.firstMatch.tap()

        XCTAssertTrue(app.webViews.staticTexts["The shape of a browser"].waitForExistence(timeout: 15),
                      "tapping the suggestion did not open the page")
        XCTAssertFalse(app.buttons["suggest.row"].exists, "the completion list stayed open")
    }

    /// Wait for a control to publish exactly this value, rather than reading it
    /// the moment after a tap. The assertion still compares exact strings.
    private func waitForValue(_ element: XCUIElement, _ value: String,
                              timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// A supported external scheme can be answered by the platform itself: on
    /// iPad the simulator's FaceTime takes `tel:` and presents a call menu that
    /// covers the page. Its Copy Phone Number action is harmless and closes it,
    /// after which the browser's own route record is readable. The menu belongs
    /// to the system, so it may sit in the app's tree or in SpringBoard's.
    @discardableResult
    private func closeSystemHandoffIfPresent(_ app: XCUIApplication,
                                             whileWaitingFor scheme: String,
                                             timeout: TimeInterval = 8) -> Bool {
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let systemCopy = system.buttons["Copy Phone Number"]
        let appCopy = app.buttons["Copy Phone Number"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // The menu is a system surface: ask SpringBoard first, so an app
            // held behind it cannot block the query that closes it.
            if systemCopy.exists, systemCopy.isHittable {
                systemCopy.tap()
                return true
            }
            if appCopy.exists, appCopy.isHittable {
                appCopy.tap()
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return false
    }

    /// The routing decision is visible only to the browser, so the tests read the
    /// same record the app keeps: `mailto opened` / `tel refused`.
    private func waitForRoute(_ app: XCUIApplication, _ scheme: String, timeout: TimeInterval = 10) -> Bool {
        let route = app.staticTexts["debug.lastroute"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@", scheme),
            object: route
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// The simulator's networking process occasionally stalls for over a minute:
    /// the submit never reaches the server (`fixtures/server.log` has no request
    /// for the page, only the next test's), so the page's own content cannot
    /// appear. A second navigation is a real request rather than a longer wait
    /// on a load that never started, and the server log records both attempts.
    @discardableResult
    private func openRetrying(_ url: String, in app: XCUIApplication,
                              until element: XCUIElement,
                              timeout: TimeInterval = 20) -> Bool {
        open(url, in: app)
        if element.waitForExistence(timeout: timeout) { return true }
        print("NAV-DEBUG \(url) never arrived; submitting again")
        open(url, in: app)
        return element.waitForExistence(timeout: timeout)
    }

    /// Put text in the pill and submit it without assuming a page loads: the
    /// rejected-address and typed-scheme cases end somewhere other than a page.
    private func submitAddress(_ text: String, in app: XCUIApplication) {
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            guard focusAddressPill(field, in: app) else { return }
            if typeIntoPill(text, in: app) { break }
        }
        XCTAssertEqual(field.value as? String, text, "address pill did not take the typed text: \(appTrace(app))")
        field.typeText("\n")
        let keyboard = app.keyboards.firstMatch
        if keyboard.waitForExistence(timeout: 3) {
            let go = keyboard.buttons["Go"]
            if go.exists { go.tap() }
        }
    }

    /// Puts `url` in the pill and submits it, without assuming a page loads: the
    /// rejected-address and typed-scheme cases end somewhere other than a page,
    /// and the stress pass types while a load is still in flight.
    private func submitPill(_ url: String, in app: XCUIApplication) {
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            guard focusAddressPill(field, in: app) else { return }
            if typeIntoPill(url, in: app) { break }
            print("PILL-DEBUG typed \(url) but the field reads \(field.value ?? "nil"): \(appTrace(app))")
        }
        XCTAssertEqual(
            field.value as? String, url,
            "address pill did not replace the current URL: \(appTrace(app))"
        )
        field.typeText("\n")
        // The simulator occasionally drops the synthetic hardware Return. The
        // keyboard's Go key runs the same UITextFieldDelegate callback, so press
        // it when the field still holds focus instead of failing the navigation.
        let keyboard = app.keyboards.firstMatch
        if keyboard.waitForExistence(timeout: 3) {
            let go = keyboard.buttons["Go"]
            if go.exists { go.tap() }
        }
    }

    private func open(_ url: String, in app: XCUIApplication, expect text: String? = nil) {
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        // A page that is still loading belongs to WebKit's process pool, and on a
        // cold runner that pool can take half a minute to start: run 45036456881
        // measured 24.3 s for the networking process and 30.7 s for WebContent.
        // Typing an address at 10% left the load queued behind that launch and
        // wiped by the old page's late finish, so the 401 prompt's 15 s window
        // opened with no request in flight. Wait for the current page to settle
        // before driving the browser. This is a precondition, not a retry: every
        // assertion about the submitted address stays exactly as it was.
        let loading = app.descendants(matching: .any)["rail.progress"]
        // Give the page surface a beat to report its load before believing it is
        // idle: the start page begins loading with the first frame, and a probe
        // that runs a moment too early would read "absent" and wave the input through.
        _ = loading.waitForExistence(timeout: 2)
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: loading
        )
        if XCTWaiter().wait(for: [settled], timeout: 60) != .completed {
            // A local page that has not finished in a minute is not loading slowly:
            // WebKit's first content process stalled (measured at 24–31 s on a cold
            // runner, and run 45658539518 held one past 60 s on both families). Stop
            // the load the way a thumb would — the rail's own control — and drive on
            // from whatever is on screen, rather than failing a typing test on the
            // platform's process launch.
            print("LOAD-DEBUG never finished: tabs=\(app.staticTexts["debug.tabs"].label); stopping the load")
            if app.buttons["rail.reload"].exists { app.buttons["rail.reload"].tap() }
            let halted = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: loading
            )
            let stopped = XCTWaiter().wait(for: [halted], timeout: 10)
            if stopped != .completed {
                XCTFail("the page would not stop loading: tabs=\(app.staticTexts["debug.tabs"].label)")
                return
            }
        }

        func submit() { submitPill(url, in: app) }

        submit()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 25))
        if let text {
            let loaded = app.webViews.staticTexts[text]
            if !loaded.waitForExistence(timeout: 12) {
                // The local fixture server can drop the first connection on a busy
                // runner. A real second navigation is cheap and proves the app,
                // rather than papering over it with a longer wait on a dead load.
                submit()
                XCTAssertTrue(
                    loaded.waitForExistence(timeout: 20),
                    "navigation to \(url) did not commit"
                )
            }
        }
    }

    /// The pill must take typing at the instant a page starts loading, not only
    /// once the dock has settled. Three runs failed before the page arrived with
    /// the pill still reading its placeholder (45400873379, 45408366570,
    /// 45520613696), so this forces that state on purpose: submit an address, then
    /// immediately tap the pill and type the next one, six times. The app traces
    /// its own focus and main-thread events (`-BrowsAddressTrace`); a missed tap
    /// fails as a missed tap with that trace attached, never as an empty field.
    func testPillTakesTypingTheMomentThePageLoads() {
        let app = makeApp(extra: ["-BrowsAddressTrace"])
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        let article = "http://localhost:8000/article.html"
        let other = "http://localhost:8000/other.html"
        for iteration in 0..<6 {
            let first = iteration % 2 == 0 ? article : other
            let second = iteration % 2 == 0 ? other : article
            let expected = iteration % 2 == 0 ? "Other page" : "The shape of a browser"
            submitPill(first, in: app)
            // Deliberately no wait for the load: this tap lands while it runs.
            submitPill(second, in: app)
            print("PILL-STRESS \(iteration) value=\(field.value ?? "nil")")
            print("PILL-TRACE \(iteration) \(appTrace(app))")
            XCTAssertTrue(
                app.webViews.staticTexts[expected].waitForExistence(timeout: 30),
                "iteration \(iteration): the typed address did not become the page (\(appTrace(app)))"
            )
        }
        XCTAssertTrue(app.textFields["rail.address"].exists, "the dock did not survive the pass")
    }

    /// A 401 Basic challenge is answered by the app's own sheet, not WebKit's blank
    /// challenge, and the entered credentials reach the protected content.
    func testHTTPAuthPromptCompletesAndSaves() {
        let app = makeApp()
        XCTAssertTrue(
            openRetrying("http://localhost:8000/auth.html", in: app, until: app.buttons["auth.cancel"]),
            "HTTP auth prompt missing"
        )
        XCTAssertFalse(app.alerts["Sign in"].exists, "the system's chrome answered instead of the app")
        signIn(user: "browsuser", password: "browssecret", in: app)

        XCTAssertTrue(
            app.webViews.staticTexts["Protected area"].waitForExistence(timeout: 25),
            "401-protected content was not reached with the entered credentials"
        )
        // iOS AutoFill raises its own modal "Save Password?" sheet for a native
        // username + secure pair as it leaves the hierarchy; it would sit above the
        // browser's card and take every tap. The fields must stay out of that flow.
        XCTAssertFalse(app.sheets["Save Password?"].exists, "the system's AutoFill save sheet covered the browser's")
        let save = app.staticTexts["Save password?"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "completed auth was not offered for saving")
        waitUntilHittable(app.buttons["save.new"])
        app.buttons["save.new"].tap()
        waitUntilGone(save, app: app)
        print("SAVE-DEBUG1 creds=\(app.staticTexts["debug.credentials"].label) state=\(app.staticTexts["debug.credentialstate"].label)")
        XCTAssertEqual(app.staticTexts["debug.credentials"].label, "1", "auth save did not reach the credential list")
    }

    /// Relaunch answers from the Keychain with no prompt, and a second account on
    /// the same origin offers both Save new account and Update saved.
    func testHTTPAuthSurvivesRelaunchAndSecondAccountOffersChoice() {
        let app = makeApp()
        open("http://localhost:8000/auth.html", in: app)
        XCTAssertTrue(app.buttons["auth.cancel"].waitForExistence(timeout: 15), "HTTP auth prompt missing")
        signIn(user: "browsuser", password: "browssecret", in: app)
        XCTAssertTrue(app.webViews.staticTexts["Protected area"].waitForExistence(timeout: 25))
        let firstSave = app.staticTexts["Save password?"]
        XCTAssertTrue(firstSave.waitForExistence(timeout: 10))
        waitUntilHittable(app.buttons["save.new"])
        app.buttons["save.new"].tap()
        waitUntilGone(firstSave, app: app)
        print("SAVE-DEBUG2 creds=\(app.staticTexts["debug.credentials"].label) state=\(app.staticTexts["debug.credentialstate"].label)")
        XCTAssertEqual(app.staticTexts["debug.credentials"].label, "1", "auth save did not reach the credential list")
        app.terminate()

        let relaunched = makeApp(extra: ["-BrowsOpenURL", "http://localhost:8000/auth.html"], reset: false)
        print("RELAUNCH-STATE creds=\(relaunched.staticTexts["debug.credentials"].label) state=\(relaunched.staticTexts["debug.credentialstate"].label)")
        XCTAssertEqual(relaunched.staticTexts["debug.credentials"].label, "1", "saved list was not loaded after relaunch")
        let protected = relaunched.webViews.staticTexts["Protected area"]
        if !protected.waitForExistence(timeout: 25) {
            print("RELAUNCH-DEBUG prompt=\(relaunched.buttons["auth.cancel"].exists)")
            print(relaunched.debugDescription)
        }
        XCTAssertTrue(protected.exists, "saved Keychain credential was not offered after relaunch")
        XCTAssertFalse(relaunched.buttons["auth.cancel"].exists, "relaunch prompted instead of using the Keychain")

        // Same origin, second protection space: there is no saved entry for it, so
        // the prompt must open and the new account must be offered for saving.
        open("http://localhost:8000/auth2.html", in: relaunched)
        XCTAssertTrue(relaunched.buttons["auth.cancel"].waitForExistence(timeout: 15), "second-account challenge did not prompt")
        signIn(user: "otheraccount", password: "othersecret", in: relaunched)
        XCTAssertTrue(relaunched.webViews.staticTexts["Protected area"].waitForExistence(timeout: 25))

        XCTAssertFalse(relaunched.sheets["Save Password?"].exists, "the system's AutoFill save sheet covered the browser's")
        let choice = relaunched.staticTexts["Save password?"]
        XCTAssertTrue(choice.waitForExistence(timeout: 10), "second account was not offered for saving")
        waitUntilHittable(relaunched.buttons["save.new"])
        XCTAssertTrue(relaunched.buttons["save.new"].exists, "save-new choice missing")
        XCTAssertTrue(relaunched.buttons["save.update"].exists, "update-saved choice missing")
        relaunched.buttons["save.new"].tap()
        waitUntilGone(choice, app: relaunched)
    }

    /// Dismissal is animated; a tap on the next surface during it lands nowhere.
    /// A sheet's navigation bar exists before the sheet is interactive; tapping
    /// during the presentation animation lands nowhere.
    /// Types into the pill and proves the text was replaced, not appended.
    private func typeInPill(_ text: String, in app: XCUIApplication) {
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            guard focusAddressPill(field, in: app) else { return }
            if typeIntoPill(text, in: app) { return }
        }
        XCTFail("the pill would not replace its text with \(text): \(field.value ?? "nil") - \(appTrace(app))")
    }

    /// Sends the text and waits for the field to report it. XCTest injects the
    /// keys and returns before the app has processed them; the app's main thread
    /// was measured blocked for 1.6–4.2 s while the keyboard came up (run
    /// 45635875780, `STALL` in `-BrowsAddressTrace`), and an immediate read then
    /// returned the pre-typing value — the placeholder the three sightings
    /// recorded. This waits for the app's own result instead of reading once.
    private func typeIntoPill(_ text: String, in app: XCUIApplication) -> Bool {
        let field = app.textFields["rail.address"]
        field.typeText(text)
        let took = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", text),
            object: field
        )
        if XCTWaiter().wait(for: [took], timeout: 12) == .completed { return true }
        print("TYPE-DEBUG wanted \(text), field reads \(field.value ?? "nil"): \(appTrace(app))")
        return false
    }

    /// Taps the pill and waits until the field itself reports it is first
    /// responder. The old version waited for a keyboard and then slept 0.4 s;
    /// that is a delay, not a synchronization — the keyboard can be on screen
    /// while the field never took focus (run 45046850662, and the three
    /// placeholder sightings). `debug.addressfocus` is set by the field in
    /// `becomeFirstResponder`/`armReplacement`, so the wait is on the fact typing
    /// needs. When four taps all miss, this fails here, naming the pill, instead
    /// of surfacing later as an empty address field.
    @discardableResult
    private func focusAddressPill(_ field: XCUIElement, in app: XCUIApplication) -> Bool {
        let probe = app.staticTexts["debug.addressfocus"]
        _ = probe.waitForExistence(timeout: 5)
        for attempt in 0..<4 {
            // A keyboard from the previous submission can still be leaving when the
            // next tap lands. The dismissal covers the dock, so that tap never
            // reaches the field. Wait for it to go; it stays if the pill already
            // has focus, and the tap is then a no-op that keeps it.
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists {
                let gone = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == false"),
                    object: keyboard
                )
                _ = XCTWaiter().wait(for: [gone], timeout: 6)
            }
            field.tap()
            let focused = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label BEGINSWITH %@", "focused=1"),
                object: probe
            )
            if XCTWaiter().wait(for: [focused], timeout: 8) == .completed { return true }
            print("FOCUS-DEBUG attempt \(attempt) missed the pill: \(appTrace(app)) value=\(field.value ?? "nil") keyboards=\(app.keyboards.count)")
        }
        XCTFail("the address pill never took keyboard focus after four taps: \(appTrace(app))")
        return false
    }

    /// The app's own record of the pill, when the run asked for it
    /// (`-BrowsAddressTrace`).
    private func appTrace(_ app: XCUIApplication) -> String {
        let trace = app.staticTexts["debug.addresstrace"]
        return trace.exists ? trace.label : "trace off"
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout), .completed,
            "element did not become hittable"
        )
        // Hittable flips during the presentation animation, when the frame is
        // still moving; a tap there can land on the dimmed background.
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// A popup gets its own web view; on a private tab WebKit also has to start a
    /// content process for the non-persistent store. On a loaded CI runner that
    /// launch was measured at 24–31 s (run 45036456881) — longer than the 20 s the
    /// popup tests used to allow, so the tab opened and was private while its
    /// first paint was still waiting on the process. The assertions are unchanged;
    /// the ceiling now matches the platform's measured cold start.
    private func waitForPopupText(_ text: String, in app: XCUIApplication,
                                  timeout: TimeInterval = 45) -> Bool {
        app.webViews.staticTexts[text].waitForExistence(timeout: timeout)
    }

    /// The rail's own tab count. A fixture can replace a popup's first page on a
    /// timer: `links.html` re-opens its named window 1.8 s after the click, which
    /// navigates the popup from `article.html` to `other.html`. Waiting for that
    /// first page is a race against the page's own timer. On a loaded iPad the
    /// popup's first paint landed after the navigation, so the text was never in a
    /// snapshot even though the tab, its badge and the popup route were (runs
    /// 45646011526 and 45658539518). The tab the app created is the durable fact.
    private func waitForOpenTabs(_ minimum: Int, in app: XCUIApplication,
                                 timeout: TimeInterval = 20) -> Int {
        let rail = app.buttons["rail.tabs"]
        let deadline = Date().addingTimeInterval(timeout)
        var count = Self.openTabCount(rail)
        while count < minimum && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            count = Self.openTabCount(rail)
        }
        return count
    }

    private static func openTabCount(_ rail: XCUIElement) -> Int {
        guard let value = rail.value as? String,
              let first = value.split(separator: " ").first else { return 0 }
        return Int(first) ?? 0
    }

    /// Either page the named-window fixture can be showing, whichever the popup
    /// has painted. Returns nil if neither ever appears, so a blank popup fails
    /// rather than being counted as opened.
    private func waitForPopupPage(_ pages: [String], in app: XCUIApplication,
                                  timeout: TimeInterval = 45) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for page in pages where app.webViews.staticTexts[page].exists {
                return page
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return nil
    }

    /// The app's own popup facts, for a failure message. The two sightings of the
    /// named popup left "did not open" with nothing behind it; these make the next
    /// one say whether the tab appeared and which route produced it.
    private func popupState(_ app: XCUIApplication) -> String {
        let route = app.staticTexts["debug.lastroute"]
        let tabs = app.staticTexts["debug.tabs"]
        return "rail says \(app.buttons["rail.tabs"].value.map { "\($0)" } ?? "?"), "
            + "route \(route.exists ? route.label : "none"), "
            + "tabs \(tabs.exists ? tabs.label : "none")"
    }

    private func waitUntilGone(_ element: XCUIElement, app: XCUIApplication? = nil) {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        let result = XCTWaiter().wait(for: [gone], timeout: 10)
        if result != .completed {
            print("DISMISS-DEBUG label=\(element.label) creds=\(app?.staticTexts["debug.credentials"].label ?? "?")")
            if let app { print(app.debugDescription) }
        }
        XCTAssertEqual(result, .completed, "element did not dismiss")
    }

    /// Fills the app's HTTP auth sheet. The system never sees this challenge.
    private func signIn(user: String, password: String, in app: XCUIApplication) {
        let username = app.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5), "auth username field missing")
        // The prompt is prefilled from the saved account. Put the caret at the end
        // and clear it, otherwise the second username is typed onto the first.
        username.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let existing = (username.value as? String) ?? ""
        if existing != "Username", !existing.isEmpty {
            username.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        username.typeText(user)
        let secret = app.secureTextFields["Password"]
        XCTAssertTrue(secret.exists, "auth password field missing")
        secret.tap()
        secret.typeText(password)
        waitUntilHittable(app.buttons["auth.signIn"])
        app.buttons["auth.signIn"].tap()
    }

    /// End to end password manager: submit a served login form, save it, leave the
    /// origin, come back, and assert the fields hold the stored credentials.
    func testPasswordSaveAndAutofill() {
        let app = makeApp()
        open("http://localhost:8000/login.html", in: app, expect: "Sign in")

        let username = app.webViews.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout: 15), "login fixture fields missing")
        username.tap()
        username.typeText("browsuser")

        let password = app.webViews.secureTextFields["Password"]
        XCTAssertTrue(password.exists, "fixture password field missing")
        password.tap()
        password.typeText("browssecret")

        app.webViews.buttons["Log in"].tap()

        let saveSheet = app.staticTexts["Save password?"]
        XCTAssertTrue(saveSheet.waitForExistence(timeout: 10), "submitted login was not offered for saving")
        waitUntilHittable(app.buttons["save.new"])
        app.buttons["save.new"].tap()
        waitUntilGone(saveSheet, app: app)

        // The credential is in the app's own store, filed under origin and port.
        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Passwords"].waitForExistence(timeout: 10))
        app.staticTexts["Passwords"].tap()
        let stored = app.staticTexts["localhost:8000"].waitForExistence(timeout: 10)
        let diag = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Keychain' OR label BEGINSWITH 'Not saved'")
        ).firstMatch
        XCTAssertTrue(stored, "credential was not stored; diag: \(diag.exists ? diag.label : "none")")
        XCTAssertTrue(app.staticTexts["browsuser"].exists, "stored username missing")
        app.buttons["Done"].tap()

        // Leave the origin by editing the pill, then edit it back. This is a later
        // navigation, and the second edit is the regression case: tapping the pill
        // again must select the whole URL, not drop the caret into the middle of it.
        open("http://localhost:8000/other.html", in: app)
        XCTAssertTrue(app.webViews.staticTexts["Other page"].waitForExistence(timeout: 20))

        let pill = app.textFields["rail.address"]
        pill.tap()
        pill.typeText("http://localhost:8000/login.html")
        XCTAssertEqual(
            pill.value as? String,
            "http://localhost:8000/login.html",
            "second pill edit appended instead of replacing the URL"
        )
        pill.typeText("\n")

        let deadline = Date().addingTimeInterval(15)
        var filledUser = ""
        while Date() < deadline {
            filledUser = (app.webViews.textFields["Username"].value as? String) ?? ""
            if filledUser == "browsuser" { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertEqual(filledUser, "browsuser", "username was not autofilled on return")
        XCTAssertFalse(
            ((app.webViews.secureTextFields["Password"].value as? String) ?? "").isEmpty,
            "password field was left empty"
        )
        XCTAssertTrue(
            app.webViews.staticTexts["U=browsuser P=browssecret"].waitForExistence(timeout: 10),
            "the page does not hold the stored secret"
        )
    }

    /// Find reads matches out of the loaded page.
    func testFindInPage() {
        let app = makeApp()
        open("example.com", in: app)

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))
        app.swipeUp()
        let findRow = app.staticTexts["Find in page"]
        XCTAssertTrue(findRow.waitForExistence(timeout: 10))
        findRow.tap()

        let find = app.textFields["Find in page"]
        XCTAssertTrue(find.waitForExistence(timeout: 10), "find bar did not open")
        find.tap()
        find.typeText("Domain")

        let counted = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' of '")).firstMatch
        XCTAssertTrue(counted.waitForExistence(timeout: 10), "find did not report a match count")
    }

    /// Per-site blocking is a real toggle and it flips its own label back.
    func testSiteBlockingToggle() {
        let app = makeApp()
        // A local host: the toggle is per site, and the internet is not a
        // fixture this suite may depend on.
        XCTAssertTrue(
            openRetrying("http://localhost:8000/other.html", in: app,
                         until: app.webViews.staticTexts["Other page"], timeout: 25),
            "the fixture page never loaded"
        )

        app.buttons["rail.siteInfo"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))

        let off = app.buttons["Turn off blocking on this site"]
        XCTAssertTrue(off.waitForExistence(timeout: 10), "no per-site blocking toggle")
        waitUntilHittable(off)
        off.tap()

        XCTAssertTrue(
            app.buttons["Turn on blocking on this site"].waitForExistence(timeout: 10),
            "blocking toggle did not flip"
        )
        app.buttons["Done"].tap()
    }

    /// Closing from the gallery decrements the real tab list.
    func testCloseTab() {
        let app = makeApp()

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 10))
        app.buttons["tab.add"].tap()

        // The gallery stays open on the tab it just added, so the count updates in
        // place; reopening it is not part of this assertion any more.
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10))
        let closes = app.buttons.matching(identifier: "tab.close")
        XCTAssertTrue(closes.firstMatch.waitForExistence(timeout: 10))
        closes.firstMatch.tap()

        XCTAssertTrue(app.staticTexts["1 open"].waitForExistence(timeout: 10), "closing a tab did not update the count")
        app.buttons["Done"].tap()
    }

    /// A workspace is created and then becomes the one the rail names.
    func testWorkspaceSwitch() {
        let app = makeApp()

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.buttons["menu.workspaces"].waitForExistence(timeout: 10), "menu did not open")
        menuRow("menu.workspaces", in: app).tap()

        let field = app.textFields["New workspace"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Work")
        app.buttons["workspace.add"].tap()

        let row = app.buttons.matching(identifier: "workspace.row.WO").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "workspace was not created")
        row.tap()
        // The sheet dismisses and the switch rebuilds the dock's tab set; tapping
        // the bar while that commit is in flight sends the touch into a view that
        // is being replaced (trace, shard 2, run 45013202399: tap synthesised, app
        // idle, no panel). Wait for the panel to be gone before using the dock.
        XCTAssertTrue(app.staticTexts["Workspaces"].waitForNonExistence(timeout: 10),
                      "the workspaces panel stayed up after a switch")

        // No workspace button in the dock any more: the switch is shown where
        // workspaces live, by the row that now reads CURRENT.
        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.buttons["menu.workspaces"].waitForExistence(timeout: 10), "menu did not open")
        menuRow("menu.workspaces", in: app).tap()

        let workRow = app.buttons.matching(identifier: "workspace.row.WO").firstMatch
        XCTAssertTrue(workRow.waitForExistence(timeout: 10), "workspace row missing")
        let deadline = Date().addingTimeInterval(8)
        var marked = false
        while Date() < deadline {
            marked = workRow.label.contains("CURRENT")
            if marked { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(marked, "workspace did not switch")
        app.buttons["Done"].tap()
    }

    /// The dock is the phone's own row, not the desktop rail's: back leads, the
    /// pill is the centre, and tabs and the menu — the two a thumb reaches for —
    /// close the row at the trailing edge. Reload is not dock width; it is a menu
    /// row. Every dock control is a 44 pt target.
    func testDockKeepsTabsAndMenuAfterThePill() {
        let app = makeApp()
        open("http://localhost:8000/other.html", in: app, expect: "Other page")

        let back = app.buttons["rail.back"]
        let field = app.textFields["rail.address"]
        let tabs = app.buttons["rail.tabs"]
        let menu = app.buttons["rail.menu"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "back control missing after navigating")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "address pill missing")
        XCTAssertTrue(tabs.waitForExistence(timeout: 10), "tabs destination missing")
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "menu destination missing")

        // Reload is a primary control inside the address bar, as in every iOS
        // browser: always visible, never behind the menu.
        let reload = app.buttons["rail.reload"]
        XCTAssertTrue(reload.waitForExistence(timeout: 10), "reload missing from the dock")

        XCTAssertLessThan(back.frame.maxX, field.frame.minX, "back must sit left of the pill")
        XCTAssertGreaterThan(reload.frame.minX, field.frame.maxX, "reload belongs inside the pill, after the URL")
        XCTAssertLessThan(field.frame.maxX, tabs.frame.minX, "tabs belong after the pill, at the trailing edge")
        XCTAssertLessThan(tabs.frame.maxX, menu.frame.minX, "the menu is the outermost destination")
        XCTAssertFalse(app.buttons["rail.workspace"].exists, "workspaces belong in the menu, not the dock")

        for control in [back, tabs, menu] {
            XCTAssertGreaterThanOrEqual(control.frame.height, 44, "dock target under 44 pt")
            XCTAssertGreaterThanOrEqual(control.frame.width, 44, "dock target under 44 pt")
        }

        // The star hides while the address is being typed, so the keyboard gets
        // the whole pill, and comes back when editing ends.
        let star = app.buttons["rail.star"]
        XCTAssertTrue(star.waitForExistence(timeout: 10), "star missing from the pill")
        field.tap()
        let typing = Date().addingTimeInterval(6)
        var hidden = false
        while Date() < typing {
            hidden = !app.buttons["rail.star"].exists
            if hidden { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(hidden, "star still sits in the pill while typing")

        // And reload is live: reloading keeps the same page.
        reload.tap()
        XCTAssertTrue(app.webViews.staticTexts["Other page"].waitForExistence(timeout: 20), "reload left the page")
    }

    /// Reader takes a real article apart and shows it as text. The article is the
    /// fixture served on :8000 — Wikipedia's availability is not what this tests.
    func testReaderMode() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")
        XCTAssertTrue(app.webViews.staticTexts["The shape of a browser"].waitForExistence(timeout: 20))

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))
        app.swipeUp()
        let readerRow = app.staticTexts["Reader mode"]
        XCTAssertTrue(readerRow.waitForExistence(timeout: 10))
        readerRow.tap()

        XCTAssertTrue(app.navigationBars["Reader"].waitForExistence(timeout: 10), "reader did not open")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
    }

    /// A page with no article text must fail in the app's own card. A system alert
    /// would hand the failure to iOS chrome the browser never uses, and the desktop
    /// lesson says the page must also stay exactly where it was.
    func testReaderFailureUsesTheAppsOwnCard() {
        let app = makeApp()
        open("http://localhost:8000/other.html", in: app, expect: "Other page")
        XCTAssertTrue(app.webViews.staticTexts["Other page"].waitForExistence(timeout: 20))

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))
        app.swipeUp()
        let readerRow = app.staticTexts["Reader mode"]
        XCTAssertTrue(readerRow.waitForExistence(timeout: 10))
        readerRow.tap()

        let card = app.otherElements["notice.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "reader failure showed no app card")
        XCTAssertEqual(app.alerts.count, 0, "reader failure used a system alert")
        XCTAssertTrue(app.staticTexts["notice.message"].exists, "card carries no message")
        XCTAssertFalse(app.navigationBars["Reader"].exists, "reader opened with no article text")

        app.buttons["notice.ok"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: card)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(
            app.webViews.staticTexts["Other page"].waitForExistence(timeout: 10),
            "the page did not survive the failure"
        )
    }

    /// A real octet-stream navigation must land in the download list as a finished
    /// row, not as text in the page. The workflow serves sample.bin on port 8000.
    /// The row is not matched by name: a file left by an earlier test makes this
    /// transfer write sample-1.bin, and a finished row renames itself to the file it
    /// actually wrote (`updateDownload(path:)`). That is the row telling the truth,
    /// so the assertion is the finished row, not the filename (runs 44509250031 and
    /// 44516877871 failed on the name alone while the transfer itself worked).
    func testDownloadStarts() {
        let app = makeApp()

        func finishedRow() -> Bool {
            app.buttons["rail.menu"].tap()
            guard app.staticTexts["Site information"].waitForExistence(timeout: 10),
                  app.staticTexts["Downloads"].waitForExistence(timeout: 10) else { return false }
            // Downloads sits in the menu's second section, above the fold.
            app.staticTexts["Downloads"].tap()
            // The share action exists only on a row whose transfer finished.
            if app.buttons["download.share"].waitForExistence(timeout: 20) {
                app.buttons["Done"].tap()
                return true
            }
            // Wait for the sheet to leave before the caller re-submits. A tap that
            // lands while it is still animating away submits nothing.
            let done = app.buttons["Done"]
            if done.exists { done.tap() }
            let gone = NSPredicate(format: "exists == false")
            expectation(for: gone, evaluatedWith: done)
            waitForExpectations(timeout: 5)
            return false
        }

        open("http://localhost:8000/sample.bin", in: app)
        if !finishedRow() {
            // No row means the request may never have left the app; a second
            // navigation is a real one (see openRetrying). Nothing here prints
            // element lists: querying a stale snapshot throws and hides the reason.
            print("DOWNLOAD-DEBUG first navigation produced no finished row; submitting again")
            open("http://localhost:8000/sample.bin", in: app)
            XCTAssertTrue(finishedRow(), "download did not start or did not finish")
        }
        XCTAssertFalse(
            app.webViews.staticTexts["brows download fixture"].exists,
            "the binary rendered as page text instead of downloading"
        )
    }

    /// A name outlives the window it named only as a name: once that popup is
    /// closed, the next `window.open(url, name)` must create a fresh, selected web
    /// view and return it. A dropped navigation or a `null` return breaks every
    /// flow that reuses a window it already closed.
    func testNamedWindowReopensAfterItsPopupIsClosed() {
        let app = makeApp()
        open("http://localhost:8000/links.html", in: app, expect: "Links")

        app.webViews.buttons["Open named window"].tap()
        XCTAssertTrue(waitForPopupText("The shape of a browser", in: app),
                      "the named window did not open")

        // Tabs are in creation order: opener first, the named popup second.
        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10),
                      "the first named open did not make exactly one tab")
        let closes = app.buttons.matching(identifier: "tab.close")
        XCTAssertTrue(closes.firstMatch.waitForExistence(timeout: 10))
        closes.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["1 open"].waitForExistence(timeout: 10),
                      "closing the named popup did not close its tab")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 10),
                      "the opener did not survive closing the named popup")

        // Same name, no window alive: WebKit must create a fresh one.
        app.webViews.buttons["Open the closed name again"].tap()
        XCTAssertTrue(waitForPopupText("Other page", in: app),
                      "reopening a closed name dropped the navigation")

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10),
                      "reopening the closed name did not make exactly one fresh tab")
        XCTAssertTrue(app.staticTexts["Other page"].waitForExistence(timeout: 10),
                      "the fresh tab is not the page the page requested")
        app.staticTexts["Links"].tap()
        XCTAssertTrue(waitForPopupText("fresh-open", in: app),
                      "window.open returned no window for the closed name")
    }

    /// A download started in a private tab must leave no trace on disk: its row
    /// carries the source URL, so it may not be persisted and it may not reappear in
    /// a later session. That is the same promise `save()` makes for private tabs.
    func testPrivateDownloadIsNotPersisted() {
        let app = makeApp()
        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))
        app.swipeUp()
        let privateRow = app.staticTexts["New private tab"]
        XCTAssertTrue(privateRow.waitForExistence(timeout: 10))
        privateRow.tap()
        XCTAssertTrue(app.staticTexts["PRIVATE"].waitForExistence(timeout: 10), "no private tab")

        XCTAssertEqual(startDownload("http://localhost:8000/sample.bin", in: app, rows: 1), 1,
                       "the private download never started, so its trace cannot be judged")
        app.buttons["Done"].tap()

        // A fresh launch: the private tab is gone, so its download row must be too.
        app.terminate()
        let again = makeApp(reset: false)
        again.buttons["rail.menu"].tap()
        XCTAssertTrue(again.staticTexts["Downloads"].waitForExistence(timeout: 10),
                      "menu did not open after the relaunch")
        again.staticTexts["Downloads"].tap()
        XCTAssertTrue(again.staticTexts["Nothing downloaded yet."].waitForExistence(timeout: 10),
                      "a private download survived the relaunch; its row names the page that fetched it")
        XCTAssertFalse(again.staticTexts["sample.bin"].exists,
                       "the private download row was written to disk")
        again.buttons["Done"].tap()
    }

    /// `window.open(url, name, features)` - the OAuth and share-button path - must
    /// give the page a real window. Returning nil made `window.open()` null, which
    /// pages read as "popup blocked", so the tab is opened *and* the window handed
    /// back; the opener must survive and the count must be exactly one more.
    func testWindowOpenWithFeaturesOpensOneSelectedTab() {
        let app = makeApp()
        open("http://localhost:8000/links.html", in: app, expect: "Links")

        let page = app.webViews.firstMatch
        let button = page.buttons["Open popup with features"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "the feature popup button is missing")
        // The button is the page's last control, and the floating dock covers the
        // bottom of the page until it is scrolled. A tap the dock covers never
        // reaches the page, so bring the button above the dock first.
        let clearOfDock = app.windows.firstMatch.frame.maxY - 120
        var scrolls = 0
        while button.frame.maxY > clearOfDock && scrolls < 4 {
            page.swipeUp()
            scrolls += 1
        }
        XCTAssertLessThanOrEqual(button.frame.maxY, clearOfDock,
                                 "the feature popup button stays under the dock")
        button.tap()

        XCTAssertTrue(waitForPopupText("The shape of a browser", in: app),
                      "window.open with features did not open the page")
        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10),
                      "a feature popup did not open exactly one tab")

        // Back to the opener: it still has its page, and it saw a real window.
        app.staticTexts["Links"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 10),
                      "the opener page was lost")
        // The page writes "opened" only when window.open gave it a window; a nil
        // return is what it writes as "blocked". Read the word, not an element that
        // only exists on one branch, so a failure reports the page's own verdict.
        let opened = app.webViews.staticTexts["opened"]
        if !opened.waitForExistence(timeout: 15) {
            let verdict = app.webViews.staticTexts["blocked"].exists ? "blocked" : "missing"
            XCTFail("window.open returned no window; the page says \(verdict)")
        }
    }

    /// Waits for `count` finished download rows. A previous row already shows a share
    /// button, so waiting on the button alone would pass without a new transfer.
    private func waitForFinishedDownloads(_ count: Int, in app: XCUIApplication) -> Int {
        let rows = app.buttons.matching(identifier: "download.share")
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline && rows.count < count {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return rows.count
    }

    /// Submits a download and leaves its sheet open, returning the finished rows it
    /// shows. The simulator occasionally drops the synthetic Return on a loaded
    /// runner, so the request never leaves the app; a missing row is re-submitted
    /// once as a real navigation, the same rule `openRetrying` follows. The retry is
    /// never hidden behind a longer wait, and a second transfer would still fail the
    /// caller's count.
    private func startDownload(_ url: String, in app: XCUIApplication, rows: Int) -> Int {
        submitAddress(url, in: app)
        openDownloads(in: app)
        var count = waitForFinishedDownloads(rows, in: app)
        if count < rows {
            print("DOWNLOAD-DEBUG first submission showed \(count) of \(rows) rows; submitting again")
            app.buttons["Done"].tap()
            let gone = NSPredicate(format: "exists == false")
            expectation(for: gone, evaluatedWith: app.buttons["Done"])
            waitForExpectations(timeout: 5)
            submitAddress(url, in: app)
            openDownloads(in: app)
            count = waitForFinishedDownloads(rows, in: app)
        }
        return count
    }

    private func downloadFileCounts(_ app: XCUIApplication) -> (privateCount: Int, normalCount: Int) {
        // "private 1 normal 2", from the app's own folders. The normal folder is not
        // emptied by the test reset, so callers compare it against a baseline.
        let label = app.staticTexts["audit.downloadfiles"].label
        let parts = label.split(separator: " ")
        guard parts.count == 4, let priv = Int(parts[1]), let norm = Int(parts[3]) else {
            XCTFail("the download-folder probe did not report counts; it says (label)")
            return (-1, -1)
        }
        return (priv, norm)
    }

    /// Both callers arrive straight from a submission, so the menu tap has two ways
    /// to be lost: the dock re-lays itself out when the load moves the back control,
    /// and a keyboard still leaving from the address field swallows the touch (the
    /// hazard `focusAddressPill` names). One tap and a 10 s wait is what failed on
    /// iPad shard 3 of run 45532569919 — "menu did not open", row never appeared —
    /// while every other menu journey in the suite goes through `menuRow`, which
    /// retries the tap and scrolls. Use that instead of a second copy of the race.
    private func openDownloads(in app: XCUIApplication) {
        menuRow("menu.downloads", in: app).tap()
        XCTAssertTrue(app.staticTexts["Downloads"].waitForExistence(timeout: 10),
                      "the downloads panel did not open from its menu row")
    }

    private func newPrivateTab(in app: XCUIApplication) {
        menuRow("menu.new-private-tab", in: app).tap()
        XCTAssertTrue(app.staticTexts["PRIVATE"].waitForExistence(timeout: 10), "no private tab badge")
    }

    /// A kill runs no cleanup hook, so the next launch is what keeps the promise: the
    /// private download folder is swept and the normal one is untouched. A second
    /// launch proves the sweep is repeatable (the orphan-file case).
    func testPrivateDownloadFileIsSweptOnNextLaunch() {
        let app = makeApp()
        let baseline = downloadFileCounts(app).normalCount

        XCTAssertEqual(startDownload("http://localhost:8000/sample.bin", in: app, rows: 1), 1,
                       "the normal download never finished")
        app.buttons["Done"].tap()

        newPrivateTab(in: app)
        XCTAssertEqual(startDownload("http://localhost:8000/sample.bin", in: app, rows: 2), 2,
                       "the private download never finished; the sheet still shows no second row")
        app.buttons["Done"].tap()

        let beforeKill = downloadFileCounts(app)
        XCTAssertEqual(beforeKill.privateCount, 1, "the private file did not land in the private folder")
        XCTAssertEqual(beforeKill.normalCount, baseline + 1, "the normal file did not land in the normal folder")

        // Kill mid-session. The private tab is not restored; its file must not survive.
        app.terminate()
        let again = makeApp(reset: false)
        let afterLaunch = downloadFileCounts(again)
        XCTAssertEqual(afterLaunch.privateCount, 0, "a private download file survived the relaunch")
        XCTAssertEqual(afterLaunch.normalCount, baseline + 1, "the sweep took the normal file")

        // The file name is not asserted: earlier tests leave same-named files in the
        // normal folder, so the app may have stored this one as `sample-1.bin`. What
        // matters is that the normal row survived and the private one did not.
        openDownloads(in: again)
        XCTAssertEqual(waitForFinishedDownloads(1, in: again), 1,
                       "the normal download row was lost with the private files; the sheet has no row")
        again.buttons["Done"].tap()

        again.terminate()
        let third = makeApp(reset: false)
        let afterSecond = downloadFileCounts(third)
        XCTAssertEqual(afterSecond.privateCount, 0, "the orphan sweep did not hold on a second launch")
        XCTAssertEqual(afterSecond.normalCount, baseline + 1, "the normal file was swept on a later launch")
    }

    /// Ending the private session deletes its files at once, and only its files.
    func testClosingPrivateTabsDeletesTheirDownloadFiles() {
        let app = makeApp()
        let baseline = downloadFileCounts(app).normalCount

        XCTAssertEqual(startDownload("http://localhost:8000/sample.bin", in: app, rows: 1), 1,
                       "the normal download never started")
        app.buttons["Done"].tap()

        newPrivateTab(in: app)
        XCTAssertEqual(startDownload("http://localhost:8000/sample.bin", in: app, rows: 2), 2,
                       "the private download never started")
        app.buttons["Done"].tap()
        let beforeClose = downloadFileCounts(app)
        XCTAssertEqual(beforeClose.privateCount, 1, "the private file did not land in the private folder")
        XCTAssertEqual(beforeClose.normalCount, baseline + 1)

        app.buttons["rail.tabs"].tap()
        let closePrivate = app.buttons["Close private"]
        XCTAssertTrue(closePrivate.waitForExistence(timeout: 10),
                      "no Close private control while a private tab exists")
        closePrivate.tap()
        app.buttons["Done"].tap()

        let afterClose = downloadFileCounts(app)
        XCTAssertEqual(afterClose.privateCount, 0, "closing the private tabs left a private file")
        XCTAssertEqual(afterClose.normalCount, baseline + 1, "closing private tabs took the normal file")
    }

    /// A popup named by a private page is private too: the tab carries the badge, and a
    /// relaunch neither restores the popup nor the private session it came from.
    func testNamedPopupFromAPrivateTabStaysPrivate() {
        let app = makeApp()
        newPrivateTab(in: app)

        open("http://localhost:8000/links.html", in: app, expect: "Links")
        app.webViews.buttons["Open named window again"].tap()
        // The fixture navigates its named window away from `article.html` 1.8 s
        // after the click. Wait for the tab the app created and the popup route,
        // then for whichever page the popup has painted, instead of a page the
        // fixture itself replaces.
        let popupTabs = waitForOpenTabs(2, in: app)
        XCTAssertGreaterThanOrEqual(popupTabs, 2,
                      "the named popup did not open a tab from the private page (\(popupState(app)))")
        XCTAssertEqual(app.staticTexts["debug.lastroute"].label, "popup localhost",
                      "the private named popup did not come through the popup path (\(popupState(app)))")
        XCTAssertNotNil(waitForPopupPage(["The shape of a browser", "Other page"], in: app),
                      "the private named popup opened a tab but never painted a page (\(popupState(app)))")
        XCTAssertTrue(app.staticTexts["PRIVATE"].waitForExistence(timeout: 10),
                      "the popup opened from a private tab is not marked private")

        app.buttons["rail.tabs"].tap()
        let countLabel = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' open'")).firstMatch
        XCTAssertTrue(countLabel.waitForExistence(timeout: 10), "the gallery showed no tab count")
        // Private web views are non-persistent, so WebKit opens a second window for the
        // second call instead of reusing the first (measured: 3 tabs). The contract this
        // test owns is privacy: every tab that came from the private page carries the badge.
        let total = Int(countLabel.label.split(separator: " ").first ?? "") ?? 0
        XCTAssertGreaterThanOrEqual(total, 2,
                       "the private named popup did not open a second tab; the gallery says (countLabel.label)")
        let badges = app.staticTexts.matching(NSPredicate(format: "label == 'PRIVATE'")).count
        XCTAssertGreaterThanOrEqual(badges, total,
                       "a tab opened from a private page is not private: (badges) badges for (total) tabs")
        app.buttons["Done"].tap()

        app.terminate()
        let again = makeApp(reset: false)
        XCTAssertFalse(again.staticTexts["PRIVATE"].exists,
                       "a private named popup was restored on relaunch")
        again.buttons["rail.tabs"].tap()
        XCTAssertTrue(again.staticTexts["1 open"].waitForExistence(timeout: 10),
                      "the relaunch restored tabs from the private session")
    }

    /// `window.open(url, "name")` twice with the same name: the second call must reach
    /// the window WebKit already gave that name - the page compares the two returns and
    /// writes `same-window`, `different-window` or `null-again`. A second tab here is the
    /// duplicate OAuth/SSO and chat-widget popup the record lists as open.
    func testWindowOpenReusesTheNamedWindow() {
        let app = makeApp()
        open("http://localhost:8000/links.html", in: app, expect: "Links")

        // One page action opens its popup, then re-opens the same name 1.8 s later -
        // the way an SSO flow or a chat widget reuses its own window. The page writes
        // `same-window` only if both calls reached the same window.
        app.webViews.buttons["Open named window again"].tap()
        // `article.html` is on screen only until the page's own 1.8 s timer
        // navigates the named window to `other.html`. Wait for the tab and the
        // popup route the app produced, then for whichever page it painted.
        XCTAssertEqual(waitForOpenTabs(2, in: app), 2,
                      "the named window did not open exactly one tab (\(popupState(app)))")
        XCTAssertEqual(app.staticTexts["debug.lastroute"].label, "popup localhost",
                      "the named window did not come through the popup path (\(popupState(app)))")
        XCTAssertNotNil(waitForPopupPage(["The shape of a browser", "Other page"], in: app),
                      "the named window opened a tab but never painted a page (\(popupState(app)))")

        // Back to the opener to read its verdict; only the active tab is mounted.
        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10),
                      "the first named open did not make exactly one tab")
        app.staticTexts["Links"].tap()
        if !waitForPopupText("same-window", in: app) {
            let verdict = app.webViews.staticTexts["different-window"].exists ? "different-window"
                : (app.webViews.staticTexts["null-again"].exists ? "null-again" : "missing")
            XCTFail("window.open(name) did not reuse the named window; the page says (verdict)")
        }

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10),
                      "re-opening the named window made a duplicate tab")
        // The reused window is the one that navigated, not a fresh tab.
        XCTAssertTrue(app.staticTexts["Other page"].waitForExistence(timeout: 10),
                      "the named window did not navigate to the second URL")
        app.staticTexts["Other page"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Other page"].waitForExistence(timeout: 10),
                      "the navigated named window did not show its page")
    }

    /// The history panel is the browser's own record, so it has to list what this
    /// app actually visited and let a page be removed from it.
    func testHistoryListsVisitedPagesAndRemovesOne() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")
        open("http://localhost:8000/other.html", in: app, expect: "Other page")

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10),
                      "menu did not open")
        menuRow("menu.history", in: app).tap()

        let first = app.staticTexts["The shape of a browser"]
        XCTAssertTrue(first.waitForExistence(timeout: 10), "history lost the first page")
        XCTAssertTrue(app.staticTexts["Other page"].exists, "history lost the second page")

        first.press(forDuration: 1.2)
        let remove = app.buttons["Remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "a history row offered no way to remove it")
        remove.tap()
        XCTAssertTrue(first.waitForNonExistence(timeout: 10), "a removed page stayed in history")
    }

    /// Site information is the page's own truth: the host and the scheme it was
    /// fetched with, not a decoration.
    func testSiteInformationNamesTheHostAndScheme() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app)

        app.buttons["rail.siteInfo"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10),
                      "site information did not open")
        XCTAssertTrue(app.staticTexts["Host"].waitForExistence(timeout: 10), "no host row")
        // The row carries the host and its port, so match the host rather than a
        // bare string the panel is not required to use.
        let host = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "localhost")).firstMatch
        XCTAssertTrue(host.exists, "site information did not name the host")
        XCTAssertTrue(app.staticTexts["Scheme"].exists, "no scheme row")
        app.buttons["Done"].tap()
    }

    /// Zoom steps per tab and the percentage is the reset, like the desktop strip.
    func testZoomStepsAndResets() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app)

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10),
                      "menu did not open")
        let reset = app.buttons["menu.zoom.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 10), "no zoom control in the menu")
        waitUntilHittable(reset)
        XCTAssertEqual(reset.value as? String, "100%", "zoom did not start at 100%")

        // The row is a plate of three small controls and the page's zoom is
        // applied by the web view before the model republishes its value; run
        // 45057825247 read the old percentage 0.7 s after each iPad tap. The
        // expected values are unchanged, they are now waited for.
        menuRow("menu.zoom.in", in: app).tap()
        XCTAssertTrue(waitForValue(reset, "110%"), "zoom in did not step the page")
        menuRow("menu.zoom.in", in: app).tap()
        XCTAssertTrue(waitForValue(reset, "120%"), "zoom in did not step the page")

        menuRow("menu.zoom.out", in: app).tap()
        XCTAssertTrue(waitForValue(reset, "110%"), "zoom out did not step the page")

        reset.tap()
        XCTAssertTrue(waitForValue(reset, "100%"), "the percentage did not reset the zoom")
    }

    /// Save as PDF only presents sharing after the file is on disk; the sheet is
    /// therefore the proof the page became a real PDF.
    func testSaveAsPDFPresentsTheFile() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app)

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10),
                      "menu did not open")
        menuRow("menu.save-as-pdf", in: app).tap()

        let activity = app.otherElements["ActivityListView"]
        let close = app.buttons["Close"]
        let deadline = Date().addingTimeInterval(30)
        var presented = false
        while Date() < deadline {
            if activity.exists || close.exists { presented = true; break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(presented, "the PDF was never offered for sharing")
        if close.exists { close.tap() }
    }

    /// The dock must stay above the keyboard, or the page controls go under it.
    func testKeyboardDoesNotCoverTheDock() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app)

        let field = app.textFields["rail.address"]
        field.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), "the keyboard never came up")
        let reload = app.buttons["rail.reload"]
        XCTAssertTrue(reload.waitForExistence(timeout: 10), "the dock left the screen")
        XCTAssertLessThanOrEqual(reload.frame.maxY, keyboard.frame.minY + 1,
                                 "the dock sits under the keyboard")
    }

    /// One destination is not the whole phone: the dock has to survive rotation.
    func testLandscapeKeepsTheDockOnScreen() {
        let app = makeApp()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        open("http://localhost:8000/article.html", in: app)

        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "no address pill in landscape")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(field.frame),
                      "the address pill left the screen in landscape")
        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10),
                      "the menu did not open in landscape")
    }

    /// A popup whose scheme the browser cannot render is refused in the app's own
    /// card: no system alert, no tab, and the page stays exactly where it was.
    func testRefusedPopupUsesTheAppsCard() {
        let app = makeApp()
        open("http://localhost:8000/links.html", in: app, expect: "Links")

        app.webViews.links["Open refused popup"].tap()

        XCTAssertTrue(app.buttons["linknotice.ok"].waitForExistence(timeout: 10),
                      "a popup with an unrenderable scheme was swallowed")
        XCTAssertEqual(app.alerts.count, 0, "the refusal borrowed system chrome")
        XCTAssertTrue(app.staticTexts["linknotice.message"].label.contains("brows-nothing"),
                      "the card did not name the scheme: \(app.staticTexts["linknotice.message"].label)")

        app.buttons["linknotice.ok"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 10),
                      "a refused popup replaced the page")
        app.buttons["rail.tabs"].tap()
        // The notice has only just gone, and its dismissal can swallow the first
        // tap on the dock. Asking again is the same user action, not a looser check.
        if !app.staticTexts["1 open"].waitForExistence(timeout: 5) {
            app.buttons["rail.tabs"].tap()
        }
        XCTAssertTrue(app.staticTexts["1 open"].waitForExistence(timeout: 10),
                      "a refused popup created a tab")
        app.buttons["Done"].tap()
    }

    /// Typing an address the browser cannot build must not be a dead end: the pill
    /// keeps the text, the page stays, and the app says why in its own card.
    func testAddressPillExplainsAnAddressItCannotOpen() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")

        submitAddress("https://exa mple.com", in: app)

        XCTAssertTrue(app.otherElements["notice.card"].waitForExistence(timeout: 10),
                      "an unbuildable address was swallowed in silence")
        XCTAssertEqual(app.alerts.count, 0, "the failure borrowed system chrome")
        XCTAssertTrue(app.staticTexts["notice.message"].label.contains("could not open that address"),
                      "the card did not say what happened: \(app.staticTexts["notice.message"].label)")
        XCTAssertTrue(app.webViews.staticTexts["The shape of a browser"].waitForExistence(timeout: 10),
                      "a rejected address replaced the page")

        app.buttons["notice.ok"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.otherElements["notice.card"])
        waitForExpectations(timeout: 5)
    }

    /// A typed scheme is routed like a tapped one: `mailto:` reaches the system (or
    /// gets the app's refusal card) and never becomes an `https://mailto:` page.
    func testTypedExternalSchemeRoutesInsteadOfBecomingAPage() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")

        submitAddress("mailto:someone@brows.dev", in: app)

        XCTAssertTrue(waitForRoute(app, "mailto"), "a typed mailto was not routed anywhere")
        if app.buttons["linknotice.ok"].waitForExistence(timeout: 3) {
            app.buttons["linknotice.ok"].tap()
        }
        XCTAssertTrue(app.webViews.staticTexts["The shape of a browser"].waitForExistence(timeout: 10),
                      "a typed mailto replaced the page")
        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["1 open"].waitForExistence(timeout: 10),
                      "a typed mailto created a tab")
        app.buttons["Done"].tap()
    }

    /// The start page's own SEARCH bubble is wired to navigation, not decoration.
    func testStartPageSearchNavigates() {
        let app = makeApp()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))

        let field = app.webViews.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "start page search field missing")
        field.tap()
        field.typeText("http://localhost:8000/other.html\n")

        XCTAssertTrue(
            app.webViews.staticTexts["Other page"].waitForExistence(timeout: 25),
            "start page search did not navigate"
        )
    }

    /// A saved bookmark is a real link: it navigates from the bookmarks sheet.
    /// (The dock carried favourite chips until the floating-capsule dock; the star
    /// and this sheet are the phone's route to the same list.)
    func testBookmarkFromMenuNavigates() {
        let app = makeApp()
        // With an expected line the helper re-submits when the simulator drops the
        // synthetic Return, which is how this test once failed with a WebView that
        // had never left the start page.
        open("http://localhost:8000/other.html", in: app, expect: "Other page")
        XCTAssertTrue(app.webViews.staticTexts["Other page"].waitForExistence(timeout: 20))

        let star = app.buttons["rail.star"]
        XCTAssertTrue(star.waitForExistence(timeout: 10))
        star.tap()

        open("http://localhost:8000/login.html", in: app)

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.buttons["menu.bookmarks"].waitForExistence(timeout: 10), "menu did not open")
        menuRow("menu.bookmarks", in: app).tap()
        let row = app.buttons.matching(identifier: "bookmark.row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "bookmark row missing from the sheet")
        // The row is a full-width button; make sure it is not still fading in.
        waitUntilHittable(row)
        row.tap()

        XCTAssertTrue(
            app.webViews.staticTexts["Other page"].waitForExistence(timeout: 20),
            "bookmark row did not navigate"
        )
    }

    /// Deleting a workspace from the sheet's context menu removes it.
    func testWorkspaceDelete() {
        let app = makeApp()
        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.buttons["menu.workspaces"].waitForExistence(timeout: 10), "menu did not open")
        menuRow("menu.workspaces", in: app).tap()

        let field = app.textFields["New workspace"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Temp")
        app.buttons["workspace.add"].tap()

        let row = app.buttons.matching(identifier: "workspace.row.TE").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "workspace was not created")
        row.press(forDuration: 1.2)

        let delete = app.buttons["Delete workspace"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "delete action missing")
        delete.tap()

        // Deleting asks first: the row must still be there until the question is
        // answered, and only then disappear.
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "delete did not ask for confirmation")
        XCTAssertTrue(row.exists, "the workspace vanished before the confirmation was answered")
        confirm.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 8), "workspace still listed after delete")
    }

    /// Turning the bar-position setting off moves the rail to the top.
    func testAddressBarTopSetting() {
        let app = makeApp()
        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))

        menuRow("menu.settings", in: app).tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10))

        // The setting persists, so the switch may already be off from an earlier
        // test. Turn it off rather than toggling blind, then wait for the dock.
        let toggle = app.switches["settings.addressBarBottom"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "bar-position switch missing")
        if (toggle.value as? String) == "1" { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, "0", "the bottom-bar switch stayed on")
        app.buttons["Done"].tap()

        let pill = app.textFields["rail.address"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline && pill.frame.minY >= app.frame.height / 2 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertLessThan(pill.frame.minY, app.frame.height / 2, "rail did not move to the top")
    }

    func testStartPageSearchField() {
        let app = makeApp()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15), "no web view")
    }

    /// The address pill really navigates: type a URL, submit, and the pill carries it.
    func testNavigationFromAddressPill() {
        let app = makeApp()

        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "address pill missing")
        field.tap()
        field.typeText("example.com\n")

        let deadline = Date().addingTimeInterval(20)
        var value = ""
        while Date() < deadline {
            value = (field.value as? String) ?? ""
            if value.contains("example.com") { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertTrue(value.contains("example.com"), "pill did not take the navigation: \(value)")
        XCTAssertTrue(app.webViews.firstMatch.exists, "no web view after navigation")
    }
    // MARK: Page tools

    /// Pull down at the top of a page: the browser loads it again.
    func testPullToRefreshReloadsThePage() {
        let app = makeApp()
        open("http://localhost:8000/refresh.html", in: app, expect: "Refresh")
        let probe = app.staticTexts["debug.page"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        let first = probe.label
        XCTAssertTrue(first.contains("Refresh"), "page probe did not report the fixture: \(first)")
        // A short flick only bounces the page; the refresh control needs a real
        // pull from near the top to past the middle.
        let page = app.webViews.firstMatch
        page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            .press(forDuration: 0.1,
                   thenDragTo: page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", first), object: probe)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 25), .completed,
                       "pull to refresh did not load the page again: \(probe.label)")
    }

    /// The desktop version is a name change for this tab, and the page sees it.
    func testDesktopSiteChangesTheNameThisTabSends() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")
        let probe = app.staticTexts["debug.page"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        XCTAssertFalse(probe.label.hasPrefix("desktop|"), "started on the desktop name: \(probe.label)")
        menuRow("menu.desktop-site", in: app).tap()
        let desktop = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'desktop|'"), object: probe)
        XCTAssertEqual(XCTWaiter().wait(for: [desktop], timeout: 30), .completed,
                       "the page never saw the desktop name: \(probe.label)")
    }

    /// Darkening a page is a filter on the page, not a change to the app.
    func testDarkPagesDarkenThePage() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")
        let probe = app.staticTexts["debug.page"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        XCTAssertTrue(probe.label.contains("|light|"), "page started dark: \(probe.label)")
        app.buttons["rail.menu"].tap()
        app.swipeUp()
        menuRow("menu.darken-web-pages", in: app).tap()
        let dark = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '|dark|'"), object: probe)
        XCTAssertEqual(XCTWaiter().wait(for: [dark], timeout: 20), .completed,
                       "the page was not darkened: \(probe.label)")
    }

    /// The consent banner on the fixture page is hidden before it is seen.
    func testCookieBannerIsHidden() {
        let app = makeApp()
        open("http://localhost:8000/cookie.html", in: app, expect: "Cookies")
        let probe = app.staticTexts["debug.page"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        XCTAssertTrue(probe.label.contains("|0|"), "a consent banner is still visible: \(probe.label)")
    }

    /// Translate opens on the page's own text.
    func testTranslatePageOpensOnThePagesText() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")
        app.buttons["rail.menu"].tap()
        app.swipeUp()
        menuRow("menu.translate-page", in: app).tap()
        XCTAssertTrue(app.staticTexts["Translate page"].waitForExistence(timeout: 15), "translate card missing")
        XCTAssertTrue(app.buttons["translate.run"].waitForExistence(timeout: 5), "translate action missing")
    }

    /// Voice search opens its card and can be dismissed.
    func testVoiceSearchOpensTheMicrophoneCard() {
        let app = makeApp()
        app.buttons["rail.menu"].tap()
        app.swipeUp()
        menuRow("menu.voice-search", in: app).tap()
        XCTAssertTrue(app.staticTexts["voice.status"].waitForExistence(timeout: 15), "voice card missing")
        XCTAssertTrue(app.buttons["voice.start"].exists, "voice card cannot start listening")
        XCTAssertTrue(app.buttons["voice.cancel"].exists, "voice card cannot be dismissed")
    }

    /// The scanner card opens and tells the truth on a machine without a camera.
    func testCodeScannerSaysThisDeviceHasNoCamera() {
        let app = makeApp()
        app.buttons["rail.menu"].tap()
        app.swipeUp()
        menuRow("menu.scan-a-code", in: app).tap()
        XCTAssertTrue(app.staticTexts["scan.unavailable"].waitForExistence(timeout: 15), "scanner card did not open")
    }

    /// The name the browser gives websites is the same in the request the server
    /// receives, in what the page reads, and in a popup window.
    func testBrowserIdentityReachesServerAndPage() {
        let app = makeApp()
        open("http://localhost:8000/ua", in: app, expect: "Identity")
        let header = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'HEADER '")).firstMatch
        let page = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'JS '")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 15), "server row missing")
        XCTAssertTrue(page.waitForExistence(timeout: 15), "page row missing")
        print("BROWS-UA-SERVER: \(header.label)")
        print("BROWS-UA-JS: \(page.label)")
        XCTAssertTrue(header.label.contains("Safari/"), "server saw: \(header.label)")
        XCTAssertTrue(page.label.contains("Safari/"), "page saw: \(page.label)")

        open("http://localhost:8000/links.html", in: app, expect: "Links")
        app.webViews.links["Open identity popup"].tap()
        let popupHeader = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'HEADER '")).firstMatch
        XCTAssertTrue(popupHeader.waitForExistence(timeout: 25), "popup identity row missing")
        print("BROWS-UA-POPUP: \(popupHeader.label)")
        XCTAssertTrue(popupHeader.label.contains("Safari/"), "popup saw: \(popupHeader.label)")
    }

    // MARK: - Evidence for the register's built rows

    /// The tab count the model reports, without a sheet in front of the page.
    private func openTabCount(_ app: XCUIApplication) -> Int {
        Int(app.staticTexts["debug.tabs"].label.split(separator: "|").first ?? "") ?? -1
    }

    /// Waits on a debug probe's value until the predicate holds, then returns
    /// whether it ever did. These probes are the app's own state, so the wait is
    /// not a sleep dressed up.
    private func waitForDebug(
        _ identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 15,
        _ predicate: @escaping (String) -> Bool
    ) -> Bool {
        let element = app.staticTexts[identifier]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, predicate(element.label) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.exists && predicate(element.label)
    }

    /// iOS 26 draws a confirmation dialog as a popover whose only button is the
    /// destructive one; "Cancel" is the dismiss region around it. That is the
    /// same answer the old action sheet's Cancel gave, so the tests use it.
    private func dismissDialog(in app: XCUIApplication) {
        let region = app.otherElements["PopoverDismissRegion"]
        XCTAssertTrue(region.waitForExistence(timeout: 5), "the question cannot be dismissed")
        region.tap()
    }

    /// A private tab is a promise about the history list, not a badge: the pages
    /// it shows must never appear there, while it is open or after it closes.
    func testPrivateTabLeavesNoHistory() {
        let app = makeApp()
        XCTAssertTrue(app.staticTexts["debug.history"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["debug.history"].label, "0|-")

        newPrivateTab(in: app)
        submitAddress("http://localhost:8000/article.html", in: app)
        XCTAssertTrue(
            app.webViews.staticTexts["The shape of a browser"].waitForExistence(timeout: 25),
            "the private tab did not load the page"
        )
        XCTAssertEqual(
            app.staticTexts["debug.history"].label, "0|-",
            "a private visit was written to history"
        )

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 10), "tab gallery missing")
        app.buttons["tab.close"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["1 open"].waitForExistence(timeout: 10), "the private tab did not close")
        app.buttons["Done"].tap()
        XCTAssertEqual(
            app.staticTexts["debug.history"].label, "0|-",
            "closing a private tab released its visit into history"
        )

        app.buttons["rail.menu"].tap()
        menuRow("menu.history", in: app).tap()
        XCTAssertTrue(
            app.staticTexts["Nothing in history yet."].waitForExistence(timeout: 10),
            "the History panel listed a private visit"
        )
    }

    /// The hardware keyboard drives the browser, not just its text fields: the
    /// same keys Safari and Chrome answer must open, close, select and find.
    func testHardwareKeyboardDrivesTheBrowser() {
        let app = makeApp()
        XCTAssertTrue(app.buttons["rail.tabs"].waitForExistence(timeout: 15))
        XCTAssertEqual(openTabCount(app), 1)

        app.typeKey("t", modifierFlags: .command)
        XCTAssertTrue(
            waitForDebug("debug.tabs", in: app) { $0.hasPrefix("2|") },
            "command-T did not open a tab (tabs: \(app.staticTexts["debug.tabs"].label))"
        )

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(
            waitForDebug("debug.tabs", in: app) { $0.hasPrefix("1|") },
            "command-W did not close the tab (tabs: \(app.staticTexts["debug.tabs"].label))"
        )

        app.typeKey("f", modifierFlags: .command)
        let find = app.textFields.matching(
            NSPredicate(format: "placeholderValue == %@", "Find in page")
        ).firstMatch
        XCTAssertTrue(find.waitForExistence(timeout: 10), "command-F did not open Find in page")

        app.typeKey("n", modifierFlags: [.command, .shift])
        XCTAssertTrue(
            app.staticTexts["PRIVATE"].waitForExistence(timeout: 10),
            "shift-command-N did not open a private tab"
        )
    }

    /// The chrome token resolves to the desktop's own size at the default text
    /// size. The accessibility job proves the same token grows at AX5; this is
    /// the other end of that comparison.
    func testChromeTypeUsesTheDesktopSizeByDefault() {
        let app = makeApp()
        XCTAssertTrue(app.staticTexts["debug.type"].waitForExistence(timeout: 15))
        let size = Double(app.staticTexts["debug.type"].label) ?? 0
        XCTAssertEqual(
            size, 13, accuracy: 0.01,
            "the 13 pt chrome token did not resolve to 13 at the default text size"
        )
    }

    /// The four haptic moments cannot be felt on a simulator, but the request for
    /// one is observable: opening, closing and bookmarking must each ask.
    func testHapticsFireAtTheNamedMoments() {
        let app = makeApp()
        XCTAssertTrue(app.staticTexts["debug.haptics"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["debug.haptics"].label, "open 0|pick 0")

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 10), "tab gallery missing")
        app.buttons["tab.add"].tap()
        XCTAssertTrue(
            waitForDebug("debug.haptics", in: app) { $0.contains("open 1") },
            "opening a tab did not ask for a haptic (\(app.staticTexts["debug.haptics"].label))"
        )
        app.buttons["Done"].tap()

        app.buttons["rail.star"].tap()
        XCTAssertTrue(
            waitForDebug("debug.haptics", in: app) { $0.contains("pick 1") },
            "bookmarking did not ask for a selection haptic (\(app.staticTexts["debug.haptics"].label))"
        )

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 10), "tab gallery missing")
        app.buttons["tab.close"].firstMatch.tap()
        XCTAssertTrue(
            waitForDebug("debug.haptics", in: app) { $0.contains("open 2") },
            "closing a tab did not ask for a haptic (\(app.staticTexts["debug.haptics"].label))"
        )
    }

    /// A press is the only moment the rail's wash exists, so the count inside the
    /// button style is what proves a real touch reaches it.
    func testControlPressEntersThePressedState() {
        let app = makeApp()
        let press = app.staticTexts["debug.press"]
        XCTAssertTrue(press.waitForExistence(timeout: 15))
        let before = Int(press.label) ?? 0

        // The site badge and the pill's reload are plain buttons. The menu is a
        // rail control that carries `GlassCircleButtonStyle`, and a normal tap is
        // the contact the wash exists for.
        app.buttons["rail.menu"].tap()

        XCTAssertTrue(
            waitForDebug("debug.press", in: app) { (Int($0) ?? 0) > before },
            "a real touch never entered the control's pressed state (count \(press.label), was \(before))"
        )
    }

    /// The share action hands the finished file to the system share sheet; the
    /// sheet itself is the proof, not the button's presence.
    func testShareSheetPresentsTheDownload() {
        let app = makeApp()
        XCTAssertEqual(
            startDownload("http://localhost:8000/sample.bin", in: app, rows: 1), 1,
            "no finished download to share"
        )

        let share = app.buttons["download.share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10), "the finished download has no share action")
        share.tap()

        let activity = app.otherElements["ActivityListView"]
        let copy = app.buttons["Copy"]
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline && !activity.exists && !copy.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(
            activity.exists || copy.exists || app.buttons["Save to Files"].exists,
            "the share action did not present the system share sheet"
        )
    }

    /// Clearing history asks first, and Cancel means cancel: the row is still
    /// there. Confirming is what removes it.
    func testHistoryClearAsksFirstAndCancelKeepsIt() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")

        app.buttons["rail.menu"].tap()
        menuRow("menu.history", in: app).tap()
        XCTAssertTrue(
            app.staticTexts["The shape of a browser"].waitForExistence(timeout: 10),
            "history did not list the visit"
        )

        app.buttons["Clear"].tap()
        XCTAssertTrue(
            app.staticTexts["Clear all history?"].waitForExistence(timeout: 8),
            "Clear did not ask first"
        )
        dismissDialog(in: app)
        XCTAssertTrue(
            app.staticTexts["The shape of a browser"].waitForExistence(timeout: 5),
            "Cancel still cleared history"
        )

        app.buttons["Clear"].tap()
        let confirm = app.sheets.buttons["Clear history"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8), "Clear did not ask the second time")
        confirm.tap()
        XCTAssertTrue(
            app.staticTexts["Nothing in history yet."].waitForExistence(timeout: 10),
            "confirming Clear left history behind"
        )
    }

    /// The settings clear-all is the widest destructive action in the app: the
    /// question comes first, Cancel leaves the history intact, and only the
    /// confirmed path empties it.
    func testClearEverythingAsksFirstAndCancelKeepsHistory() {
        let app = makeApp()
        open("http://localhost:8000/article.html", in: app, expect: "The shape of a browser")
        XCTAssertTrue(
            app.staticTexts["debug.history"].label.hasPrefix("1|"),
            "the visit was not recorded before the test"
        )

        app.buttons["rail.menu"].tap()
        menuRow("menu.settings", in: app).tap()
        let clear = app.buttons["Clear history, cookies and site data"]
        XCTAssertTrue(clear.waitForExistence(timeout: 10), "the clear-all row is missing")
        // The Data section sits below the fold on a phone; a tap on an off-screen
        // row is delivered to the scroll view, not the button.
        if !clear.isHittable { app.swipeUp() }
        waitUntilHittable(clear, timeout: 10)

        clear.tap()
        XCTAssertTrue(
            app.staticTexts["Delete history, cookies and site data?"].waitForExistence(timeout: 8),
            "clearing everything did not ask first"
        )
        dismissDialog(in: app)
        XCTAssertTrue(
            app.staticTexts["debug.history"].label.hasPrefix("1|"),
            "Cancel still cleared history"
        )

        clear.tap()
        let confirm = app.sheets.buttons["Clear everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8), "the clear-all question did not appear the second time")
        confirm.tap()
        XCTAssertTrue(
            waitForDebug("debug.history", in: app, timeout: 25) { $0.hasPrefix("0|") },
            "confirming did not clear the history (\(app.staticTexts["debug.history"].label))"
        )
    }

    /// Deleting a saved password asks first; Cancel keeps the credential and the
    /// confirmed path removes it from the list.
    func testPasswordDeleteAsksFirst() {
        let app = makeApp()
        app.buttons["rail.menu"].tap()
        menuRow("menu.passwords", in: app).tap()
        XCTAssertTrue(app.staticTexts["Passwords"].waitForExistence(timeout: 10), "passwords panel missing")

        let site = app.textFields["Site"]
        XCTAssertTrue(site.waitForExistence(timeout: 5), "no site field")
        site.tap()
        site.typeText("example.com")
        let username = app.textFields["Username"]
        username.tap()
        username.typeText("probe")
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("secret")
        app.buttons["Save"].tap()
        XCTAssertTrue(
            app.staticTexts["example.com"].waitForExistence(timeout: 10),
            "the password was not saved, so its delete cannot be tested"
        )
        // A tap with the keyboard still up is spent dismissing it, not on the row.
        if app.keyboards.firstMatch.exists {
            app.staticTexts["SAVED"].tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
        }

        let delete = app.buttons["Delete"].firstMatch
        if !delete.isHittable { app.swipeUp() }
        waitUntilHittable(delete, timeout: 10)
        delete.tap()
        XCTAssertTrue(
            app.staticTexts["Delete this saved password?"].waitForExistence(timeout: 8),
            "Delete did not ask first"
        )
        dismissDialog(in: app)
        XCTAssertTrue(app.staticTexts["example.com"].exists, "Cancel still deleted the password")

        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(
            app.sheets.buttons["Delete"].waitForExistence(timeout: 8),
            "the delete question did not appear the second time"
        )
        app.sheets.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["example.com"].waitForNonExistence(timeout: 10),
            "the confirmed delete did not remove the password"
        )
    }

}
