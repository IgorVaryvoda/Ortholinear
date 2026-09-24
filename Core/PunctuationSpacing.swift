import Foundation

/// Tracks only the space this keyboard just inserted; never rewrites unrelated spaces.
struct PunctuationSpacing {
    struct Edit: Equatable {
        var deleteBackward = false
        var text: String
    }
    /// A second Space within this window after a word types “. ”.
    static let doubleSpaceWindow: TimeInterval = 1.2
    private var expectedSuffix: String?
    private var punctuation: String?
    private var spaceAfterWord: (suffix: String, time: TimeInterval)?

    mutating func reset() { expectedSuffix = nil; punctuation = nil; spaceAfterWord = nil }

    /// Treats the space an accepted suggestion added like an automatic one: a mark
    /// replaces it (“word. ”), and a second Space ends the sentence.
    mutating func adoptSpace(before context: String, at time: TimeInterval = 0) {
        reset()
        guard context.last == " ", let word = context.dropLast().last, word.isLetter || word.isNumber else { return }
        expectedSuffix = String(context.suffix(32))
        spaceAfterWord = (String(context.suffix(32)), time)
    }

    mutating func edit(for value: String, before context: String?, enabled: Bool,
                       doubleSpacePeriod: Bool = false, at time: TimeInterval = 0) -> Edit {
        let pendingSpace = spaceAfterWord
        if doubleSpacePeriod, value == " ", let pendingSpace, let context, context.hasSuffix(pendingSpace.suffix),
           time >= pendingSpace.time, time - pendingSpace.time < Self.doubleSpaceWindow {
            reset()
            // Owned like an automatic space, so a following mark or Space doesn't double it.
            if enabled {
                expectedSuffix = String(context.dropLast().suffix(32)) + ". "
                punctuation = "."
            }
            return Edit(deleteBackward: true, text: ". ")
        }
        defer {
            if doubleSpacePeriod, value == " ", let context, let last = context.last, last.isLetter || last.isNumber {
                spaceAfterWord = (String(context.suffix(31)) + " ", time)
            }
        }
        guard enabled else { reset(); return Edit(text: value) }
        let marks = Set([".", ",", "!", "?", ":", ";", "…"])
        let ownsSpace = expectedSuffix.map { context?.hasSuffix($0) == true } ?? false
        let numericContinuation = ownsSpace && [".", ",", ":"].contains(punctuation ?? "")
            && value.first?.isNumber == true && context?.dropLast(2).last?.isNumber == true
        let removeSpace = ownsSpace && (marks.contains(value) || value == "\n" || numericContinuation)
        reset()
        // A deliberate space after punctuation accepts the automatic space once.
        if ownsSpace && value == " " { return Edit(text: "") }
        let output = value + (marks.contains(value) ? " " : "")
        if marks.contains(value), let context {
            expectedSuffix = String((removeSpace ? String(context.dropLast()) : context).suffix(32)) + output
            punctuation = value
        }
        return Edit(deleteBackward: removeSpace, text: output)
    }
}
