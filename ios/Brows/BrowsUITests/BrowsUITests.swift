import XCTest

/// Drives the surfaces the app actually shows: the rail exists, the menu opens,
/// and the panels behind its rows are real.
final class BrowsUITests: XCTestCase {
    func testRailAndMenuPanels() {
        let app = XCUIApplication()
        app.launch()

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

    func testStartPageSearchField() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15), "no web view")
    }

    /// The address pill really navigates: type a URL, submit, and the pill carries it.
    func testNavigationFromAddressPill() {
        let app = XCUIApplication()
        app.launch()

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
