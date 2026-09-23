import Foundation

/// Where the keyboard is typing, as far as an extension can tell. iOS names neither
/// the app nor the window, and documentIdentifier changes every time a field gains
/// focus, so fields are told apart by kind: their keyboard and return-key traits.
struct LanguageContext: Equatable, Sendable {
    var field: String?
    /// Email, URL and ASCII fields start in a Latin layout unless told otherwise.
    var requiresLatin = false
}

/// The language each kind of field last used. One keyboard process serves every app,
/// so this is shared across apps. It holds field traits and language names, never text.
struct LanguageMemory: Codable, Equatable, Sendable {
    static let fieldLimit = 32

    struct Field: Codable, Equatable, Sendable {
        var key: String
        var language: KeyboardLanguage
    }

    private(set) var startingLanguage: KeyboardLanguage
    /// Bumped by "Forget remembered languages" in the app, which can't reach the
    /// keyboard's own storage.
    private(set) var generation: Int
    /// The last language of an ordinary field, for fields without history. Forced
    /// English in an email field doesn't leak into the next message.
    var fallback: KeyboardLanguage
    /// Least recently used first.
    private var fields: [Field] = []

    init(startingLanguage: KeyboardLanguage, generation: Int = 0) {
        self.startingLanguage = startingLanguage
        self.generation = generation
        fallback = startingLanguage
    }

    /// Settings apply at once: a new starting language, forgetting, or turning off the
    /// language in use starts over from the starting language.
    mutating func adopt(startingLanguage: KeyboardLanguage, generation: Int, enabled: [KeyboardLanguage]) {
        guard startingLanguage != self.startingLanguage || generation != self.generation
                || !enabled.contains(fallback) else { return }
        self = Self(startingLanguage: startingLanguage, generation: generation)
    }

    /// `suggested` is the input mode the host saved for this document, if any.
    func resolve(_ context: LanguageContext, enabled: [KeyboardLanguage],
                 suggested: KeyboardLanguage? = nil) -> KeyboardLanguage {
        func usable(_ language: KeyboardLanguage?) -> KeyboardLanguage? {
            language.flatMap { enabled.contains($0) ? $0 : nil }
        }
        let remembered = context.field.flatMap { key in fields.last { $0.key == key }?.language }
        // A remembered choice wins even in an email field: the user picked it there.
        if let language = usable(remembered) ?? usable(suggested) { return language }
        let language = usable(fallback) ?? enabled.first ?? fallback
        guard context.requiresLatin, !language.isLatin else { return language }
        return enabled.first(where: \.isLatin) ?? .english
    }

    mutating func record(_ language: KeyboardLanguage, in context: LanguageContext, chosen: Bool) {
        if chosen || !context.requiresLatin { fallback = language }
        guard let key = context.field else { return }
        fields.removeAll { $0.key == key }
        fields.append(Field(key: key, language: language))
        fields.removeFirst(max(0, fields.count - Self.fieldLimit))
    }
}
