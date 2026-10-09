import Foundation

/// Cursor and deletion commands for navigation layers. Keyboards without Full Access can move
/// the cursor and delete, but can't select text or use the clipboard.
enum KeyCommand: String, Codable, CaseIterable, Sendable {
    case left, right, wordLeft, wordRight, lineStart, lineEnd, deleteWord, deleteToLineStart

    var title: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .wordLeft: "Word left"
        case .wordRight: "Word right"
        case .lineStart: "Line start"
        case .lineEnd: "Line end"
        case .deleteWord: "Delete word"
        case .deleteToLineStart: "Delete to line start"
        }
    }

    /// What the key shows when it has no label of its own.
    var symbol: String {
        switch self {
        case .left: "←"
        case .right: "→"
        case .wordLeft: "⇠"
        case .wordRight: "⇢"
        case .lineStart: "⇤"
        case .lineEnd: "⇥"
        case .deleteWord: "⌫w"
        case .deleteToLineStart: "⌫⇤"
        }
    }
}

/// What a command does to the text around the cursor: move it, or delete characters before it.
enum TextEdit: Equatable, Sendable {
    /// Move by this many UTF-16 units, the unit `adjustTextPosition` and `NSRange` use.
    case move(Int)
    /// Delete this many characters before the cursor, one `deleteBackward` each.
    case deleteBackward(Int)
}

enum TextNavigation {
    /// The UTF-16 offset for moving the caret `steps` whole characters, negative to the left.
    /// Past the text the host shares, each step counts as one unit, as before.
    static func offset(steps: Int, before: String, after: String) -> Int {
        if steps < 0 {
            let known = before.suffix(-steps)
            return -(String(known).utf16.count + (-steps - known.count))
        }
        if steps > 0 {
            let known = after.prefix(steps)
            return String(known).utf16.count + (steps - known.count)
        }
        return 0
    }

    /// The edit for `command`, given the text either side of the cursor. Text the host doesn't
    /// share counts as absent, so commands stop where the known text ends.
    static func edit(for command: KeyCommand, before: String, after: String) -> TextEdit? {
        switch command {
        case .left: return before.last.map { .move(-$0.utf16.count) }
        case .right: return after.first.map { .move($0.utf16.count) }
        case .wordLeft:
            let span = wordSpan(Array(before.reversed()))
            return span.isEmpty ? nil : .move(-String(span).utf16.count)
        case .wordRight:
            let span = wordSpan(Array(after))
            return span.isEmpty ? nil : .move(String(span).utf16.count)
        case .lineStart:
            let line = before.reversed().prefix { !$0.isNewline }
            return line.isEmpty ? nil : .move(-String(line).utf16.count)
        case .lineEnd:
            let line = after.prefix { !$0.isNewline }
            return line.isEmpty ? nil : .move(String(line).utf16.count)
        case .deleteWord:
            let span = wordSpan(Array(before.reversed()))
            return span.isEmpty ? nil : .deleteBackward(span.count)
        case .deleteToLineStart:
            let line = before.reversed().prefix { !$0.isNewline }
            return line.isEmpty ? nil : .deleteBackward(line.count)
        }
    }

    /// Spaces next to the cursor, then one word or one run of punctuation: what Option-arrow
    /// skips on a Mac. Characters are given in the direction of travel.
    private static func wordSpan(_ characters: [Character]) -> ArraySlice<Character> {
        var end = 0
        while end < characters.count, characters[end].isWhitespace, !characters[end].isNewline { end += 1 }
        guard end < characters.count else { return characters[..<end] }
        if characters[end].isNewline { return characters[..<(end == 0 ? 1 : end)] }
        let wordy: (Character) -> Bool = { $0.isLetter || $0.isNumber || "'’ʼ_".contains($0) }
        let inWord = wordy(characters[end])
        while end < characters.count, !characters[end].isWhitespace,
              wordy(characters[end]) == inWord { end += 1 }
        return characters[..<end]
    }
}
