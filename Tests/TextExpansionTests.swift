import XCTest
@testable import OrtholinearCore

final class TextExpansionTests: XCTestCase {
    private let expansions = [TextExpansion(";mail", "me@example.com"), TextExpansion(";m", "Maria"),
                              TextExpansion(";shrug", "¯\\_(ツ)_/¯"), TextExpansion("brb", "be right back")]

    func testShortcutsExpandWhenFinished() {
        var expander = TextExpander()
        XCTAssertEqual(expander.expand(before: "write to ;mail", trigger: " ", expansions: expansions),
                       .init(deleteCount: 5, insert: "me@example.com"))
        XCTAssertEqual(expander.expand(before: ";m", trigger: ".", expansions: expansions),
                       .init(deleteCount: 2, insert: "Maria"), "The longest match wins; ;m alone is its own")
        XCTAssertEqual(expander.expand(before: "Brb", trigger: "\n", expansions: expansions)?.insert, "be right back",
                       "An automatic capital still matches")
        XCTAssertEqual(expander.expand(before: "(;shrug", trigger: ")", expansions: expansions), nil, "Only listed triggers finish")
        XCTAssertEqual(expander.expand(before: "(;shrug", trigger: " ", expansions: expansions)?.insert, "¯\\_(ツ)_/¯")
        XCTAssertNil(expander.expand(before: "xbrb", trigger: " ", expansions: expansions), "Not inside a word")
        XCTAssertNil(expander.expand(before: "brb", trigger: "a", expansions: expansions))
        XCTAssertNil(expander.expand(before: "brb", trigger: " ", expansions: []))
        XCTAssertNil(expander.expand(before: "a b", trigger: " ", expansions: [TextExpansion("a b", "x"), TextExpansion("b", "x")]),
                     "Shortcuts with spaces or a single character are ignored")
    }

    func testDeleteRightAfterPutsTheShortcutBack() {
        var expander = TextExpander()
        _ = expander.expand(before: "hi ;Mail", trigger: " ", expansions: expansions)
        XCTAssertEqual(expander.revert(before: "hi me@example.com "), .init(deleteCount: 15, insert: ";Mail"))
        XCTAssertNil(expander.revert(before: "hi ;Mail"), "Only once")

        _ = expander.expand(before: "brb", trigger: " ", expansions: expansions)
        expander.forget()
        XCTAssertNil(expander.revert(before: "be right back "), "Anything in between ends it")

        _ = expander.expand(before: "brb", trigger: " ", expansions: expansions)
        XCTAssertNil(expander.revert(before: "be right back x"), "The text changed some other way")
    }

    func testSelectionIsNeverExpandedOrReverted() {
        var expander = TextExpander()
        XCTAssertNil(expander.expand(before: "brb", trigger: " ", expansions: expansions, selected: "XYZ"))
        XCTAssertNotNil(expander.expand(before: "brb", trigger: " ", expansions: expansions))
        XCTAssertNil(expander.revert(before: "be right back ", selected: "x"))
        XCTAssertNil(expander.revert(before: "be right back "), "The chance to revert is gone")
    }

    func testExpansionsSaveAndSurviveDamage() throws {
        var preferences = KeyboardPreferences()
        preferences.expansions = expansions
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: JSONEncoder().encode(preferences)), preferences)
        preferences.apply(.original)
        XCTAssertEqual(preferences.expansions, expansions)
        preferences.extrasEnabled = false
        XCTAssertEqual(preferences.shownExpansions, [])

        let json = #"{"keyHeight":60,"expansions":[{"abbreviation":"brb","expansion":"be right back"},{"abbreviation":7},"junk"]}"#
        let decoded = try JSONDecoder().decode(KeyboardPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.expansions.map(\.abbreviation), ["brb"])
        XCTAssertEqual(decoded.keyHeight, 60)
    }
}
