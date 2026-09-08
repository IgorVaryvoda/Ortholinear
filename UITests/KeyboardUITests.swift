import XCTest

final class KeyboardUITests: XCTestCase {
    @MainActor
    func testAppearanceThemesAccentsAndPersistence() throws {
        let app = launchApp()
        tapMainButton("customize-keyboard", in: app)
        let themes = app.buttons["theme-settings"]
        XCTAssertTrue(themes.isHittable, "Themes should be visible as soon as settings opens")
        XCTAssertTrue(app.otherElements["settings-keyboard-preview"].waitForExistence(timeout: 5))
        let settingsScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settingsScreenshot.name = "Organized keyboard settings"
        settingsScreenshot.lifetime = .keepAlways
        add(settingsScreenshot)
        themes.tap()
        XCTAssertTrue(app.buttons["theme-system"].waitForExistence(timeout: 5))
        app.buttons["appearance-done"].tap()
        let yi = app.switches["yi-on-long-press"]
        revealSetting(yi, in: app)
        if yi.value as? String == "0" {
            yi.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -25, dy: 0)).tap()
        }
        app.buttons["choose-theme"].tap()
        let form = app.collectionViews["appearance-controls"]
        func reveal(_ element: XCUIElement, down fallback: Bool = true) {
            for _ in 0..<18 {
                let top = app.navigationBars["Make it yours"].frame.maxY + 10
                if element.exists && element.frame.minY > top && element.frame.maxY < form.frame.maxY - 10 { return }
                let down = element.exists ? element.frame.midY > (top + form.frame.maxY) / 2 : fallback
                form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.8 : 0.5))
                    .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.5 : 0.8)))
            }
            XCTFail("Appearance control is offscreen: \(element)")
        }
        let preview = app.otherElements.matching(identifier: "settings-keyboard-preview").firstMatch
        let hints = app.switches["show-long-press-hints"]
        reveal(hints)
        if hints.value as? String == "0" {
            hints.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -25, dy: 0)).tap()
        }
        reveal(app.buttons["theme-light"], down: false)
        for (id, title) in [("light", "Warm Light"), ("dark", "Soft Dark"), ("tokyoNight", "Tokyo Night"),
                            ("catppuccin", "Catppuccin Mocha"), ("nord", "Nord"), ("highContrast", "High Contrast")] {
            let theme = app.buttons["theme-\(id)"]
            reveal(theme, down: id != "highContrast")
            theme.tap()
            XCTAssertTrue((preview.value as? String ?? "").contains("theme \(title)"))
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Keyboard theme — \(title)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        reveal(app.buttons["theme-tokyoNight"])
        app.buttons["theme-tokyoNight"].tap()
        reveal(app.buttons["accent-rose"])
        app.buttons["accent-rose"].tap()
        XCTAssertTrue((preview.value as? String ?? "").contains("accent Rose"))
        reveal(hints)
        hints.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -25, dy: 0)).tap()
        XCTAssertEqual(hints.value as? String, "0")
        app.buttons["appearance-done"].tap()
        app.buttons["Done"].tap()
        app.terminate(); app.launch()
        tapMainButton("customize-keyboard", in: app)
        app.buttons["theme-settings"].tap()
        XCTAssertTrue((preview.value as? String ?? "").contains("theme Tokyo Night, accent Rose"))
        reveal(hints)
        XCTAssertEqual(hints.value as? String, "0")
        hints.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -25, dy: 0)).tap()
        reveal(app.buttons["accent-theme"], down: false)
        app.buttons["accent-theme"].tap()
        reveal(app.buttons["theme-system"], down: false)
        app.buttons["theme-system"].tap()
        app.buttons["appearance-done"].tap()
        revealSetting(app.buttons["preset-bigLetters"], in: app, scrollingDown: false)
        app.buttons["preset-bigLetters"].tap()
        app.buttons["Done"].tap()
    }

    @MainActor
    func testLiveSettingsPreviewTracksSpacingAndLanguage() throws {
        let app = launchApp()
        tapMainButton("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        let preview = app.otherElements["settings-keyboard-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        let originalFrame = preview.frame
        let rowSpacing = app.sliders["Row spacing"]
        revealSetting(app.sliders["Column spacing"], in: app)
        app.sliders["Column spacing"].adjust(toNormalizedSliderPosition: 0.85)
        revealSetting(rowSpacing, in: app)
        rowSpacing.adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertFalse((preview.value as? String ?? "").contains("column spacing 2,"))
        XCTAssertFalse((preview.value as? String ?? "").hasSuffix("row spacing 3"))
        XCTAssertEqual(preview.frame.maxY, originalFrame.maxY, accuracy: 1)
        XCTAssertTrue(app.frame.contains(preview.frame))
        let portrait = XCTAttachment(screenshot: app.screenshot())
        portrait.name = "Live spacing preview — portrait"
        portrait.lifetime = .keepAlways
        add(portrait)
        app.segmentedControls["preview-language"].buttons["EN"].tap()
        XCTAssertTrue((preview.value as? String ?? "").hasPrefix("EN"))
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        XCTAssertTrue(app.frame.contains(preview.frame))
        app.segmentedControls["preview-language"].buttons["UA"].tap()
        let horizontal = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        horizontal.name = "Live spacing preview — landscape"
        horizontal.lifetime = .keepAlways
        add(horizontal)
        XCUIDevice.shared.orientation = .portrait
        app.segmentedControls["preview-language"].buttons["EN"].tap()
        app.buttons["Done"].tap()
        tapMainButton("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        app.buttons["Done"].tap()
    }

    @MainActor
    func testOptionalYiLongPressPersistsAndCanBeDisabled() throws {
        let app = launchApp()
        tapMainButton("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        let toggle = app.switches["yi-on-long-press"]
        revealSetting(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25, dy: 0)).tap()
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["key-ї"].exists)
        let editor = app.textViews["preview-editor"]
        app.buttons["key-і"].tap()
        app.buttons["key-і"].press(forDuration: 0.6)
        app.buttons["key-Shift"].tap()
        app.buttons["key-І"].press(forDuration: 0.6)
        app.buttons["key-і"].tap()
        XCTAssertEqual(editor.value as? String, "іїЇі")
        let key = app.buttons["key-і"]
        let surface = app.otherElements["keyboard-surface"]
        key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).withOffset(CGVector(dx: 0, dy: 20)))
        XCTAssertEqual(editor.value as? String, "іїЇі")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["key-і"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["key-ї"].exists)
        tapMainButton("customize-keyboard", in: app)
        revealSetting(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25, dy: 0)).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["key-ї"].exists)
    }

    @MainActor
    func testDeleteAccelerationAndReleaseCancellation() throws {
        let app = launchApp()
        let editor = app.textViews["preview-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        for _ in 0..<50 { app.buttons["key-а"].tap() }
        let delete = app.buttons["key-Delete"]
        delete.press(forDuration: 1)
        let remaining = (editor.value as? String ?? "").count
        let shortDeleted = 50 - remaining
        XCTAssertGreaterThan(shortDeleted, 1)
        delete.press(forDuration: 3)
        let afterLong = (editor.value as? String ?? "").count
        XCTAssertGreaterThan(remaining - afterLong, shortDeleted * 3)
        XCTAssertGreaterThan(afterLong, 0)
        let released = editor.value as? String
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in editor.value as? String != released }, object: nil)
        changed.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 0.5), .completed)
        let surface = app.otherElements["keyboard-surface"]
        delete.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 1)).withOffset(CGVector(dx: 0, dy: 20)), withVelocity: .fast, thenHoldForDuration: 0.7)
        let afterSlide = editor.value as? String
        XCTAssertFalse(afterSlide?.isEmpty ?? true)
        let changedAfterSlide = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in editor.value as? String != afterSlide }, object: nil)
        changedAfterSlide.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [changedAfterSlide], timeout: 0.5), .completed)
        delete.tap()
        XCTAssertEqual((editor.value as? String ?? "").count, (afterSlide ?? "").count - 1)
    }

    @MainActor
    private func revealSetting(_ element: XCUIElement, in app: XCUIApplication, scrollingDown: Bool = true) {
        let form = app.collectionViews["geometry-controls"]
        for _ in 0..<16 {
            let top = max(form.frame.minY, app.navigationBars["Keyboard settings"].frame.maxY) + 20
            if element.exists && element.frame.midY > top && element.frame.midY < form.frame.maxY - 20 { return }
            let down = element.exists ? element.frame.midY > form.frame.midY : scrollingDown
            form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.8 : 0.5))
                .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.5 : 0.8)))
        }
        XCTFail("Could not scroll setting into view: \(element)")
    }

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
    func testSymbolSlideAndCancellation() throws {
        let app = launchApp()
        let editor = app.textViews["preview-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        app.buttons["key-Switch to English"].tap()
        let numbers = app.buttons["key-Numbers"]
        let origin = numbers.frame
        // Read coordinates from the real number layout before starting the gesture.
        numbers.tap()
        let one = app.buttons["key-1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).screenPoint
        let seven = app.buttons["key-7"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).screenPoint
        XCTAssertEqual(app.buttons["key-Letters"].frame.minX, origin.minX, accuracy: 1)
        app.buttons["key-More symbols"].tap()
        XCTAssertEqual(app.buttons["key-Letters"].frame.minX, origin.minX, accuracy: 1)
        app.buttons["key-Letters"].tap()
        numbers.press(forDuration: 0.6)
        XCTAssertTrue(numbers.exists)
        XCTAssertEqual(editor.value as? String, "")

        // Convert targets to app coordinates so they remain valid on the letter page.
        let first = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: one.x, dy: one.y))
        let last = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: seven.x, dy: seven.y))
        numbers.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: first)
        XCTAssertEqual(editor.value as? String, "1")
        XCTAssertTrue(numbers.exists)
        app.buttons["key-a"].tap()
        numbers.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: last)
        XCTAssertEqual(editor.value as? String, "1a7")
        XCTAssertTrue(numbers.exists)

        let outside = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: origin.midX, dy: origin.maxY + 25))
        numbers.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: outside)
        XCTAssertEqual(editor.value as? String, "1a7")
        XCTAssertTrue(numbers.exists)
        // A normal tap still latches numbers for typing several symbols.
        numbers.tap()
        app.buttons["key-1"].tap()
        app.buttons["key-2"].tap()
        XCTAssertTrue(app.buttons["key-Letters"].exists)
        XCTAssertEqual(editor.value as? String, "1a712")
    }

    @MainActor
    func testGeometryAndSetup() throws {
        let app = launchApp()
        tapMainButton("customize-keyboard", in: app)
        XCTAssertTrue(app.navigationBars["Keyboard settings"].waitForExistence(timeout: 5))
        app.buttons["preset-original"].tap()
        revealSetting(app.switches["show-punctuation"], in: app)
        XCTAssertEqual(app.switches["show-punctuation"].value as? String, "1")
        revealSetting(app.sliders["Key height"], in: app, scrollingDown: false)
        app.sliders["Key height"].adjust(toNormalizedSliderPosition: 0.7)
        revealSetting(app.buttons["preset-bigLetters"], in: app, scrollingDown: false)
        app.buttons["preset-bigLetters"].tap()
        revealSetting(app.switches["show-punctuation"], in: app)
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
        // SwiftUI may expose either the whole toggle row or just its switch.
        // A fixed inset from the trailing edge hits the thumb in both cases.
        app.switches["show-punctuation"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25, dy: 0)).tap()
        XCTAssertEqual(app.switches["show-punctuation"].value as? String, "1")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["key-."].exists)
        XCTAssertLessThan(app.buttons["key-я"].frame.width, wider)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["key-."].waitForExistence(timeout: 5))
        tapMainButton("customize-keyboard", in: app)
        app.buttons["preset-bigLetters"].tap()
        app.switches["show-apostrophe"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25, dy: 0)).tap()
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
