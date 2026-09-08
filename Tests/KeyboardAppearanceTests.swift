import XCTest
@testable import OrtholinearCore

final class KeyboardAppearanceTests: XCTestCase {
    func testThemesAndAccentsKeepLettersAndHintsReadable() {
        for theme in KeyboardTheme.allCases {
            for dark in [false, true] {
                for accent in KeyboardAccent.allCases {
                    let colors = KeyboardColors.resolve(theme: theme, accent: accent, systemDark: dark)
                    for background in [colors.key, colors.control] {
                        XCTAssertGreaterThanOrEqual(contrast(colors.text, background), 4.5, "\(theme) \(accent)")
                        XCTAssertGreaterThanOrEqual(contrast(colors.secondary, background), 4.5, "Hints in \(theme)")
                        let pressed = blend(background, colors.accent, opacity: colors.highContrast ? 0.12 : 0.16)
                        XCTAssertGreaterThanOrEqual(contrast(colors.text, pressed), 4.5, "Pressed \(theme) \(accent)")
                        XCTAssertGreaterThanOrEqual(contrast(colors.secondary, pressed), 4.5, "Pressed hints in \(theme) \(accent)")
                        if colors.highContrast {
                            XCTAssertGreaterThanOrEqual(contrast(colors.text, background), 7)
                        }
                    }
                }
            }
        }
    }

    func testAutomaticAndExplicitThemesRespectAppearance() {
        XCTAssertFalse(KeyboardColors.resolve(theme: .system, systemDark: false).isDark)
        XCTAssertTrue(KeyboardColors.resolve(theme: .system, systemDark: true).isDark)
        XCTAssertFalse(KeyboardColors.resolve(theme: .light, systemDark: true).isDark)
        XCTAssertTrue(KeyboardColors.resolve(theme: .dark, systemDark: false).isDark)
        XCTAssertEqual(KeyboardColors.resolve(theme: .tokyoNight, systemDark: false).background, 0x1A1B26)
        let increased = KeyboardColors.resolve(theme: .nord, systemDark: true, increasedContrast: true)
        XCTAssertEqual(increased.border, increased.text)
        XCTAssertEqual(increased.secondary, increased.text)
    }

    func testAppearancePersistsAndGeometryPresetsKeepIt() throws {
        var preferences = KeyboardPreferences()
        preferences.theme = .tokyoNight
        preferences.accent = .rose
        preferences.showLongPressHints = false
        XCTAssertEqual(try JSONDecoder().decode(KeyboardPreferences.self, from: JSONEncoder().encode(preferences)), preferences)
        for preset in KeyboardPreset.allCases {
            preferences.apply(preset)
            XCTAssertEqual(preferences.theme, .tokyoNight)
            XCTAssertEqual(preferences.accent, .rose)
            XCTAssertFalse(preferences.showLongPressHints)
        }
        let legacy = try JSONDecoder().decode(KeyboardPreferences.self, from: Data(#"{"schemaVersion":2,"yiOnLongPress":true,"keyHeight":65}"#.utf8))
        XCTAssertEqual(legacy.theme, .system)
        XCTAssertEqual(legacy.accent, .theme)
        XCTAssertTrue(legacy.showLongPressHints)
        XCTAssertTrue(legacy.yiOnLongPress)
        XCTAssertEqual(legacy.keyHeight, 65)
    }

    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let values = [luminance(a), luminance(b)].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }

    private func luminance(_ rgb: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift -> Double in
            let value = Double((rgb >> shift) & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }

    private func blend(_ background: UInt32, _ foreground: UInt32, opacity: Double) -> UInt32 {
        [16, 8, 0].reduce(0) { result, shift in
            let bg = Double((background >> shift) & 255)
            let fg = Double((foreground >> shift) & 255)
            return result | (UInt32((bg * (1 - opacity) + fg * opacity).rounded()) << shift)
        }
    }
}
