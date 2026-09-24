import UIKit

/// Apple's spell checker for layouts without a bundled dictionary. It works in a
/// keyboard without Full Access and stays on the device.
@MainActor
enum SystemSuggestions {
    private static let checker = UITextChecker()

    static func checkerLanguage(for language: KeyboardLanguage) -> String? {
        let available = UITextChecker.availableLanguages
        let code = language.code.replacingOccurrences(of: "-", with: "_")
        if available.contains(code) { return code }
        let prefix = String(code.prefix { $0 != "_" })
        return available.first { $0 == prefix || $0.hasPrefix(prefix + "_") }
    }

    static func suggest(target: SuggestionTarget, language: KeyboardLanguage, learned: [String],
                        geometry: SuggestionGeometry) -> [WordSuggestion] {
        let word = target.word
        guard !word.isEmpty, let code = checkerLanguage(for: language) else { return [] }
        let query = SuggestionText.normalize(word)
        let range = NSRange(location: 0, length: (word as NSString).length)
        let known = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: code).location == NSNotFound
            || learned.contains { SuggestionText.normalize($0) == query }
        let usable: (String) -> Bool = { candidate in
            let normalized = SuggestionText.normalize(candidate)
            return normalized != query && SuggestionText.isWord(candidate) && SuggestionText.belongs(candidate, to: language)
        }
        var results: [WordSuggestion] = []
        if !known || target.selected || target.rightCount > 0 {
            // Guesses come back in near-alphabetical order; nearby keys decide instead.
            let guesses = (checker.guesses(forWordRange: range, in: word, language: code) ?? []).filter(usable)
            let ranked = guesses.enumerated().sorted { a, b in
                let costA = SuggestionDistance.evaluate(query, SuggestionText.normalize(a.element), geometry: geometry)
                let costB = SuggestionDistance.evaluate(query, SuggestionText.normalize(b.element), geometry: geometry)
                return costA == costB ? a.offset < b.offset : costA < costB
            }
            results += ranked.prefix(known ? 3 : 2).map { .init(word: $0.element, kind: .correction) }
        }
        if !target.selected && target.rightCount == 0 {
            let taught = learned.filter { SuggestionText.normalize($0).hasPrefix(query) && usable($0) }
            let completions = (checker.completions(forPartialWordRange: range, in: word, language: code) ?? []).filter(usable)
            results += (taught + completions).map { .init(word: $0, kind: .completion) }
        }
        var seen = Set<String>()
        return results.filter { seen.insert(SuggestionText.normalize($0.word)).inserted }.prefix(3).map {
            // Keep the checker's own capitals, such as German nouns.
            .init(word: SuggestionText.cased($0.word, like: word, language: language), kind: $0.kind)
        }
    }
}
