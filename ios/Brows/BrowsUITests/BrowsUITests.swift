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

        app.staticTexts["Site information"].tap()
        XCTAssertTrue(app.navigationBars["Site information"].waitForExistence(timeout: 10), "site information panel missing")
        app.buttons["Done"].tap()

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Downloads"].waitForExistence(timeout: 10), "menu did not reopen")
        app.staticTexts["Downloads"].tap()
        XCTAssertTrue(app.navigationBars["Downloads"].waitForExistence(timeout: 10), "downloads panel missing")
        app.buttons["Done"].tap()

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Passwords"].waitForExistence(timeout: 10), "menu did not reopen")
        app.staticTexts["Passwords"].tap()
        XCTAssertTrue(app.navigationBars["Passwords"].waitForExistence(timeout: 10), "passwords panel missing")
        app.buttons["Done"].tap()

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 10), "tab gallery missing")
        app.buttons["Done"].tap()

        app.buttons["rail.workspace"].tap()
        XCTAssertTrue(app.navigationBars["Workspaces"].waitForExistence(timeout: 10), "workspaces panel missing")
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
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.webViews.staticTexts["Other page"].waitForExistence(timeout: 25),
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
        XCTAssertTrue(app.webViews.staticTexts["The shape of a browser"].waitForExistence(timeout: 25),
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
            app.webViews.links[link].tap()
            XCTAssertTrue(waitForRoute(app, scheme), "\(scheme) was not routed anywhere")
            // A refused handoff explains itself in the app's card; a handled one
            // leaves nothing behind. Either way the page is untouched.
            if app.buttons["linknotice.ok"].waitForExistence(timeout: 3) {
                app.buttons["linknotice.ok"].tap()
            }
            XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 5), "\(scheme) replaced the page")
            app.buttons["rail.tabs"].tap()
            XCTAssertTrue(app.staticTexts["1 open"].waitForExistence(timeout: 10), "\(scheme) created a tab")
            app.buttons["Done"].tap()
        }

        app.webViews.links["Unsupported"].tap()
        XCTAssertTrue(app.buttons["linknotice.ok"].waitForExistence(timeout: 10), "an unsupported scheme was swallowed")
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
            field.tap()
            field.typeText(text)
            if (field.value as? String) == text { break }
        }
        XCTAssertEqual(field.value as? String, text, "address pill did not take the typed text")
        field.typeText("\n")
        let keyboard = app.keyboards.firstMatch
        if keyboard.waitForExistence(timeout: 3) {
            let go = keyboard.buttons["Go"]
            if go.exists { go.tap() }
        }
    }

    private func open(_ url: String, in app: XCUIApplication, expect text: String? = nil) {
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        func submit() {
            // Tapping the pill selects the whole URL, so typing must replace it. On
            // a loaded runner the tap can land before the selection settles and the
            // URL grows into a half-typed mess; re-tapping is the real fix.
            for _ in 0..<3 {
                field.tap()
                field.typeText(url)
                if (field.value as? String) == url { break }
            }
            XCTAssertEqual(field.value as? String, url, "address pill did not replace the current URL")
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
            field.tap()
            field.typeText(text)
            if (field.value as? String) == text { return }
        }
        XCTFail("the pill would not replace its text with \(text): \(field.value ?? "nil") - the URL grew instead")
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
        XCTAssertTrue(app.navigationBars["Site information"].waitForExistence(timeout: 10))

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
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 10))
        app.buttons["tab.add"].tap()

        app.buttons["rail.tabs"].tap()
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

        app.buttons["rail.workspace"].tap()
        XCTAssertTrue(app.navigationBars["Workspaces"].waitForExistence(timeout: 10))

        let field = app.textFields["New workspace"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Work")
        app.buttons["workspace.add"].tap()

        let row = app.buttons.matching(identifier: "workspace.row.WO").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "workspace was not created")
        row.tap()

        XCTAssertTrue(app.buttons["rail.workspace"].waitForExistence(timeout: 10))
        let deadline = Date().addingTimeInterval(8)
        var name = ""
        while Date() < deadline {
            name = (app.buttons["rail.workspace"].value as? String) ?? ""
            if name == "Work" { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertEqual(name, "Work", "rail did not switch workspace")
    }

    /// The desktop rail's order, kept on the phone: the page controls (back,
    /// forward, reload) sit together before the pill, not after the favourites.
    func testPageControlsSitBeforeThePill() {
        let app = makeApp()
        open("http://localhost:8000/other.html", in: app, expect: "Other page")

        let back = app.buttons["rail.back"]
        let reload = app.buttons["rail.reload"]
        let field = app.textFields["rail.address"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "back control missing after navigating")
        XCTAssertTrue(reload.waitForExistence(timeout: 10), "reload control missing")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "address pill missing")
        XCTAssertLessThan(back.frame.maxX, reload.frame.minX, "back must sit left of reload")
        XCTAssertLessThan(
            reload.frame.maxX, field.frame.minX,
            "reload belongs with the page controls, left of the pill"
        )
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

    /// A real octet-stream navigation must land in the download list, not as text
    /// in the page. The workflow serves sample.bin on port 8000 for this test.
    func testDownloadStarts() {
        let app = makeApp()

        func listed() -> Bool {
            app.buttons["rail.menu"].tap()
            guard app.staticTexts["Site information"].waitForExistence(timeout: 10),
                  app.staticTexts["Downloads"].waitForExistence(timeout: 10) else { return false }
            // Downloads sits in the menu's second section, above the fold.
            app.staticTexts["Downloads"].tap()
            if app.staticTexts["sample.bin"].waitForExistence(timeout: 20) { return true }
            app.buttons["Done"].tap()
            return false
        }

        open("http://localhost:8000/sample.bin", in: app)
        if !listed() {
            // No row means the request may never have left the app; a second
            // navigation is a real one (see openRetrying). Nothing here prints
            // element lists: querying a stale snapshot throws and hides the reason.
            print("DOWNLOAD-DEBUG first navigation produced no row; submitting again")
            open("http://localhost:8000/sample.bin", in: app)
            XCTAssertTrue(listed(), "download did not start or was not listed")
        }
        XCTAssertTrue(
            app.buttons["download.share"].waitForExistence(timeout: 20),
            "download never finished (no share action on the row)"
        )
    }

    /// `window.open(url, name, features)` - the OAuth and share-button path - must
    /// give the page a real window. Returning nil made `window.open()` null, which
    /// pages read as "popup blocked", so the tab is opened *and* the window handed
    /// back; the opener must survive and the count must be exactly one more.
    func testWindowOpenWithFeaturesOpensOneSelectedTab() {
        let app = makeApp()
        open("http://localhost:8000/links.html", in: app, expect: "Links")

        app.webViews.buttons["Open popup with features"].tap()

        XCTAssertTrue(app.webViews.staticTexts["The shape of a browser"].waitForExistence(timeout: 20),
                      "window.open with features did not open the page")
        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["2 open"].waitForExistence(timeout: 10),
                      "a feature popup did not open exactly one tab")

        // Back to the opener: it still has its page, and it saw a real window.
        app.staticTexts["Links"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 10),
                      "the opener page was lost")
        XCTAssertTrue(app.webViews.staticTexts["opened"].waitForExistence(timeout: 15),
                      "window.open returned no window, so the page read it as blocked: "
                      + app.webViews.staticTexts["popup-result"].label)
    }

    /// A popup whose scheme the browser cannot render is refused in the app's own
    /// card: no system alert, no tab, and the page stays exactly where it was.
    func testRefusedPopupUsesTheAppsCard() {
        let app = makeApp()
        open("http://localhost:8000/links.html", in: app, expect: "Links")

        app.webViews.buttons["Open refused popup"].tap()

        XCTAssertTrue(app.buttons["linknotice.ok"].waitForExistence(timeout: 10),
                      "a popup with an unrenderable scheme was swallowed")
        XCTAssertEqual(app.alerts.count, 0, "the refusal borrowed system chrome")
        XCTAssertTrue(app.staticTexts["linknotice.message"].label.contains("brows-nothing"),
                      "the card did not name the scheme: \(app.staticTexts["linknotice.message"].label)")

        app.buttons["linknotice.ok"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Links"].waitForExistence(timeout: 10),
                      "a refused popup replaced the page")
        app.buttons["rail.tabs"].tap()
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

    /// A favourite chip is a real link, not a label.
    func testBookmarkChipNavigates() {
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

        let chip = app.buttons.matching(identifier: "bookmark.chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "bookmark chip missing from the rail")
        chip.tap()

        XCTAssertTrue(
            app.webViews.staticTexts["Other page"].waitForExistence(timeout: 20),
            "bookmark chip did not navigate"
        )
    }

    /// Deleting a workspace from the sheet's context menu removes it.
    func testWorkspaceDelete() {
        let app = makeApp()
        app.buttons["rail.workspace"].tap()
        XCTAssertTrue(app.navigationBars["Workspaces"].waitForExistence(timeout: 10))

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
        XCTAssertFalse(row.waitForExistence(timeout: 4), "workspace still listed after delete")
    }

    /// Turning the bar-position setting off moves the rail to the top.
    func testAddressBarTopSetting() {
        let app = makeApp()
        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))
        app.swipeUp()

        let settingsRow = app.staticTexts["Settings"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 10), "Settings row missing")
        settingsRow.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))

        let toggle = app.switches["settings.addressBarBottom"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "bar-position switch missing")
        toggle.tap()
        app.buttons["Done"].tap()

        let pill = app.textFields["rail.address"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
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
}
