import XCTest
import UIKit

/// The platform passes the audit used to list as open: the largest Dynamic Type
/// category, Reduce Motion, and the accessibility tree VoiceOver reads.
///
/// These run in the `accessibility` CI job, which sets the simulator's content
/// size to AX5 and its Reduce Motion preference before the runner launches. Each
/// test asserts its own precondition, so a green result cannot come from the
/// default configuration.
///
/// The app's type is fixed-point on purpose: it reproduces a desktop rail, not a
/// system form. The Dynamic Type pass therefore asserts what fixed type still
/// owes the setting — every rail control and every panel the suite opens stays
/// on screen, hittable and unclipped at AX5 — rather than pretending the glyphs
/// scale.
final class BrowsAccessibilityUITests: XCTestCase {
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-BrowsUITestReset"]
        app.launch()
        return app
    }

    /// Visible, hittable, non-degenerate and wholly inside the app's frame: the
    /// clipping check the rail and its panels must clear at the largest setting.
    private func assertOnScreen(
        _ element: XCUIElement,
        _ name: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(name) missing", file: file, line: line)
        XCTAssertTrue(element.isHittable, "\(name) exists but is not hittable", file: file, line: line)
        XCTAssertGreaterThan(element.frame.width, 0, "\(name) has no width", file: file, line: line)
        XCTAssertGreaterThan(element.frame.height, 0, "\(name) has no height", file: file, line: line)
        let screen = app.frame.insetBy(dx: -1, dy: -1)
        XCTAssertTrue(
            screen.contains(element.frame),
            "\(name) at \(element.frame) is clipped by the \(screen) screen",
            file: file,
            line: line
        )
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while element.exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return !element.exists
    }

    private func dismiss(_ app: XCUIApplication) {
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the panel has no Done button")
        done.tap()
        XCTAssertTrue(waitUntilGone(done), "the panel did not dismiss")
    }

    private func openMenu(_ app: XCUIApplication, scroll: Bool = false) {
        let menu = app.buttons["rail.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15), "menu destination missing")
        menu.tap()
        XCTAssertTrue(
            app.buttons["menu.site-information"].waitForExistence(timeout: 10),
            "menu did not open"
        )
        _ = scroll
    }

    private func openPanel(_ app: XCUIApplication, row: String, title: String, scroll: Bool = false) {
        openMenu(app, scroll: scroll)
        let button = app.buttons[row]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "\(row) row missing from the menu")
        var scrolls = 0
        while !button.isHittable && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        button.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "\(title) panel missing")
    }

    private func openPage(_ app: XCUIApplication) {
        let field = app.textFields["rail.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "address pill missing")
        let address = "http://localhost:8000/article.html"
        for _ in 0..<3 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 8) { break }
        }
        field.typeText(address)
        // The keystrokes are synthesized faster than an AX5 simulator repaints
        // the field: run 45057825247 read the placeholder seven seconds after
        // typeText returned, and the Return that followed still navigated, so
        // the text was there and the read was early. Wait for the field to hold
        // the address; the assertion itself stays exact.
        let tookAddress = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", address),
            object: field
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [tookAddress], timeout: 10), .completed,
            "the pill did not take the address"
        )
        field.typeText("\n")
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 25), "the page never opened")
    }

    /// At AX5 every rail control and both panels the audit names stay on screen,
    /// hittable and unclipped. The content size is asserted first: if the
    /// simulator is not at the largest category this pass would prove nothing.
    func testDynamicTypeLargestCategoryKeepsTheRailAndPanelsOnScreen() {
        let category = UIApplication.shared.preferredContentSizeCategory
        XCTAssertEqual(
            category,
            .accessibilityExtraExtraExtraLarge,
            "the simulator was not at AX5 (content size \(category.rawValue))"
        )

        let app = makeApp()
        assertOnScreen(app.textFields["rail.address"], "address pill", in: app)
        assertOnScreen(app.buttons["rail.siteInfo"], "site information", in: app)
        assertOnScreen(app.buttons["rail.reload"], "reload", in: app)
        assertOnScreen(app.buttons["rail.star"], "bookmark star", in: app)
        assertOnScreen(app.buttons["rail.tabs"], "tabs", in: app)
        assertOnScreen(app.buttons["rail.menu"], "menu", in: app)

        // The menu's first section without scrolling, and the page tools after
        // one swipe: both must lay out whole at AX5, not push a row off-screen.
        openMenu(app)
        for row in [
            "menu.site-information",
            "menu.downloads",
            "menu.passwords",
            "menu.workspaces",
            "menu.settings",
        ] {
            assertOnScreen(app.buttons[row], row, in: app)
        }
        app.swipeUp()
        for row in ["menu.find-in-page", "menu.save-as-pdf"] {
            assertOnScreen(app.buttons[row], row, in: app)
        }
        dismiss(app)

        openPanel(app, row: "menu.site-information", title: "Site information")
        assertOnScreen(app.buttons["Done"], "site information Done", in: app)
        dismiss(app)

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 10), "tab gallery missing")
        assertOnScreen(app.buttons["Done"], "tab gallery Done", in: app)
        dismiss(app)

        assertOnScreen(app.textFields["rail.address"], "address pill after the panels", in: app)
    }

    /// With Reduce Motion on, every panel the suite opens is still reachable in
    /// order, the tab gallery still opens, a real navigation still commits, and
    /// the dock comes back each time. The setting itself is asserted first.
    func testReduceMotionReachesEveryScreen() {
        XCTAssertTrue(
            UIAccessibility.isReduceMotionEnabled,
            "Reduce Motion was not enabled on the simulator before the runner launched"
        )

        let app = makeApp()
        assertOnScreen(app.textFields["rail.address"], "address pill", in: app)

        openPanel(app, row: "menu.site-information", title: "Site information")
        dismiss(app)
        openPanel(app, row: "menu.bookmarks", title: "Bookmarks")
        dismiss(app)
        openPanel(app, row: "menu.history", title: "History")
        dismiss(app)
        openPanel(app, row: "menu.downloads", title: "Downloads")
        dismiss(app)
        openPanel(app, row: "menu.passwords", title: "Passwords")
        dismiss(app)
        openPanel(app, row: "menu.content-blockers", title: "Content blockers")
        dismiss(app)
        openPanel(app, row: "menu.workspaces", title: "Workspaces")
        XCTAssertTrue(app.staticTexts["CURRENT"].waitForExistence(timeout: 10), "workspaces did not load")
        dismiss(app)
        openPanel(app, row: "menu.settings", title: "Settings", scroll: true)
        dismiss(app)

        app.buttons["rail.tabs"].tap()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 10), "tab gallery unreachable")
        dismiss(app)

        openPage(app)
        // Once the page commits, the pill returns to its placeholder; the URL
        // is only in the field while it is being edited. The page's own heading
        // is the proof the navigation landed, the same check every other test
        // makes. Run 45086747875 read the placeholder here and failed on a page
        // that had loaded.
        XCTAssertTrue(
            app.webViews.staticTexts["The shape of a browser"].waitForExistence(timeout: 25),
            "the navigation did not commit with Reduce Motion on"
        )
        openMenu(app)
        assertOnScreen(app.buttons["menu.site-information"], "menu after navigation", in: app)
        dismiss(app)
        assertOnScreen(app.buttons["rail.menu"], "dock after every screen", in: app)
    }

    /// VoiceOver's raw material: the key controls carry a real name, the right
    /// trait, a reachable frame, and no two dock controls share a name. The
    /// address field and the site button only became named when this pass was
    /// written; before that the field read as its placeholder and the button as
    /// the lock glyph alone.
    func testVoiceOverExposesLabelsAndTraitsOnTheKeyControls() {
        let app = makeApp()

        let address = app.textFields["rail.address"]
        assertOnScreen(address, "address field", in: app)
        XCTAssertEqual(address.elementType, .textField, "the address control is not a text field")
        XCTAssertEqual(address.label, "Address and search", "the address field has no accessible name")

        let site = app.buttons["rail.siteInfo"]
        assertOnScreen(site, "site information", in: app)
        XCTAssertEqual(site.elementType, .button, "site information is not a button")
        XCTAssertEqual(site.label, "Site information", "site information has no accessible name")

        let reload = app.buttons["rail.reload"]
        assertOnScreen(reload, "reload", in: app)
        XCTAssertEqual(reload.elementType, .button)
        XCTAssertEqual(reload.label, "Reload")

        let star = app.buttons["rail.star"]
        assertOnScreen(star, "bookmark star", in: app)
        XCTAssertEqual(star.elementType, .button)
        XCTAssertFalse(star.label.isEmpty, "the star has no accessible name")
        XCTAssertTrue(
            ["bookmarked", "not bookmarked"].contains(star.value as? String ?? ""),
            "the star's value is not its bookmark state: \(star.value ?? "nil")"
        )

        let tabs = app.buttons["rail.tabs"]
        assertOnScreen(tabs, "tabs", in: app)
        XCTAssertEqual(tabs.label, "Tabs")
        XCTAssertEqual(tabs.value as? String, "1 open", "the tab count is not exposed")

        let menu = app.buttons["rail.menu"]
        assertOnScreen(menu, "menu", in: app)
        XCTAssertEqual(menu.label, "Menu")

        let dockNames = [address.label, site.label, reload.label, star.label, tabs.label, menu.label]
        XCTAssertEqual(Set(dockNames).count, dockNames.count, "two dock controls share a VoiceOver name")
        for control in [site, reload, star, tabs, menu] {
            XCTAssertTrue(control.isHittable, "\(control.label) is not reachable")
        }

        openPage(app)
        let back = app.buttons["rail.back"]
        assertOnScreen(back, "back", in: app)
        XCTAssertEqual(back.label, "Back")
        back.tap()
        let forward = app.buttons["rail.forward"]
        XCTAssertTrue(forward.waitForExistence(timeout: 15), "forward never appeared after back")
        XCTAssertEqual(forward.label, "Forward")

        openMenu(app)
        let siteRow = app.buttons["menu.site-information"]
        XCTAssertTrue(siteRow.waitForExistence(timeout: 10), "menu row missing")
        XCTAssertTrue(siteRow.label.contains("Site information"), "the menu row reads '\(siteRow.label)'")
        XCTAssertTrue(siteRow.isHittable, "the menu row is not reachable")
        let settingsRow = app.buttons["menu.settings"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 5), "settings row missing")
        XCTAssertTrue(settingsRow.label.contains("Settings"), "the settings row reads '\(settingsRow.label)'")
    }
}
