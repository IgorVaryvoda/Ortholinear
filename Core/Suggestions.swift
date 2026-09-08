import Foundation

/// Immutable context: a suggestion is only an offer tied to this exact snapshot.
struct SuggestionSnapshot: Equatable, Sendable {
    var document: UUID
    var before: String
    var after: String
    var selection: String
    var language: KeyboardLanguage

    var target: SuggestionTarget? {
        let leftToken = String(before.reversed().prefix { !$0.isWhitespace }.reversed())
        let rightToken = String(after.prefix { !$0.isWhitespace })
        let token = leftToken + selection + rightToken
        guard !token.contains("@"), !token.contains("/"), !token.contains("\\"),
              !token.hasPrefix("#"), !token.contains(where: \.isNumber),
              token.range(of: #"[\p{L}\p{N}]\.[\p{L}\p{N}]"#, options: .regularExpression) == nil else { return nil }
        if !selection.isEmpty {
            guard SuggestionText.isWord(selection),
                  before.last.map({ !SuggestionText.isWordCharacter($0) }) ?? true,
                  after.first.map({ !SuggestionText.isWordCharacter($0) }) ?? true else { return nil }
            return .init(word: selection, leftCount: 0, rightCount: 0, selected: true, context: SuggestionText.context(before))
        }
        let left = String(before.reversed().prefix(while: SuggestionText.isWordCharacter).reversed())
        let right = String(after.prefix(while: SuggestionText.isWordCharacter))
        let word = left + right
        guard word.isEmpty || SuggestionText.isWord(word) else { return nil }
        // Don't offer word edits within emails, URLs, handles, numbers, or mixed tokens.
        let adjacentLeft = before.dropLast(left.count).last
        let adjacentRight = after.dropFirst(right.count).first
        let unsafe: (Character?) -> Bool = { ch in
            guard let ch else { return false }
            return ch.isNumber || "@/_#\\".contains(ch)
        }
        guard !unsafe(adjacentLeft), !unsafe(adjacentRight) else { return nil }
        let preceding = String(before.dropLast(left.count))
        let precedingToken = preceding.split(whereSeparator: { $0.isWhitespace }).last.map(String.init) ?? ""
        guard !precedingToken.contains("://"), !precedingToken.contains("@") else { return nil }
        return .init(word: word, leftCount: left.count, rightCount: right.count, selected: false,
                     context: SuggestionText.context(preceding))
    }
}

struct SuggestionTarget: Equatable, Sendable {
    var word: String
    var leftCount: Int
    var rightCount: Int
    var selected: Bool
    var context: [String]
}

struct WordSuggestion: Equatable, Sendable {
    enum Kind: Sendable { case correction, completion, nextWord }
    var word: String
    var kind: Kind
}

struct SuggestionEdit: Equatable, Sendable {
    var moveRight: Int
    var deleteCount: Int
    var replaceSelection: Bool
    var text: String

    static func make(suggestion: WordSuggestion, offered: SuggestionSnapshot,
                     current: SuggestionSnapshot) -> Self? {
        guard offered == current, let target = current.target,
              SuggestionText.isWord(suggestion.word) else { return nil }
        let isNext = suggestion.kind == .nextWord
        guard isNext == target.word.isEmpty else { return nil }
        // Preserve punctuation and following text. Space is only added at the end of
        // the document when explicitly accepting a completion or a next word.
        let addSpace = current.after.isEmpty && !target.selected && target.rightCount == 0
            && suggestion.kind != .correction
        return .init(moveRight: target.rightCount,
                     deleteCount: target.selected ? 0 : target.leftCount + target.rightCount,
                     replaceSelection: target.selected, text: suggestion.word + (addSpace ? " " : ""))
    }
}

enum SuggestionText {
    static func normalize(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping.lowercased()
            .replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "ʼ", with: "'")
    }
    static func isWordCharacter(_ ch: Character) -> Bool { ch.isLetter || "'’ʼ".contains(ch) }
    static func isWord(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 24 && value.first?.isLetter == true && value.last?.isLetter == true
            && value.allSatisfy(isWordCharacter)
    }
    static func belongs(_ word: String, to language: KeyboardLanguage) -> Bool {
        let alphabet = language == .english ? "abcdefghijklmnopqrstuvwxyz'" : "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'"
        return normalize(word).allSatisfy { alphabet.contains($0) }
    }
    static func context(_ before: String) -> [String] {
        let sentence = before.split(omittingEmptySubsequences: false, whereSeparator: { ".!?;:\n".contains($0) }).last ?? ""
        return sentence.split(whereSeparator: { !isWordCharacter($0) }).suffix(2).map { normalize(String($0)) }
    }
    static func cased(_ word: String, like original: String, language: KeyboardLanguage) -> String {
        var result = word
        if original.count > 1 && original == original.uppercased() { result = word.uppercased() }
        else if original.first?.isUppercase == true { result = word.prefix(1).uppercased() + word.dropFirst() }
        if original.contains("’") { result = result.replacingOccurrences(of: "'", with: "’") }
        else if original.contains("ʼ") || language == .ukrainian { result = result.replacingOccurrences(of: "'", with: "ʼ") }
        if language == .english && result == "i" { return "I" }
        return result
    }
}

/// The same prefix-delete hash is used by the reproducible asset builder.
/// Collisions only add candidates; full edit distance always verifies them.
enum SuggestionHash {
    static func variants(_ word: String, distance: Int = 2) -> Set<UInt32> {
        let prefix = Array(word.unicodeScalars.prefix(5).map(\.value))
        var terms: Set<[UInt32]> = [prefix]
        var frontier = terms
        for _ in 0..<distance {
            var next = Set<[UInt32]>()
            for term in frontier {
                for index in term.indices {
                    var value = term; value.remove(at: index); next.insert(value)
                }
            }
            terms.formUnion(next); frontier = next
        }
        return Set(terms.map { $0.reduce(UInt32(2166136261)) { ($0 ^ $1) &* 16777619 } })
    }
}

struct SuggestionGeometry: Sendable {
    var centers: [Character: CGPoint] = [:]
    var unit: Double = 40
    init(language: KeyboardLanguage, preferences: KeyboardPreferences, width: Double) {
        var state = InputState(); state.language = language
        let cells = KeyboardGeometry.cells(width: max(width, 200), state: state,
                                          preferences: preferences, needsGlobe: false)
        for cell in cells {
            guard case .text(let text) = cell.key.action, let ch = text.first, ch.isLetter else { continue }
            centers[ch] = CGPoint(x: cell.hitFrame.midX, y: cell.hitFrame.midY)
            unit = cell.hitFrame.width
        }
        centers["ґ"] = centers["г"]
        if centers["ї"] == nil { centers["ї"] = centers["і"] }
    }
    func cost(_ a: Character, _ b: Character) -> Double {
        guard a != b else { return 0 }
        guard let p = centers[a], let q = centers[b] else { return 1 }
        let distance = hypot(p.x - q.x, p.y - q.y) / max(unit, 1)
        return min(1.3, 0.55 + distance * 0.22)
    }
}

enum SuggestionDistance {
    static func evaluate(_ source: String, _ destination: String, geometry: SuggestionGeometry?) -> Double {
        let a = Array(source), b = Array(destination)
        var previousPrevious = [Double](repeating: 0, count: b.count + 1)
        var previous = (0...b.count).map(Double.init)
        for i in a.indices {
            var current = [Double](repeating: 0, count: b.count + 1); current[0] = Double(i + 1)
            for j in b.indices {
                let substitution = a[i] == b[j] ? 0 : geometry?.cost(a[i], b[j]) ?? 1
                current[j + 1] = min(previous[j + 1] + 1, current[j] + 1, previous[j] + substitution)
                if i > 0 && j > 0 && a[i] == b[j - 1] && a[i - 1] == b[j] {
                    current[j + 1] = min(current[j + 1], previousPrevious[j - 1] + (geometry == nil ? 1 : 0.7))
                }
            }
            previousPrevious = previous; previous = current
        }
        return previous[b.count]
    }
}

struct SuggestionLexicon: Sendable {
    struct Entry: Decodable, Sendable {
        let word: String
        let frequency: Int
        init(from decoder: any Decoder) throws {
            var values = try decoder.unkeyedContainer()
            word = try values.decode(String.self); frequency = try values.decode(Int.self)
        }
    }
    private struct Metadata: Decodable { let words: [Entry] }
    let words: [Entry]
    private let data: Data
    private let offset: Int
    private let count: Int
    private var common: [Int] = []

    init(url: URL) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 16, data.prefix(8) == Data("ORTHLEX1".utf8) else { throw CocoaError(.fileReadCorruptFile) }
        let length = Int(Self.u32(data, 8))
        guard length <= data.count - 16 else { throw CocoaError(.fileReadCorruptFile) }
        words = try JSONDecoder().decode(Metadata.self, from: data.subdata(in: 12..<(12 + length))).words
        offset = 16 + length
        count = Int(Self.u32(data, 12 + length))
        guard count <= (data.count - offset) / 8 else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
        common = words.indices.sorted { words[$0].frequency > words[$1].frequency }.prefix(12).map { $0 }
    }
    private static func u32(_ data: Data, _ at: Int) -> UInt32 {
        data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: at, as: UInt32.self)) }
    }
    private func lowerBound(_ term: String) -> Int {
        var low = 0, high = words.count
        while low < high {
            let mid = (low + high) / 2
            if words[mid].word < term { low = mid + 1 } else { high = mid }
        }
        return low
    }
    func contains(_ word: String) -> Bool {
        let index = lowerBound(word)
        return index < words.count && words[index].word == word
    }
    func completions(_ prefix: String) -> [Int] {
        if prefix.isEmpty { return common }
        var index = lowerBound(prefix), result = [Int]()
        while index < words.count && words[index].word.hasPrefix(prefix) {
            result.append(index); index += 1
        }
        return result.sorted { words[$0].frequency > words[$1].frequency }.prefix(12).map { $0 }
    }
    func candidates(_ word: String) -> Set<Int> {
        var result = Set<Int>()
        for hash in SuggestionHash.variants(word) {
            var low = 0, high = count
            while low < high {
                let mid = (low + high) / 2
                if Self.u32(data, offset + mid * 8) < hash { low = mid + 1 } else { high = mid }
            }
            while low < count && Self.u32(data, offset + low * 8) == hash {
                let id = Int(Self.u32(data, offset + low * 8 + 4))
                if id < words.count { result.insert(id) }
                low += 1
            }
        }
        return result
    }
}

struct SuggestionContextModel: Sendable {
    private struct Payload: Decodable { let contexts: [String: [SuggestionLexicon.Entry]] }
    private var contexts: [String: [SuggestionLexicon.Entry]]
    init(url: URL) throws {
        contexts = try JSONDecoder().decode(Payload.self, from: Data(contentsOf: url)).contexts
    }
    func following(_ context: [String]) -> [SuggestionLexicon.Entry] {
        if context.count >= 2, let words = contexts[context.suffix(2).joined(separator: " ")] { return words }
        return context.last.flatMap { contexts[$0] } ?? []
    }
}

struct SuggestionEngine: Sendable {
    let lexicon: SuggestionLexicon
    let context: SuggestionContextModel?
    func suggest(target: SuggestionTarget, language: KeyboardLanguage, learned: [String],
                 geometry: SuggestionGeometry?, nextWords: Bool, useContext: Bool) -> [WordSuggestion] {
        let query = SuggestionText.normalize(target.word)
        guard query.isEmpty || SuggestionText.belongs(query, to: language) else { return [] }
        let following = useContext ? context?.following(target.context) ?? [] : []
        let contextual = Dictionary(following.map { ($0.word, $0.frequency) }, uniquingKeysWith: max)
        if query.isEmpty {
            guard nextWords, !target.context.isEmpty else { return [] }
            let candidates = following.map(\.word) + lexicon.completions("").map { lexicon.words[$0].word }
            var seen = Set<String>()
            return candidates.filter { seen.insert($0).inserted }.prefix(3).map {
                .init(word: SuggestionText.cased($0, like: "", language: language), kind: .nextWord)
            }
        }
        let known = lexicon.contains(query) || learned.contains { SuggestionText.normalize($0) == query }
        var candidates = Set(lexicon.completions(query))
        if query.count >= 2 && (!known || target.selected || target.rightCount > 0) {
            candidates.formUnion(lexicon.candidates(query))
        }
        var scored: [(String, Double, WordSuggestion.Kind)] = []
        func consider(_ word: String, frequency: Int, taught: Bool) {
            guard word != query else { return }
            let completion = word.hasPrefix(query) && !target.selected && target.rightCount == 0
            let distance = completion ? 0 : SuggestionDistance.evaluate(query, word, geometry: nil)
            guard completion || distance <= (query.count <= 3 ? 1 : 2) else { return }
            let cost = completion ? 0.6 + Double(word.count - query.count) * 0.10
                : SuggestionDistance.evaluate(query, word, geometry: geometry)
            let contextBoost = log1p(Double(contextual[word] ?? 0)) * 0.22
            let score = Double(frequency) / 100 * 0.55 - cost * 2.3 + (taught ? 1.5 : 0) + contextBoost
            scored.append((word, score, completion ? .completion : .correction))
        }
        for id in candidates {
            if Task.isCancelled { return [] }
            let entry = lexicon.words[id]
            if abs(entry.word.count - query.count) <= 2 || entry.word.hasPrefix(query) {
                consider(entry.word, frequency: entry.frequency, taught: false)
            }
        }
        for word in learned { consider(SuggestionText.normalize(word), frequency: 450, taught: true) }
        scored.sort { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
        var seen = Set<String>()
        let floor = (scored.first?.1 ?? 0) - 1.6
        return scored.filter { $0.1 >= floor && seen.insert($0.0).inserted }.prefix(3).map {
            .init(word: SuggestionText.cased($0.0, like: target.word, language: language), kind: $0.2)
        }
    }
}

enum SuggestionResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
    static func engine(language: KeyboardLanguage) throws -> SuggestionEngine {
        let code = language == .english ? "en" : "uk"
        guard let lexiconURL = bundle.url(forResource: code, withExtension: "orthlex") else { throw CocoaError(.fileNoSuchFile) }
        let model = bundle.url(forResource: code + "-context", withExtension: "json").flatMap { try? SuggestionContextModel(url: $0) }
        return SuggestionEngine(lexicon: try SuggestionLexicon(url: lexiconURL), context: model)
    }
}
