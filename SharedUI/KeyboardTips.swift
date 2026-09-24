import Foundation

/// One-line tips shown in the idle suggestion row of an empty field.
enum KeyboardTip: String, CaseIterable, Sendable {
    case symbolSlide, glide, flick, hold, spaceCursor, doubleSpace

    var text: String {
        switch self {
        case .symbolSlide: "Tip: hold 123 and slide to a symbol"
        case .glide: "Tip: slide across letters to type a word"
        case .flick: "Tip: flick a top-row key down for its digit"
        case .hold: "Tip: hold a key with a small letter for more"
        case .spaceCursor: "Tip: slide on Space to move the cursor"
        case .doubleSpace: "Tip: tap Space twice to end a sentence"
        }
    }

    func applies(to preferences: KeyboardPreferences, language: KeyboardLanguage) -> Bool {
        switch self {
        case .glide: preferences.glideTyping && language.dictionaryCode != nil
        case .flick: preferences.digitAccess == .flick
        case .doubleSpace: preferences.doubleSpacePeriod
        case .symbolSlide, .hold, .spaceCursor: true
        }
    }
}

/// Counts live in this process's own defaults, which the keyboard may write without Full Access.
@MainActor
enum TipStore {
    static let limit = 3
    private static func key(_ tip: KeyboardTip) -> String { "tip-shown-\(tip.rawValue)" }

    static func next(for preferences: KeyboardPreferences, language: KeyboardLanguage) -> KeyboardTip? {
        guard !ProcessInfo.processInfo.arguments.contains("-no-keyboard-tips") else { return nil }
        return KeyboardTip.allCases.first {
            $0.applies(to: preferences, language: language) && UserDefaults.standard.integer(forKey: key($0)) < limit
        }
    }
    static func markShown(_ tip: KeyboardTip) {
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key(tip)) + 1, forKey: key(tip))
    }
    static func dismiss(_ tip: KeyboardTip) { UserDefaults.standard.set(limit, forKey: key(tip)) }
}
