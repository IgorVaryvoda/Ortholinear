import XCTest

final class KeyboardUITests: XCTestCase {
    @MainActor
    private func tapMainButton(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        for _ in 0..<8 {
            if button.frame.minY > 60 && button.frame.maxY < app.frame.height - 45 { break }
            let up = button.frame.midY > app.frame.height / 2
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: up ? 0.8 : 0.25))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: up ? 0.3 : 0.75)))
        }
        button.tap()
    }

    @MainActor
    private func launchApp(landscape: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            landscape ? app.frame.width > app.frame.height : app.frame.width < app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 5), .completed)
        return app
    }

    @MainActor
    func testTypingLanguagesShiftSymbolsAndDelete() throws {
        let app = launchApp()
        let editor = app.textViews["preview-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        app.buttons["key-ф"].tap()
        app.buttons["key-і"].tap()
        XCTAssertEqual(editor.value as? String, "фі")
        app.buttons["key-Shift"].tap()
        XCTAssertFalse(app.buttons["key-Ґ"].exists)
        app.buttons["key-Г"].press(forDuration: 0.6)
        XCTAssertEqual(editor.value as? String, "фіҐ")
        app.buttons["key-Switch to English"].tap()
        app.buttons["key-a"].tap()
        app.buttons["key-Numbers"].tap()
        app.buttons["key-1"].tap()
        app.buttons["key-More symbols"].tap()
        app.buttons["key-₴"].tap()
        XCTAssertEqual(editor.value as? String, "фіҐa1₴")
        app.buttons["key-Delete"].tap()
        XCTAssertEqual(editor.value as? String, "фіҐa1")
        app.buttons["key-Return"].tap()
        XCTAssertEqual(editor.value as? String, "фіҐa1\n")
        app.buttons["clear-preview"].tap()
        XCTAssertEqual(editor.value as? String, "")
    }

    @MainActor
    func testGeometryAndSetup() throws {
        let app = launchApp()
        tapMainButton("customize-keyboard", in: app)
        XCTAssertTrue(app.navigationBars["Your geometry"].waitForExistence(timeout: 5))
        app.buttons["preset-original"].tap()
        XCTAssertEqual(app.switches["show-punctuation"].value as? String, "1")
        app.sliders["Key height"].adjust(toNormalizedSliderPosition: 0.7)
        app.buttons["preset-bigLetters"].tap()
        XCTAssertEqual(app.switches["show-punctuation"].value as? String, "0")
        app.buttons["Done"].tap()
        tapMainButton("enable-keyboard", in: app)
        XCTAssertTrue(app.navigationBars["Meet your new keyboard"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    @MainActor
    func testHoldDeleteAndSpaceCursor() throws {
        let app = launchApp()
        let editor = app.textViews["preview-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        app.buttons["key-Switch to English"].tap()
        for _ in 0..<8 { app.buttons["key-a"].tap() }
        let space = app.buttons["key-Space"]
        let start = space.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -37, dy: 0)))
        app.buttons["key-b"].tap()
        XCTAssertEqual(editor.value as? String, "aaaaabaaa")
        app.buttons["key-Delete"].press(forDuration: 1.1)
        XCTAssertLessThan((editor.value as? String ?? "").count, 8)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Ortholinear preview"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPunctuationHoldAndCapsLock() throws {
        let app = launchApp()
        let editor = app.textViews["preview-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        app.buttons["key-Shift"].doubleTap()
        app.buttons["key-А"].tap()
        app.buttons["key-Б"].tap()
        XCTAssertEqual(editor.value as? String, "АБ")
        app.buttons["key-Shift"].tap()
        app.buttons["key-Numbers"].tap()
        let first = app.buttons["key-1"].frame
        let last = app.buttons["key-0"].frame
        let target = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: (first.minX + last.maxX) / 2 - 26, dy: first.minY + 17))
        app.buttons["key-."].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: target)
        XCTAssertEqual(editor.value as? String, "АБ… ")
        app.buttons["key-Space"].tap()
        XCTAssertEqual(editor.value as? String, "АБ… ")
    }

    @MainActor
    func testCustomizationPersistsAndMakesRoomForLetters() throws {
        let app = launchApp()
        tapMainButton("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["key-."].exists)
        XCTAssertFalse(app.buttons["key-,"].exists)
        let wider = app.buttons["key-я"].frame.width
        XCTAssertEqual(app.buttons["key-ф"].frame.height, 75, accuracy: 1)
        XCTAssertEqual(app.buttons["key-Space"].frame.height, 59, accuracy: 1)
        XCTAssertGreaterThan(app.buttons["key-Return"].frame.width, 70)
        XCTAssertGreaterThan(app.buttons["key-Delete"].frame.width, 2 * app.buttons["key-ю"].frame.width)
        XCTAssertEqual(app.buttons["key-Delete"].frame.height, app.buttons["key-ю"].frame.height, accuracy: 1)
        XCTAssertEqual(app.buttons["key-Delete"].frame.minY, app.buttons["key-ю"].frame.minY, accuracy: 1)
        XCTAssertEqual(app.buttons["key-Delete"].frame.minX, app.buttons["key-ю"].frame.maxX, accuracy: 1)
        XCTAssertEqual(app.buttons["key-Shift"].frame.minY, app.buttons["key-я"].frame.minY, accuracy: 1)
        XCTAssertEqual(app.buttons["key-Shift"].frame.maxX, app.buttons["key-я"].frame.minX, accuracy: 1)

        tapMainButton("customize-keyboard", in: app)
        app.switches["show-punctuation"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(app.switches["show-punctuation"].value as? String, "1")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["key-."].exists)
        XCTAssertLessThan(app.buttons["key-я"].frame.width, wider)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["key-."].waitForExistence(timeout: 5))
        tapMainButton("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        app.switches["show-apostrophe"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(app.switches["show-apostrophe"].value as? String, "0")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["key-'"].exists)
        XCTAssertEqual(app.buttons["key-я"].frame.width, wider, accuracy: 1)
        app.buttons["key-Switch to English"].tap()
        XCTAssertFalse(app.buttons["key-'"].exists)
        tapMainButton("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["key-'"].exists)
        app.buttons["key-Switch to Українська"].tap()
    }

    @MainActor
    func testLandscapeLayout() throws {
        let app = launchApp(landscape: true)
        defer {
            XCUIDevice.shared.orientation = .portrait
            let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.frame.width < app.frame.height
            }, object: nil)
            _ = XCTWaiter.wait(for: [portrait], timeout: 5)
        }
        let key = app.buttons["key-є"]
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            if key.frame.midY > 50 && key.frame.midY < app.frame.height - 45 { break }
            let fromY = key.frame.midY < 50 ? 0.3 : 0.7
            let toY = key.frame.midY < 50 ? 0.6 : 0.4
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: fromY))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: toY)))
        }
        key.tap()
        XCTAssertEqual(app.textViews["preview-editor"].value as? String, "є")
    }
}
