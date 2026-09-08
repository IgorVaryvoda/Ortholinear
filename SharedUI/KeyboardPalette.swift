import UIKit

extension UIColor {
    convenience init(keyboardHex value: UInt32) {
        self.init(red: CGFloat((value >> 16) & 255) / 255,
                  green: CGFloat((value >> 8) & 255) / 255,
                  blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}

struct KeyboardPalette {
    let colors: KeyboardColors
    var background: UIColor { UIColor(keyboardHex: colors.background) }
    var key: UIColor { UIColor(keyboardHex: colors.key) }
    var control: UIColor { UIColor(keyboardHex: colors.control) }
    var text: UIColor { UIColor(keyboardHex: colors.text) }
    var secondary: UIColor { UIColor(keyboardHex: colors.secondary) }
    var border: UIColor { UIColor(keyboardHex: colors.border) }
    var accent: UIColor { UIColor(keyboardHex: colors.accent) }
    var borderWidth: CGFloat { colors.highContrast ? 1.5 : 0.5 }
    var highlightOpacity: CGFloat { colors.highContrast ? 0.12 : 0.16 }
}
