import Foundation
import CoreGraphics

enum KeyboardLanguage: String, Codable, CaseIterable, Sendable {
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

enum KeyboardPage: Sendable { case letters, numbers, symbols }
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
}

struct Key: Sendable {
    let action: KeyAction
    var weight: Double = 1
    var letterAlternatives: [String] = []
    var alternatives: [String] {
        guard case .text(let value) = action else { return [] }
        switch value {
        case ".": return [".", "…", "!", "?"]
        case ",": return [",", ";", ":"]
        case "'": return ["'", "’", "ʼ", "\""]
        case "-": return ["-", "–", "—", "_"]
        case "\"": return ["\"", "«", "»", "“", "”"]
        case "?": return ["?", "!", "¿"]
        default: return letterAlternatives
        }
    }
}

enum KeyboardLayout {
    static func rows(state: InputState, needsGlobe: Bool, preferences: KeyboardPreferences = .init()) -> [[Key]] {
        let strings: [String]
        switch state.page {
        case .letters: strings = letterRows(state.language, preferences: preferences)
        case .numbers:
            strings = ["1234567890", "-/:;()$&@\"", ".,?!'[]=+%"]
        case .symbols:
            strings = ["[]{}#%^*+=", "_\\|~<>€£¥•", ".,?!'`:;₴…"]
        }
        var result = strings.map { row in
            row.map { character in
                Key(action: .text(String(character)),
                    letterAlternatives: state.page == .letters ? letterAlternatives(character, language: state.language, preferences: preferences) : [])
            }
        }
        // Delete follows the last letter, ahead of any optional punctuation.
        if state.page == .letters, let lastLetter = result[2].lastIndex(where: { key in
            guard case .text(let value) = key.action else { return false }
            return value == "'" || value.first?.isLetter == true
        }) {
            result[2].insert(Key(action: .backspace, weight: preferences.validated.actionKeyWidth), at: lastLetter + 1)
        }
        var controls: [Key] = [Key(action: .page, weight: 1.35)]
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
        return result
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
    let schemaVersion = 3
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

    enum CodingKeys: String, CodingKey {
        case schemaVersion, keyHeight, columnSpacing, rowSpacing, fillGaps, defaultLanguage
        case controlHeight, letterSize, actionKeyWidth, shiftPlacement, showPunctuation, showApostrophe, showHeader, autoSpacePunctuation
        case yiOnLongPress
        case theme, accent, showLongPressHints
        case suggestionsEnabled, nextWordSuggestions, contextualSuggestions
        case languages, englishLayout, rememberLanguage, languageMemoryGeneration, invasionAnswer
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
    var suggestionHeight: Double { suggestionsEnabled ? 44 : 0 }
    var headerHeight: Double { suggestionHeight + (showHeader ? KeyboardGeometry.ribbonHeight : 0) }
    var keyboardHeight: Double {
        let p = validated
        return p.headerHeight + 3 * (p.keyHeight + p.rowSpacing) + p.controlHeight + p.rowSpacing
    }

    mutating func apply(_ preset: KeyboardPreset) {
        let language = (defaultLanguage, languages, englishLayout, rememberLanguage, languageMemoryGeneration, invasionAnswer)
        let appearance = (theme, accent, showLongPressHints)
        let suggestions = (suggestionsEnabled, nextWordSuggestions, contextualSuggestions)
        self = preset.preferences
        (defaultLanguage, languages, englishLayout, rememberLanguage, languageMemoryGeneration, invasionAnswer) = language
        (theme, accent, showLongPressHints) = appearance
        (suggestionsEnabled, nextWordSuggestions, contextualSuggestions) = suggestions
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
        return KeyboardLayout.rows(state: state, needsGlobe: needsGlobe, preferences: p).enumerated().flatMap { row, keys in
            let unit = width / keys.reduce(0) { $0 + $1.weight }
            let keyHeight = row == 3 ? p.controlHeight : p.keyHeight
            let rowHeight = keyHeight + p.rowSpacing
            let rowY = p.headerHeight + Double(row) * (p.keyHeight + p.rowSpacing)
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
}
