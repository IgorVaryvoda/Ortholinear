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

/// A key's place in a custom layout, used by the Workshop editor.
struct KeyPosition: Hashable, Sendable {
    var row: Int
    var column: Int
}

enum MoveDirection: CaseIterable, Sendable { case left, right, up, down }

extension CustomKey {
    /// The characters typed into a "Hold for" field: one per grapheme, spaces ignored, no repeats.
    static func characters(in text: String) -> [String] {
        var seen: Set<String> = []
        return text.filter { !$0.isWhitespace }.map(String.init).filter { seen.insert($0).inserted }
    }
}

extension CustomLetterLayout {
    func contains(_ position: KeyPosition) -> Bool {
        rows.indices.contains(position.row) && rows[position.row].indices.contains(position.column)
    }

    subscript(position: KeyPosition) -> CustomKey {
        get { rows[position.row][position.column] }
        set { rows[position.row][position.column] = newValue }
    }

    /// Where `move` would put the key, or nil at an edge, out of a one-key row, or into a full one.
    func destination(of position: KeyPosition, _ direction: MoveDirection) -> KeyPosition? {
        guard contains(position) else { return nil }
        switch direction {
        case .left:
            return position.column > 0 ? KeyPosition(row: position.row, column: position.column - 1) : nil
        case .right:
            return position.column < rows[position.row].count - 1 ? KeyPosition(row: position.row, column: position.column + 1) : nil
        case .up, .down:
            let row = position.row + (direction == .up ? -1 : 1)
            guard rows.indices.contains(row), rows[position.row].count > 1,
                  rows[row].count < Self.maximumRowLength else { return nil }
            return KeyPosition(row: row, column: min(position.column, rows[row].count))
        }
    }

    /// Moves a key one step and returns its new position, or nil when it can't move that way.
    @discardableResult
    mutating func move(_ position: KeyPosition, _ direction: MoveDirection) -> KeyPosition? {
        guard let target = destination(of: position, direction) else { return nil }
        if target.row == position.row {
            rows[position.row].swapAt(position.column, target.column)
        } else {
            let key = rows[position.row].remove(at: position.column)
            rows[target.row].insert(key, at: target.column)
        }
        return target
    }

    mutating func swapKeys(_ a: KeyPosition, _ b: KeyPosition) {
        guard contains(a), contains(b), a != b else { return }
        (self[a], self[b]) = (self[b], self[a])
    }

    /// Adds an empty key after `position` and returns where it went, or nil when the row is full.
    @discardableResult
    mutating func insertKey(after position: KeyPosition) -> KeyPosition? {
        guard contains(position), rows[position.row].count < Self.maximumRowLength else { return nil }
        let target = KeyPosition(row: position.row, column: position.column + 1)
        rows[target.row].insert(CustomKey(""), at: target.column)
        return target
    }

    /// Removes a key unless it is the last one in its row; returns the position to select next.
    @discardableResult
    mutating func removeKey(at position: KeyPosition) -> KeyPosition? {
        guard contains(position), rows[position.row].count > 1 else { return nil }
        rows[position.row].remove(at: position.column)
        return KeyPosition(row: position.row, column: min(position.column, rows[position.row].count - 1))
    }
}

/// A single letter layout, as shared between people in a `.ortholayout` file.
struct LayoutFile: Codable, Equatable, Sendable {
    static let format = "ortholinear-layout"
    static let version = 1
    /// Far above any real layout; refuses to parse anything larger.
    static let maximumSize = 64 * 1024

    var format = Self.format
    var version = Self.version
    var language: KeyboardLanguage
    var layout: CustomLetterLayout

    init(language: KeyboardLanguage, layout: CustomLetterLayout) {
        self.language = language
        self.layout = layout
    }

    enum ReadError: Error, Equatable {
        case tooLarge, notALayout, newerVersion, unknownLanguage, malformed
    }

    /// Reads a shared layout. Fixable problems, such as a missing letter, are left for the
    /// editor to show; only files the editor couldn't display are refused.
    static func read(_ data: Data) throws(ReadError) -> LayoutFile {
        guard data.count <= maximumSize else { throw .tooLarge }
        struct Header: Decodable { let format: String?; let version: Int?; let language: String? }
        guard let header = try? JSONDecoder().decode(Header.self, from: data), header.format == format else { throw .notALayout }
        guard let version = header.version, version <= Self.version else { throw .newerVersion }
        guard version >= 1 else { throw .malformed }
        guard header.language.flatMap(KeyboardLanguage.init(rawValue:)) != nil else { throw .unknownLanguage }
        guard let file = try? JSONDecoder().decode(LayoutFile.self, from: data) else { throw .malformed }
        let rows = file.layout.rows
        let keys = rows.joined()
        guard rows.count == 3, rows.allSatisfy({ $0.count <= CustomLetterLayout.maximumRowLength }),
              keys.allSatisfy({ $0.alternatives.count <= CustomLetterLayout.maximumAlternatives }),
              keys.flatMap({ [$0.output] + $0.alternatives }).allSatisfy({ $0.count <= 1 }) else { throw .malformed }
        return file
    }

    func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

/// Decodes to nil instead of failing the surrounding container.
struct Lossy<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: any Decoder) throws { value = try? Value(from: decoder) }
}
