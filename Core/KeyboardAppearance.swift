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
