import Foundation
import CoreGraphics

enum KeyboardLanguage: String, Codable, CaseIterable, Sendable {
    case ukrainian, english
    var title: String { self == .ukrainian ? "Українська" : "English" }
    var badge: String { self == .ukrainian ? "UA" : "EN" }
    var code: String { self == .ukrainian ? "uk-UA" : "en-US" }
    var next: Self { self == .ukrainian ? .english : .ukrainian }
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
        let result = shift == .off ? value : value.uppercased()
        if value.lowercased() != value.uppercased() {
            if shift == .once { shift = .off }
            lastShiftTap = nil
        }
        return result
    }
}

enum KeyAction: Hashable, Sendable {
    case text(String), shift, backspace, space, enter, language, page, globe, dismiss, voice
}

struct Key: Sendable {
    let action: KeyAction
    var weight: Double = 1
    var alternatives: [String] {
        guard case .text(let value) = action else { return [] }
        switch value {
        case "г": return ["ґ"]
        case ".": return [".", "…", "!", "?"]
        case ",": return [",", ";", ":"]
        case "'": return ["'", "’", "ʼ", "\""]
        case "-": return ["-", "–", "—", "_"]
        case "\"": return ["\"", "«", "»", "“", "”"]
        case "?": return ["?", "!", "¿"]
        default: return []
        }
    }
}

enum KeyboardLayout {
    static func rows(state: InputState, needsGlobe: Bool, preferences: KeyboardPreferences = .init()) -> [[Key]] {
        let strings: [String]
        switch state.page {
        case .letters:
            let apostrophe = preferences.showApostrophe ? "'" : ""
            strings = state.language == .ukrainian
                ? ["йцукенгшщзхї", "фівапролджє", "ячсмитьбю" + (preferences.showPunctuation ? ".," : "") + apostrophe]
                : ["qwertyuiop", "asdfghjkl" + apostrophe, "zxcvbnm" + (preferences.showPunctuation ? ".,?" : "")]
        case .numbers:
            strings = ["1234567890", "-/:;()$&@\"", ".,?!'[]=+%"]
        case .symbols:
            strings = ["[]{}#%^*+=", "_\\|~<>€£¥•", ".,?!'`:;₴…"]
        }
        var result = strings.map { $0.map { Key(action: .text(String($0))) } }
        var controls: [Key] = []
        if state.page == .letters && preferences.shiftPlacement == .beforeLastRow {
            result[2].insert(Key(action: .shift, weight: 0.8), at: 0)
        } else {
            controls.append(Key(action: .shift, weight: 1.25))
        }
        controls.append(Key(action: .page, weight: 1.35))
        if needsGlobe { controls.append(Key(action: .globe)) }
        controls += [Key(action: .language, weight: 1.25), Key(action: .space, weight: 3.8),
                     Key(action: .enter, weight: preferences.validated.actionKeyWidth),
                     Key(action: .backspace, weight: preferences.validated.actionKeyWidth)]
        controls.append(Key(action: .voice, weight: 0.9))
        result.append(controls)
        return result
    }
}

struct KeyboardPreferences: Codable, Equatable, Sendable {
    let schemaVersion = 2
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

    enum CodingKeys: String, CodingKey {
        case schemaVersion, keyHeight, columnSpacing, rowSpacing, fillGaps, defaultLanguage
        case controlHeight, letterSize, actionKeyWidth, shiftPlacement, showPunctuation, showApostrophe, showHeader
    }

    var validated: Self {
        var result = self
        result.keyHeight = keyHeight.isFinite ? min(88, max(36, keyHeight)) : 72
        result.controlHeight = controlHeight.isFinite ? min(72, max(36, controlHeight)) : 56
        result.letterSize = letterSize.isFinite ? min(36, max(18, letterSize)) : 28
        result.actionKeyWidth = actionKeyWidth.isFinite ? min(3.5, max(1.25, actionKeyWidth)) : 2.4
        result.columnSpacing = columnSpacing.isFinite ? min(8, max(0, columnSpacing)) : 2
        result.rowSpacing = rowSpacing.isFinite ? min(12, max(0, rowSpacing)) : 3
        return result
    }
    var headerHeight: Double { showHeader ? KeyboardGeometry.ribbonHeight : 0 }
    var keyboardHeight: Double {
        let p = validated
        return p.headerHeight + 3 * (p.keyHeight + p.rowSpacing) + p.controlHeight + p.rowSpacing
    }

    mutating func apply(_ preset: KeyboardPreset) {
        let language = defaultLanguage
        self = preset.preferences
        defaultLanguage = language
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
        defaultLanguage = try c.decodeIfPresent(KeyboardLanguage.self, forKey: .defaultLanguage) ?? defaultLanguage
        controlHeight = try c.decodeIfPresent(Double.self, forKey: .controlHeight) ?? controlHeight
        letterSize = try c.decodeIfPresent(Double.self, forKey: .letterSize) ?? letterSize
        actionKeyWidth = try c.decodeIfPresent(Double.self, forKey: .actionKeyWidth) ?? actionKeyWidth
        shiftPlacement = try c.decodeIfPresent(ShiftPlacement.self, forKey: .shiftPlacement) ?? shiftPlacement
        showPunctuation = try c.decodeIfPresent(Bool.self, forKey: .showPunctuation) ?? showPunctuation
        showApostrophe = try c.decodeIfPresent(Bool.self, forKey: .showApostrophe) ?? showApostrophe
        showHeader = try c.decodeIfPresent(Bool.self, forKey: .showHeader) ?? showHeader
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
