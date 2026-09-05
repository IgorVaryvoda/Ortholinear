import XCTest

/// Run separately on a disposable simulator; enables Ortholinear in iOS Settings.
final class SystemExtensionTests: XCTestCase {
    @MainActor
    private func tapOnMainPage(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        for _ in 0..<8 {
            if button.frame.minY > 90 && button.frame.maxY < app.frame.height - 60 { break }
            let upward = button.frame.midY > app.frame.height / 2
            // Start outside the keyboard so its touch surface doesn't claim the drag.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: upward ? 0.8 : 0.25))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: upward ? 0.3 : 0.75)))
        }
        button.tap()
    }

    @MainActor
    func testInstalledExtensionTypesInHostField() throws {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        tapOnMainPage("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        app.sliders["Key height"].adjust(toNormalizedSliderPosition: 1)
        app.buttons["Done"].tap()
        // XCUITest's slider endpoint can round short of 1.0. Compare the extension
        // with the actual saved preview geometry, while requiring a customized size.
        let previewKeyHeight = app.buttons["key-ф"].frame.height
        XCTAssertGreaterThan(previewKeyHeight, 80)
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        if !settings.buttons["AddNewKeyboard"].waitForExistence(timeout: 2) {
            XCTAssertTrue(settings.staticTexts["General"].waitForExistence(timeout: 10), settings.debugDescription)
            settings.staticTexts["General"].tap()
            let keyboard = settings.staticTexts["Keyboard"]
            for _ in 0..<5 {
                if keyboard.isHittable { break }
                settings.swipeUp()
            }
            XCTAssertTrue(keyboard.exists, settings.debugDescription)
            keyboard.tap()
            settings.cells.containing(.staticText, identifier: "Keyboards").firstMatch.tap()
        }
        if !settings.cells.containing(.staticText, identifier: "Ortholinear").firstMatch.exists {
            settings.buttons["AddNewKeyboard"].tap()
            XCTAssertTrue(settings.staticTexts["Ortholinear"].waitForExistence(timeout: 5), settings.debugDescription)
            settings.staticTexts["Ortholinear"].tap()
        }

        app.activate()
        tapOnMainPage("system-test", in: app)
        let editor = app.textViews["system-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        let surface = app.otherElements["system-keyboard-surface"]
        if surface.buttons["key-Switch to Українська"].exists { surface.buttons["key-Switch to Українська"].tap() }
        let ukrainianKey = surface.buttons["key-ф"]
        if !ukrainianKey.waitForExistence(timeout: 2) {
            let globe = app.buttons["Next keyboard"]
            XCTAssertTrue(globe.exists, app.debugDescription)
            globe.press(forDuration: 1)
            let option = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ortholinear'")).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5), app.debugDescription)
            option.tap()
        }
        XCTAssertTrue(ukrainianKey.waitForExistence(timeout: 10), app.debugDescription)
        let loaded = XCTAttachment(screenshot: app.screenshot())
        loaded.name = "System keyboard loaded"
        loaded.lifetime = .keepAlways
        add(loaded)
        XCTAssertEqual(ukrainianKey.frame.height, previewKeyHeight, accuracy: 1, "Extension must read the same saved key height as the app preview")
        XCTAssertFalse(surface.buttons["key-."].exists)
        XCTAssertFalse(surface.buttons["key-,"].exists)
        XCTAssertFalse(surface.buttons["key-ґ"].exists)
        XCTAssertEqual(surface.buttons["key-Space"].frame.height, 59, accuracy: 1)
        XCTAssertGreaterThan(surface.buttons["key-Return"].frame.width, 70)
        XCTAssertGreaterThan(surface.buttons["key-Delete"].frame.width, 70)
        XCTAssertEqual(surface.buttons["key-Shift"].frame.minY, surface.buttons["key-я"].frame.minY, accuracy: 1)
        XCTAssertEqual(surface.buttons["key-Shift"].frame.maxX, surface.buttons["key-я"].frame.minX, accuracy: 1)
        XCTAssertEqual(surface.buttons["key-Delete"].frame.minY, surface.buttons["key-ю"].frame.minY, accuracy: 1)
        XCTAssertEqual(surface.buttons["key-Delete"].frame.minX, surface.buttons["key-ю"].frame.maxX, accuracy: 1)
        XCTAssertFalse(surface.buttons["key-'"].exists)
        ukrainianKey.tap()
        surface.buttons["key-і"].tap()
        surface.buttons["key-Switch to English"].tap()
        surface.buttons["key-a"].tap()
        XCTAssertEqual(editor.value as? String, "фіa")
        surface.buttons["key-Delete"].tap()
        XCTAssertEqual(editor.value as? String, "фі")
        surface.buttons["key-Switch to Українська"].tap()
        surface.buttons["key-г"].tap()
        surface.buttons["key-г"].press(forDuration: 0.6)
        XCTAssertEqual(editor.value as? String, "фігґ")
        surface.buttons["key-Shift"].tap()
        surface.buttons["key-Г"].press(forDuration: 0.6)
        surface.buttons["key-г"].tap()
        XCTAssertEqual(editor.value as? String, "фігґҐг")
        surface.buttons["key-Switch to English"].tap()
        let numbers = surface.buttons["key-Numbers"]
        let leftEdge = numbers.frame.minX
        numbers.tap()
        XCTAssertEqual(surface.buttons["key-Letters"].frame.minX, leftEdge, accuracy: 1)
        let symbolPoint = surface.buttons["key-1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).screenPoint
        surface.buttons["key-Letters"].tap()
        let symbol = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: symbolPoint.x, dy: symbolPoint.y))
        numbers.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: symbol)
        XCTAssertEqual(editor.value as? String, "фігґҐг1")
        XCTAssertTrue(numbers.exists, "A symbol slide must restore letters in the installed extension")
        surface.buttons["key-a"].tap()
        XCTAssertEqual(editor.value as? String, "фігґҐг1a")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Installed keyboard extension"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["Done"].tap()
        tapOnMainPage("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        app.buttons["Done"].tap()
    }
}
