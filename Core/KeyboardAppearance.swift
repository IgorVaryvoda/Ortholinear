import Foundation

enum KeyboardTheme: String, Codable, CaseIterable, Sendable {
    case system, light, dark, highContrast, tokyoNight, catppuccin, nord

    var title: String {
        switch self {
        case .system: "Automatic"
        case .light: "Warm Light"
        case .dark: "Soft Dark"
        case .highContrast: "High Contrast"
        case .tokyoNight: "Tokyo Night"
        case .catppuccin: "Catppuccin Mocha"
        case .nord: "Nord"
        }
    }

    var detail: String {
        switch self {
        case .system: "Follows your iPhone"
        case .light: "Paper and warm gray"
        case .dark: "Charcoal and soft white"
        case .highContrast: "Bold edges, clear letters"
        case .tokyoNight: "Midnight blue and neon dusk"
        case .catppuccin: "Soft pastels after dark"
        case .nord: "Arctic blue and frost"
        }
    }
}

enum KeyboardAccent: String, Codable, CaseIterable, Sendable {
    case theme, teal, blue, purple, rose, amber

    var title: String { self == .theme ? "Theme default" : rawValue.capitalized }

    func hex(dark: Bool) -> UInt32? {
        switch self {
        case .theme: nil
        case .teal: dark ? 0x8DD9CA : 0x24786D
        case .blue: dark ? 0x89B4FA : 0x3569B8
        case .purple: dark ? 0xCBA6F7 : 0x8056AD
        case .rose: dark ? 0xF5A9C4 : 0xAA476B
        case .amber: dark ? 0xF5CB8B : 0x996515
        }
    }
}

/// RGB values shared by the renderer, theme swatches, and contrast checks.
struct KeyboardColors: Sendable {
    let background: UInt32
    let key: UInt32
    let control: UInt32
    let text: UInt32
    var secondary: UInt32
    var border: UInt32
    var accent: UInt32
    let isDark: Bool
    var highContrast = false
    /// Legends on modifier keys, when a colorway gives them their own color.
    var controlText: UInt32?
    /// Return's keycap and legend, when a colorway makes it an accent key.
    var accentKey: UInt32?
    var accentKeyText: UInt32?

    static func resolve(theme: KeyboardTheme, accent: KeyboardAccent = .theme,
                        systemDark: Bool, increasedContrast: Bool = false) -> Self {
        var colors: Self
        switch theme {
        case .tokyoNight:
            colors = Self(background: 0x1A1B26, key: 0x24283B, control: 0x1F2335,
                          text: 0xC0CAF5, secondary: 0xA9B1D6, border: 0x414868, accent: 0x7AA2F7, isDark: true)
        case .catppuccin:
            colors = Self(background: 0x1E1E2E, key: 0x313244, control: 0x181825,
                          text: 0xCDD6F4, secondary: 0xBAC2DE, border: 0x45475A, accent: 0xCBA6F7, isDark: true)
        case .nord:
            colors = Self(background: 0x2E3440, key: 0x3B4252, control: 0x343B49,
                          text: 0xECEFF4, secondary: 0xD8DEE9, border: 0x4C566A, accent: 0x88C0D0, isDark: true)
        case .highContrast:
            colors = systemDark
                ? Self(background: 0x000000, key: 0x111111, control: 0x000000,
                       text: 0xFFFFFF, secondary: 0xFFFFFF, border: 0xFFFFFF, accent: 0x8DD9CA, isDark: true)
                : Self(background: 0xFFFFFF, key: 0xFFFFFF, control: 0xF1F1F1,
                       text: 0x000000, secondary: 0x000000, border: 0x000000, accent: 0x24786D, isDark: false)
        case .dark, .light, .system:
            let dark = theme == .dark || (theme == .system && systemDark)
            colors = dark
                ? Self(background: 0x16191E, key: 0x292E37, control: 0x20242C,
                       text: 0xE8EAF0, secondary: 0xB4BDCD, border: 0x3B424E, accent: 0x8CC9BD, isDark: true)
                : Self(background: 0xE9E7E2, key: 0xFBFAF7, control: 0xE1E0DB,
                       text: 0x242630, secondary: 0x4B524C, border: 0xC7CAC3, accent: 0x31766C, isDark: false)
        }
        colors.accent = accent.hex(dark: colors.isDark) ?? colors.accent
        colors.highContrast = theme == .highContrast || increasedContrast
        if colors.highContrast { colors.border = colors.text; colors.secondary = colors.text }
        return colors
    }
}

enum LegendFont: String, Codable, CaseIterable, Sendable {
    case system, rounded, mono, serif
    var title: String {
        switch self {
        case .system: "Default"
        case .rounded: "Rounded"
        case .mono: "Mono"
        case .serif: "Serif"
        }
    }
}

enum KeycapShape: String, Codable, CaseIterable, Sendable {
    case flat, outlined, sculpted
    var title: String { rawValue.capitalized }
}

/// A colorway, the way keycap sets come: letter keys, modifiers and an accent, each with its
/// own legend color. Fixed colors, so it looks the same in light and dark mode.
struct KeycapStyle: Codable, Hashable, Sendable {
    var background: UInt32
    var alpha: UInt32
    var alphaLegend: UInt32
    var modifier: UInt32
    var modifierLegend: UInt32
    var accent: UInt32
    var accentLegend: UInt32
    /// Return in the accent color, like the accent Enter in a keycap set.
    var accentReturn: Bool = true
    var font: LegendFont = .system
    var shape: KeycapShape = .sculpted

    init(background: UInt32, alpha: UInt32, alphaLegend: UInt32, modifier: UInt32, modifierLegend: UInt32,
         accent: UInt32, accentLegend: UInt32, accentReturn: Bool = true, font: LegendFont = .system,
         shape: KeycapShape = .sculpted) {
        (self.background, self.alpha, self.alphaLegend) = (background, alpha, alphaLegend)
        (self.modifier, self.modifierLegend, self.accent, self.accentLegend) = (modifier, modifierLegend, accent, accentLegend)
        (self.accentReturn, self.font, self.shape) = (accentReturn, font, shape)
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func color(_ key: CodingKeys) throws -> UInt32 { try c.decode(UInt32.self, forKey: key) & 0xFFFFFF }
        background = try color(.background)
        alpha = try color(.alpha)
        alphaLegend = try color(.alphaLegend)
        modifier = try color(.modifier)
        modifierLegend = try color(.modifierLegend)
        accent = try color(.accent)
        accentLegend = try color(.accentLegend)
        accentReturn = try c.decodeIfPresent(Bool.self, forKey: .accentReturn) ?? true
        font = (try? c.decodeIfPresent(LegendFont.self, forKey: .font)) ?? .system
        shape = (try? c.decodeIfPresent(KeycapShape.self, forKey: .shape)) ?? .sculpted
    }

    /// Legend-on-keycap pairs below 4.5:1, by role, for the studio to warn about.
    var lowContrast: [String] {
        var roles: [String] = []
        if KeyboardColors.contrast(alphaLegend, alpha) < 4.5 { roles.append("Letters") }
        if KeyboardColors.contrast(modifierLegend, modifier) < 4.5 { roles.append("Modifiers") }
        if accentReturn, KeyboardColors.contrast(accentLegend, accent) < 4.5 { roles.append("Accent") }
        return roles
    }
}

extension KeyboardColors {
    /// A colorway's colors. Hints are the legend softened toward the keycap; borders follow
    /// the keycap shape. Increased Contrast still draws full-strength edges and hints.
    static func resolve(keycaps style: KeycapStyle, increasedContrast: Bool = false) -> Self {
        var colors = Self(background: style.background, key: style.alpha, control: style.modifier,
                          text: style.alphaLegend, secondary: blend(style.alpha, style.alphaLegend, opacity: 0.72),
                          border: style.shape == .outlined ? style.alphaLegend : blend(style.alpha, 0x000000, opacity: 0.18),
                          accent: style.accent, isDark: luminance(style.background) < 0.2)
        colors.controlText = style.modifierLegend
        if style.accentReturn { (colors.accentKey, colors.accentKeyText) = (style.accent, style.accentLegend) }
        colors.highContrast = increasedContrast
        if increasedContrast { colors.border = colors.text; colors.secondary = colors.text }
        return colors
    }

    /// WCAG contrast ratio between two colors.
    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let values = [luminance(a), luminance(b)].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }

    static func luminance(_ rgb: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift -> Double in
            let value = Double((rgb >> shift) & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }

    static func blend(_ background: UInt32, _ foreground: UInt32, opacity: Double) -> UInt32 {
        [16, 8, 0].reduce(0) { result, shift in
            let bg = Double((background >> shift) & 255)
            let fg = Double((foreground >> shift) & 255)
            return result | (UInt32((bg * (1 - opacity) + fg * opacity).rounded()) << shift)
        }
    }
}
