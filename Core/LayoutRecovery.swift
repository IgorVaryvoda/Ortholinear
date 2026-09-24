import Foundation
import CoreGraphics

/// Recovers a word typed with the other layout active, such as “ghbdsn” for “привіт”:
/// the same finger positions, read through the other language's keys.
enum LayoutRecovery {
    /// Each typed letter maps to the nearest keys of the other layout. A second
    /// key counts when it's nearly as close, which absorbs different column counts.
    static func candidates(_ word: String, from source: SuggestionGeometry, to target: SuggestionGeometry,
                           limit: Int = 64) -> [String] {
        let targets = target.centers.filter { !target.isAlternative($0.key) }
        var results = [""]
        for character in SuggestionText.normalize(word) {
            guard let point = source.centers[character] else { return [] }
            let ranked: [(Character, CGFloat)] = targets.map { key, center in
                (key, hypot(center.x - point.x, center.y - point.y))
            }.sorted { a, b in a.1 == b.1 ? a.0 < b.0 : a.1 < b.1 }
            guard let best = ranked.first else { return [] }
            var options = [best.0]
            if ranked.count > 1, ranked[1].1 <= best.1 * 1.35 + 2 { options.append(ranked[1].0) }
            results = results.flatMap { prefix in options.map { prefix + String($0) } }
            if results.count > limit { results = Array(results.prefix(limit)) }
        }
        return results
    }

    /// Rarer words match some mapping of ordinary typos far too often.
    static let minimumFrequency = 380

    /// The most frequent common candidate the other lexicon knows, if any. Callers should only
    /// ask for words the active lexicon can't complete, or half-typed words match by chance.
    static func recover(_ word: String, from source: SuggestionGeometry, to target: SuggestionGeometry,
                        lexicon: SuggestionLexicon) -> String? {
        guard word.count >= 4 else { return nil }
        var best: (word: String, frequency: Int)?
        for candidate in candidates(word, from: source, to: target) {
            guard let frequency = lexicon.frequency(of: candidate), frequency >= minimumFrequency else { continue }
            if best == nil || frequency > best!.frequency { best = (candidate, frequency) }
        }
        return best?.word
    }
}

extension SuggestionGeometry {
    /// ґ and a long-press ї share their base key's center; they are never the nearest key.
    func isAlternative(_ character: Character) -> Bool {
        character == "ґ" || (character == "ї" && centers["ї"] == centers["і"])
    }
}

extension SuggestionLexicon {
    func frequency(of word: String) -> Int? {
        var low = 0, high = words.count
        while low < high {
            let mid = (low + high) / 2
            if words[mid].word < word { low = mid + 1 } else { high = mid }
        }
        return low < words.count && words[low].word == word ? words[low].frequency : nil
    }
}
