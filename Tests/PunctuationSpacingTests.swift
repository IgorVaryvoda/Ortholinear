import XCTest
@testable import OrtholinearCore

final class PunctuationSpacingTests: XCTestCase {
    private func type(_ keys: [String], initial: String = "", enabled: Bool = true) -> String {
        var spacing = PunctuationSpacing()
        var text = initial
        for key in keys {
            let edit = spacing.edit(for: key, before: text, enabled: enabled)
            if edit.deleteBackward { text.removeLast() }
            text += edit.text
        }
        return text
    }

    func testSentencesAndExplicitSpaceDoNotDoubleSpace() {
        XCTAssertEqual(type([",", " ", "світ", "!"], initial: "Привіт"), "Привіт, світ! ")
        for mark in [".", ",", "!", "?", ":", ";", "…"] {
            XCTAssertEqual(type([mark, "next"], initial: "word"), "word" + mark + " next")
        }
        XCTAssertEqual(type(["'", "t"], initial: "don"), "don't")
        XCTAssertEqual(type([".", "next"], initial: "word", enabled: false), "word.next")
    }

    func testPunctuationClustersNumbersAndNewlines() {
        XCTAssertEqual(type(["?", "!"], initial: "What"), "What?! ")
        XCTAssertEqual(type([".", ".", "."], initial: "Wait"), "Wait... ")
        XCTAssertEqual(type([".", "1", "4"], initial: "3"), "3.14")
        XCTAssertEqual(type([":", "3", "0"], initial: "12"), "12:30")
        XCTAssertEqual(type([",", " ", "2"], initial: "1"), "1, 2")
        XCTAssertEqual(type([".", "\n"], initial: "Done"), "Done.\n")
    }

    func testCursorChangesAndDisabledSettingPreserveUnrelatedSpaces() {
        var spacing = PunctuationSpacing()
        _ = spacing.edit(for: ".", before: "Hello", enabled: true)
        XCTAssertEqual(spacing.edit(for: "!", before: "Other ", enabled: true), .init(text: "! "))
        spacing.reset()
        XCTAssertEqual(spacing.edit(for: " ", before: "Other ! ", enabled: true), .init(text: " "))
        _ = spacing.edit(for: ".", before: "Hello", enabled: true)
        XCTAssertEqual(spacing.edit(for: "!", before: "Hello. ", enabled: false), .init(text: "!"))
    }
}
