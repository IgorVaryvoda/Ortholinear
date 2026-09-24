import XCTest

/// Raw App Store captures for goldie (goldie/goldie.config.ts). Skipped unless the runner gets
/// STORE_CAPTURE_DIR, e.g. `TEST_RUNNER_STORE_CAPTURE_DIR=… xcodebuild test -only-testing:…`.
/// Screens are saved as <scene id>.png; the preview test prints STORE_MARK lines that
/// Tools/store-capture.py uses to cut its screen recording into segments.
final class StoreCaptureTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        guard let path = ProcessInfo.processInfo.environment["STORE_CAPTURE_DIR"] else {
            throw XCTSkip("Set STORE_CAPTURE_DIR to capture store screenshots")
        }
        directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-no-keyboard-tips"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["clear-preview"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func save(_ id: String) throws {
        sleep(1)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appendingPathComponent("\(id).png"))
    }

    @MainActor
    private func type(_ keys: [String], in app: XCUIApplication) {
        for key in keys { app.buttons["key-\(key)"].tap() }
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        app.buttons["customize-keyboard"].tap()
        XCTAssertTrue(app.navigationBars["Keyboard settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test1Type() throws {
        let app = launch()
        app.buttons["clear-preview"].tap()
        // Automatic capitals put Shift on in the empty field.
        type(["П", "р", "и", "в", "і", "т", "Space", "я", "к", "Space", "с", "п", "р", "а", "в"], in: app)
        XCTAssertTrue(app.buttons["suggestion-0"].waitForExistence(timeout: 5))
        try save("type")
    }

    @MainActor
    func test2Suggest() throws {
        let app = launch()
        app.buttons["clear-preview"].tap()
        app.buttons["key-Switch to English"].tap()
        type(["S", "e", "e", "Space", "y", "o", "u", "Space", "t", "o", "m", "o", "r", "o", "w"], in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Use tomorrow")).firstMatch.waitForExistence(timeout: 5))
        try save("suggest")
    }

    @MainActor
    func test3Languages() throws {
        let app = launch()
        openSettings(app)
        app.buttons["language-settings"].tap()
        XCTAssertTrue(app.switches["language-polish"].waitForExistence(timeout: 5))
        try save("languages")
    }

    @MainActor
    func test4Settings() throws {
        let app = launch()
        openSettings(app)
        let form = app.collectionViews["geometry-controls"]
        let slider = app.sliders["Key height"]
        for _ in 0..<8 where !(slider.exists && slider.frame.midY < form.frame.maxY - 80) {
            form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.85))
                .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.55)))
        }
        try save("settings")
    }

    @MainActor
    func test5Private() throws {
        let app = launch()
        let button = app.buttons["enable-keyboard"]
        // Small steps, so the page behind the sheet still shows the headline, not keys.
        for _ in 0..<10 where button.frame.maxY > app.frame.height - 40 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.975, dy: 0.85))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.975, dy: 0.75)))
        }
        button.tap()
        XCTAssertTrue(app.navigationBars["Meet your new keyboard"].waitForExistence(timeout: 5))
        try save("private")
    }

    /// Last: it leaves Tokyo Night selected.
    @MainActor
    func test6Themes() throws {
        let app = launch()
        openSettings(app)
        app.buttons["choose-theme"].tap()
        XCTAssertTrue(app.buttons["theme-tokyoNight"].waitForExistence(timeout: 5))
        app.buttons["theme-tokyoNight"].tap()
        try save("themes")
        app.buttons["theme-system"].tap()
    }

    /// One continuous take; STORE_MARK lines split it into the config's segments.
    @MainActor
    func test7Preview() throws {
        let app = launch()
        app.buttons["clear-preview"].tap()
        func mark(_ name: String) { print("STORE_MARK \(name) \(Date().timeIntervalSince1970)") }
        sleep(1)
        mark("type")
        for key in ["П", "р", "и", "в", "і", "т"] { app.buttons["key-\(key)"].tap(); usleep(150_000) }
        usleep(600_000)
        // Two Spaces end the sentence, so the glided word starts with a capital.
        app.buttons["key-Space"].doubleTap()
        sleep(1)
        mark("glide")
        app.buttons["key-Switch to English"].tap()
        sleep(1)
        // A straight e → l slide decodes to “well”; the leading capital is automatic.
        app.buttons["key-E"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.buttons["key-L"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: 350, thenHoldForDuration: 0.05)
        sleep(2)
        mark("theme")
        openSettings(app)
        sleep(1)
        app.buttons["choose-theme"].tap()
        sleep(1)
        app.buttons["theme-tokyoNight"].tap()
        sleep(1)
        app.buttons["theme-nord"].tap()
        sleep(2)
        mark("end")
        app.buttons["theme-system"].tap()
    }
}
