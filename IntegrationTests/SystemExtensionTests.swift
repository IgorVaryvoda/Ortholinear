import XCTest

/// Run separately on a disposable simulator; enables Ortholinear in iOS Settings.
final class SystemExtensionTests: XCTestCase {
    /// Uses the already enabled extension; safe to run on the paired iPhone too.
    @MainActor
    func testInstalledSuggestionsAreTapOnly() throws {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        tapOnMainPage("system-test", in: app)
        let editor = app.textViews["system-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        let surface = app.otherElements["system-keyboard-surface"]
        if !surface.waitForExistence(timeout: 2) {
            let globe = app.buttons["Next keyboard"]
            XCTAssertTrue(globe.waitForExistence(timeout: 3), app.debugDescription)
            globe.press(forDuration: 1)
            let option = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ortholinear'")).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 3), app.debugDescription)
            option.tap()
        }
        XCTAssertTrue(surface.waitForExistence(timeout: 8), app.debugDescription)
        if surface.buttons["key-Switch to English"].exists { surface.buttons["key-Switch to English"].tap() }
        func type(_ word: String) { for letter in word { surface.buttons["key-\(letter)"].tap() } }
        func suggestion(_ word: String) -> XCUIElement { surface.buttons.matching(NSPredicate(format: "label == %@", "Use \(word)")).firstMatch }
        type("teh")
        XCTAssertTrue(suggestion("the").waitForExistence(timeout: 5), app.debugDescription)
        surface.buttons["key-Space"].tap()
        XCTAssertEqual(editor.value as? String, "teh ")
        surface.buttons["key-Delete"].press(forDuration: 1)
        XCTAssertEqual(editor.value as? String ?? "", "")
        type("teh")
        XCTAssertTrue(suggestion("the").waitForExistence(timeout: 5))
        let cursor = surface.buttons["key-Space"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        cursor.press(forDuration: 0.1, thenDragTo: cursor.withOffset(CGVector(dx: -15, dy: 0)))
        XCTAssertTrue(suggestion("the").waitForExistence(timeout: 5))
        suggestion("the").tap()
        XCTAssertEqual(editor.value as? String, "the")
        surface.buttons["key-Delete"].press(forDuration: 1)
        surface.buttons["key-Switch to Українська"].tap()
        type("привт")
        XCTAssertTrue(suggestion("привіт").waitForExistence(timeout: 5))
        suggestion("привіт").tap()
        XCTAssertEqual(editor.value as? String, "привіт")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        print("DEVICE_SUGGESTION_METRICS \(surface.otherElements["suggestion-bar"].value ?? "unavailable")")
        screenshot.name = "Installed suggestion-only keyboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        surface.buttons["key-Delete"].press(forDuration: 1)
        type("зорбліф")
        surface.buttons["suggestion-options"].tap()
        let teach = app.buttons["Teach “зорбліф”"]
        XCTAssertTrue(teach.waitForExistence(timeout: 3), app.debugDescription)
        teach.tap()
        app.buttons["Done"].tap()
        tapOnMainPage("system-test", in: app)
        editor.tap()
        if surface.buttons["key-Switch to Українська"].exists { surface.buttons["key-Switch to Українська"].tap() }
        type("зорблі")
        XCTAssertTrue(suggestion("зорбліф").waitForExistence(timeout: 5))
        suggestion("зорбліф").tap()
        surface.buttons["key-Delete"].tap()
        surface.buttons["suggestion-options"].tap()
        app.buttons["Forget “зорбліф”"].tap()
        app.buttons["Done"].tap()
    }


    /// Runs after testInstalledExtensionTypesInHostField has enabled the extension.
    @MainActor
    func testInstalledKeyboardRemembersLanguagePerKindOfField() throws {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        // The memory persists across runs; start from the starting language.
        forgetRememberedLanguages(in: app)
        tapOnMainPage("system-test", in: app)
        let surface = app.otherElements["system-keyboard-surface"]
        let editor = app.textViews["system-editor"]
        let email = app.textFields["email-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        func dismissKeyboard() {
            surface.buttons["suggestion-options"].tap()
            app.buttons["Dismiss keyboard"].tap()
            XCTAssertTrue(surface.waitForNonExistence(timeout: 3))
        }
        func focus(_ field: XCUIElement) {
            // A field under the keyboard would pass the tap to a key instead.
            if surface.exists, !field.isHittable || field.frame.maxY > surface.frame.minY { dismissKeyboard() }
            field.tap()
            XCTAssertTrue(surface.waitForExistence(timeout: 8), app.debugDescription)
        }
        func expect(_ language: String, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
            let next = surface.buttons[language == "EN" ? "key-Switch to Українська" : "key-Switch to English"]
            XCTAssertTrue(next.waitForExistence(timeout: 3), "\(message): expected \(language)", file: file, line: line)
        }
        func choose(_ language: String) {
            surface.buttons[language == "EN" ? "key-Switch to English" : "key-Switch to Українська"].tap()
            expect(language, "Language key")
        }
        editor.tap()
        if !surface.waitForExistence(timeout: 2) {
            app.buttons["Next keyboard"].press(forDuration: 1)
            let option = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ortholinear'")).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 3), app.debugDescription)
            option.tap()
        }
        XCTAssertTrue(surface.waitForExistence(timeout: 8), app.debugDescription)
        if surface.buttons["key-Switch to Українська"].exists { choose("UA") }

        focus(email)
        expect("EN", "Email starts in English")
        focus(editor)
        expect("UA", "Email's English must not leak into the editor")
        choose("EN")
        focus(email)
        expect("EN", "Email")
        choose("UA")
        focus(editor)
        expect("EN", "The editor keeps the language chosen in it")
        focus(email)
        expect("UA", "The email field keeps the language chosen in it")
        dismissKeyboard()
        focus(editor)
        expect("EN", "Reopening the keyboard keeps the editor's language")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Language remembered per kind of field"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        choose("UA")
        app.buttons["Done"].tap()
    }

    @MainActor
    private func forgetRememberedLanguages(in app: XCUIApplication) {
        func scroll(to element: XCUIElement, in form: XCUIElement) {
            for _ in 0..<30 where !(element.exists && element.isHittable && element.frame.maxY < form.frame.maxY - 10) {
                form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.8))
                    .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)))
            }
            element.tap()
        }
        tapOnMainPage("customize-keyboard", in: app)
        scroll(to: app.buttons["language-settings"], in: app.collectionViews["geometry-controls"])
        let languages = app.collectionViews["language-controls"]
        XCTAssertTrue(languages.waitForExistence(timeout: 3), app.debugDescription)
        scroll(to: app.buttons["forget-languages"], in: languages)
        app.navigationBars["Languages"].buttons.firstMatch.tap()
        app.buttons["Done"].tap()
    }

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
        let form = app.collectionViews["geometry-controls"]
        func reveal(_ element: XCUIElement, down fallback: Bool = true) {
            for _ in 0..<30 {
                let top = app.navigationBars["Keyboard settings"].frame.maxY + 10
                if element.exists && element.frame.minY > top && element.frame.maxY < form.frame.maxY - 10 { return }
                let down = element.exists ? element.frame.midY > (top + form.frame.maxY) / 2 : fallback
                form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.8 : 0.5))
                    .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.5 : 0.8)))
            }
            XCTFail("Setting is offscreen: \(element)")
        }
        let yi = app.switches["yi-on-long-press"]
        reveal(yi)
        yi.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25, dy: 0)).tap()
        let keyHeight = app.sliders["Key height"]
        reveal(keyHeight, down: false)
        keyHeight.adjust(toNormalizedSliderPosition: 1)
        app.buttons["choose-theme"].tap()
        app.buttons["theme-tokyoNight"].tap()
        app.buttons["appearance-done"].tap()
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
        if !editor.waitForExistence(timeout: 5) {
            // The first tap can finish scrolling after returning from Settings.
            tapOnMainPage("system-test", in: app)
        }
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
        XCTAssertTrue((surface.value as? String ?? "").contains("Tokyo Night"), "The extension must load the saved theme")
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
        surface.buttons["key-Switch to Українська"].tap()
        XCTAssertFalse(surface.buttons["key-ї"].exists)
        surface.buttons["key-і"].press(forDuration: 0.6)
        surface.buttons["key-Shift"].tap()
        surface.buttons["key-І"].press(forDuration: 0.6)
        XCTAssertEqual(editor.value as? String, "фігґҐг1aїЇ")
        surface.buttons["key-Delete"].press(forDuration: 2)
        XCTAssertEqual(editor.value as? String ?? "", "")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Installed keyboard extension"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Verify the host remains responsive after held Delete reaches empty text.
        surface.buttons["key-а"].tap()
        XCTAssertEqual(editor.value as? String, "а")
        app.buttons["Done"].tap()
        XCTAssertFalse(editor.exists)
        // This disposable simulator retains the enabled keyboard and test preferences.
    }
}
