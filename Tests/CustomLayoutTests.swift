import XCTest
import CoreGraphics
@testable import OrtholinearCore

final class CustomLayoutTests: XCTestCase {
    private func texts(_ rows: [[Key]]) -> [[String]] {
        rows.map { row in row.map { key in
            if case .text(let value) = key.action { return value + "|" + key.alternatives.joined() }
            return "\(key.action)"
        } }
    }

    private func letters(_ layout: CustomLetterLayout) -> [String] {
        layout.rows.map { $0.map(\.output).joined() }
    }

    func testEveryBuiltInLayoutCopiesExactly() {
        for language in KeyboardLanguage.allCases {
            for englishLayout in language == .english ? EnglishLayout.allCases : [.qwerty] {
                for punctuation in [false, true] {
                    var preferences = KeyboardPreferences(showPunctuation: punctuation, englishLayout: englishLayout)
                    let builtIn = KeyboardLayout.rows(state: InputState(language: language), needsGlobe: true, preferences: preferences)
                    let copy = CustomLetterLayout(builtIn: language, preferences: preferences)
                    XCTAssertEqual(copy.problems(for: language), [], "\(language) \(englishLayout)")
                    preferences.customLayouts[language] = copy
                    // A copy must not change a single key, hold or width, whatever the punctuation setting later becomes.
                    preferences.showPunctuation.toggle()
                    let custom = KeyboardLayout.rows(state: InputState(language: language), needsGlobe: true, preferences: preferences)
                    XCTAssertEqual(texts(custom), texts(builtIn), "\(language) \(englishLayout)")
                    XCTAssertEqual(custom.map { $0.map(\.weight) }, builtIn.map { $0.map(\.weight) })
                }
            }
        }
    }

    func testCustomLayoutDrivesTouchSuggestionsAndGlide() throws {
        var layout = CustomLetterLayout(builtIn: .english)
        layout.rows[0][0] = CustomKey("z")
        layout.rows[2][0] = CustomKey("q")
        let preferences = KeyboardPreferences(customLayouts: [.english: layout])
        var state = InputState(language: .english)
        let cells = KeyboardGeometry.cells(width: 393, state: state, preferences: preferences, needsGlobe: false)
        let touched = try XCTUnwrap(KeyboardGeometry.hit(at: CGPoint(x: 5, y: preferences.headerHeight + 20), cells: cells))
        XCTAssertEqual(cells[touched].key.action, .text("z"))

        let custom = SuggestionGeometry(language: .english, preferences: preferences, width: 393)
        let builtIn = SuggestionGeometry(language: .english, preferences: .init(), width: 393)
        XCTAssertEqual(custom.centers["z"], builtIn.centers["q"])
        XCTAssertEqual(custom.centers["q"], builtIn.centers["z"])
        XCTAssertEqual(GlideDecoder.keyPath("zap", geometry: custom)?.first, builtIn.centers["q"])

        state.page = .numbers
        XCTAssertEqual(texts(KeyboardLayout.rows(state: state, needsGlobe: false, preferences: preferences)),
                       texts(KeyboardLayout.rows(state: state, needsGlobe: false)), "Other pages are unchanged")
    }

    func testGheWithItsOwnKeyIsNoLongerTreatedAsHeld() throws {
        let builtIn = SuggestionGeometry(language: .ukrainian, preferences: .init(), width: 393)
        XCTAssertEqual(builtIn.centers["ґ"], builtIn.centers["г"])
        XCTAssertTrue(builtIn.isAlternative("ґ"))
        XCTAssertFalse(builtIn.isAlternative("ї"))

        var layout = CustomLetterLayout(builtIn: .ukrainian)
        let row = try XCTUnwrap(layout.rows[0].firstIndex { $0.output == "г" })
        layout.rows[0][row].alternatives = []
        layout.rows[2].append(CustomKey("ґ"))
        XCTAssertEqual(layout.problems(for: .ukrainian), [])
        let custom = SuggestionGeometry(language: .ukrainian, preferences: KeyboardPreferences(customLayouts: [.ukrainian: layout]), width: 393)
        XCTAssertNotEqual(custom.centers["ґ"], custom.centers["г"])
        XCTAssertFalse(custom.isAlternative("ґ"))
        XCTAssertGreaterThan(try XCTUnwrap(custom.centers["ґ"]).y, try XCTUnwrap(custom.centers["г"]).y)

        let yi = SuggestionGeometry(language: .ukrainian, preferences: KeyboardPreferences(yiOnLongPress: true), width: 393)
        XCTAssertEqual(yi.centers["ї"], yi.centers["і"])
        XCTAssertTrue(yi.isAlternative("ї"))
    }

    func testProblemsAreReportedAndUnusableLayoutsFallBack() {
        var layout = CustomLetterLayout(builtIn: .english)
        layout.rows[1].removeAll { $0.output == "s" }
        layout.rows[0][0] = CustomKey("W")
        layout.rows[0][1] = CustomKey("ab", alternatives: Array(repeating: "x", count: 9))
        layout.rows[2][0] = CustomKey("x")
        let problems = layout.problems(for: .english)
        XCTAssertTrue(problems.contains(.missingLetters("qswz")))
        XCTAssertTrue(problems.contains(.notLowercase("W")))
        XCTAssertTrue(problems.contains(.notOneCharacter("ab")))
        XCTAssertTrue(problems.contains(.tooManyAlternatives("ab")))
        XCTAssertTrue(problems.contains(.duplicate("x")))
        XCTAssertEqual(CustomLetterLayout(rows: [[CustomKey("a")]]).problems(for: .english).first, .rowCount(1))
        XCTAssertTrue(CustomLetterLayout(rows: [Array(repeating: CustomKey("a"), count: 13), [], []])
            .problems(for: .english).contains(.rowLength(row: 1, count: 0)))

        let preferences = KeyboardPreferences(customLayouts: [.english: layout])
        let state = InputState(language: .english)
        XCTAssertEqual(texts(KeyboardLayout.rows(state: state, needsGlobe: false, preferences: preferences)),
                       texts(KeyboardLayout.rows(state: state, needsGlobe: false)))
    }

    func testPunctuationOnlyLastRowStillHasDelete() {
        var layout = CustomLetterLayout(builtIn: .english)
        layout.rows[0] += [CustomKey("z"), CustomKey("x")]
        layout.rows[1] += [CustomKey("c"), CustomKey("v")]
        for (letter, held) in [("g", "b"), ("h", "n"), ("j", "m")] {
            let index = layout.rows[1].firstIndex { $0.output == letter }!
            layout.rows[1][index].alternatives = [held]
        }
        layout.rows[2] = [CustomKey("."), CustomKey(",")]
        XCTAssertEqual(layout.problems(for: .english), [])
        let rows = KeyboardLayout.rows(state: InputState(language: .english), needsGlobe: false,
                                       preferences: KeyboardPreferences(customLayouts: [.english: layout]))
        XCTAssertEqual(rows[2].map(\.action), [.shift, .text("."), .text(","), .backspace])
    }

    func testCustomHoldsReplacePunctuationDefaultsOnlyWhenGiven() {
        XCTAssertEqual(Key(action: .text(".")).alternatives, [".", "…", "!", "?"])
        XCTAssertEqual(Key(action: .text("."), letterAlternatives: [".", "·"]).alternatives, [".", "·"])
        XCTAssertEqual(Key(action: .text("q")).alternatives, [])
    }

    func testLayoutsSurviveSavingPresetsAndDamage() throws {
        var preferences = KeyboardPreferences()
        var dvorak = CustomLetterLayout(builtIn: .english, preferences: KeyboardPreferences(englishLayout: .dvorak))
        dvorak.rows[0].swapAt(0, 1)
        preferences.customLayouts[.english] = dvorak
        let saved = try JSONEncoder().encode(preferences)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: saved), preferences)
        XCTAssertTrue(try XCTUnwrap(String(data: saved, encoding: .utf8)).contains(#""customLayouts":{"english":"#))

        preferences.apply(.original)
        XCTAssertEqual(preferences.customLayouts[.english], dvorak)

        let damaged = Data(#"""
        {"schemaVersion":4,"keyHeight":60,"customLayouts":{
          "english":{"rows":[[{"output":"q"}],[{"output":"a","alternatives":["á"]}],[{"output":"z"}]]},
          "klingon":{"rows":[]},
          "polish":{"rows":"broken"},
          "german":{"rows":[[{"alternatives":["x"]}]]}}}
        """#.utf8)
        let decoded = try JSONDecoder().decode(KeyboardPreferences.self, from: damaged)
        XCTAssertEqual(decoded.keyHeight, 60)
        XCTAssertEqual(Array(decoded.customLayouts.keys), [.english])
        XCTAssertEqual(decoded.customLayouts[.english]?.rows[1], [CustomKey("a", alternatives: ["á"])])
        // Kept, though it can't be used yet: it lacks most of the alphabet.
        XCTAssertFalse(try XCTUnwrap(decoded.customLayouts[.english]).isUsable(for: .english))

        let wrongType = try JSONDecoder().decode(KeyboardPreferences.self, from: Data(#"{"keyHeight":60,"customLayouts":[1,2]}"#.utf8))
        XCTAssertEqual(wrongType.keyHeight, 60)
        XCTAssertTrue(wrongType.customLayouts.isEmpty)
    }

    func testWorkshopEditsKeepRowsWithinBounds() {
        var layout = CustomLetterLayout(builtIn: .english)
        let q = KeyPosition(row: 0, column: 0)
        XCTAssertNil(layout.move(q, .left))
        XCTAssertNil(layout.move(q, .up))
        let right = layout.move(q, .right)
        XCTAssertEqual(right, KeyPosition(row: 0, column: 1))
        XCTAssertEqual(letters(layout)[0], "wqertyuiop")

        // Down moves into the same column of the next row, which grows by one.
        let down = layout.move(KeyPosition(row: 0, column: 9), .down)
        XCTAssertEqual(down, KeyPosition(row: 1, column: 9))
        XCTAssertEqual(letters(layout), ["wqertyuio", "asdfghjklp'", "zxcvbnm"])
        XCTAssertEqual(layout.move(KeyPosition(row: 1, column: 2), .down), KeyPosition(row: 2, column: 2))
        XCTAssertEqual(letters(layout)[2], "zxdcvbnm")

        layout.swapKeys(KeyPosition(row: 0, column: 0), KeyPosition(row: 2, column: 0))
        XCTAssertEqual(letters(layout).map { $0.prefix(1) }, ["z", "a", "w"])

        let added = layout.insertKey(after: KeyPosition(row: 2, column: 0))
        XCTAssertEqual(added, KeyPosition(row: 2, column: 1))
        XCTAssertTrue(layout.problems(for: .english).contains(.notOneCharacter("")))
        XCTAssertEqual(layout.removeKey(at: KeyPosition(row: 2, column: 1)), KeyPosition(row: 2, column: 1))

        var full = CustomLetterLayout(rows: [Array(repeating: CustomKey("a"), count: 12), [CustomKey("b")], [CustomKey("c")]])
        XCTAssertNil(full.insertKey(after: KeyPosition(row: 0, column: 3)))
        XCTAssertNil(full.move(KeyPosition(row: 1, column: 0), .up), "Row 0 is full")
        XCTAssertNil(full.move(KeyPosition(row: 1, column: 0), .down), "Row 1 would be empty")
        XCTAssertNil(full.removeKey(at: KeyPosition(row: 2, column: 0)))
        XCTAssertNil(full.move(KeyPosition(row: 5, column: 0), .right))

        XCTAssertEqual(CustomKey.characters(in: " é è é\u{301}ê "), ["é", "è", "é\u{301}", "ê"])
        XCTAssertEqual(CustomKey.characters(in: "ґґ"), ["ґ"])
    }

    func testLayoutFilesRoundTripAndRefuseWhatTheEditorCannotShow() throws {
        var layout = CustomLetterLayout(builtIn: .ukrainian)
        layout.rows[2].append(CustomKey("ʼ"))
        let file = LayoutFile(language: .ukrainian, layout: layout)
        let data = try file.data()
        XCTAssertEqual(try LayoutFile.read(data), file)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains(#""format" : "ortholinear-layout""#))
        XCTAssertFalse(text.contains("schemaVersion"), "Files carry only the layout")

        func error(_ json: String) -> LayoutFile.ReadError? {
            do { _ = try LayoutFile.read(Data(json.utf8)); return nil } catch { return error }
        }
        let rows = #"[[{"output":"q"}],[{"output":"a"}],[{"output":"z"}]]"#
        XCTAssertEqual(error(#"{"keyHeight":60}"#), .notALayout)
        XCTAssertEqual(error("not json"), .notALayout)
        XCTAssertEqual(error(#"{"format":"ortholinear-layout","version":2,"language":"english","layout":{"rows":\#(rows)}}"#), .newerVersion)
        XCTAssertEqual(error(#"{"format":"ortholinear-layout","version":1,"language":"klingon","layout":{"rows":\#(rows)}}"#), .unknownLanguage)
        XCTAssertEqual(error(#"{"format":"ortholinear-layout","version":1,"language":"english","layout":{"rows":[[{"output":"qq"}],[],[]]}}"#), .malformed)
        XCTAssertEqual(error(#"{"format":"ortholinear-layout","version":1,"language":"english","layout":{"rows":[]}}"#), .malformed)
        XCTAssertEqual(error(#"{"format":"ortholinear-layout","version":1,"language":"english"}"#), .malformed)
        XCTAssertEqual(error(#"{"format":"ortholinear-layout","version":1,"language":"english","pad":""# + String(repeating: " ", count: 70_000) + #""}"#), .tooLarge)

        // Missing letters are for the editor to point out, not a reason to refuse the file.
        let partial = try LayoutFile.read(Data(#"{"format":"ortholinear-layout","version":1,"language":"english","layout":{"rows":\#(rows)}}"#.utf8))
        XCTAssertFalse(partial.layout.isUsable(for: .english))
    }
}

private extension InputState {
    init(language: KeyboardLanguage) {
        self.init()
        self.language = language
    }
}
