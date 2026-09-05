import Foundation

/// Tracks only the space this keyboard just inserted; never rewrites unrelated spaces.
struct PunctuationSpacing {
    struct Edit: Equatable {
        var deleteBackward = false
        var text: String
    }
    private var expectedSuffix: String?
    private var punctuation: String?

    mutating func reset() { expectedSuffix = nil; punctuation = nil }

    mutating func edit(for value: String, before context: String?, enabled: Bool) -> Edit {
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
