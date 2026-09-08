import XCTest
@testable import OrtholinearCore

final class SuggestionTests: XCTestCase {
    private let document = UUID()
    private func snapshot(_ before: String, after: String = "", selected: String = "", language: KeyboardLanguage = .english) -> SuggestionSnapshot {
        .init(document: document, before: before, after: after, selection: selected, language: language)
    }
    func testTargetsAndSafeEdits() throws {
        let middle = snapshot("say he", after: "llo, friend")
        XCTAssertEqual(middle.target?.word, "hello")
        XCTAssertEqual(middle.target?.rightCount, 3)
        let correction = WordSuggestion(word: "help", kind: .correction)
        let edit = try XCTUnwrap(SuggestionEdit.make(suggestion: correction, offered: middle, current: middle))
        XCTAssertEqual(edit.moveRight, 3)
        XCTAssertEqual(edit.deleteCount, 5)
        XCTAssertEqual(edit.text, "help")
        XCTAssertNil(SuggestionEdit.make(suggestion: correction, offered: middle, current: snapshot("say hel", after: "lo, friend")))
        var otherDocument = middle; otherDocument.document = UUID()
        XCTAssertNil(SuggestionEdit.make(suggestion: correction, offered: middle, current: otherDocument))
        let selected = snapshot("say ", after: "!", selected: "hellp")
        let selectionEdit = try XCTUnwrap(SuggestionEdit.make(suggestion: correction, offered: selected, current: selected))
        XCTAssertTrue(selectionEdit.replaceSelection)
        XCTAssertEqual(selectionEdit.deleteCount, 0)
        XCTAssertEqual(selectionEdit.text, "help")
        XCTAssertNil(snapshot("a", after: "z", selected: "word").target)
        XCTAssertNil(snapshot("", selected: "two words").target)
        XCTAssertNil(snapshot("hello@example").target)
        XCTAssertNil(snapshot("https://example").target)
        XCTAssertNil(snapshot("example.cmo").target)
        XCTAssertNil(snapshot("mail@", after: ".com", selected: "example").target)
        XCTAssertNil(snapshot("abc123").target)
        XCTAssertNil(snapshot(String(repeating: "a", count: 25)).target)
    }
    func testSpacesAndPunctuationStayExplicit() throws {
        let typo = snapshot("teh", after: ".")
        let correction = WordSuggestion(word: "the", kind: .correction)
        XCTAssertEqual(SuggestionEdit.make(suggestion: correction, offered: typo, current: typo)?.text, "the")
        let prefix = snapshot("hel")
        let completion = WordSuggestion(word: "hello", kind: .completion)
        XCTAssertEqual(SuggestionEdit.make(suggestion: completion, offered: prefix, current: prefix)?.text, "hello ")
        let next = snapshot("see you ")
        let predicted = WordSuggestion(word: "soon", kind: .nextWord)
        XCTAssertEqual(SuggestionEdit.make(suggestion: predicted, offered: next, current: next)?.deleteCount, 0)
        XCTAssertEqual(SuggestionEdit.make(suggestion: predicted, offered: next, current: next)?.text, "soon ")
        XCTAssertNil(SuggestionEdit.make(suggestion: predicted, offered: typo, current: typo))
        XCTAssertNil(SuggestionEdit.make(suggestion: correction, offered: next, current: next))
    }
    func testNormalizationDoesNotEraseUkrainianLettersOrCase() {
        XCTAssertNotEqual(SuggestionText.normalize("ї"), SuggestionText.normalize("і"))
        XCTAssertNotEqual(SuggestionText.normalize("ґ"), SuggestionText.normalize("г"))
        XCTAssertEqual(SuggestionText.normalize("ПАМ’ЯТЬ"), "пам'ять")
        XCTAssertEqual(SuggestionText.cased("привіт", like: "ПРИВТ", language: .ukrainian), "ПРИВІТ")
        XCTAssertEqual(SuggestionText.cased("hello", like: "Helo", language: .english), "Hello")
        XCTAssertEqual(SuggestionText.cased("пам'ять", like: "пам’ять", language: .ukrainian), "пам’ять")
        XCTAssertFalse(SuggestionText.belongs("привiт", to: .ukrainian))
        XCTAssertEqual(SuggestionText.context("This ends. Next sentence "), ["next", "sentence"])
        XCTAssertEqual(SuggestionText.context("What? "), [])
    }
    func testDistanceAndGeometry() {
        XCTAssertEqual(SuggestionDistance.evaluate("teh", "the", geometry: nil), 1)
        XCTAssertEqual(SuggestionDistance.evaluate("helllo", "hello", geometry: nil), 1)
        XCTAssertEqual(SuggestionDistance.evaluate("привт", "привіт", geometry: nil), 1)
        let geometry = SuggestionGeometry(language: .english, preferences: .init(), width: 393)
        XCTAssertLessThan(geometry.cost("s", "d"), geometry.cost("s", "p"))
        XCTAssertFalse(SuggestionHash.variants("teh").isDisjoint(with: SuggestionHash.variants("the")))
    }
    func testSettingsMigrateAndPresetsPreserveSuggestionChoices() throws {
        var preferences = try JSONDecoder().decode(KeyboardPreferences.self, from: Data("{}".utf8))
        XCTAssertTrue(preferences.suggestionsEnabled)
        let height = preferences.keyboardHeight
        preferences.suggestionsEnabled = false
        preferences.nextWordSuggestions = false
        preferences.contextualSuggestions = false
        XCTAssertEqual(height - preferences.keyboardHeight, 44)
        preferences.apply(.balanced)
        XCTAssertFalse(preferences.suggestionsEnabled)
        XCTAssertFalse(preferences.nextWordSuggestions)
        XCTAssertFalse(preferences.contextualSuggestions)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: JSONEncoder().encode(preferences)), preferences)
    }
    func testBundledSuggestionsAndTaughtWords() throws {
        for (language, typo, expected) in [(KeyboardLanguage.english, "teh", "the"), (.ukrainian, "привт", "привіт")] {
            let engine = try SuggestionResources.engine(language: language)
            let target = try XCTUnwrap(snapshot(typo, language: language).target)
            let result = engine.suggest(target: target, language: language, learned: [], geometry: nil, nextWords: true, useContext: true)
            XCTAssertTrue(result.contains { SuggestionText.normalize($0.word) == expected }, "\(typo): \(result)")
        }
        let engine = try SuggestionResources.engine(language: .english)
        let target = try XCTUnwrap(snapshot("zorbli").target)
        XCTAssertTrue(engine.suggest(target: target, language: .english, learned: ["zorblify"], geometry: nil, nextWords: true, useContext: false).contains { $0.word == "zorblify" })
        let known = try XCTUnwrap(snapshot("shit").target)
        XCTAssertFalse(engine.suggest(target: known, language: .english, learned: [], geometry: nil, nextWords: true, useContext: true).contains { $0.kind == .correction })
        let next = try XCTUnwrap(snapshot("thank you ").target)
        XCTAssertTrue(engine.suggest(target: next, language: .english, learned: [], geometry: nil, nextWords: false, useContext: true).isEmpty)
    }
    func testCorrectionBenchmark() throws {
        let cases: [(KeyboardLanguage, [(String, String)])] = [
            (.english, [("teh","the"),("hellp","hello"),("worls","world"),("keybaord","keyboard"),("thnaks","thanks"),
                        ("pleasr","please"),("tomorow","tomorrow"),("becuase","because"),("freind","friend"),("mesage","message"),
                        ("sugestions","suggestions"),("qucik","quick"),("peopel","people"),("typign","typing"),("beutiful","beautiful")]),
            (.ukrainian, [("привт","привіт"),("дякуб","дякую"),("будласка","будь ласка"),("сьогдні","сьогодні"),("заврта","завтра"),
                         ("повідомленя","повідомлення"),("клавіатра","клавіатура"),("украінська","українська"),("друез","друже"),("гарнго","гарного"),
                         ("робта","робота"),("людни","людини"),("прекрсно","прекрасно"),("зрозумло","зрозуміло"),("питаня","питання")])
        ]
        // Diagnostic sample, not a representative population or a tuned acceptance gate.
        for (language, pairs) in cases {
            let start = ContinuousClock.now
            let engine = try SuggestionResources.engine(language: language)
            let load = start.duration(to: .now)
            var timings: [Double] = [], plainHits = 0, rankedHits = 0
            let geometry = SuggestionGeometry(language: language, preferences: .init(), width: 393)
            for (typo, expected) in pairs {
                let target = try XCTUnwrap(snapshot(typo, language: language).target)
                let plain = engine.suggest(target: target, language: language, learned: [], geometry: nil, nextWords: true, useContext: false)
                plainHits += plain.contains { SuggestionText.normalize($0.word) == expected } ? 1 : 0
                let began = Date.timeIntervalSinceReferenceDate
                let ranked = engine.suggest(target: target, language: language, learned: [], geometry: geometry, nextWords: true, useContext: true)
                timings.append((Date.timeIntervalSinceReferenceDate - began) * 1000)
                rankedHits += ranked.contains { SuggestionText.normalize($0.word) == expected } ? 1 : 0
                print("SUGGESTION_CASE \(language.badge) \(typo) → \(ranked.map(\.word).joined(separator: ", "))")
            }
            timings.sort()
            print("SUGGESTION_BENCHMARK \(language.badge) load=\(load) baseline=\(plainHits)/\(pairs.count) geometry=\(rankedHits)/\(pairs.count) p50_ms=\(timings[timings.count/2]) p95_ms=\(timings[Int(Double(timings.count-1)*0.95)])")
        }
    }
}
