import XCTest
import CoreGraphics
@testable import OrtholinearCore

final class KeyboardCoreTests: XCTestCase {
    func testOptionalYiLongPressPreservesAlphabetAndWidensFirstRow() throws {
        let defaults = KeyboardPreferences()
        var preferences = defaults
        preferences.yiOnLongPress = true
        let rows = KeyboardLayout.rows(state: InputState(), needsGlobe: false, preferences: preferences)
        XCTAssertEqual(rows[0].count, 11)
        let keys = rows.flatMap { $0 }
        XCTAssertFalse(keys.contains { $0.action == .text("ї") })
        XCTAssertEqual(keys.first { $0.action == .text("і") }?.alternatives, ["ї"])
        let available = keys.flatMap { key -> [String] in
            if case .text(let value) = key.action { return [value] + key.alternatives }
            return []
        }
        XCTAssertEqual(Set(available), Set("абвгґдеєжзиіїйклмнопрстуфхцчшщьюя".map(String.init)))
        let normal = KeyboardGeometry.cells(width: 393, state: InputState(), preferences: defaults, needsGlobe: false)
        let compact = KeyboardGeometry.cells(width: 393, state: InputState(), preferences: preferences, needsGlobe: false)
        XCTAssertGreaterThan(compact[0].hitFrame.width, normal[0].hitFrame.width)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: JSONEncoder().encode(preferences)), preferences)
        XCTAssertFalse(try JSONDecoder().decode(KeyboardPreferences.self, from: Data(#"{"schemaVersion":2,"keyHeight":65}"#.utf8)).yiOnLongPress)
        var state = InputState()
        state.shift = .once
        XCTAssertEqual(state.consume("ї"), "Ї")
        XCTAssertEqual(state.shift, .off)
        state.language = .english
        XCTAssertEqual(KeyboardLayout.rows(state: state, needsGlobe: false, preferences: preferences).map { $0.map(\.action) },
                       KeyboardLayout.rows(state: state, needsGlobe: false, preferences: defaults).map { $0.map(\.action) })
    }

    func testDeleteRepeatAcceleratesAndCapsAtSafeInterval() {
        XCTAssertEqual(DeleteRepeat.initialDelay, 0.42)
        XCTAssertEqual(DeleteRepeat.interval(heldFor: 0), 0.12, accuracy: 0.001)
        var previous = DeleteRepeat.interval(heldFor: 0)
        for elapsed in stride(from: 0.5, through: 10.0, by: 0.1) {
            let interval = DeleteRepeat.interval(heldFor: elapsed)
            XCTAssertLessThanOrEqual(interval, previous)
            XCTAssertGreaterThanOrEqual(interval, 0.0249)
            previous = interval
        }
        XCTAssertLessThan(DeleteRepeat.interval(heldFor: 3), DeleteRepeat.interval(heldFor: 1))
        XCTAssertEqual(DeleteRepeat.interval(heldFor: 60), 0.025, accuracy: 0.001)
        XCTAssertEqual(DeleteRepeat.interval(heldFor: 0), 0.12, accuracy: 0.001, "A new hold starts slowly again")
    }

    func testDefaultUkrainianHasEveryLetterWithoutDotOrComma() {
        let rows = KeyboardLayout.rows(state: InputState(), needsGlobe: false).prefix(3)
        XCTAssertEqual(rows.map(\.count), [12, 11, 11])
        let letters = rows.flatMap { $0 }.compactMap { key -> String? in
            if case .text(let text) = key.action { return text }; return nil
        }
        let alphabet = Set("абвгґдеєжзиіїйклмнопрстуфхцчшщьюя".map(String.init))
        let alternatives = rows.flatMap { $0 }.flatMap(\.alternatives)
        XCTAssertTrue(alphabet.isSubset(of: Set(letters + alternatives)))
        XCTAssertFalse(letters.contains("ґ"))
        XCTAssertEqual(rows.flatMap { $0 }.first { $0.action == .text("г") }?.alternatives, ["ґ"])
        XCTAssertEqual(letters.count, Set(letters).count)
        XCTAssertFalse(letters.contains("'"))
        XCTAssertFalse(letters.contains("."))
        XCTAssertFalse(letters.contains(","))
    }

    func testOriginalPresetRowCounts() {
        let letters: [KeyboardLanguage: [Int]] = [.ukrainian: [12, 11, 12], .english: [10, 10, 11], .polish: [10, 9, 11],
                                                  .german: [11, 11, 11], .french: [10, 10, 11], .spanish: [10, 10, 11],
                                                  .czech: [10, 9, 11], .slovak: [10, 9, 11], .bcms: [12, 12, 11],
                                                  .serbianCyrillic: [12, 12, 9], .swedish: [11, 11, 11], .norwegian: [11, 11, 11],
                                                  .danish: [11, 11, 11], .dutch: [10, 9, 11], .russian: [11, 11, 12]]
        for language in KeyboardLanguage.allCases {
            for page in [KeyboardPage.letters, .numbers, .symbols] {
                var state = InputState(); state.language = language; state.page = page
                let rows = KeyboardLayout.rows(state: state, needsGlobe: true, preferences: KeyboardPreset.original.preferences)
                let expected = page == .letters ? letters[language]! : [10, 10, 10]
                XCTAssertEqual(rows.prefix(3).map(\.count), expected)
                XCTAssertTrue(rows.last!.contains { $0.action == .globe })
            }
        }
    }

    func testGapFillingCoversEntireGridAtPhoneAndTabletWidths() {
        for width in [320.0, 393, 430, 768, 1024] {
            for language in KeyboardLanguage.allCases {
                var state = InputState(); state.language = language
                let p = KeyboardPreferences(keyHeight: 36, columnSpacing: 8, rowSpacing: 12)
                let cells = KeyboardGeometry.cells(width: width, state: state, preferences: p, needsGlobe: true)
                for x in stride(from: 0.0, to: width, by: 1.3) {
                    for y in stride(from: p.headerHeight, to: p.keyboardHeight, by: 2.7) {
                        let point = CGPoint(x: x, y: y)
                        XCTAssertEqual(cells.filter { $0.hitFrame.contains(point) }.count, 1)
                    }
                }
                let firstRow = Array(cells.prefix(KeyboardLayout.rows(state: state, needsGlobe: true, preferences: p)[0].count))
                XCTAssertEqual(firstRow.first!.visualFrame.minX, 0)
                XCTAssertEqual(firstRow.last!.visualFrame.maxX, width, accuracy: 0.001)
                // Cell widths are equal; edge keys consume the outer half-gutter visually.
                for cell in firstRow { XCTAssertEqual(cell.hitFrame.width, firstRow[0].hitFrame.width, accuracy: 0.001) }
            }
        }
    }

    func testVisibleOnlyModeLeavesGapsAndNoTouchesOutside() {
        var p = KeyboardPreset.original.preferences
        p.fillGaps = false
        p.suggestionsEnabled = false
        let cells = KeyboardGeometry.cells(width: 360, state: InputState(), preferences: p, needsGlobe: false)
        XCTAssertNil(KeyboardGeometry.hit(at: CGPoint(x: 30, y: 60), cells: cells))
        XCTAssertNotNil(KeyboardGeometry.hit(at: CGPoint(x: 15, y: 60), cells: cells))
        XCTAssertNil(KeyboardGeometry.hit(at: CGPoint(x: -1, y: 60), cells: cells))
        XCTAssertNil(KeyboardGeometry.hit(at: CGPoint(x: 12, y: 10), cells: cells))
    }

    func testShiftConsumptionAndCapsLock() {
        var state = InputState()
        state.tapShift(at: 1)
        XCTAssertEqual(state.consume("ґ"), "Ґ")
        XCTAssertEqual(state.consume("ї"), "ї")
        state.tapShift(at: 2)
        state.tapShift(at: 2.15)
        XCTAssertEqual(state.shift, .locked)
        XCTAssertEqual(state.consume("і"), "І")
        XCTAssertEqual(state.consume("a"), "A")
        XCTAssertEqual(state.shift, .locked)
        state.tapShift(at: 3)
        XCTAssertEqual(state.shift, .off)
    }

    func testPunctuationDoesNotConsumeShiftOrCreateAccidentalCapsLock() {
        var state = InputState()
        state.tapShift(at: 1)
        XCTAssertEqual(state.consume("'"), "'")
        XCTAssertEqual(state.shift, .once)
        _ = state.consume("a")
        state.tapShift(at: 1.2)
        XCTAssertEqual(state.shift, .once)
    }

    func testPreferencesClampMalformedValues() throws {
        let p = KeyboardPreferences(keyHeight: -100, columnSpacing: 999, rowSpacing: .infinity).validated
        XCTAssertEqual(p.keyHeight, 36)
        XCTAssertEqual(p.columnSpacing, 8)
        XCTAssertEqual(p.rowSpacing, 3)
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: data), p)
    }

    func testRemovedPunctuationGivesWidthToRemainingLetters() {
        var p = KeyboardPreferences()
        let normal = KeyboardGeometry.cells(width: 360, state: InputState(), preferences: p, needsGlobe: false)
        XCTAssertEqual(normal.first { $0.key.action == .text("я") }!.hitFrame.width, 360 / 12.2, accuracy: 0.001)
        p.showApostrophe = false
        let lettersOnly = KeyboardGeometry.cells(width: 360, state: InputState(), preferences: p, needsGlobe: false)
        XCTAssertEqual(lettersOnly.first { $0.key.action == .text("я") }!.hitFrame.width, 360 / 12.2, accuracy: 0.001)
        p.showPunctuation = true
        p.showApostrophe = true
        let originalKeys = KeyboardGeometry.cells(width: 360, state: InputState(), preferences: p, needsGlobe: false)
        XCTAssertEqual(originalKeys.first { $0.key.action == .text("я") }!.hitFrame.width, 360 / 14.2, accuracy: 0.001)
    }

    func testPunctuationChoicesPreserveAllLettersInEveryLanguage() {
        for language in KeyboardLanguage.allCases {
            var state = InputState(); state.language = language
            for punctuation in [false, true] {
                for apostrophe in [false, true] {
                    let p = KeyboardPreferences(showPunctuation: punctuation, showApostrophe: apostrophe)
                    let rows = KeyboardLayout.rows(state: state, needsGlobe: false, preferences: p)
                    let values = rows.prefix(3).flatMap { $0 }.compactMap { key -> String? in
                        if case .text(let text) = key.action { return text }; return nil
                    }
                    let available = values + rows.prefix(3).flatMap { $0 }.flatMap(\.alternatives)
                    XCTAssertEqual(Set(available.filter { $0.lowercased() != $0.uppercased() }), Set(language.alphabet.map(String.init)))
                    XCTAssertEqual(values.contains("."), punctuation)
                    XCTAssertEqual(values.contains(","), punctuation)
                    XCTAssertEqual(values.contains("'"), language == .french || apostrophe && language == .english)
                    XCTAssertEqual(Set(values).count, values.count)
                }
            }
            state.page = .numbers
            let numbers = KeyboardLayout.rows(state: state, needsGlobe: false, preferences: .init(showApostrophe: false))
            for value in [".", ",", language == .ukrainian ? "ʼ" : "'", "?"] {
                XCTAssertTrue(numbers.flatMap { $0 }.contains { $0.action == .text(value) })
            }
        }
    }

    func testLetterAndControlSizesAreIndependentAndHeaderIsOptional() {
        var p = KeyboardPreferences()
        let originalHeight = p.keyboardHeight
        p.controlHeight += 10
        XCTAssertEqual(p.keyboardHeight, originalHeight + 10)
        var cells = KeyboardGeometry.cells(width: 390, state: InputState(), preferences: p, needsGlobe: false)
        XCTAssertEqual(cells[0].visualFrame.height, 72)
        XCTAssertEqual(cells.last!.visualFrame.height, 66)
        XCTAssertEqual(cells[0].hitFrame.minY, 44)
        XCTAssertEqual(cells.last!.hitFrame.maxY, p.keyboardHeight)
        p.showHeader = true
        cells = KeyboardGeometry.cells(width: 390, state: InputState(), preferences: p, needsGlobe: false)
        XCTAssertEqual(cells[0].hitFrame.minY, 82)
        XCTAssertEqual(p.keyboardHeight, originalHeight + 10 + 38)
        XCTAssertFalse(cells.contains { $0.key.action == .dismiss })
    }

    func testLegacySettingsMigrateWithoutDiscardingCustomizations() throws {
        let legacy = Data(#"{"keyHeight":48,"columnSpacing":6,"rowSpacing":7,"fillGaps":false,"defaultLanguage":"english"}"#.utf8)
        let p = try JSONDecoder().decode(KeyboardPreferences.self, from: legacy)
        XCTAssertEqual(p.keyHeight, 72)
        XCTAssertEqual(p.columnSpacing, 6)
        XCTAssertEqual(p.rowSpacing, 7)
        XCTAssertEqual(p.defaultLanguage, .english)
        XCTAssertFalse(p.fillGaps)
        XCTAssertFalse(p.showPunctuation)
        XCTAssertFalse(p.showHeader)
        let custom = try JSONDecoder().decode(KeyboardPreferences.self, from: Data(#"{"keyHeight":60}"#.utf8))
        XCTAssertEqual(custom.keyHeight, 60)
        let current = KeyboardPreset.original.preferences
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: JSONEncoder().encode(current)), current)
    }

    func testPresetsKeepLanguageAndNewSizesClamp() {
        var p = KeyboardPreferences(defaultLanguage: .english)
        p.apply(.original)
        XCTAssertEqual(p.defaultLanguage, .english)
        XCTAssertTrue(p.showPunctuation)
        p.apply(.bigLetters)
        XCTAssertEqual(p.defaultLanguage, .english)
        XCTAssertFalse(p.showPunctuation)
        p.keyHeight = 999
        p.controlHeight = -2
        p.letterSize = .nan
        XCTAssertEqual(p.validated.keyHeight, 88)
        XCTAssertEqual(p.validated.controlHeight, 36)
        XCTAssertEqual(p.validated.letterSize, 28)
    }

    func testPageSwitchIsAlwaysFarLeft() {
        for language in KeyboardLanguage.allCases {
            for page in [KeyboardPage.letters, .numbers, .symbols] {
                for placement in ShiftPlacement.allCases {
                    for globe in [false, true] {
                        var state = InputState()
                        state.language = language
                        state.page = page
                        let preferences = KeyboardPreferences(shiftPlacement: placement)
                        let rows = KeyboardLayout.rows(state: state, needsGlobe: globe, preferences: preferences)
                        XCTAssertEqual(rows[3].first?.action, .page)
                        XCTAssertEqual(rows.flatMap { $0 }.filter { $0.action == .page }.count, 1)
                        let cells = KeyboardGeometry.cells(width: 393, state: state, preferences: preferences, needsGlobe: globe)
                        let pageKey = cells.first { $0.key.action == .page }!
                        XCTAssertEqual(pageKey.hitFrame.minX, cells.map(\.hitFrame.minX).min())
                    }
                }
            }
        }
    }

    func testShiftIsImmediatelyBeforeZOrYaAndActionsAreLarge() {
        let bottom: [KeyboardLanguage: (first: String, last: String)] = [
            .ukrainian: ("я", "ю"), .english: ("z", "m"), .polish: ("z", "m"),
            .german: ("y", "m"), .french: ("w", "'"), .spanish: ("z", "m"),
            .czech: ("y", "m"), .slovak: ("y", "m"), .bcms: ("y", "m"), .serbianCyrillic: ("џ", "м"),
            .swedish: ("z", "m"), .norwegian: ("z", "m"), .danish: ("z", "m"), .dutch: ("z", "m"), .russian: ("я", "ю")
        ]
        for language in KeyboardLanguage.allCases {
            var state = InputState(); state.language = language
            let rows = KeyboardLayout.rows(state: state, needsGlobe: false)
            XCTAssertEqual(rows[2][0].action, .shift)
            XCTAssertEqual(rows[2][1].action, .text(bottom[language]!.first))
            XCTAssertFalse(rows[3].contains { $0.action == .shift })
            let cells = KeyboardGeometry.cells(width: 393, state: state, preferences: .init(), needsGlobe: false)
            let shift = cells.first { $0.key.action == .shift }!
            let letter = cells.first { $0.key.action == rows[2][1].action }!
            XCTAssertEqual(shift.hitFrame.minY, letter.hitFrame.minY)
            XCTAssertEqual(shift.hitFrame.maxX, letter.hitFrame.minX, accuracy: 0.001)
            for action in [KeyAction.enter, .backspace] {
                let cell = cells.first { $0.key.action == action }!
                XCTAssertGreaterThan(cell.visualFrame.width, 69)
                XCTAssertEqual(cell.visualFrame.height, action == .backspace ? 72 : 56)
            }
            let lastLetter = cells.first { $0.key.action == .text(bottom[language]!.last) }!
            let delete = cells.first { $0.key.action == .backspace }!
            XCTAssertEqual(delete.hitFrame.minY, lastLetter.hitFrame.minY)
            XCTAssertEqual(delete.hitFrame.minX, lastLetter.hitFrame.maxX, accuracy: 0.001)
            XCTAssertFalse(rows[3].contains { $0.action == .backspace })
            state.page = .numbers
            XCTAssertTrue(KeyboardLayout.rows(state: state, needsGlobe: false)[3].contains { $0.action == .shift })
            XCTAssertTrue(KeyboardLayout.rows(state: state, needsGlobe: false)[3].contains { $0.action == .backspace })
        }
    }

    private func letters(_ rows: [[Key]]) -> [String] {
        rows.prefix(3).flatMap { $0 }.compactMap { key -> String? in
            guard case .text(let text) = key.action, text.first?.isLetter == true else { return nil }
            return text
        }
    }

    func testEveryLanguageAndEnglishLayoutReachesItsWholeAlphabetOnce() {
        for language in KeyboardLanguage.allCases {
            for layout in EnglishLayout.allCases {
                for yi in [false, true] {
                    var state = InputState(); state.language = language
                    let p = KeyboardPreferences(yiOnLongPress: yi, englishLayout: layout)
                    let rows = KeyboardLayout.rows(state: state, needsGlobe: false, preferences: p)
                    let keys = letters(rows)
                    let held = rows.prefix(3).flatMap { $0 }.flatMap(\.alternatives).filter { $0.lowercased() != $0.uppercased() }
                    XCTAssertEqual(keys.count, Set(keys).count, "\(language) \(layout) repeats a letter")
                    XCTAssertEqual(Set(keys + held), Set(language.alphabet.map(String.init)), "\(language) \(layout)")
                }
            }
        }
    }

    func testEnglishLayoutsRearrangeOnlyEnglish() {
        var english = InputState(); english.language = .english
        var seen = Set<[String]>()
        for layout in EnglishLayout.allCases {
            let p = KeyboardPreferences(showApostrophe: false, englishLayout: layout)
            XCTAssertTrue(seen.insert(letters(KeyboardLayout.rows(state: english, needsGlobe: false, preferences: p))).inserted)
            XCTAssertEqual(KeyboardLayout.rows(state: InputState(), needsGlobe: false, preferences: p).map { $0.map(\.action) },
                           KeyboardLayout.rows(state: InputState(), needsGlobe: false).map { $0.map(\.action) })
        }
        let colemak = KeyboardLayout.rows(state: english, needsGlobe: false, preferences: .init(showApostrophe: false, englishLayout: .colemakDH))
        XCTAssertEqual(letters([colemak[1]]).joined(), "arstgmneio")
        XCTAssertEqual(letters([colemak[2]]).joined(), "zxcdvkh", "Colemak-DH uses the matrix bottom row")
        // Dvorak keeps ' , . together at the start of the top row.
        let dvorak = KeyboardLayout.rows(state: english, needsGlobe: false,
                                         preferences: .init(showPunctuation: true, englishLayout: .dvorak))
        XCTAssertEqual(dvorak[0].prefix(4).map(\.action), [.text("'"), .text(","), .text("."), .text("p")])
        XCTAssertEqual(dvorak[2].last?.action, .backspace)
        let geometry = SuggestionGeometry(language: .english, preferences: .init(englishLayout: .colemak), width: 393)
        XCTAssertLessThan(geometry.cost("n", "e"), SuggestionGeometry(language: .english, preferences: .init(), width: 393).cost("n", "e"),
                          "Suggestions measure distance on the chosen layout")
    }

    func testLanguageKeyCyclesThroughEnabledLanguagesInOrder() {
        let p = KeyboardPreferences(defaultLanguage: .spanish, languages: [.german, .ukrainian, .english, .german]).validated
        XCTAssertEqual(p.languages, [.ukrainian, .english, .german])
        XCTAssertEqual(p.defaultLanguage, .ukrainian, "A starting language that is off falls back to the first enabled")
        XCTAssertEqual(p.language(after: .ukrainian), .english)
        XCTAssertEqual(p.language(after: .english), .german)
        XCTAssertEqual(p.language(after: .german), .ukrainian)
        XCTAssertEqual(p.language(after: .french), .ukrainian)
        XCTAssertEqual(KeyboardPreferences(languages: []).validated.languages, [.ukrainian, .english])

        let single = KeyboardPreferences(defaultLanguage: .polish, languages: [.polish])
        var state = InputState(); state.language = .polish
        XCTAssertFalse(KeyboardLayout.rows(state: state, needsGlobe: false, preferences: single).flatMap { $0 }.contains { $0.action == .language },
                       "One language has nothing to switch to")
        state.language = .english
        XCTAssertTrue(KeyboardLayout.rows(state: state, needsGlobe: false, preferences: single).flatMap { $0 }.contains { $0.action == .language },
                      "An email field's English must have a way back")
        XCTAssertEqual(single.language(after: .english), .polish)
    }

    func testLanguageSettingsDecodeTolerantlyAndSurvivePresets() throws {
        let saved = Data(#"{"schemaVersion":3,"languages":["polish","klingon","english"],"englishLayout":"dvorak","defaultLanguage":"klingon","rememberLanguage":false}"#.utf8)
        let p = try JSONDecoder().decode(KeyboardPreferences.self, from: saved)
        XCTAssertEqual(p.languages, [.english, .polish])
        XCTAssertEqual(p.defaultLanguage, .english)
        XCTAssertEqual(p.englishLayout, .dvorak)
        XCTAssertFalse(p.rememberLanguage)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: JSONEncoder().encode(p)), p)
        let legacy = try JSONDecoder().decode(KeyboardPreferences.self, from: Data(#"{"schemaVersion":3,"keyHeight":60}"#.utf8))
        XCTAssertEqual(legacy.languages, [.ukrainian, .english])
        XCTAssertEqual(legacy.englishLayout, .qwerty)
        XCTAssertTrue(legacy.rememberLanguage)
        var custom = p
        custom.apply(.original)
        XCTAssertEqual(custom.languages, p.languages)
        XCTAssertEqual(custom.englishLayout, .dvorak)
        XCTAssertFalse(custom.rememberLanguage)
        custom.languageMemoryGeneration = 3
        custom.apply(.bigLetters)
        XCTAssertEqual(custom.languageMemoryGeneration, 3, "Presets don't make the keyboard forget")
        XCTAssertEqual(legacy.languageMemoryGeneration, 0)
    }

    func testHeldLettersTypeAccentsAndSharpSShiftsToOneCapital() {
        var state = InputState(); state.language = .polish
        let rows = KeyboardLayout.rows(state: state, needsGlobe: false)
        XCTAssertEqual(rows.flatMap { $0 }.first { $0.action == .text("z") }?.alternatives, ["ż", "ź"])
        state.language = .german
        XCTAssertEqual(KeyboardLayout.rows(state: state, needsGlobe: false).flatMap { $0 }.first { $0.action == .text("s") }?.alternatives, ["ß"])
        XCTAssertEqual(state.consume("ß"), "ß")
        state.tapShift(at: 1)
        XCTAssertEqual(state.consume("ß"), "ẞ")
        XCTAssertEqual(state.shift, .off)
        state.page = .numbers
        XCTAssertTrue(KeyboardLayout.rows(state: state, needsGlobe: false).flatMap { $0 }.allSatisfy { $0.letterAlternatives.isEmpty })
    }

    func testLanguageCodesMapToLayouts() {
        XCTAssertEqual(KeyboardLanguage(languageCode: "en-GB"), .english)
        XCTAssertEqual(KeyboardLanguage(languageCode: "uk"), .ukrainian)
        XCTAssertEqual(KeyboardLanguage(languageCode: "de_DE"), .german)
        XCTAssertEqual(KeyboardLanguage(languageCode: "FR-ca"), .french)
        XCTAssertEqual(KeyboardLanguage(languageCode: "sr-Cyrl"), .serbianCyrillic)
        XCTAssertNil(KeyboardLanguage(languageCode: "ja-JP"))
        XCTAssertNil(KeyboardLanguage(languageCode: ""))
        for language in KeyboardLanguage.allCases { XCTAssertEqual(KeyboardLanguage(languageCode: language.code), language) }
    }

    func testRussianIsOfferedOnlyToThoseWhoOpposeTheInvasion() throws {
        var p = KeyboardPreferences(defaultLanguage: .russian, languages: [.ukrainian, .russian])
        XCTAssertEqual(p.validated.languages, [.ukrainian])
        XCTAssertEqual(p.validated.defaultLanguage, .ukrainian)
        p.invasionAnswer = .supports
        XCTAssertEqual(p.validated.languages, [.ukrainian])
        XCTAssertEqual(p.language(after: .ukrainian), .ukrainian)
        p.invasionAnswer = .opposes
        XCTAssertEqual(p.validated.languages, [.ukrainian, .russian])
        XCTAssertEqual(p.validated.defaultLanguage, .russian)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: JSONEncoder().encode(p)), p)
        p.apply(.original)
        XCTAssertEqual(p.invasionAnswer, .opposes, "Presets keep the answer")
        let odd = try JSONDecoder().decode(KeyboardPreferences.self,
                                          from: Data(#"{"languages":["russian"],"invasionAnswer":"maybe"}"#.utf8))
        XCTAssertEqual(odd.invasionAnswer, .unanswered)
        XCTAssertEqual(odd.languages, [.ukrainian, .english], "Nothing left after the gate falls back to the defaults")
        var state = InputState(); state.language = .russian
        let keys = KeyboardLayout.rows(state: state, needsGlobe: false).flatMap { $0 }
        XCTAssertEqual(keys.first { $0.action == .text("е") }?.alternatives, ["ё"])
        XCTAssertEqual(keys.first { $0.action == .text("ь") }?.alternatives, ["ъ"])
    }

    func testDigitsFlickFromTheTopRowOrSitInANumberRow() throws {
        let ukrainian = KeyboardLayout.rows(state: InputState(), needsGlobe: false)
        XCTAssertEqual(ukrainian[0].prefix(10).map(\.flick), "1234567890".map { String($0) })
        XCTAssertNil(ukrainian[0][10].flick, "Only the first ten keys carry digits")
        XCTAssertTrue(ukrainian.dropFirst().joined().allSatisfy { $0.flick == nil })
        var off = KeyboardPreferences(); off.digitAccess = .off
        XCTAssertTrue(KeyboardLayout.rows(state: InputState(), needsGlobe: false, preferences: off).joined().allSatisfy { $0.flick == nil })
        var numbers = InputState(); numbers.page = .numbers
        XCTAssertTrue(KeyboardLayout.rows(state: numbers, needsGlobe: false).joined().allSatisfy { $0.flick == nil })

        var row = KeyboardPreferences(); row.digitAccess = .numberRow
        XCTAssertEqual(row.numberRowHeight, 43)
        XCTAssertEqual(row.keyboardHeight, KeyboardPreferences().keyboardHeight + 43 + 3)
        let rows = KeyboardLayout.rows(state: InputState(), needsGlobe: true, preferences: row)
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(rows[0].map(\.action), "1234567890".map { .text(String($0)) })
        XCTAssertTrue(rows.joined().allSatisfy { $0.flick == nil })
        XCTAssertTrue(rows[3].contains { $0.action == .backspace }, "Delete still follows the last letter")
        for page in [KeyboardPage.letters, .numbers, .symbols] {
            var state = InputState(); state.page = page
            let cells = KeyboardGeometry.cells(width: 393, state: state, preferences: row, needsGlobe: true)
            XCTAssertEqual(cells.first!.hitFrame.minY, row.headerHeight)
            XCTAssertEqual(cells.last!.hitFrame.maxY, row.keyboardHeight, accuracy: 0.001, "Every page fills the same height")
            for y in stride(from: row.headerHeight, to: row.keyboardHeight, by: 1.9) {
                XCTAssertEqual(cells.filter { $0.hitFrame.contains(CGPoint(x: 200, y: y)) }.count, 1)
            }
        }
        var preset = row
        preset.apply(.balanced)
        XCTAssertEqual(preset.digitAccess, .numberRow, "Presets keep typing choices")
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: JSONEncoder().encode(row)), row)
        let old = try JSONDecoder().decode(KeyboardPreferences.self, from: Data(#"{"schemaVersion":3,"digitAccess":"dial"}"#.utf8))
        XCTAssertEqual(old.digitAccess, .flick)
        XCTAssertTrue(old.autoCapitalize && old.doubleSpacePeriod && old.glideTyping)
    }

    func testUkrainianNumbersPageTypesTheModifierApostrophe() {
        var state = InputState(); state.page = .numbers
        let keys = KeyboardLayout.rows(state: state, needsGlobe: false).joined()
        XCTAssertEqual(keys.first { $0.action == .text("ʼ") }?.alternatives, ["ʼ", "'", "’", "\""])
        XCTAssertFalse(keys.contains { $0.action == .text("'") })
        state.language = .english
        XCTAssertTrue(KeyboardLayout.rows(state: state, needsGlobe: false).joined().contains { $0.action == .text("'") })
    }
}
