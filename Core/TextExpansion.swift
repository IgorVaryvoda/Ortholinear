import Foundation

/// A shortcut such as ";mail" that becomes longer text when it's followed by a space,
/// punctuation or a new line.
struct TextExpansion: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var abbreviation: String
    var expansion: String

    static let maximumCount = 300
    static let abbreviationLength = 2...24
    static let maximumExpansionLength = 2000

    init(_ abbreviation: String, _ expansion: String) {
        self.abbreviation = abbreviation
        self.expansion = expansion
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        abbreviation = try c.decode(String.self, forKey: .abbreviation)
        expansion = try c.decode(String.self, forKey: .expansion)
    }

    /// No spaces in the shortcut, and something to expand to.
    var isUsable: Bool {
        Self.abbreviationLength.contains(abbreviation.count) && !abbreviation.contains(where: \.isWhitespace)
            && !expansion.isEmpty && expansion.count <= Self.maximumExpansionLength
    }
}

extension Collection where Element == TextExpansion {
    /// First characters of shortcuts that are marks, which shouldn't get an automatic space.
    var shortcutStarts: Set<String> {
        Set(compactMap { $0.abbreviation.first }.filter { !$0.isLetter && !$0.isNumber }.map(String.init))
    }
}

/// Expands shortcuts as they're finished, and puts the shortcut back if Delete comes next.
struct TextExpander: Sendable {
    /// What finishes a shortcut.
    static let triggers: Set<String> = [" ", "\n", ".", ",", "!", "?", ":", ";"]
    /// What may come right before a shortcut, besides the start of the text and white space.
    private static let openers: Set<Character> = ["(", "[", "{", "\"", "'", "«", "„", "“", "‘"]

    struct Edit: Equatable, Sendable {
        let deleteCount: Int
        let insert: String
    }

    private var undo: (typed: String, inserted: String)?

    /// Before `trigger` is typed: the edit that swaps a finished shortcut for its expansion.
    /// Shortcuts match regardless of case, so an automatic capital doesn't stop them.
    mutating func expand(before: String, trigger: String, expansions: [TextExpansion]) -> Edit? {
        undo = nil
        guard Self.triggers.contains(trigger) else { return nil }
        let lowered = before.lowercased()
        let candidates = expansions.filter(\.isUsable).sorted { $0.abbreviation.count > $1.abbreviation.count }
        for expansion in candidates where lowered.hasSuffix(expansion.abbreviation.lowercased()) {
            let typed = String(before.suffix(expansion.abbreviation.count))
            let boundary = before.dropLast(typed.count).last
            guard boundary == nil || boundary!.isWhitespace || Self.openers.contains(boundary!) else { continue }
            undo = (typed, expansion.expansion + trigger)
            return Edit(deleteCount: typed.count, insert: expansion.expansion)
        }
        return nil
    }

    /// When Delete comes right after an expansion: the edit that puts the shortcut back.
    mutating func revert(before: String) -> Edit? {
        defer { undo = nil }
        guard let undo, before.hasSuffix(undo.inserted) else { return nil }
        return Edit(deleteCount: undo.inserted.count, insert: undo.typed)
    }

    /// Anything else typed or done ends the chance to revert.
    mutating func forget() { undo = nil }
}
