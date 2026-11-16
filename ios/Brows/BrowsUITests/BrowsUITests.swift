import XCTest

/// Drives the surfaces the app actually shows: the rail exists, the menu opens,
/// and the panels behind its rows are real.
final class BrowsUITests: XCTestCase {
    /// Each test starts from a clean install state, so tab counts are deterministic.
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-BrowsUITestReset"]
        app.launch()
        return app
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

    private func open(_ url: String, in app: XCUIApplication) {
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText(url + "\n")
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 25))
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
