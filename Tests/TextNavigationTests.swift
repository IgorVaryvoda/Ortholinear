import XCTest
@testable import OrtholinearCore

final class TextNavigationTests: XCTestCase {
    private func edit(_ command: KeyCommand, _ text: String) -> TextEdit? {
        let parts = text.components(separatedBy: "|")
        return TextNavigation.edit(for: command, before: parts[0], after: parts[1])
    }

    func testMovesByCharacterWordAndLine() {
        XCTAssertEqual(edit(.left, "ab|c"), .move(-1))
        XCTAssertEqual(edit(.left, "a👍🏽|c"), .move(-4), "One emoji with a skin tone is four UTF-16 units")
        XCTAssertEqual(edit(.right, "ab|ґc"), .move(1))
        XCTAssertNil(edit(.left, "|abc"))
        XCTAssertNil(edit(.right, "abc|"))

        XCTAssertEqual(edit(.wordLeft, "hello world|"), .move(-5))
        XCTAssertEqual(edit(.wordLeft, "hello world  |"), .move(-7), "Spaces, then the word")
        XCTAssertEqual(edit(.wordLeft, "it’s fine, ok|"), .move(-2))
        XCTAssertEqual(edit(.wordLeft, "it’s|"), .move(-4), "Apostrophes stay inside words")
        XCTAssertEqual(edit(.wordLeft, "call(arg|"), .move(-3))
        XCTAssertEqual(edit(.wordLeft, "call(|"), .move(-1), "A run of punctuation is its own stop")
        XCTAssertEqual(edit(.wordRight, "|привіт світ"), .move(6))
        XCTAssertEqual(edit(.wordRight, "| світ"), .move(5))
        XCTAssertEqual(edit(.wordLeft, "line one\n|"), .move(-1), "A line break is one stop")
        XCTAssertEqual(edit(.wordLeft, "one\n  |"), .move(-2))

        XCTAssertEqual(edit(.lineStart, "first\nsecond line|end"), .move(-11))
        XCTAssertEqual(edit(.lineEnd, "x|yz\nmore"), .move(2))
        XCTAssertNil(edit(.lineStart, "first\n|"))
        XCTAssertNil(edit(.lineEnd, "x|\nmore"))
    }

    func testDeletesWholeWordsAndLines() {
        XCTAssertEqual(edit(.deleteWord, "hello world|"), .deleteBackward(5))
        XCTAssertEqual(edit(.deleteWord, "hello world |"), .deleteBackward(6))
        XCTAssertEqual(edit(.deleteWord, "привіт 👍🏽|"), .deleteBackward(1), "Counted in characters, as deleteBackward removes them")
        XCTAssertEqual(edit(.deleteToLineStart, "a\nbc d|"), .deleteBackward(4))
        XCTAssertNil(edit(.deleteWord, "|text"))
    }

    func testLayerKeysBecomeCommandsPairsOrText() {
        XCTAssertEqual(CustomKey("", command: .wordLeft).layerKey.action, .command(.wordLeft))
        XCTAssertNil(CustomKey("", command: .wordLeft).layerKey.label, "Drawn as its symbol, announced by name")
        XCTAssertEqual(CustomKey("()", cursorBack: 1).layerKey.action, .pair("()", cursorBack: 1))
        XCTAssertEqual(CustomKey("π", alternatives: ["Π"]).layerKey.action, .text("π"))

        let fine = CustomLayer(name: "Nav", rows: [[CustomKey("", command: .left)], [CustomKey("<b></b>", cursorBack: 4)], [CustomKey("x")]])
        XCTAssertEqual(fine.problems, [], "A command key needs no text")
        let wrong = CustomLayer(name: "Nav", rows: [[CustomKey("")], [CustomKey("()", cursorBack: 3)], [CustomKey("x")]])
        XCTAssertEqual(wrong.problems, [.emptyKey, .cursorOutside("()")])

        let decoded = try? JSONDecoder().decode(CustomKey.self, from: Data(#"{"output":"","command":"teleport","cursorBack":-2}"#.utf8))
        XCTAssertNil(decoded?.command, "Unknown commands are dropped, not fatal")
        XCTAssertEqual(decoded?.cursorBack, 0)
    }
}
