import XCTest

/// The Layout Workshop end to end. Set WORKSHOP_SHOT_DIR (TEST_RUNNER_WORKSHOP_SHOT_DIR for
/// xcodebuild) to also save screenshots of each step for review.
final class WorkshopUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testSwapApplyTypeAndReturnToBuiltIn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-no-auto-capitals", "-no-keyboard-tips", "-reset-custom-layouts"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        let editor = app.textViews["preview-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertLessThan(app.buttons["key-й"].frame.minX, app.buttons["key-ц"].frame.minX)

        openWorkshop(in: app)
        let first = app.buttons["workshop-key-0-0"], second = app.buttons["workshop-key-0-1"]
        XCTAssertEqual(first.label, "й")
        XCTAssertFalse(app.buttons["workshop-apply"].isEnabled, "Nothing to apply yet")
        try shot("workshop-1-built-in")

        first.tap()
        reveal(app.buttons["workshop-swap"], in: app)
        app.buttons["workshop-swap"].tap()
        reveal(second, in: app, down: false)
        second.tap()
        XCTAssertEqual(first.label, "ц")
        XCTAssertEqual(second.label, "й")
        try shot("workshop-2-swapped")

        // Replacing й leaves it unreachable, which blocks Apply; Undo brings the swap back.
        let output = app.textFields["workshop-output"]
        reveal(output, in: app)
        output.tap()
        output.typeText("q")
        XCTAssertEqual(second.label, "q")
        XCTAssertEqual(output.value as? String, "q")
        let check = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Missing: й")).firstMatch
        reveal(check, in: app)
        XCTAssertTrue(check.exists)
        try shot("workshop-3-problem")
        reveal(app.buttons["workshop-undo"], in: app)
        XCTAssertFalse(app.buttons["workshop-apply"].isEnabled)
        app.buttons["workshop-undo"].tap()
        reveal(app.staticTexts["Every letter is reachable"], in: app)
        XCTAssertTrue(app.staticTexts["Every letter is reachable"].exists)

        // Try it types with the draft before anything is applied.
        reveal(app.buttons["workshop-try"], in: app)
        app.buttons["workshop-try"].tap()
        XCTAssertTrue(app.navigationBars["Try Українська"].waitForExistence(timeout: 5))
        // The home preview is still underneath the sheets; use the keys that can be touched.
        func visibleKey(_ letter: String) throws -> XCUIElement {
            try XCTUnwrap(app.buttons.matching(identifier: "key-\(letter)").allElementsBoundByIndex.first { $0.isHittable })
        }
        XCTAssertLessThan(try visibleKey("ц").frame.minX, try visibleKey("й").frame.minX)
        try shot("workshop-5-try")
        app.navigationBars["Try Українська"].buttons["Done"].tap()

        reveal(app.buttons["workshop-apply"], in: app)
        XCTAssertTrue(app.buttons["workshop-apply"].isEnabled)
        app.buttons["workshop-apply"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Applied.")).firstMatch.waitForExistence(timeout: 2))
        try shot("workshop-4-applied")

        // The home preview types with the new arrangement.
        app.navigationBars["Layout Workshop"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["layout-workshop"].staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Your layout: UA")).firstMatch.exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertLessThan(app.buttons["key-ц"].frame.minX, app.buttons["key-й"].frame.minX)
        app.buttons["key-ц"].tap()
        app.buttons["key-й"].tap()
        XCTAssertEqual(editor.value as? String, "цй")
        app.buttons["clear-preview"].tap()

        openWorkshop(in: app)
        let builtIn = app.buttons["workshop-use-built-in"]
        reveal(builtIn, in: app)
        builtIn.tap()
        reveal(first, in: app, down: false)
        XCTAssertEqual(first.label, "й")
        app.navigationBars["Layout Workshop"].buttons.firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertLessThan(app.buttons["key-й"].frame.minX, app.buttons["key-ц"].frame.minX)
    }

    @MainActor
    private func openWorkshop(in app: XCUIApplication) {
        let customize = app.buttons["customize-keyboard"]
        for _ in 0..<8 where !(customize.frame.minY > 60 && customize.frame.maxY < app.frame.height - 45) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.25))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.75)))
        }
        customize.tap()
        let row = app.buttons["layout-workshop"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["workshop-key-0-0"].waitForExistence(timeout: 5))
    }

    /// Scrolls the Workshop form until `element` sits fully inside it.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, down: Bool = true) {
        let form = app.collectionViews["workshop-controls"]
        for attempt in 0..<20 {
            let top = app.navigationBars["Layout Workshop"].frame.maxY + 10
            let bottom = min(form.frame.maxY, app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : .greatestFiniteMagnitude) - 10
            if element.exists && element.isHittable && element.frame.minY > top && element.frame.maxY < bottom { return }
            let scrollDown = element.exists ? element.frame.midY > (top + bottom) / 2 : down == (attempt < 10)
            form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: scrollDown ? 0.6 : 0.3))
                .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: scrollDown ? 0.3 : 0.6)))
        }
        XCTFail("Could not scroll into view: \(element)")
    }

    @MainActor
    private func shot(_ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["WORKSHOP_SHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
