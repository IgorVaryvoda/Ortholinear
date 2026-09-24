import Foundation

/// Mirrors UITextAutocapitalizationType without importing UIKit into Core.
enum AutoCapitalization: Sendable {
    case none, words, sentences, allCharacters

    /// Whether the next letter typed after `before` should start with Shift on.
    func shouldCapitalize(before: String?) -> Bool {
        let before = before ?? ""
        switch self {
        case .none: return false
        case .allCharacters: return true
        case .words: return before.last.map { $0.isWhitespace } ?? true
        case .sentences:
            guard let last = before.last else { return true }
            if last.isNewline { return true }
            guard last.isWhitespace else { return false }
            // Closing quotes and brackets may follow the sentence mark: “Так.” Далі
            let trimmed = before.reversed().drop { $0.isWhitespace && !$0.isNewline }
            if trimmed.isEmpty || trimmed.first?.isNewline == true { return true }
            let mark = trimmed.drop { "\"'”’»)]".contains($0) }.first
            return mark.map { ".!?".contains($0) } ?? false
        }
    }
}
