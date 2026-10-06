import Foundation

/// One key on a custom letter page: what a tap types, and what holding it offers.
struct CustomKey: Codable, Equatable, Sendable {
    var output: String
    /// Empty keeps the usual holds for punctuation, such as … ! ? on the period.
    var alternatives: [String] = []

    init(_ output: String, alternatives: [String] = []) {
        self.output = output
        self.alternatives = alternatives
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        output = try c.decode(String.self, forKey: .output)
        alternatives = try c.decodeIfPresent([String].self, forKey: .alternatives) ?? []
    }
}

/// A person's own arrangement of a language's three letter rows. Delete, Shift and the
/// control row are added around it exactly as for the built-in layouts.
struct CustomLetterLayout: Codable, Equatable, Sendable {
    var rows: [[CustomKey]]

    static let maximumRowLength = 12
    static let maximumAlternatives = 8

    /// The built-in layout as an editable starting point, holds included.
    init(builtIn language: KeyboardLanguage, preferences: KeyboardPreferences = .init()) {
        rows = KeyboardLayout.letterRows(language, preferences: preferences).map { row in
            row.map { character in
                CustomKey(String(character),
                          alternatives: KeyboardLayout.letterAlternatives(character, language: language, preferences: preferences))
            }
        }
    }

    init(rows: [[CustomKey]]) { self.rows = rows }

    enum Problem: Equatable, Sendable {
        case rowCount(Int)
        case rowLength(row: Int, count: Int)
        case notOneCharacter(String)
        case notLowercase(String)
        case duplicate(String)
        case tooManyAlternatives(String)
        /// Letters of the alphabet that no key types, directly or by holding.
        case missingLetters(String)
    }

    /// Everything that stops this layout from being used for `language`; empty when usable.
    func problems(for language: KeyboardLanguage) -> [Problem] {
        var problems: [Problem] = []
        if rows.count != 3 { problems.append(.rowCount(rows.count)) }
        for (index, row) in rows.enumerated() where row.isEmpty || row.count > Self.maximumRowLength {
            problems.append(.rowLength(row: index, count: row.count))
        }
        var seen: Set<String> = []
        for key in rows.joined() {
            for value in [key.output] + key.alternatives {
                if value.count != 1 || value.first?.isWhitespace == true { problems.append(.notOneCharacter(value)) }
                // Shift uppercases what the key types, so the rows hold lowercase.
                else if value != value.lowercased() { problems.append(.notLowercase(value)) }
            }
            if !seen.insert(key.output).inserted { problems.append(.duplicate(key.output)) }
            if key.alternatives.count > Self.maximumAlternatives { problems.append(.tooManyAlternatives(key.output)) }
        }
        let reachable = Set(rows.joined().flatMap { [$0.output] + $0.alternatives }.compactMap(\.first))
        let missing = String(language.alphabet.filter { !reachable.contains($0) })
        if !missing.isEmpty { problems.append(.missingLetters(missing)) }
        return problems
    }

    func isUsable(for language: KeyboardLanguage) -> Bool { problems(for: language).isEmpty }
}

/// Decodes to nil instead of failing the surrounding container.
struct Lossy<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: any Decoder) throws { value = try? Value(from: decoder) }
}
