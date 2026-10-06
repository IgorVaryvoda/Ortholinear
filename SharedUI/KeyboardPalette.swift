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
    var font: LegendFont = .system
    var shape: KeycapShape?
    var background: UIColor { UIColor(keyboardHex: colors.background) }
    var key: UIColor { UIColor(keyboardHex: colors.key) }
    var control: UIColor { UIColor(keyboardHex: colors.control) }
    var text: UIColor { UIColor(keyboardHex: colors.text) }
    var secondary: UIColor { UIColor(keyboardHex: colors.secondary) }
    var border: UIColor { UIColor(keyboardHex: colors.border) }
    var accent: UIColor { UIColor(keyboardHex: colors.accent) }
    var controlText: UIColor { colors.controlText.map(UIColor.init(keyboardHex:)) ?? text }

    /// A legend font in the colorway's typeface.
    func legend(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let design: UIFontDescriptor.SystemDesign? = switch font {
        case .system: nil
        case .rounded: .rounded
        case .mono: .monospaced
        case .serif: .serif
        }
        guard let design, let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
    var borderWidth: CGFloat {
        if colors.highContrast { return 1.5 }
        return switch shape { case .flat: 0; case .outlined: 1.2; default: 0.5 }
    }
    var highlightOpacity: CGFloat { colors.highContrast ? 0.12 : 0.16 }
}
