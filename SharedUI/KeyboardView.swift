import UIKit

@MainActor
final class AccessibleKey: UIView {
    var activate: (() -> Void)?
    override func accessibilityActivate() -> Bool { activate?(); return true }
}

/// A single touch surface owns the complete grid, including the visual gutters.
@MainActor
final class KeyboardView: UIControl {
    var inputState = InputState() { didSet { refresh() } }
    var preferences = KeyboardPreferences() { didSet { setNeedsLayout() } }
    var needsGlobe = true { didSet { setNeedsLayout() } }
    var returnTitle = "return" { didSet { refresh() } }
    var returnEnabled = true { didSet { refresh() } }
    var onAction: ((KeyAction) -> Void)?
    var onCursor: ((Int) -> Void)?
    var onDismiss: (() -> Void)?
    let globeButton = UIButton(type: .custom)
    private let dismissButton = UIButton(type: .custom)
    private(set) var cells: [KeyCell] = []
    private var sessions: [ObjectIdentifier: TouchSession] = [:]
    private var popup: (owner: ObjectIdentifier, values: [String], selected: Int)?
    private var accessibleKeys: [AccessibleKey] = []

    private struct TouchSession {
        var cell: Int
        let original: KeyAction
        let start: CGPoint
        var cursorSteps = 0
        var cursorMode = false
        var timer: Timer?
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
        isOpaque = true
        backgroundColor = .systemGray5
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: KeyboardView, _: UITraitCollection) in
            view.setNeedsDisplay()
        }
        accessibilityIdentifier = "keyboard-surface"
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.tintColor = .label
        globeButton.accessibilityLabel = "Next keyboard"
        globeButton.accessibilityIdentifier = "key-globe"
        addSubview(globeButton)
        dismissButton.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        dismissButton.tintColor = .secondaryLabel
        dismissButton.accessibilityLabel = "Dismiss keyboard"
        dismissButton.addAction(UIAction { [weak self] _ in self?.onDismiss?() }, for: .touchUpInside)
        addSubview(dismissButton)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: preferences.keyboardHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let newCells = KeyboardGeometry.cells(width: bounds.width, state: inputState,
                                              preferences: preferences, needsGlobe: needsGlobe)
        // Rotation and settings changes must not leave an old repeat timer running.
        if cells.map(\.hitFrame) != newCells.map(\.hitFrame) { cancelTouches() }
        cells = newCells
        globeButton.isHidden = !needsGlobe
        globeButton.frame = cells.first(where: { $0.key.action == .globe })?.hitFrame ?? .zero
        dismissButton.frame = CGRect(x: bounds.width - 44, y: 0, width: 44, height: 38)
        dismissButton.isHidden = !preferences.showHeader || popup != nil
        rebuildAccessibility()
        setNeedsDisplay()
    }

    private func refresh() {
        setNeedsLayout()
        setNeedsDisplay()
    }

    func cancelTouches() {
        for session in sessions.values { session.timer?.invalidate() }
        sessions.removeAll()
        popup = nil
        dismissButton.isHidden = !preferences.showHeader
        setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { cancelTouches() }
    }

    private func title(_ action: KeyAction) -> String {
        switch action {
        case .text(let text): return inputState.shift == .off ? text : text.uppercased()
        case .shift: return inputState.page == .letters ? (inputState.shift == .locked ? "⇪" : "⇧") : (inputState.page == .numbers ? "#+=" : "123")
        case .backspace: return "⌫"
        case .space: return inputState.language.title
        case .enter: return returnTitle
        case .language: return inputState.language.next.badge
        case .page: return inputState.page == .letters ? "123" : "ABC"
        case .globe: return ""
        case .dismiss: return "⌄"
        }
    }

    private func accessibilityName(_ action: KeyAction) -> String {
        switch action {
        case .shift: return inputState.page == .letters ? "Shift" : (inputState.page == .numbers ? "More symbols" : "Numbers")
        case .backspace: return "Delete"
        case .space: return "Space"
        case .enter: return "Return"
        case .language: return "Switch to \(inputState.language.next.title)"
        case .page: return inputState.page == .letters ? "Numbers" : "Letters"
        case .dismiss: return "Dismiss keyboard"
        default: return title(action)
        }
    }

    private func rebuildAccessibility() {
        let accessibleCells = cells.filter { $0.key.action != .globe }
        if accessibleKeys.count != accessibleCells.count {
            accessibleKeys.forEach { $0.removeFromSuperview() }
            accessibleKeys = accessibleCells.map { _ in
                let element = AccessibleKey()
                element.isAccessibilityElement = true
                // Native views preserve screen coordinates across the keyboard's remote
                // view-service boundary. Touches still go to the single grid router.
                element.isUserInteractionEnabled = false
                addSubview(element)
                return element
            }
        }
        var elements: [Any] = accessibleCells.enumerated().map { index, cell in
            let element = accessibleKeys[index]
            element.frame = cell.hitFrame
            element.accessibilityLabel = accessibilityName(cell.key.action)
            element.accessibilityIdentifier = "key-\(accessibilityName(cell.key.action))"
            element.accessibilityTraits = [.keyboardKey, .button]
            element.accessibilityValue = nil
            if cell.key.action == .enter && !returnEnabled { element.accessibilityTraits.insert(.notEnabled) }
            if cell.key.action == .shift && inputState.shift != .off {
                element.accessibilityValue = inputState.shift == .locked ? "Caps lock" : "On"
            }
            element.activate = { [weak self] in self?.emit(cell.key.action) }
            element.accessibilityCustomActions = cell.key.alternatives.map { value in
                UIAccessibilityCustomAction(name: "Type \(title(.text(value)))") { [weak self] _ in
                    self?.emit(.text(value)); return true
                }
            }
            return element
        }
        if needsGlobe { elements.append(globeButton) }
        if preferences.showHeader { elements.append(dismissButton) }
        accessibilityElements = elements
    }

    private func emit(_ action: KeyAction) {
        guard action != .enter || returnEnabled else { return }
        onAction?(action)
    }

    override func draw(_ rect: CGRect) {
        backgroundColor?.setFill()
        UIRectFill(bounds)
        let active = Set(sessions.values.map(\.cell))
        for (index, cell) in cells.enumerated() {
            let isText: Bool
            if case .text = cell.key.action { isText = true } else { isText = cell.key.action == .space }
            let selectedShift = cell.key.action == .shift && inputState.page == .letters && inputState.shift != .off
            let fill: UIColor = active.contains(index) || selectedShift ? .systemTeal : (isText ? .secondarySystemGroupedBackground : .systemGray4)
            fill.setFill()
            UIBezierPath(roundedRect: cell.visualFrame, cornerRadius: 4).fill()
            if cell.key.action == .dismiss {
                let icon = UIImage(systemName: "keyboard.chevron.compact.down")?.withTintColor(.label, renderingMode: .alwaysOriginal)
                icon?.draw(in: CGRect(x: cell.visualFrame.midX - 11, y: cell.visualFrame.midY - 10, width: 22, height: 20))
                continue
            }
            let label = cell.key.action == .space && sessions.values.contains(where: \.cursorMode) ? "↔" : title(cell.key.action)
            let small = label.count > 2
            let textColor: UIColor = cell.key.action == .enter && !returnEnabled ? .tertiaryLabel : .label
            var size: CGFloat = small ? 13 : 21
            if cell.key.action == .enter { size = min(17, max(13, cell.visualFrame.width / 4.4)) }
            if cell.key.action == .backspace { size = 26 }
            if case .text = cell.key.action {
                size = min(preferences.validated.letterSize, max(14, cell.visualFrame.width - 3))
            }
            drawText(label, in: cell.visualFrame, font: .systemFont(ofSize: size,
                     weight: isText ? .regular : .medium), color: textColor)
        }
        if let popup {
            let width = min(bounds.width - 12, CGFloat(popup.values.count) * 52)
            let origin = (bounds.width - width) / 2
            for (index, value) in popup.values.enumerated() {
                let frame = CGRect(x: origin + CGFloat(index) * width / CGFloat(popup.values.count),
                                   y: 2, width: width / CGFloat(popup.values.count), height: 34)
                (index == popup.selected ? UIColor.systemTeal : UIColor.secondarySystemGroupedBackground).setFill()
                UIBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 0), cornerRadius: 5).fill()
                drawText(title(.text(value)), in: frame, font: .systemFont(ofSize: 22), color: .label)
            }
        } else if preferences.showHeader {
            let text = sessions.values.contains(where: \.cursorMode) ? "Slide to move cursor" : "\(inputState.language.badge)  ·  ORTHOLINEAR"
            drawText(text, in: CGRect(x: 10, y: 0, width: bounds.width - 64, height: 38),
                     font: .monospacedSystemFont(ofSize: 10, weight: .medium), color: .secondaryLabel, alignment: .left)
        }
    }

    private func drawText(_ string: String, in frame: CGRect, font: UIFont, color: UIColor,
                          alignment: NSTextAlignment = .center) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let y = frame.midY - font.lineHeight / 2
        (string as NSString).draw(in: CGRect(x: frame.minX, y: y, width: frame.width, height: font.lineHeight + 2),
                                 withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            guard let index = KeyboardGeometry.hit(at: point, cells: cells) else { continue }
            let id = ObjectIdentifier(touch)
            let key = cells[index].key
            sessions[id] = TouchSession(cell: index, original: key.action, start: point)
            if key.action == .backspace { emit(.backspace) }
            if key.action == .backspace || !key.alternatives.isEmpty {
                let timer = Timer(timeInterval: 0.42, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated { self?.beginHold(id: id, key: key) }
                }
                sessions[id]?.timer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
        }
        setNeedsDisplay()
    }

    private func beginHold(id: ObjectIdentifier, key: Key) {
        guard sessions[id] != nil else { return }
        if key.action == .backspace {
            emit(.backspace)
            let timer = Timer(timeInterval: 0.075, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.sessions[id] != nil else { return }
                    self.emit(.backspace)
                }
            }
            sessions[id]?.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else if popup == nil {
            popup = (id, key.alternatives, 0)
            dismissButton.isHidden = true
            setNeedsDisplay()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard var session = sessions[id] else { continue }
            let point = touch.location(in: self)
            if var current = popup, current.owner == id {
                let width = min(bounds.width - 12, CGFloat(current.values.count) * 52)
                let origin = (bounds.width - width) / 2
                // Drag up into the ribbon to choose an alternative; release in place for the first.
                if point.y < KeyboardGeometry.ribbonHeight {
                    current.selected = min(current.values.count - 1, max(0, Int((point.x - origin) / (width / CGFloat(current.values.count)))))
                    popup = current
                }
                continue
            }
            if session.original == .space {
                let delta = point.x - session.start.x
                if abs(delta) >= 12 { session.cursorMode = true }
                if session.cursorMode {
                    let steps = Int(delta / 12)
                    let offset = steps - session.cursorSteps
                    if offset != 0 { onCursor?(offset) }
                    session.cursorSteps = steps
                    sessions[id] = session
                    continue
                }
            }
            let index = KeyboardGeometry.hit(at: point, cells: cells)
            if index != session.cell {
                session.timer?.invalidate()
                session.timer = nil
                session.cell = index ?? -1
                sessions[id] = session
            }
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let session = sessions.removeValue(forKey: id) else { continue }
            session.timer?.invalidate()
            if let current = popup, current.owner == id {
                let isInside = bounds.contains(touch.location(in: self))
                popup = nil
                dismissButton.isHidden = !preferences.showHeader
                if isInside { emit(.text(current.values[current.selected])) }
            } else if !session.cursorMode && session.original != .backspace,
                      let index = KeyboardGeometry.hit(at: touch.location(in: self), cells: cells) {
                emit(cells[index].key.action)
            }
        }
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            sessions.removeValue(forKey: id)?.timer?.invalidate()
            if popup?.owner == id { popup = nil; dismissButton.isHidden = !preferences.showHeader }
        }
        setNeedsDisplay()
    }
}
