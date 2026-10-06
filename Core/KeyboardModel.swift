import Foundation
import CoreGraphics

enum KeyboardLanguage: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case ukrainian, english, polish, german, french, spanish, czech, slovak
    case bcms, serbianCyrillic, swedish, norwegian, danish, dutch, russian
    var title: String {
        switch self {
        case .ukrainian: "Українська"
        case .english: "English"
        case .polish: "Polski"
        case .german: "Deutsch"
        case .french: "Français"
        case .spanish: "Español"
        case .czech: "Čeština"
        case .slovak: "Slovenčina"
        // One Latin layout serves Croatian, Bosnian, Montenegrin and Serbian.
        case .bcms: "Latinica"
        case .serbianCyrillic: "Ћирилица"
        case .swedish: "Svenska"
        case .norwegian: "Norsk"
        case .danish: "Dansk"
        case .dutch: "Nederlands"
        case .russian: "Русский"
        }
    }
    var badge: String {
        switch self {
        case .ukrainian: "UA"
        case .english: "EN"
        case .polish: "PL"
        case .german: "DE"
        case .french: "FR"
        case .spanish: "ES"
        case .czech: "CZ"
        case .slovak: "SK"
        case .bcms: "BCMS"
        case .serbianCyrillic: "СР"
        case .swedish: "SE"
        case .norwegian: "NO"
        case .danish: "DK"
        case .dutch: "NL"
        case .russian: "RU"
        }
    }
    var code: String {
        switch self {
        case .ukrainian: "uk-UA"
        case .english: "en-US"
        case .polish: "pl-PL"
        case .german: "de-DE"
        case .french: "fr-FR"
        case .spanish: "es-ES"
        case .czech: "cs-CZ"
        case .slovak: "sk-SK"
        case .bcms: "hr-HR"
        case .serbianCyrillic: "sr-Cyrl-RS"
        case .swedish: "sv-SE"
        case .norwegian: "nb-NO"
        case .danish: "da-DK"
        case .dutch: "nl-NL"
        case .russian: "ru-RU"
        }
    }
    /// Every lowercase letter the layout must reach, directly or by holding a key.
    var alphabet: String {
        switch self {
        case .ukrainian: "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя"
        case .english: "abcdefghijklmnopqrstuvwxyz"
        case .polish: "abcdefghijklmnopqrstuvwxyząćęłńóśźż"
        case .german: "abcdefghijklmnopqrstuvwxyzäöüß"
        case .french: "abcdefghijklmnopqrstuvwxyzàâæçéèêëîïôœùûüÿ"
        case .spanish: "abcdefghijklmnopqrstuvwxyzáéíñóúü"
        case .czech: "abcdefghijklmnopqrstuvwxyzáčďéěíňóřšťúůýž"
        case .slovak: "abcdefghijklmnopqrstuvwxyzáäčďéíĺľňóôŕšťúýž"
        case .bcms: "abcdefghijklmnopqrstuvwxyzčćđšžśź"
        case .serbianCyrillic: "абвгдђежзијклљмнњопрстћуфхцчџш"
        case .swedish: "abcdefghijklmnopqrstuvwxyzåäöé"
        case .norwegian: "abcdefghijklmnopqrstuvwxyzæøåé"
        case .danish: "abcdefghijklmnopqrstuvwxyzæøåé"
        case .dutch: "abcdefghijklmnopqrstuvwxyzáäéèêëíïóöúü"
        case .russian: "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
        }
    }
    /// Latin layouts type every ASCII letter, so email and URL fields can keep them.
    var isLatin: Bool { ![.ukrainian, .serbianCyrillic, .russian].contains(self) }
    /// Only English and Ukrainian ship bundled dictionaries.
    var dictionaryCode: String? {
        switch self {
        case .english: "en"
        case .ukrainian: "uk"
        default: nil
        }
    }

    /// Accepts BCP 47 identifiers such as "en-GB" or "uk".
    init?(languageCode: String) {
        let prefix = languageCode.lowercased().prefix { $0.isLetter }
        guard let language = Self.allCases.first(where: { $0.code.hasPrefix(prefix + "-") }) else { return nil }
        self = language
    }
}

/// Alternative English arrangements. Only the letters are listed; letterRows adds the
/// optional apostrophe and punctuation where each layout usually has them.
enum EnglishLayout: String, Codable, CaseIterable, Sendable {
    case qwerty, colemak, colemakDH, dvorak, workman
    var title: String {
        switch self {
        case .qwerty: "QWERTY"
        case .colemak: "Colemak"
        case .colemakDH: "Colemak-DH"
        case .dvorak: "Dvorak"
        case .workman: "Workman"
        }
    }
    var letters: [String] {
        switch self {
        case .qwerty: ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        case .colemak: ["qwfpgjluy", "arstdhneio", "zxcvbkm"]
        // The matrix bottom row, as used on ortholinear boards.
        case .colemakDH: ["qwfpbjluy", "arstgmneio", "zxcdvkh"]
        case .dvorak: ["pyfgcrl", "aoeuidhtns", "qjkxbmwvz"]
        case .workman: ["qdrwbjfup", "ashtgyneoi", "zxmcvkl"]
        }
    }
}

/// Russian is offered only to people who say they don't support the invasion of Ukraine.
enum InvasionAnswer: String, Codable, Sendable {
    case unanswered, supports, opposes
}

/// Which way a short swipe on a key goes.
enum FlickDirection: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case up, down, left, right
    var arrow: String {
        switch self {
        case .up: "↑"
        case .down: "↓"
        case .left: "←"
        case .right: "→"
        }
    }
}

enum KeyboardPage: Hashable, Sendable {
    case letters, numbers, symbols
    /// One of the person's own layers, which follow the symbols page.
    case layer(UUID)
    var isLayer: Bool { if case .layer = self { true } else { false } }
}
/// How digits are reached from the letter page, besides 123.
enum DigitAccess: String, Codable, CaseIterable, Sendable {
    case flick, numberRow, off
    var title: String {
        switch self {
        case .flick: "Flick down"
        case .numberRow: "Number row"
        case .off: "Off"
        }
    }
}
enum ShiftMode: Sendable { case off, once, locked }
enum ShiftPlacement: String, Codable, CaseIterable, Sendable {
    case beforeLastRow, controlRow
    var title: String { self == .beforeLastRow ? "Before Я / Z" : "Control row" }
}

struct InputState: Sendable {
    var language: KeyboardLanguage = .ukrainian
    var page: KeyboardPage = .letters
    var shift: ShiftMode = .off
    private var lastShiftTap: TimeInterval?

    mutating func tapShift(at time: TimeInterval) {
        if shift == .locked { shift = .off; lastShiftTap = nil }
        else if let lastShiftTap, time >= lastShiftTap, time - lastShiftTap < 0.32 {
            shift = .locked
            self.lastShiftTap = nil
        } else {
            shift = shift == .off ? .once : .off
            lastShiftTap = time
        }
    }

    mutating func consume(_ value: String) -> String {
        // Layer keys type exactly what they hold: a phrase, or a Greek π, never shifted.
        if page.isLayer { return value }
        let result = shift == .off ? value : value.shifted
        if value.lowercased() != value.uppercased() {
            if shift == .once { shift = .off }
            lastShiftTap = nil
        }
        return result
    }
}

extension String {
    /// Shift, not text-transform uppercasing: ß becomes ẞ rather than "SS".
    var shifted: String { self == "ß" ? "ẞ" : uppercased() }
}

enum KeyAction: Hashable, Sendable {
    case text(String), shift, backspace, space, enter, language, page, globe, dismiss
    /// Opens the first of the person's layers from the letter page.
    case layers
    /// Moves the cursor or deletes, from a navigation layer.
    case command(KeyCommand)
    /// Types text, then moves the cursor back into it, as `()` leaves it between the brackets.
    case pair(String, cursorBack: Int)
}

struct Key: Sendable {
    let action: KeyAction
    var weight: Double = 1
    /// A letter's holds, or a custom key's own; they replace the punctuation defaults below.
    var letterAlternatives: [String] = []
    /// Typed by a short swipe in each direction: top-row digits down, or the person's own.
    var flicks: [FlickDirection: String] = [:]
    /// The downward flick, where top-row digits live.
    var flick: String? {
        get { flicks[.down] }
        set { flicks[.down] = newValue }
    }
    /// Shown instead of the text, for phrase keys.
    var label: String?
    var alternatives: [String] {
        guard case .text(let value) = action else { return [] }
        if !letterAlternatives.isEmpty { return letterAlternatives }
        switch value {
        case ".": return [".", "…", "!", "?"]
        case ",": return [",", ";", ":"]
        case "'": return ["'", "’", "ʼ", "\""]
        // Ukrainian types the modifier-letter apostrophe, as macOS does.
        case "ʼ": return ["ʼ", "'", "’", "\""]
        case "-": return ["-", "–", "—", "_"]
        case "\"": return ["\"", "«", "»", "“", "”"]
        case "?": return ["?", "!", "¿"]
        default: return []
        }
    }
}

enum KeyboardLayout {
    static func rows(state: InputState, needsGlobe: Bool, preferences: KeyboardPreferences = .init()) -> [[Key]] {
        var result: [[Key]]
        switch state.page {
        case .letters: result = letterKeys(state.language, preferences: preferences)
        case .numbers: result = numberKeys(state.language)
        case .symbols:
            result = textKeys(["[]{}#%^*+=", "_\\|~<>€£¥•", ".,?!'`:;₴…"])
        case .layer(let id):
            // A layer deleted while it was open shows the numbers instead.
            if let layer = preferences.shownLayers.first(where: { $0.id == id }) {
                result = layer.rows.map { row in row.map(\.layerKey) }
            } else { result = numberKeys(state.language) }
        }
        let digits = "1234567890".map(String.init)
        if state.page == .letters && preferences.digitAccess == .flick {
            // A down flick the person set on a key wins over its digit.
            for index in result[0].indices.prefix(digits.count) where result[0][index].flick == nil {
                result[0][index].flick = digits[index]
            }
        }
        // Delete follows the last letter, ahead of any optional punctuation. A custom
        // last row of punctuation alone still gets Delete, at its end.
        if state.page == .letters {
            let lastLetter = result[2].lastIndex { key in
                guard case .text(let value) = key.action else { return false }
                return value == "'" || value.first?.isLetter == true
            }
            result[2].insert(Key(action: .backspace, weight: preferences.validated.actionKeyWidth),
                             at: lastLetter.map { $0 + 1 } ?? result[2].endIndex)
        }
        var controls: [Key] = [Key(action: .page, weight: 1.35)]
        if state.page == .letters && preferences.showLayerKey && firstLayerPage(preferences) != nil {
            controls.append(Key(action: .layers, weight: 1.25))
        }
        if state.page == .letters && preferences.shiftPlacement == .beforeLastRow {
            result[2].insert(Key(action: .shift, weight: 0.8), at: 0)
        } else {
            controls.append(Key(action: .shift, weight: 1.25))
        }
        if needsGlobe { controls.append(Key(action: .globe)) }
        // With a single language there is nothing to switch to, unless a URL or
        // email field put the keyboard in English and it needs a way back.
        if preferences.language(after: state.language) != state.language {
            controls.append(Key(action: .language, weight: 1.25))
        }
        controls += [Key(action: .space, weight: 3.8),
                     Key(action: .enter, weight: preferences.validated.actionKeyWidth)]
        if state.page != .letters {
            controls.append(Key(action: .backspace, weight: preferences.validated.actionKeyWidth))
        }
        result.append(controls)
        if state.page == .letters && preferences.digitAccess == .numberRow {
            result.insert(digits.map { Key(action: .text($0)) }, at: 0)
        }
        return result
    }

    /// The person's own layout when it is usable for this language, otherwise the built-in one.
    /// An unusable layout is kept in the preferences but never shown as a partial grid.
    static func letterKeys(_ language: KeyboardLanguage, preferences: KeyboardPreferences) -> [[Key]] {
        if let custom = preferences.customLayouts[language], custom.isUsable(for: language) {
            return custom.rows.map { row in
                row.map { Key(action: .text($0.output), letterAlternatives: $0.alternatives,
                              flicks: preferences.extrasEnabled ? $0.usableFlicks : [:]) }
            }
        }
        return letterRows(language, preferences: preferences).map { row in
            row.map { character in
                Key(action: .text(String(character)),
                    letterAlternatives: letterAlternatives(character, language: language, preferences: preferences))
            }
        }
    }

    private static func numberKeys(_ language: KeyboardLanguage) -> [[Key]] {
        textKeys(["1234567890", "-/:;()$&@\"", (language == .ukrainian ? ".,?!ʼ" : ".,?!'") + "[]=+%"])
    }

    /// The pages the #+= / 123 key steps through: numbers, symbols, then each usable layer.
    static func pageCycle(_ preferences: KeyboardPreferences) -> [KeyboardPage] {
        [.numbers, .symbols] + preferences.shownLayers.map { .layer($0.id) }
    }

    static func page(after page: KeyboardPage, preferences: KeyboardPreferences) -> KeyboardPage {
        let cycle = pageCycle(preferences)
        guard let index = cycle.firstIndex(of: page) else { return .numbers }
        return cycle[(index + 1) % cycle.count]
    }

    static func firstLayerPage(_ preferences: KeyboardPreferences) -> KeyboardPage? {
        preferences.shownLayers.first.map { .layer($0.id) }
    }

    /// A page's short name, as the key that opens it shows it.
    static func pageTitle(_ page: KeyboardPage, preferences: KeyboardPreferences) -> String {
        switch page {
        case .letters: "ABC"
        case .numbers: "123"
        case .symbols: "#+="
        case .layer(let id): preferences.layers.first { $0.id == id }?.shortTitle ?? "123"
        }
    }

    /// A page's spoken name.
    static func pageName(_ page: KeyboardPage, preferences: KeyboardPreferences) -> String {
        switch page {
        case .letters: "Letters"
        case .numbers: "Numbers"
        case .symbols: "More symbols"
        case .layer(let id): preferences.layers.first { $0.id == id }?.name ?? "Numbers"
        }
    }

    private static func textKeys(_ rows: [String]) -> [[Key]] {
        rows.map { row in row.map { Key(action: .text(String($0))) } }
    }

    static func letterRows(_ language: KeyboardLanguage, preferences: KeyboardPreferences) -> [String] {
        let punctuation = preferences.showPunctuation ? ".,?" : ""
        switch language {
        case .ukrainian:
            return ["йцукенгшщзх" + (preferences.yiOnLongPress ? "" : "ї"), "фівапролджє",
                    "ячсмитьбю" + (preferences.showPunctuation ? ".," : "")]
        case .english:
            var rows = preferences.englishLayout.letters
            if preferences.englishLayout == .dvorak {
                // Dvorak keeps ' , . together at the start of the top row.
                rows[0] = (preferences.showApostrophe ? "'" : "") + (preferences.showPunctuation ? ",." : "") + rows[0]
            } else {
                if preferences.showApostrophe { rows[1] += "'" }
                rows[2] += punctuation
            }
            return rows
        case .polish: return ["qwertyuiop", "asdfghjkl", "zxcvbnm" + punctuation]
        case .german: return ["qwertzuiopü", "asdfghjklöä", "yxcvbnm" + punctuation]
        // French needs its apostrophe (l'eau, j'ai), so it is always on the letter page.
        case .french: return ["azertyuiop", "qsdfghjklm", "wxcvbn'" + punctuation]
        case .spanish: return ["qwertyuiop", "asdfghjklñ", "zxcvbnm" + punctuation]
        // Czech and Slovak use so many accents that iOS, too, keeps them on held keys.
        case .czech, .slovak: return ["qwertzuiop", "asdfghjkl", "yxcvbnm" + punctuation]
        case .bcms: return ["qwertzuiopšđ", "asdfghjklčćž", "yxcvbnm" + punctuation]
        case .serbianCyrillic:
            return ["љњертзуиопшђ", "асдфгхјклчћж", "џцвбнм" + (preferences.showPunctuation ? ".," : "")]
        case .swedish: return ["qwertyuiopå", "asdfghjklöä", "zxcvbnm" + punctuation]
        case .norwegian: return ["qwertyuiopå", "asdfghjkløæ", "zxcvbnm" + punctuation]
        case .danish: return ["qwertyuiopå", "asdfghjklæø", "zxcvbnm" + punctuation]
        case .dutch: return ["qwertyuiop", "asdfghjkl", "zxcvbnm" + punctuation]
        case .russian:
            return ["йцукенгшщзх", "фывапролджэ", "ячсмитьбю" + (preferences.showPunctuation ? ".," : "")]
        }
    }

    /// Hold a letter for these; releasing in place types the first one.
    static func letterAlternatives(_ character: Character, language: KeyboardLanguage,
                                   preferences: KeyboardPreferences) -> [String] {
        switch (language, character) {
        // Only Ukrainian has ґ; Russian and Serbian г must not offer it.
        case (.ukrainian, "г"): ["ґ"]
        case (.ukrainian, "і"): preferences.yiOnLongPress ? ["ї"] : []
        case (.polish, "a"): ["ą"]
        case (.polish, "c"): ["ć"]
        case (.polish, "e"): ["ę"]
        case (.polish, "l"): ["ł"]
        case (.polish, "n"): ["ń"]
        case (.polish, "o"): ["ó"]
        case (.polish, "s"): ["ś"]
        case (.polish, "z"): ["ż", "ź"]
        case (.german, "s"): ["ß"]
        case (.french, "e"): ["é", "è", "ê", "ë"]
        case (.french, "a"): ["à", "â", "æ"]
        case (.french, "c"): ["ç"]
        case (.french, "u"): ["ù", "û", "ü"]
        case (.french, "i"): ["î", "ï"]
        case (.french, "o"): ["ô", "œ"]
        case (.french, "y"): ["ÿ"]
        case (.spanish, "a"): ["á"]
        case (.spanish, "e"): ["é"]
        case (.spanish, "i"): ["í"]
        case (.spanish, "o"): ["ó"]
        case (.spanish, "u"): ["ú", "ü"]
        case (.czech, "a"): ["á"]
        case (.czech, "c"): ["č"]
        case (.czech, "d"): ["ď"]
        case (.czech, "e"): ["ě", "é"]
        case (.czech, "i"): ["í"]
        case (.czech, "n"): ["ň"]
        case (.czech, "o"): ["ó"]
        case (.czech, "r"): ["ř"]
        case (.czech, "s"): ["š"]
        case (.czech, "t"): ["ť"]
        case (.czech, "u"): ["ů", "ú"]
        case (.czech, "y"): ["ý"]
        case (.czech, "z"): ["ž"]
        case (.slovak, "a"): ["á", "ä"]
        case (.slovak, "c"): ["č"]
        case (.slovak, "d"): ["ď"]
        case (.slovak, "e"): ["é"]
        case (.slovak, "i"): ["í"]
        case (.slovak, "l"): ["ľ", "ĺ"]
        case (.slovak, "n"): ["ň"]
        case (.slovak, "o"): ["ó", "ô"]
        case (.slovak, "r"): ["ŕ"]
        case (.slovak, "s"): ["š"]
        case (.slovak, "t"): ["ť"]
        case (.slovak, "u"): ["ú"]
        case (.slovak, "y"): ["ý"]
        case (.slovak, "z"): ["ž"]
        // Montenegrin's two extra letters.
        case (.bcms, "s"): ["ś"]
        case (.bcms, "z"): ["ź"]
        case (.swedish, "e"), (.norwegian, "e"), (.danish, "e"): ["é"]
        case (.dutch, "a"): ["á", "ä"]
        case (.dutch, "e"): ["é", "ë", "è", "ê"]
        case (.dutch, "i"): ["ï", "í"]
        case (.dutch, "o"): ["ó", "ö"]
        case (.dutch, "u"): ["ü", "ú"]
        case (.russian, "е"): ["ё"]
        case (.russian, "ь"): ["ъ"]
        default: []
        }
    }
}

struct KeyboardPreferences: Codable, Equatable, Sendable {
    let schemaVersion = 4
    var keyHeight: Double = 72
    var columnSpacing: Double = 2
    var rowSpacing: Double = 3
    var fillGaps: Bool = true
    var defaultLanguage: KeyboardLanguage = .ukrainian
    var controlHeight: Double = 56
    var letterSize: Double = 28
    var actionKeyWidth: Double = 2.4
    var shiftPlacement: ShiftPlacement = .beforeLastRow
    var showPunctuation: Bool = false
    var showApostrophe: Bool = true
    var showHeader: Bool = false
    var autoSpacePunctuation: Bool = true
    var yiOnLongPress: Bool = false
    var theme: KeyboardTheme = .system
    var accent: KeyboardAccent = .theme
    var showLongPressHints: Bool = true
    var autoCapitalize: Bool = true
    var doubleSpacePeriod: Bool = true
    var digitAccess: DigitAccess = .flick
    var glideTyping: Bool = true

    var suggestionsEnabled: Bool = true
    var nextWordSuggestions: Bool = true
    var contextualSuggestions: Bool = true

    /// The languages the language key cycles through, in `allCases` order.
    var languages: [KeyboardLanguage] = [.ukrainian, .english]
    var englishLayout: EnglishLayout = .qwerty
    var rememberLanguage: Bool = true
    /// Bumped to make the keyboard forget remembered languages; see LanguageMemory.
    var languageMemoryGeneration: Int = 0
    var invasionAnswer: InvasionAnswer = .unanswered
    /// Letter rows the person arranged in the Workshop; languages without one use the built-in rows.
    var customLayouts: [KeyboardLanguage: CustomLetterLayout] = [:]
    /// Extra pages of keys after the symbols page.
    var layers: [CustomLayer] = []
    /// A control-row key that opens the first layer from the letters.
    var showLayerKey: Bool = false
    /// A colorway that replaces the theme's colors.
    var keycaps: KeycapStyle?
    /// Shortcuts that become longer text, such as ";mail".
    var expansions: [TextExpansion] = []
    /// Whether the keyboard uses the extras: layers, keycap colorways and text expansions. The app sets it in
    /// the copy it publishes, so they can be switched off without deleting them; see
    /// docs/PRO-IMPLEMENTATION.md.
    var extrasEnabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case schemaVersion, keyHeight, columnSpacing, rowSpacing, fillGaps, defaultLanguage
        case controlHeight, letterSize, actionKeyWidth, shiftPlacement, showPunctuation, showApostrophe, showHeader, autoSpacePunctuation
        case yiOnLongPress, autoCapitalize, doubleSpacePeriod, digitAccess, glideTyping
        case theme, accent, showLongPressHints
        case suggestionsEnabled, nextWordSuggestions, contextualSuggestions
        case languages, englishLayout, rememberLanguage, languageMemoryGeneration, invasionAnswer
        case customLayouts, layers, showLayerKey, keycaps, expansions, extrasEnabled
    }

    var validated: Self {
        var result = self
        result.keyHeight = keyHeight.isFinite ? min(88, max(36, keyHeight)) : 72
        result.controlHeight = controlHeight.isFinite ? min(72, max(36, controlHeight)) : 56
        result.letterSize = letterSize.isFinite ? min(36, max(18, letterSize)) : 28
        result.actionKeyWidth = actionKeyWidth.isFinite ? min(3.5, max(1.25, actionKeyWidth)) : 2.4
        result.columnSpacing = columnSpacing.isFinite ? min(8, max(0, columnSpacing)) : 2
        result.rowSpacing = rowSpacing.isFinite ? min(12, max(0, rowSpacing)) : 3
        let enabled = KeyboardLanguage.allCases.filter { languages.contains($0) && ($0 != .russian || invasionAnswer == .opposes) }
        result.languages = enabled.isEmpty ? Self().languages : enabled
        if !result.languages.contains(defaultLanguage) { result.defaultLanguage = result.languages[0] }
        return result
    }

    /// The language key's target. A language outside the cycle, such as English
    /// forced by an email field, leads back to the first enabled one.
    func language(after language: KeyboardLanguage) -> KeyboardLanguage {
        let enabled = validated.languages
        guard let index = enabled.firstIndex(of: language) else { return enabled[0] }
        return enabled[(index + 1) % enabled.count]
    }
    /// The layers the keyboard offers: usable ones, when layers are enabled.
    var shownLayers: [CustomLayer] { extrasEnabled ? layers.filter(\.isUsable) : [] }
    /// The colorway the keyboard draws, when extras are enabled.
    var shownKeycaps: KeycapStyle? { extrasEnabled ? keycaps : nil }
    var shownExpansions: [TextExpansion] { extrasEnabled ? expansions.filter(\.isUsable) : [] }
    var suggestionHeight: Double { suggestionsEnabled ? 44 : 0 }
    var headerHeight: Double { suggestionHeight + (showHeader ? KeyboardGeometry.ribbonHeight : 0) }
    /// A shorter row: it costs about 45 pt at the default key height.
    var numberRowHeight: Double {
        digitAccess == .numberRow ? min(48, max(30, (validated.keyHeight * 0.6).rounded())) : 0
    }
    var keyboardHeight: Double {
        let p = validated
        let numberRow = p.numberRowHeight > 0 ? p.numberRowHeight + p.rowSpacing : 0
        return p.headerHeight + numberRow + 3 * (p.keyHeight + p.rowSpacing) + p.controlHeight + p.rowSpacing
    }

    mutating func apply(_ preset: KeyboardPreset) {
        let language = (defaultLanguage, languages, englishLayout, rememberLanguage, languageMemoryGeneration, invasionAnswer)
        let appearance = (theme, accent, showLongPressHints)
        let suggestions = (suggestionsEnabled, nextWordSuggestions, contextualSuggestions)
        let typing = (autoCapitalize, doubleSpacePeriod, digitAccess, glideTyping)
        let custom = (customLayouts, layers, showLayerKey, keycaps, expansions, extrasEnabled)
        self = preset.preferences
        (customLayouts, layers, showLayerKey, keycaps, expansions, extrasEnabled) = custom
        (defaultLanguage, languages, englishLayout, rememberLanguage, languageMemoryGeneration, invasionAnswer) = language
        (theme, accent, showLongPressHints) = appearance
        (suggestionsEnabled, nextWordSuggestions, contextualSuggestions) = suggestions
        (autoCapitalize, doubleSpacePeriod, digitAccess, glideTyping) = typing
    }
}

extension KeyboardPreferences {
    init(from decoder: any Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keyHeight = try c.decodeIfPresent(Double.self, forKey: .keyHeight) ?? keyHeight
        columnSpacing = try c.decodeIfPresent(Double.self, forKey: .columnSpacing) ?? columnSpacing
        rowSpacing = try c.decodeIfPresent(Double.self, forKey: .rowSpacing) ?? rowSpacing
        fillGaps = try c.decodeIfPresent(Bool.self, forKey: .fillGaps) ?? fillGaps
        // Tolerate languages this version doesn't know rather than dropping every setting.
        defaultLanguage = (try? c.decodeIfPresent(KeyboardLanguage.self, forKey: .defaultLanguage)) ?? defaultLanguage
        controlHeight = try c.decodeIfPresent(Double.self, forKey: .controlHeight) ?? controlHeight
        letterSize = try c.decodeIfPresent(Double.self, forKey: .letterSize) ?? letterSize
        actionKeyWidth = try c.decodeIfPresent(Double.self, forKey: .actionKeyWidth) ?? actionKeyWidth
        shiftPlacement = try c.decodeIfPresent(ShiftPlacement.self, forKey: .shiftPlacement) ?? shiftPlacement
        showPunctuation = try c.decodeIfPresent(Bool.self, forKey: .showPunctuation) ?? showPunctuation
        showApostrophe = try c.decodeIfPresent(Bool.self, forKey: .showApostrophe) ?? showApostrophe
        showHeader = try c.decodeIfPresent(Bool.self, forKey: .showHeader) ?? showHeader
        autoSpacePunctuation = try c.decodeIfPresent(Bool.self, forKey: .autoSpacePunctuation) ?? autoSpacePunctuation
        yiOnLongPress = try c.decodeIfPresent(Bool.self, forKey: .yiOnLongPress) ?? yiOnLongPress
        autoCapitalize = try c.decodeIfPresent(Bool.self, forKey: .autoCapitalize) ?? autoCapitalize
        doubleSpacePeriod = try c.decodeIfPresent(Bool.self, forKey: .doubleSpacePeriod) ?? doubleSpacePeriod
        digitAccess = (try? c.decodeIfPresent(DigitAccess.self, forKey: .digitAccess)) ?? digitAccess
        glideTyping = try c.decodeIfPresent(Bool.self, forKey: .glideTyping) ?? glideTyping
        theme = try c.decodeIfPresent(KeyboardTheme.self, forKey: .theme) ?? theme
        accent = try c.decodeIfPresent(KeyboardAccent.self, forKey: .accent) ?? accent
        showLongPressHints = try c.decodeIfPresent(Bool.self, forKey: .showLongPressHints) ?? showLongPressHints
        suggestionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .suggestionsEnabled) ?? suggestionsEnabled
        nextWordSuggestions = try c.decodeIfPresent(Bool.self, forKey: .nextWordSuggestions) ?? nextWordSuggestions
        contextualSuggestions = try c.decodeIfPresent(Bool.self, forKey: .contextualSuggestions) ?? contextualSuggestions
        if let codes = try c.decodeIfPresent([String].self, forKey: .languages) {
            languages = codes.compactMap(KeyboardLanguage.init(rawValue:))
        }
        englishLayout = (try? c.decodeIfPresent(EnglishLayout.self, forKey: .englishLayout)) ?? englishLayout
        rememberLanguage = try c.decodeIfPresent(Bool.self, forKey: .rememberLanguage) ?? rememberLanguage
        languageMemoryGeneration = try c.decodeIfPresent(Int.self, forKey: .languageMemoryGeneration) ?? languageMemoryGeneration
        invasionAnswer = (try? c.decodeIfPresent(InvasionAnswer.self, forKey: .invasionAnswer)) ?? invasionAnswer
        // One damaged layout, or one for a language this version doesn't know, costs only itself.
        if let saved = try? c.decodeIfPresent([String: Lossy<CustomLetterLayout>].self, forKey: .customLayouts) {
            for (code, layout) in saved {
                if let language = KeyboardLanguage(rawValue: code), let layout = layout.value { customLayouts[language] = layout }
            }
        }
        if let saved = try? c.decodeIfPresent([Lossy<CustomLayer>].self, forKey: .layers) {
            layers = Array(saved.compactMap(\.value).prefix(CustomLayer.maximumCount))
        }
        showLayerKey = try c.decodeIfPresent(Bool.self, forKey: .showLayerKey) ?? showLayerKey
        keycaps = try? c.decodeIfPresent(KeycapStyle.self, forKey: .keycaps)
        if let saved = try? c.decodeIfPresent([Lossy<TextExpansion>].self, forKey: .expansions) {
            expansions = Array(saved.compactMap(\.value).prefix(TextExpansion.maximumCount))
        }
        extrasEnabled = try c.decodeIfPresent(Bool.self, forKey: .extrasEnabled) ?? extrasEnabled
        // Upgrade the old default height; keep heights the user actually customized.
        if !c.contains(.schemaVersion), keyHeight == 48 { keyHeight = 72 }
        self = validated
    }
}

enum KeyboardPreset: String, CaseIterable, Identifiable {
    case bigLetters, balanced, original
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bigLetters: "Big letters"
        case .balanced: "Balanced"
        case .original: "Original grid"
        }
    }
    var detail: String {
        switch self {
        case .bigLetters: "72 pt letters · wide Return and Delete · Shift before Я / Z"
        case .balanced: "60 pt letters · a little more space for your text"
        case .original: "The original 48 pt grid, with punctuation and header"
        }
    }
    var preferences: KeyboardPreferences {
        switch self {
        case .bigLetters: KeyboardPreferences()
        case .balanced: KeyboardPreferences(keyHeight: 60, columnSpacing: 3, rowSpacing: 4, controlHeight: 48, letterSize: 24, actionKeyWidth: 2)
        case .original: KeyboardPreferences(keyHeight: 48, columnSpacing: 3, rowSpacing: 5, controlHeight: 48,
                                            letterSize: 21, actionKeyWidth: 1.4, shiftPlacement: .controlRow,
                                            showPunctuation: true, showHeader: true)
        }
    }
}

struct KeyCell {
    let key: Key
    let hitFrame: CGRect
    let visualFrame: CGRect
}

enum KeyboardGeometry {
    static let ribbonHeight: Double = 38

    static func cells(width: Double, state: InputState, preferences: KeyboardPreferences,
                      needsGlobe: Bool) -> [KeyCell] {
        guard width > 0 else { return [] }
        let p = preferences.validated
        let rows = KeyboardLayout.rows(state: state, needsGlobe: needsGlobe, preferences: p)
        // Pages without the number row share its height, so the keyboard never jumps.
        let letterHeight = rows.count == 5 || p.numberRowHeight == 0 ? p.keyHeight
            : p.keyHeight + (p.numberRowHeight + p.rowSpacing) / 3
        var rowY = p.headerHeight
        return rows.enumerated().flatMap { row, keys in
            let unit = width / keys.reduce(0) { $0 + $1.weight }
            let keyHeight = row == rows.count - 1 ? p.controlHeight : (rows.count == 5 && row == 0 ? p.numberRowHeight : letterHeight)
            let rowHeight = keyHeight + p.rowSpacing
            defer { rowY += rowHeight }
            var x = 0.0
            return keys.enumerated().map { column, key in
                let right = column == keys.count - 1 ? width : x + unit * key.weight
                let frame = CGRect(x: x, y: rowY, width: right - x, height: rowHeight)
                x = right
                let leftGap = column == 0 ? 0 : p.columnSpacing / 2
                let rightGap = column == keys.count - 1 ? 0 : p.columnSpacing / 2
                let visual = CGRect(x: frame.minX + leftGap, y: frame.minY + p.rowSpacing / 2,
                                    width: frame.width - leftGap - rightGap, height: keyHeight)
                return KeyCell(key: key, hitFrame: p.fillGaps ? frame : visual, visualFrame: visual)
            }
        }
    }

    static func hit(at point: CGPoint, cells: [KeyCell]) -> Int? {
        cells.firstIndex { $0.hitFrame.contains(point) }
    }

    /// At least this far in one direction, and not much across it, types a key's flick.
    static let flickDistance: CGFloat = 18
    static let flickDrift: CGFloat = 22

    /// The flick a swipe from `start` to `point` makes on `cell`, if any. Past the glide
    /// threshold a swipe is left to glide typing, so flicks never swallow a glided word.
    static func flick(on cell: KeyCell, from start: CGPoint, to point: CGPoint) -> (direction: FlickDirection, value: String)? {
        let dx = point.x - start.x, dy = point.y - start.y
        let horizontal = abs(dx) > abs(dy)
        let along = horizontal ? abs(dx) : abs(dy), across = horizontal ? abs(dy) : abs(dx)
        let limit = horizontal ? max(36, cell.hitFrame.width * 1.1) : max(48, cell.hitFrame.height * 0.8)
        guard along >= flickDistance, across < flickDrift, along < limit else { return nil }
        let direction: FlickDirection = horizontal ? (dx < 0 ? .left : .right) : (dy < 0 ? .up : .down)
        return cell.key.flicks[direction].map { (direction, $0) }
    }
}
