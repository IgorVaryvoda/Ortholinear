import XCTest
@testable import OrtholinearCore

final class LanguageMemoryTests: XCTestCase {
    private let both: [KeyboardLanguage] = [.ukrainian, .english]
    private let message = LanguageContext(field: "0|0||2|0")
    private let search = LanguageContext(field: "0|6||2|0")
    private let email = LanguageContext(field: "7|0|emailAddress|0|1", requiresLatin: true)

    func testEachKindOfFieldKeepsItsLanguage() {
        var memory = LanguageMemory(startingLanguage: .ukrainian)
        memory.record(memory.resolve(message, enabled: both), in: message, chosen: false)
        XCTAssertEqual(memory.resolve(search, enabled: both), .ukrainian, "A new kind continues in the last language")
        memory.record(.english, in: search, chosen: true)
        XCTAssertEqual(memory.resolve(message, enabled: both), .ukrainian)
        XCTAssertEqual(memory.resolve(search, enabled: both), .english)
        XCTAssertEqual(memory.resolve(LanguageContext(field: "new"), enabled: both), .english)
        memory.adopt(startingLanguage: .ukrainian, generation: 0, enabled: both)
        XCTAssertEqual(memory.resolve(search, enabled: both), .english, "Reopening the keyboard keeps its memory")
        memory.adopt(startingLanguage: .english, generation: 0, enabled: both)
        XCTAssertEqual(memory.resolve(message, enabled: both), .english, "A new starting language applies at once")
        memory.record(.ukrainian, in: message, chosen: true)
        memory.adopt(startingLanguage: .english, generation: 0, enabled: [.english, .german])
        XCTAssertEqual(memory.resolve(message, enabled: [.english, .german]), .english,
                       "Turning off the language in use starts over")
    }

    func testMemorySurvivesUnloadingUntilForgotten() throws {
        var memory = LanguageMemory(startingLanguage: .ukrainian)
        memory.record(.english, in: search, chosen: true)
        memory.record(.ukrainian, in: email, chosen: true)
        var restored = try JSONDecoder().decode(LanguageMemory.self, from: JSONEncoder().encode(memory))
        XCTAssertEqual(restored, memory)
        restored.adopt(startingLanguage: .ukrainian, generation: 0, enabled: both)
        XCTAssertEqual(restored.resolve(search, enabled: both), .english)
        XCTAssertEqual(restored.resolve(email, enabled: both), .ukrainian)
        XCTAssertEqual(restored.resolve(message, enabled: both), .ukrainian, "Fallback is the last chosen language")
        restored.adopt(startingLanguage: .ukrainian, generation: 1, enabled: both)
        XCTAssertEqual(restored.resolve(search, enabled: both), .ukrainian, "Forgetting starts over")
        XCTAssertEqual(restored.resolve(email, enabled: both), .english)
        XCTAssertEqual(restored.generation, 1)
        let unknown = Data(#"{"startingLanguage":"klingon","generation":0,"fallback":"english","fields":[]}"#.utf8)
        XCTAssertNil(try? JSONDecoder().decode(LanguageMemory.self, from: unknown), "Unreadable memory is discarded")
    }

    func testEmailFieldsStartLatinWithoutLeakingAndKeepAChoice() {
        var memory = LanguageMemory(startingLanguage: .ukrainian)
        memory.record(.ukrainian, in: message, chosen: false)
        XCTAssertEqual(memory.resolve(email, enabled: both), .english)
        memory.record(.english, in: email, chosen: false)
        XCTAssertEqual(memory.resolve(LanguageContext(field: "new"), enabled: both), .ukrainian,
                       "A new ordinary field doesn't inherit an email field's English")
        memory.record(.ukrainian, in: email, chosen: true)
        XCTAssertEqual(memory.resolve(email, enabled: both), .ukrainian, "A choice made in an email field is kept there")
        XCTAssertEqual(memory.resolve(LanguageContext(requiresLatin: true), enabled: [.ukrainian, .german]), .german,
                       "Email fields keep the first enabled Latin layout")
        XCTAssertEqual(memory.resolve(LanguageContext(requiresLatin: true), enabled: [.ukrainian]), .english)
        memory.record(.german, in: message, chosen: true)
        XCTAssertEqual(memory.resolve(LanguageContext(field: "other", requiresLatin: true), enabled: [.ukrainian, .german]), .german,
                       "A Latin language already in use stays")
    }

    func testDisabledLanguagesAndHostHintsResolveSafely() {
        var memory = LanguageMemory(startingLanguage: .ukrainian)
        memory.record(.polish, in: message, chosen: true)
        XCTAssertEqual(memory.resolve(message, enabled: both, suggested: .english), .english,
                       "A disabled language is skipped, then the host's saved input mode applies")
        XCTAssertEqual(memory.resolve(message, enabled: both), .ukrainian)
        XCTAssertEqual(memory.resolve(message, enabled: [.ukrainian, .polish], suggested: .ukrainian), .polish,
                       "The keyboard's own record outranks the host hint")
    }

    func testMemoryIsBounded() {
        var memory = LanguageMemory(startingLanguage: .ukrainian)
        memory.record(.english, in: LanguageContext(field: "oldest"), chosen: true)
        for index in 0..<LanguageMemory.fieldLimit {
            memory.record(.ukrainian, in: LanguageContext(field: "\(index)"), chosen: true)
        }
        memory.fallback = .ukrainian
        XCTAssertEqual(memory.resolve(LanguageContext(field: "oldest"), enabled: both), .ukrainian)
        XCTAssertEqual(memory.resolve(LanguageContext(field: "0"), enabled: both), .ukrainian)
    }
}
