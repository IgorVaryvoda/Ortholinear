import XCTest

final class KeyboardUITests: XCTestCase {
    @MainActor
    func testSuggestionOnlyTypingTeachingAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-suggestion-ui-tests", "-no-auto-capitals", "-no-keyboard-tips"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        app.buttons["clear-preview"].tap()
        if app.buttons["key-Switch to English"].exists { app.buttons["key-Switch to English"].tap() }
        let editor = app.textViews["preview-editor"]
        func type(_ word: String) { for letter in word { app.buttons["key-\(letter)"].tap() } }
        func suggestion(_ word: String) -> XCUIElement { app.buttons.matching(NSPredicate(format: "label == %@", "Use \(word)")).firstMatch }
        type("teh")
        XCTAssertTrue(suggestion("the").waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["key-Space"].tap()
        XCTAssertEqual(editor.value as? String, "teh ", "Space must never accept a correction")
        app.buttons["clear-preview"].tap()
        type("teh")
        XCTAssertTrue(suggestion("the").waitForExistence(timeout: 5))
        suggestion("the").tap()
        XCTAssertEqual(editor.value as? String, "the")
        app.buttons["clear-preview"].tap()
        type("hellp")
        app.buttons["key-Space"].tap()
        type("world")
        editor.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 35, dy: 26)).doubleTap()
        XCTAssertTrue(suggestion("hello").waitForExistence(timeout: 5), app.debugDescription)
        suggestion("hello").tap()
        XCTAssertEqual(editor.value as? String, "hello world", "Fix the selected earlier word without changing the rest")
        app.buttons["clear-preview"].tap()
        type("zorblify")
        app.buttons["suggestion-options"].tap()
        let teach = app.buttons["Teach “zorblify”"]
        if teach.waitForExistence(timeout: 2) { teach.tap() }
        else { app.buttons["Forget “zorblify”"].tap(); app.buttons["suggestion-options"].tap(); teach.tap() }
        app.terminate(); app.launch()
        if app.buttons["key-Switch to English"].exists { app.buttons["key-Switch to English"].tap() }
        type("zorblif")
        XCTAssertTrue(suggestion("zorblify").waitForExistence(timeout: 5), "Taught words must persist")
        suggestion("zorblify").tap()
        XCTAssertEqual(editor.value as? String, "zorblify ")
        app.buttons["key-Delete"].tap()
        app.buttons["suggestion-options"].tap()
        XCTAssertTrue(app.buttons["Forget “zorblify”"].waitForExistence(timeout: 3))
        app.buttons["Forget “zorblify”"].tap()
        app.buttons["clear-preview"].tap()
        type("zorblif")
        XCTAssertFalse(suggestion("zorblify").waitForExistence(timeout: 1))
        app.buttons["clear-preview"].tap()
        app.buttons["key-Switch to Українська"].tap()
        type("привт")
        XCTAssertTrue(suggestion("привіт").waitForExistence(timeout: 5), app.debugDescription)
        suggestion("привіт").tap()
        XCTAssertEqual(editor.value as? String, "привіт")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Tap-only Ukrainian suggestions"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        tapMainButton("customize-keyboard", in: app)
        XCTAssertTrue(app.buttons["suggestion-settings"].waitForExistence(timeout: 3))
        app.buttons["suggestion-settings"].tap()
        let enabled = app.switches["word-suggestions"]
        XCTAssertTrue(enabled.waitForExistence(timeout: 3))
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -25, dy: 0)).tap()
        XCTAssertEqual(enabled.value as? String, "0")
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -25, dy: 0)).tap()
        XCTAssertEqual(enabled.value as? String, "1")
    }


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
                let top = app.navigationBars["Theme and colors"].frame.maxY + 10
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
        applyBigLetters(in: app)
        app.buttons["Done"].tap()
    }

    @MainActor
    func testLiveSettingsPreviewTracksSpacingAndLanguage() throws {
        let app = launchApp()
        tapMainButton("customize-keyboard", in: app)
        applyBigLetters(in: app)
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
        applyBigLetters(in: app)
        app.buttons["Done"].tap()
    }

    @MainActor
    func testOptionalYiLongPressPersistsAndCanBeDisabled() throws {
        let app = launchApp()
        tapMainButton("customize-keyboard", in: app)
        applyBigLetters(in: app)
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
        for attempt in 0..<32 {
            let top = max(form.frame.minY, app.navigationBars["Keyboard settings"].frame.maxY) + 20
            if element.exists && element.frame.midY > top && element.frame.midY < form.frame.maxY - 20 { return }
            // An unloaded row may be either way, even from the top: try the other way halfway.
            let down = element.exists ? element.frame.midY > form.frame.midY : scrollingDown == (attempt < 16)
            form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.8 : 0.5))
                .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.5 : 0.8)))
        }
        XCTFail("Could not scroll setting into view: \(element)")
    }

    @MainActor
    func testRussianNeedsAnAnswerAgainstTheInvasion() throws {
        let app = launchApp()
        func resetAndOpenLanguages() {
            let reset = app.buttons["Reset to defaults"]
            revealSetting(reset, in: app)
            reset.tap()
            let row = app.buttons["language-settings"]
            revealSetting(row, in: app, scrollingDown: false)
            row.tap()
            XCTAssertTrue(app.collectionViews["language-controls"].waitForExistence(timeout: 3))
        }
        func back() { app.navigationBars["Languages"].buttons.firstMatch.tap() }
        tapMainButton("customize-keyboard", in: app)
        resetAndOpenLanguages()
        let supports = app.buttons["invasion-supports"]
        revealLanguageSetting(supports, in: app)
        supports.tap()
        XCTAssertTrue(app.staticTexts["Russian isn’t available."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.switches["language-russian"].exists)
        back()
        resetAndOpenLanguages()
        let opposes = app.buttons["invasion-opposes"]
        revealLanguageSetting(opposes, in: app)
        opposes.tap()
        let russian = app.switches["language-russian"]
        XCTAssertTrue(russian.waitForExistence(timeout: 3))
        XCTAssertEqual(russian.value as? String, "0")
        russian.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -25, dy: 0)).tap()
        XCTAssertEqual(russian.value as? String, "1")
        back()
        app.buttons["Done"].tap()

        let editor = app.textViews["preview-editor"]
        app.buttons["clear-preview"].tap()
        app.buttons["key-Switch to English"].tap()
        app.buttons["key-Switch to Русский"].tap()
        // Reset to defaults turned automatic capitals back on, so the empty field starts with Shift.
        XCTAssertTrue(app.buttons["key-Ы"].exists)
        app.buttons["key-Е"].press(forDuration: 0.6)
        XCTAssertEqual(editor.value as? String, "Ё")
        app.buttons["key-Switch to Українська"].tap()
        app.buttons["clear-preview"].tap()

        // Other tests expect the default Ukrainian and English cycle.
        tapMainButton("customize-keyboard", in: app)
        let reset = app.buttons["Reset to defaults"]
        revealSetting(reset, in: app)
        reset.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["key-Switch to English"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func revealLanguageSetting(_ element: XCUIElement, in app: XCUIApplication) {
        let form = app.collectionViews["language-controls"]
        for attempt in 0..<24 {
            let top = app.navigationBars["Languages"].frame.maxY + 20
            if element.exists && element.isHittable && element.frame.midY > top && element.frame.midY < form.frame.maxY - 20 { return }
            let down = element.exists ? element.frame.midY > form.frame.midY : attempt < 12
            form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.8 : 0.5))
                .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.5 : 0.8)))
        }
        XCTFail("Could not scroll language setting into view: \(element)")
    }

    /// Languages sit above the presets, which can start below the fold.
    @MainActor
    private func applyBigLetters(in app: XCUIApplication) {
        let preset = app.buttons["preset-bigLetters"]
        revealSetting(preset, in: app)
        preset.tap()
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
    private func launchApp(landscape: Bool = false, arguments: [String] = ["-no-auto-capitals", "-no-keyboard-tips"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            landscape ? app.frame.width > app.frame.height : app.frame.width < app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 5), .completed)
        return app
    }

    @MainActor
    func testLanguageSettingsAddLayoutsToTheLanguageKey() throws {
        let app = launchApp()
        func openLanguages() {
            tapMainButton("customize-keyboard", in: app)
            let row = app.buttons["language-settings"]
            revealSetting(row, in: app)
            row.tap()
            XCTAssertTrue(app.switches["language-polish"].waitForExistence(timeout: 3))
        }
        func toggle(_ identifier: String) {
            app.switches[identifier].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                .withOffset(CGVector(dx: -25, dy: 0)).tap()
        }
        func chooseEnglishLayout(_ title: String) {
            revealLanguageSetting(app.buttons["english-layout"], in: app)
            app.buttons["english-layout"].tap()
            let option = app.buttons[title].firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 3), app.debugDescription)
            option.tap()
        }
        openLanguages()
        XCTAssertEqual(app.switches["language-polish"].value as? String, "0")
        toggle("language-polish")
        XCTAssertEqual(app.switches["language-polish"].value as? String, "1")
        chooseEnglishLayout("Colemak")
        app.navigationBars["Languages"].buttons.firstMatch.tap()
        XCTAssertTrue(app.segmentedControls["preview-language"].buttons["PL"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        let editor = app.textViews["preview-editor"]
        app.buttons["clear-preview"].tap()
        app.buttons["key-Switch to English"].tap()
        XCTAssertEqual(app.buttons["key-f"].frame.minY, app.buttons["key-q"].frame.minY, accuracy: 1, "Colemak puts f on the top row")
        app.buttons["key-Switch to Polski"].tap()
        app.buttons["key-z"].press(forDuration: 0.6)
        app.buttons["key-a"].tap()
        XCTAssertEqual(editor.value as? String, "ża")
        // Apple's spell checker covers Polish; the row never just says there's nothing.
        XCTAssertFalse(app.staticTexts["No word suggestions for Polski"].exists)
        let offer = app.buttons["suggestion-0"], period = app.buttons["strip-0"]
        XCTAssertTrue(offer.waitForExistence(timeout: 3) || period.waitForExistence(timeout: 1), app.debugDescription)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Polish layout in the preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["key-Switch to Українська"].tap()
        app.buttons["clear-preview"].tap()

        // Other tests expect the default Ukrainian and English cycle.
        openLanguages()
        toggle("language-polish")
        XCTAssertEqual(app.switches["language-polish"].value as? String, "0")
        chooseEnglishLayout("QWERTY")
        app.navigationBars["Languages"].buttons.firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["key-Switch to English"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSentenceCapitalsPunctuationRowAndDigitFlicks() throws {
        let app = launchApp(arguments: ["-auto-capitals", "-no-keyboard-tips"])
        let editor = app.textViews["preview-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        app.buttons["clear-preview"].tap()
        if app.buttons["key-Switch to English"].exists { app.buttons["key-Switch to English"].tap() }
        XCTAssertTrue(app.buttons["key-H"].waitForExistence(timeout: 3), "An empty field starts with a capital")
        app.buttons["key-H"].tap()
        app.buttons["key-i"].tap()
        app.buttons["key-Space"].doubleTap()
        XCTAssertEqual(editor.value as? String, "Hi. ", "Two Spaces end the sentence")
        XCTAssertTrue(app.buttons["key-S"].waitForExistence(timeout: 2), "The next sentence starts with a capital")
        for letter in ["S", "e", "e"] { app.buttons["key-\(letter)"].tap() }
        let period = app.buttons["strip-0"]
        let use = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Use ")).firstMatch
        XCTAssertTrue(use.waitForExistence(timeout: 5), app.debugDescription)
        use.tap()
        XCTAssertTrue(period.waitForExistence(timeout: 3), "Punctuation fills the row between words")
        XCTAssertEqual(period.label, "Period")
        period.tap()
        let text = try XCTUnwrap(editor.value as? String)
        XCTAssertTrue(text.hasPrefix("Hi. See") && text.hasSuffix(". "), text)
        XCTAssertFalse(text.contains(" ."), "The period attaches to the word: \(text)")

        let q = app.buttons["key-Q"]
        XCTAssertTrue(q.waitForExistence(timeout: 2))
        q.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.05, thenDragTo: q.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).withOffset(CGVector(dx: 0, dy: 40)))
        XCTAssertEqual(editor.value as? String, text + "1", "A downward flick on q types 1")
        XCTAssertEqual(app.descendants(matching: .any)["try-flick"].value as? String, "Done")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Capitals, punctuation row and digit flick"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testGlideTypingTypesAWholeWord() throws {
        let app = launchApp()
        let editor = app.textViews["preview-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        app.buttons["clear-preview"].tap()
        if app.buttons["key-Switch to English"].exists { app.buttons["key-Switch to English"].tap() }
        // w → e → t is one straight stroke along the top row.
        let w = app.buttons["key-w"], t = app.buttons["key-t"]
        w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: t.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: 300, thenHoldForDuration: 0.05)
        let glided = NSPredicate { _, _ in
            guard let value = editor.value as? String else { return false }
            return value.count > 2 && value.hasPrefix("w") && value.hasSuffix("t")
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: glided, object: nil)], timeout: 5), .completed,
                       "Glide typed \(editor.value ?? "nothing")")
        XCTAssertEqual(app.descendants(matching: .any)["try-glide"].value as? String, "Done")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Glide typing"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
        revealSetting(app.buttons["preset-original"], in: app)
        app.buttons["preset-original"].tap()
        revealSetting(app.switches["show-punctuation"], in: app)
        XCTAssertEqual(app.switches["show-punctuation"].value as? String, "1")
        revealSetting(app.sliders["Key height"], in: app, scrollingDown: false)
        app.sliders["Key height"].adjust(toNormalizedSliderPosition: 0.7)
        revealSetting(app.buttons["preset-bigLetters"], in: app, scrollingDown: false)
        applyBigLetters(in: app)
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
        // Alternatives draw along the top of the keyboard, over the suggestion row.
        let top = app.otherElements["keyboard-surface"].frame.minY
        let target = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: (first.minX + last.maxX) / 2 - 26, dy: top + 19))
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
        applyBigLetters(in: app)
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
        revealSetting(app.switches["show-punctuation"], in: app)
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
        applyBigLetters(in: app)
        revealSetting(app.switches["show-apostrophe"], in: app)
        app.switches["show-apostrophe"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25, dy: 0)).tap()
        XCTAssertEqual(app.switches["show-apostrophe"].value as? String, "0")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["key-'"].exists)
        XCTAssertEqual(app.buttons["key-я"].frame.width, wider, accuracy: 1)
        app.buttons["key-Switch to English"].tap()
        XCTAssertFalse(app.buttons["key-'"].exists)
        tapMainButton("customize-keyboard", in: app)
        applyBigLetters(in: app)
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
