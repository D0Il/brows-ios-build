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

    private func open(_ url: String, in app: XCUIApplication, expect text: String? = nil) {
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        func submit() {
            field.tap()
            // Tapping the pill selects the whole URL, so typing must replace it.
            field.typeText(url)
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
        open("http://localhost:8000/auth.html", in: app)

        XCTAssertTrue(app.navigationBars["Sign in"].waitForExistence(timeout: 15), "HTTP auth prompt missing")
        XCTAssertFalse(app.alerts["Sign in"].exists, "the system's chrome answered instead of the app")
        signIn(user: "browsuser", password: "browssecret", in: app)

        XCTAssertTrue(
            app.webViews.staticTexts["Protected area"].waitForExistence(timeout: 25),
            "401-protected content was not reached with the entered credentials"
        )
        let save = app.alerts["Save password?"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "completed auth was not offered for saving")
        save.buttons["Save"].tap()
        waitUntilGone(save, app: app)
        print("SAVE-DEBUG1 creds=\(app.staticTexts["debug.credentials"].label) state=\(app.staticTexts["debug.credentialstate"].label)")
        XCTAssertEqual(app.staticTexts["debug.credentials"].label, "1", "auth save did not reach the credential list")
    }

    /// Relaunch answers from the Keychain with no prompt, and a second account on
    /// the same origin offers both Save new account and Update saved.
    func testHTTPAuthSurvivesRelaunchAndSecondAccountOffersChoice() {
        let app = makeApp()
        open("http://localhost:8000/auth.html", in: app)
        XCTAssertTrue(app.navigationBars["Sign in"].waitForExistence(timeout: 15))
        signIn(user: "browsuser", password: "browssecret", in: app)
        XCTAssertTrue(app.webViews.staticTexts["Protected area"].waitForExistence(timeout: 25))
        let firstSave = app.alerts["Save password?"]
        XCTAssertTrue(firstSave.waitForExistence(timeout: 10))
        firstSave.buttons["Save"].tap()
        waitUntilGone(firstSave, app: app)
        print("SAVE-DEBUG2 creds=\(app.staticTexts["debug.credentials"].label) state=\(app.staticTexts["debug.credentialstate"].label)")
        XCTAssertEqual(app.staticTexts["debug.credentials"].label, "1", "auth save did not reach the credential list")
        app.terminate()

        let relaunched = makeApp(extra: ["-BrowsOpenURL", "http://localhost:8000/auth.html"], reset: false)
        print("RELAUNCH-STATE creds=\(relaunched.staticTexts["debug.credentials"].label) state=\(relaunched.staticTexts["debug.credentialstate"].label)")
        XCTAssertEqual(relaunched.staticTexts["debug.credentials"].label, "1", "saved list was not loaded after relaunch")
        let protected = relaunched.webViews.staticTexts["Protected area"]
        if !protected.waitForExistence(timeout: 25) {
            print("RELAUNCH-DEBUG prompt=\(relaunched.navigationBars["Sign in"].exists)")
            print(relaunched.debugDescription)
        }
        XCTAssertTrue(protected.exists, "saved Keychain credential was not offered after relaunch")
        XCTAssertFalse(relaunched.navigationBars["Sign in"].exists, "relaunch prompted instead of using the Keychain")

        // Same origin, second protection space: there is no saved entry for it, so
        // the prompt must open and the new account must be offered for saving.
        open("http://localhost:8000/auth2.html", in: relaunched)
        XCTAssertTrue(relaunched.navigationBars["Sign in"].waitForExistence(timeout: 15), "second-account challenge did not prompt")
        signIn(user: "otheraccount", password: "othersecret", in: relaunched)
        XCTAssertTrue(relaunched.webViews.staticTexts["Protected area"].waitForExistence(timeout: 25))

        let choice = relaunched.alerts["Save password?"]
        XCTAssertTrue(choice.waitForExistence(timeout: 10), "second account was not offered for saving")
        XCTAssertTrue(choice.buttons["Save new account"].exists, "save-new choice missing")
        XCTAssertTrue(choice.buttons["Update browsuser"].exists, "update-saved choice missing")
        choice.buttons["Save new account"].tap()
        waitUntilGone(choice, app: relaunched)
    }

    /// Dismissal is animated; a tap on the next surface during it lands nowhere.
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
        app.buttons["auth.signIn"].tap()
    }

    /// End to end password manager: submit a served login form, save it, leave the
    /// origin, come back, and assert the fields hold the stored credentials.
    func testPasswordSaveAndAutofill() {
        let app = makeApp()
        open("http://localhost:8000/login.html", in: app)

        let username = app.webViews.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout: 15), "login fixture fields missing")
        username.tap()
        username.typeText("browsuser")

        let password = app.webViews.secureTextFields["Password"]
        XCTAssertTrue(password.exists, "fixture password field missing")
        password.tap()
        password.typeText("browssecret")

        app.webViews.buttons["Log in"].tap()

        let alert = app.alerts["Save password?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "submitted login was not offered for saving")
        alert.buttons["Save"].tap()

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
        open("example.com", in: app)

        app.buttons["rail.siteInfo"].tap()
        XCTAssertTrue(app.navigationBars["Site information"].waitForExistence(timeout: 10))

        let off = app.buttons["Turn off blocking on this site"]
        XCTAssertTrue(off.waitForExistence(timeout: 10), "no per-site blocking toggle")
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

    /// A real octet-stream navigation must land in the download list, not as text
    /// in the page. The workflow serves sample.bin on port 8000 for this test.
    func testDownloadStarts() {
        let app = makeApp()
        open("http://localhost:8000/sample.bin", in: app)

        app.buttons["rail.menu"].tap()
        XCTAssertTrue(app.staticTexts["Site information"].waitForExistence(timeout: 10))
        // Downloads sits in the menu's second section, above the fold.
        let downloads = app.staticTexts["Downloads"]
        XCTAssertTrue(downloads.waitForExistence(timeout: 10))
        downloads.tap()

        if !app.staticTexts["sample.bin"].waitForExistence(timeout: 20) {
            let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
            XCTFail("download did not start or was not listed; visible labels: \(labels)")
            return
        }
        XCTAssertTrue(
            app.buttons["download.share"].waitForExistence(timeout: 20),
            "download never finished (no share action on the row)"
        )
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
        open("http://localhost:8000/other.html", in: app)
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
