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

    func testDoubleSpaceTypesPeriodAfterAWordOnly() {
        func type(_ keys: [(String, TimeInterval)], initial: String, enabled: Bool = true, double: Bool = true) -> String {
            var spacing = PunctuationSpacing()
            var text = initial
            for (key, time) in keys {
                let edit = spacing.edit(for: key, before: text, enabled: enabled, doubleSpacePeriod: double, at: time)
                if edit.deleteBackward { text.removeLast() }
                text += edit.text
            }
            return text
        }
        XCTAssertEqual(type([(" ", 0), (" ", 0.3)], initial: "Привіт"), "Привіт. ")
        XCTAssertEqual(type([(" ", 0), (" ", 0.3), (" ", 0.5)], initial: "word"), "word. ", "A third Space is absorbed")
        XCTAssertEqual(type([(" ", 0), (" ", 0.3), ("!", 0.5)], initial: "word"), "word.! ", "Marks cluster, as after a typed period")
        XCTAssertEqual(type([(" ", 0), (" ", 0.3)], initial: "word", enabled: false), "word. ")
        XCTAssertEqual(type([(" ", 0), (" ", 2)], initial: "word"), "word  ", "Too slow")
        XCTAssertEqual(type([(" ", 0), (" ", 0.3)], initial: "word", double: false), "word  ")
        XCTAssertEqual(type([(" ", 0), (" ", 0.3)], initial: "word."), "word.  ", "Only after a word")
        XCTAssertEqual(type([(" ", 0), (" ", 0.3)], initial: ""), "  ")
        XCTAssertEqual(type([(" ", 0), (" ", 0.3)], initial: "at 5"), "at 5. ")
        var spacing = PunctuationSpacing()
        _ = spacing.edit(for: " ", before: "word", enabled: true, doubleSpacePeriod: true, at: 0)
        XCTAssertEqual(spacing.edit(for: " ", before: "other ", enabled: true, doubleSpacePeriod: true, at: 0.2), .init(text: " "),
                       "The cursor moved elsewhere")
    }

    func testMarksAttachToTheWordAnAcceptedSuggestionSpaced() {
        var spacing = PunctuationSpacing()
        spacing.adoptSpace(before: "Hello ")
        XCTAssertEqual(spacing.edit(for: ".", before: "Hello ", enabled: true), .init(deleteBackward: true, text: ". "))
        spacing.adoptSpace(before: "Hello ", at: 5)
        XCTAssertEqual(spacing.edit(for: " ", before: "Hello ", enabled: true, doubleSpacePeriod: true, at: 5.3),
                       .init(deleteBackward: true, text: ". "))
        spacing.adoptSpace(before: "Hello ")
        XCTAssertEqual(spacing.edit(for: "w", before: "Hello ", enabled: true), .init(text: "w"))
        spacing.adoptSpace(before: "Hello")
        XCTAssertEqual(spacing.edit(for: ".", before: "Hello", enabled: true), .init(text: ". "), "No space to adopt")
        spacing.adoptSpace(before: "Hello ")
        XCTAssertEqual(spacing.edit(for: ".", before: "Hello ", enabled: false), .init(text: "."), "Automatic spacing off")
    }

    func testAutomaticCapitalsFollowTheFieldTrait() {
        let sentences = AutoCapitalization.sentences
        for before in [nil, "", "Так. ", "Що?  ", "Ура! ", "Line\n", "One.\n  ", "“Так.” ", "(so.) ", "   "] as [String?] {
            XCTAssertTrue(sentences.shouldCapitalize(before: before), "\(before ?? "nil")")
        }
        for before in ["Так", "Так ", "e.g", "Wait… ", "a, ", "3.", "Hi.", "word: "] {
            XCTAssertFalse(sentences.shouldCapitalize(before: before), before)
        }
        XCTAssertTrue(AutoCapitalization.words.shouldCapitalize(before: "new "))
        XCTAssertFalse(AutoCapitalization.words.shouldCapitalize(before: "new"))
        XCTAssertTrue(AutoCapitalization.allCharacters.shouldCapitalize(before: "ABC"))
        XCTAssertFalse(AutoCapitalization.none.shouldCapitalize(before: ""))
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
