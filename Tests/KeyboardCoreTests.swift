import XCTest
import CoreGraphics
@testable import OrtholinearCore

final class KeyboardCoreTests: XCTestCase {
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
        XCTAssertEqual(Key(action: .text("г")).alternatives, ["ґ"])
        XCTAssertEqual(letters.count, Set(letters).count)
        XCTAssertFalse(letters.contains("'"))
        XCTAssertFalse(letters.contains("."))
        XCTAssertFalse(letters.contains(","))
    }

    func testOriginalPresetRowCounts() {
        for language in KeyboardLanguage.allCases {
            for page in [KeyboardPage.letters, .numbers, .symbols] {
                var state = InputState(); state.language = language; state.page = page
                let rows = KeyboardLayout.rows(state: state, needsGlobe: true, preferences: KeyboardPreset.original.preferences)
                let expected = page == .letters ? (language == .ukrainian ? [12, 11, 12] : [10, 10, 11]) : [10, 10, 10]
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
                let firstRow = Array(cells.prefix(language == .ukrainian ? 12 : 10))
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

    func testPunctuationChoicesPreserveAllLettersInBothLanguages() {
        for language in KeyboardLanguage.allCases {
            var state = InputState(); state.language = language
            for punctuation in [false, true] {
                for apostrophe in [false, true] {
                    let p = KeyboardPreferences(showPunctuation: punctuation, showApostrophe: apostrophe)
                    let rows = KeyboardLayout.rows(state: state, needsGlobe: false, preferences: p)
                    let values = rows.prefix(3).flatMap { $0 }.compactMap { key -> String? in
                        if case .text(let text) = key.action { return text }; return nil
                    }
                    let alphabet = language == .ukrainian ? "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя" : "abcdefghijklmnopqrstuvwxyz"
                    let available = values + rows.prefix(3).flatMap { $0 }.flatMap(\.alternatives)
                    XCTAssertEqual(Set(available.filter { $0.lowercased() != $0.uppercased() }), Set(alphabet.map(String.init)))
                    XCTAssertEqual(values.contains("."), punctuation)
                    XCTAssertEqual(values.contains(","), punctuation)
                    XCTAssertEqual(values.contains("'"), apostrophe && language == .english)
                    XCTAssertEqual(Set(values).count, values.count)
                }
            }
            state.page = .numbers
            let numbers = KeyboardLayout.rows(state: state, needsGlobe: false, preferences: .init(showApostrophe: false))
            for value in [".", ",", "'", "?"] {
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
        XCTAssertEqual(cells[0].hitFrame.minY, 0)
        XCTAssertEqual(cells.last!.hitFrame.maxY, p.keyboardHeight)
        p.showHeader = true
        cells = KeyboardGeometry.cells(width: 390, state: InputState(), preferences: p, needsGlobe: false)
        XCTAssertEqual(cells[0].hitFrame.minY, 38)
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
        for language in KeyboardLanguage.allCases {
            var state = InputState(); state.language = language
            let rows = KeyboardLayout.rows(state: state, needsGlobe: false)
            XCTAssertEqual(rows[2][0].action, .shift)
            XCTAssertEqual(rows[2][1].action, .text(language == .english ? "z" : "я"))
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
            let lastLetter = cells.first { $0.key.action == .text(language == .english ? "m" : "ю") }!
            let delete = cells.first { $0.key.action == .backspace }!
            XCTAssertEqual(delete.hitFrame.minY, lastLetter.hitFrame.minY)
            XCTAssertEqual(delete.hitFrame.minX, lastLetter.hitFrame.maxX, accuracy: 0.001)
            XCTAssertFalse(rows[3].contains { $0.action == .backspace })
            state.page = .numbers
            XCTAssertTrue(KeyboardLayout.rows(state: state, needsGlobe: false)[3].contains { $0.action == .shift })
            XCTAssertTrue(KeyboardLayout.rows(state: state, needsGlobe: false)[3].contains { $0.action == .backspace })
        }
    }
}
