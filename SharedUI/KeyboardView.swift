import UIKit

@MainActor
final class AccessibleKey: UIView {
    var activate: (() -> Void)?
    override func accessibilityActivate() -> Bool { activate?(); return true }
}

@MainActor
final class FeedbackButton: UIButton {
    var highlightChanged: (() -> Void)?
    override var isHighlighted: Bool {
        didSet { if oldValue != isHighlighted { highlightChanged?() } }
    }
}

/// Gestures the in-app preview checks off as someone tries them.
enum KeyboardGesture: String, CaseIterable, Sendable {
    case alternative, symbolSlide, spaceCursor, flick, glide
}

/// A single touch surface owns the complete grid, including the visual gutters.
@MainActor
final class KeyboardView: UIControl {
    var inputState = InputState() {
        didSet {
            if oldValue.page != inputState.page || oldValue.language != inputState.language { cancelTouches() }
            if oldValue.page != inputState.page || oldValue.language != inputState.language || oldValue.shift != inputState.shift { refresh() }
        }
    }
    var preferences = KeyboardPreferences() {
        didSet { if oldValue != preferences { cancelTouches(); setNeedsLayout() } }
    }
    var needsGlobe = true {
        didSet { if oldValue != needsGlobe { cancelTouches(); setNeedsLayout() } }
    }
    var returnTitle = "return" { didSet { if oldValue != returnTitle { refresh() } } }
    var returnEnabled = true { didSet { if oldValue != returnEnabled { refresh() } } }
    /// Hosts turn this on only for languages and fields that can decode a trace.
    var glideEnabled = false { didSet { if !glideEnabled { for id in sessions.keys { sessions[id]?.trace = nil } } } }
    var onAction: ((KeyAction) -> Void)?
    var onCursor: ((Int) -> Void)?
    var onDismiss: (() -> Void)?
    var onGlide: (([CGPoint]) -> Void)?
    var onGesture: ((KeyboardGesture) -> Void)?
    let suggestionBar = SuggestionBar()
    let globeButton = FeedbackButton(type: .custom)
    private let dismissButton = FeedbackButton(type: .custom)
    private(set) var cells: [KeyCell] = []
    private var sessions: [ObjectIdentifier: TouchSession] = [:]
    // Hiding the opaque suggestion row here, not in layout: a hold changes no geometry,
    // so the popup would otherwise be drawn underneath the row.
    private var popup: (owner: ObjectIdentifier, values: [String], selected: Int)? {
        didSet { if (oldValue == nil) != (popup == nil) { updateChrome(); setNeedsLayout() } }
    }
    private var accessibleKeys: [AccessibleKey] = []
    private var layoutSize: CGSize = .zero
    private var releasedKeys: [KeyAction: TimeInterval] = [:]
    private var feedbackTimer: Timer?
    private var symbolSlide: (owner: ObjectIdentifier, page: KeyboardPage, began: TimeInterval, moved: Bool)?

    private var displayState: InputState {
        var state = inputState
        if let symbolSlide { state.page = symbolSlide.page }
        return state
    }

    private struct TouchSession {
        var cell: Int
        let original: KeyAction
        let start: CGPoint
        var began = ProcessInfo.processInfo.systemUptime
        var cursorSteps = 0
        var cursorMode = false
        var timer: Timer?
        var startCell: Int
        var flick: String?
        /// Recorded while a glide is still possible; nil once it can't be one.
        var trace: [CGPoint]?
        var pathLength: CGFloat = 0
        var glide = false

        init(cell: Int, original: KeyAction, start: CGPoint) {
            self.cell = cell; self.original = original; self.start = start; startCell = cell
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
        isOpaque = true
        backgroundColor = .systemGray5
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (view: KeyboardView, _: UITraitCollection) in
            view.setNeedsLayout()
            view.setNeedsDisplay()
        }
        accessibilityIdentifier = "keyboard-surface"
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.tintColor = palette.text
        globeButton.accessibilityLabel = "Next keyboard"
        globeButton.accessibilityIdentifier = "key-globe"
        globeButton.highlightChanged = { [weak self] in self?.nativeHighlightChanged(.globe) }
        addSubview(globeButton)
        dismissButton.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        dismissButton.tintColor = palette.secondary
        dismissButton.accessibilityLabel = "Dismiss keyboard"
        dismissButton.accessibilityIdentifier = "key-header-dismiss"
        dismissButton.highlightChanged = { [weak self] in self?.nativeHighlightChanged(.dismiss) }
        dismissButton.addAction(UIAction { [weak self] _ in self?.onDismiss?() }, for: .touchUpInside)
        addSubview(dismissButton)
        addSubview(suggestionBar)
        // Strip punctuation types like its key, so automatic spacing still applies.
        suggestionBar.onPunctuation = { [weak self] in self?.emit(.text($0), feedback: false) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: preferences.keyboardHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Only physical geometry changes cancel a slide. Switching pages is part of it.
        if layoutSize != bounds.size { cancelTouches(); layoutSize = bounds.size }
        cells = KeyboardGeometry.cells(width: bounds.width, state: displayState,
                                       preferences: preferences, needsGlobe: needsGlobe)
        globeButton.isHidden = !needsGlobe
        globeButton.frame = cells.first(where: { $0.key.action == .globe })?.hitFrame ?? .zero
        suggestionBar.frame = CGRect(x: 0, y: preferences.showHeader ? 38 : 0, width: bounds.width, height: preferences.suggestionHeight)
        suggestionBar.style(palette)
        dismissButton.frame = CGRect(x: bounds.width - 44, y: 0, width: 44, height: 38)
        updateChrome()
        globeButton.tintColor = palette.text
        dismissButton.tintColor = palette.secondary
        backgroundColor = palette.background
        accessibilityValue = "\(preferences.theme.title), \(preferences.accent.title)"
        rebuildAccessibility()
        setNeedsDisplay()
    }

    private func refresh() {
        setNeedsLayout()
        setNeedsDisplay()
    }

    private func updateChrome() {
        suggestionBar.isHidden = !preferences.suggestionsEnabled || popup != nil
        dismissButton.isHidden = !preferences.showHeader || popup != nil
    }

    func cancelTouches() {
        for session in sessions.values { session.timer?.invalidate() }
        sessions.removeAll()
        symbolSlide = nil
        releasedKeys.removeAll()
        feedbackTimer?.invalidate()
        feedbackTimer = nil
        popup = nil
        setNeedsLayout()
        setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { cancelTouches() }
    }

    private func title(_ action: KeyAction) -> String {
        switch action {
        case .text(let text): return displayState.shift == .off || displayState.page.isLayer ? text : text.shifted
        case .shift:
            guard displayState.page == .letters else { return KeyboardLayout.pageTitle(nextPage, preferences: preferences) }
            return displayState.shift == .locked ? "⇪" : "⇧"
        case .backspace: return "⌫"
        case .space:
            let language = displayState.language
            let layout = preferences.englishLayout
            return language == .english && layout != .qwerty ? "\(language.title) · \(layout.title)" : language.title
        case .enter: return returnTitle
        case .language: return nextLanguage.badge
        case .page: return displayState.page == .letters ? "123" : "ABC"
        case .globe: return ""
        case .dismiss: return "⌄"
        case .layers: return KeyboardLayout.firstLayerPage(preferences).map { KeyboardLayout.pageTitle($0, preferences: preferences) } ?? ""
        case .command(let command): return command.symbol
        case .pair(let text, _): return text
        }
    }

    /// Where the #+= / 123 key leads from the current non-letter page.
    private var nextPage: KeyboardPage { KeyboardLayout.page(after: displayState.page, preferences: preferences) }

    private var nextLanguage: KeyboardLanguage { preferences.language(after: displayState.language) }

    private func accessibilityName(_ action: KeyAction) -> String {
        switch action {
        case .shift: return displayState.page == .letters ? "Shift" : KeyboardLayout.pageName(nextPage, preferences: preferences)
        case .backspace: return "Delete"
        case .space: return "Space"
        case .enter: return "Return"
        case .language: return "Switch to \(nextLanguage.title)"
        case .page: return displayState.page == .letters ? "Numbers" : "Letters"
        case .dismiss: return "Dismiss keyboard"
        case .layers: return KeyboardLayout.firstLayerPage(preferences).map { KeyboardLayout.pageName($0, preferences: preferences) } ?? "Layers"
        case .command(let command): return command.title
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
            let name = cell.key.label ?? accessibilityName(cell.key.action)
            element.accessibilityLabel = name
            element.accessibilityIdentifier = "key-\(name)"
            element.accessibilityTraits = [.keyboardKey, .button]
            element.accessibilityValue = nil
            if cell.key.action == .enter && !returnEnabled { element.accessibilityTraits.insert(.notEnabled) }
            if cell.key.action == .shift && displayState.shift != .off {
                element.accessibilityValue = displayState.shift == .locked ? "Caps lock" : "On"
            }
            element.activate = { [weak self] in self?.emit(cell.key.action) }
            let flicks = FlickDirection.allCases.compactMap { cell.key.flicks[$0] }
            element.accessibilityCustomActions = (cell.key.alternatives + flicks).map { value in
                UIAccessibilityCustomAction(name: "Type \(title(.text(value)))") { [weak self] _ in
                    self?.emit(.text(value)); return true
                }
            }
            return element
        }
        if needsGlobe { elements.append(globeButton) }
        if preferences.showHeader { elements.append(dismissButton) }
        if preferences.suggestionsEnabled && popup == nil { elements.insert(suggestionBar, at: 0) }
        accessibilityElements = elements
    }

    private func emit(_ action: KeyAction, feedback: Bool = true) {
        guard action != .enter || returnEnabled else { return }
        onAction?(action)
        if feedback { flash(action) }
    }

    private func nativeHighlightChanged(_ action: KeyAction) {
        let button = action == .globe ? globeButton : dismissButton
        if !button.isHighlighted { flash(action) }
        setNeedsDisplay()
    }

    // A short color fade makes even quick taps visible, without moving key frames.
    // One timer services all releases; a new press always takes precedence over a fade.
    private func flash(_ action: KeyAction) {
        releasedKeys[action] = ProcessInfo.processInfo.systemUptime
        if feedbackTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let now = ProcessInfo.processInfo.systemUptime
                    self.releasedKeys = self.releasedKeys.filter { now - $0.value < 0.14 }
                    self.setNeedsDisplay()
                    if self.releasedKeys.isEmpty { self.feedbackTimer?.invalidate(); self.feedbackTimer = nil }
                }
            }
            feedbackTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        setNeedsDisplay()
    }

    private func feedbackOpacity(for action: KeyAction) -> CGFloat {
        guard let began = releasedKeys[action] else { return 0 }
        let elapsed = ProcessInfo.processInfo.systemUptime - began
        if UIAccessibility.isReduceMotionEnabled { return elapsed < 0.14 ? 1 : 0 }
        return max(0, 1 - elapsed / 0.14)
    }

    private var palette: KeyboardPalette {
        let increasedContrast = traitCollection.accessibilityContrast == .high
        if let keycaps = preferences.shownKeycaps {
            return KeyboardPalette(colors: .resolve(keycaps: keycaps, increasedContrast: increasedContrast),
                                   font: keycaps.font, shape: keycaps.shape)
        }
        return KeyboardPalette(colors: .resolve(theme: preferences.theme, accent: preferences.accent,
                                                systemDark: traitCollection.userInterfaceStyle == .dark,
                                                increasedContrast: increasedContrast))
    }

    override func draw(_ rect: CGRect) {
        let palette = palette
        palette.background.setFill()
        UIRectFill(bounds)
        var active = Set(sessions.values.map(\.cell))
        if globeButton.isHighlighted, let index = cells.firstIndex(where: { $0.key.action == .globe }) {
            active.insert(index)
        }
        for (index, cell) in cells.enumerated() {
            let action = cell.key.action
            let isText: Bool
            switch action {
            case .text, .pair, .space: isText = true
            default: isText = false
            }
            let selectedShift = action == .shift && displayState.page == .letters && inputState.shift != .off
            let pressed = active.contains(index) || selectedShift
            let frame = cell.visualFrame.insetBy(dx: 0.25, dy: 0.25)
            let radius = min(8, frame.width / 4)
            let accentKey = action == .enter ? palette.colors.accentKey.map(UIColor.init(keyboardHex:)) : nil
            let fill = accentKey ?? (isText ? palette.key : palette.control)
            var path = UIBezierPath(roundedRect: frame, cornerRadius: radius)
            var face = frame
            if palette.shape == .sculpted, frame.height > 12 {
                // A darker skirt under a slightly shorter top, like a keycap seen from above.
                fill.darkened(by: 0.22).setFill()
                path.fill()
                face.size.height -= 3
                path = UIBezierPath(roundedRect: face, cornerRadius: radius)
            }
            fill.setFill()
            path.fill()
            let highlight = pressed ? 1 : feedbackOpacity(for: action)
            palette.accent.withAlphaComponent(highlight * palette.highlightOpacity).setFill()
            path.fill()
            (pressed ? palette.accent : palette.border).setStroke()
            path.lineWidth = pressed ? max(1, palette.borderWidth) : palette.borderWidth
            path.stroke()

            let legend = accentKey != nil ? UIColor(keyboardHex: palette.colors.accentKeyText ?? palette.colors.text)
                : (isText ? palette.text : palette.controlText)
            let color = action == .enter && !returnEnabled ? legend.withAlphaComponent(0.5) : legend
            if drawControl(action, in: face, color: color) { continue }
            let flicked = sessions.values.first { $0.startCell == index && $0.flick != nil }?.flick
            let label = flicked ?? cell.key.label ?? (action == .space && sessions.values.contains(where: \.cursorMode) ? "↔" : title(action))
            var size: CGFloat = label.count > 2 ? 13 : 19
            if case .text = action, cell.key.label == nil {
                size = min(preferences.validated.letterSize, max(14, frame.width - 3))
            }
            drawText(label, in: face, font: palette.legend(ofSize: size, weight: isText ? .regular : .medium),
                     color: flicked == nil ? color : palette.accent)
            if preferences.showLongPressHints, case .text(let letter) = action,
               letter.first?.isLetter == true, let hint = cell.key.alternatives.first {
                let hintFrame = CGRect(x: frame.maxX - 13, y: frame.minY + 3, width: 10, height: 12)
                drawText(title(.text(hint)), in: hintFrame,
                         font: .systemFont(ofSize: 10, weight: .medium), color: palette.secondary)
            }
            if preferences.showLongPressHints, !cell.key.flicks.isEmpty {
                // An accent that doesn't stand out on the keycap, as in some colorways, gives way to the hint color.
                let flickColor = KeyboardColors.contrast(palette.colors.accent, palette.colors.key) >= 3 ? palette.accent : palette.secondary
                let font = UIFont.systemFont(ofSize: 10, weight: .semibold)
                // Down keeps the digit's top-left corner; the others sit on the edge they point to.
                for (direction, value) in cell.key.flicks {
                    let hint: CGRect
                    switch direction {
                    case .down: hint = CGRect(x: face.minX + 3, y: face.minY + 3, width: 12, height: 12)
                    case .up: hint = CGRect(x: face.midX - 8, y: face.minY + 2, width: 16, height: 12)
                    case .left: hint = CGRect(x: face.minX + 2, y: face.midY + 6, width: 12, height: 12)
                    case .right: hint = CGRect(x: face.maxX - 14, y: face.midY + 6, width: 12, height: 12)
                    }
                    drawText(value, in: hint, font: font, color: flickColor,
                             alignment: direction == .right ? .right : (direction == .up ? .center : .left))
                }
            }
        }
        for session in sessions.values where session.glide {
            guard let trace = session.trace, let first = trace.first else { continue }
            let trail = UIBezierPath()
            trail.move(to: first)
            trace.dropFirst().forEach(trail.addLine(to:))
            trail.lineWidth = 6
            trail.lineCapStyle = .round
            trail.lineJoinStyle = .round
            palette.accent.withAlphaComponent(0.55).setStroke()
            trail.stroke()
        }
        if let popup {
            let width = min(bounds.width - 12, CGFloat(popup.values.count) * 52)
            let origin = (bounds.width - width) / 2
            for (index, value) in popup.values.enumerated() {
                let frame = CGRect(x: origin + CGFloat(index) * width / CGFloat(popup.values.count),
                                   y: 2, width: width / CGFloat(popup.values.count), height: 34)
                let path = UIBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 0), cornerRadius: 8)
                palette.key.setFill(); path.fill()
                if index == popup.selected {
                    palette.accent.withAlphaComponent(palette.highlightOpacity).setFill(); path.fill()
                }
                (index == popup.selected ? palette.accent : palette.border).setStroke()
                path.lineWidth = max(1, palette.borderWidth); path.stroke()
                drawText(title(.text(value)), in: frame, font: palette.legend(ofSize: 22, weight: .regular), color: palette.text)
            }
        } else if preferences.showHeader {
            palette.accent.withAlphaComponent((dismissButton.isHighlighted ? 1 : feedbackOpacity(for: .dismiss)) * palette.highlightOpacity).setFill()
            UIBezierPath(roundedRect: dismissButton.frame.insetBy(dx: 2, dy: 2), cornerRadius: 8).fill()
            let text = sessions.values.contains(where: \.cursorMode) ? "Slide to move cursor" : "\(inputState.language.badge)  ·  ORTHOLINEAR"
            drawText(text, in: CGRect(x: 10, y: 0, width: bounds.width - 64, height: 38),
                     font: .monospacedSystemFont(ofSize: 10, weight: .medium), color: palette.secondary, alignment: .left)
        }
    }

    private func drawControl(_ action: KeyAction, in frame: CGRect, color: UIColor) -> Bool {
        switch action {
        case .shift where displayState.page == .letters:
            let name = inputState.shift == .locked ? "capslock.fill" : (inputState.shift == .once ? "shift.fill" : "shift")
            drawSymbol(name, in: frame, size: 21, color: color)
        case .backspace:
            drawSymbol("delete.left", in: frame, size: 23, color: color)
        case .enter:
            if returnTitle == "return" {
                drawSymbol("return", in: frame, size: 23, color: color)
            } else {
                let name = returnTitle == "search" ? "magnifyingglass" : (returnTitle == "send" ? "paperplane" : (returnTitle == "done" ? "checkmark" : "arrow.right"))
                drawSymbol(name, in: frame.offsetBy(dx: 0, dy: -7), size: 17, color: color)
                drawText(returnTitle, in: CGRect(x: frame.minX + 2, y: frame.midY + 5, width: frame.width - 4, height: 13),
                         font: .systemFont(ofSize: 11, weight: .medium), color: color)
            }
        case .language:
            drawSymbol("arrow.left.arrow.right", in: frame.offsetBy(dx: 0, dy: -8), size: 16, color: color)
            drawText(nextLanguage.badge,
                     in: CGRect(x: frame.minX, y: frame.midY + 5, width: frame.width, height: 13),
                     font: .systemFont(ofSize: 10, weight: .semibold), color: color)
        case .dismiss:
            drawSymbol("keyboard.chevron.compact.down", in: frame, size: 21, color: color)
        case .globe: break // Native button keeps Apple's tap-and-hold behavior.
        default: return false
        }
        return true
    }

    private func drawSymbol(_ name: String, in frame: CGRect, size: CGFloat, color: UIColor) {
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        guard let image = UIImage(systemName: name, withConfiguration: configuration)?.withTintColor(color, renderingMode: .alwaysOriginal) else { return }
        let scale = min(1, (frame.width - 6) / image.size.width, (frame.height - 6) / image.size.height)
        let width = image.size.width * scale
        let height = image.size.height * scale
        image.draw(in: CGRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height))
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
        layoutIfNeeded()
        for touch in touches {
            let point = touch.location(in: self)
            guard let index = KeyboardGeometry.hit(at: point, cells: cells) else { continue }
            let id = ObjectIdentifier(touch)
            let key = cells[index].key
            // One finger owns the temporary page; other fingers must not change it.
            guard symbolSlide == nil else { continue }
            if key.action == .page && inputState.page == .letters {
                cancelTouches()
                symbolSlide = (id, .numbers, touch.timestamp, false)
                refresh()
                layoutIfNeeded()
                let pageIndex = cells.firstIndex { $0.key.action == .page } ?? -1
                sessions[id] = TouchSession(cell: pageIndex, original: .page, start: point)
                continue
            }
            // A second finger means fast typing, never a glide.
            for other in sessions.keys where !(sessions[other]?.glide ?? false) { sessions[other]?.trace = nil }
            var session = TouchSession(cell: index, original: key.action, start: point)
            if glideEnabled, sessions.isEmpty, case .text(let value) = key.action, value.first?.isLetter == true {
                session.trace = [point]
            }
            sessions[id] = session
            if key.action == .backspace { emit(.backspace) }
            if key.action == .backspace || !key.alternatives.isEmpty {
                let delay = key.action == .backspace ? DeleteRepeat.initialDelay : 0.42
                let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
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
            repeatDelete(id: id)
        } else if popup == nil {
            sessions[id]?.trace = nil
            popup = (id, key.alternatives, 0)
            setNeedsDisplay()
        }
    }

    private func repeatDelete(id: ObjectIdentifier) {
        guard let session = sessions[id], session.original == .backspace,
              cells.indices.contains(session.cell), cells[session.cell].key.action == .backspace else { return }
        emit(.backspace)
        // Emitting can synchronously dismiss or reconfigure the keyboard.
        guard sessions[id] != nil else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - session.began
        let timer = Timer(timeInterval: DeleteRepeat.interval(heldFor: elapsed), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.repeatDelete(id: id) }
        }
        sessions[id]?.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard var session = sessions[id] else { continue }
            let point = touch.location(in: self)
            if var slide = symbolSlide, slide.owner == id {
                if hypot(point.x - session.start.x, point.y - session.start.y) >= 10 { slide.moved = true }
                let index = KeyboardGeometry.hit(at: point, cells: cells)
                if index != session.cell {
                    session.timer?.invalidate()
                    session.timer = nil
                    // Require a deliberate pause: passing over #+= en route to a
                    // symbol must not unexpectedly change the page under the finger.
                    if let index, cells[index].key.action == .shift {
                        let timer = Timer(timeInterval: 0.42, repeats: false) { [weak self] _ in
                            MainActor.assumeIsolated { self?.switchSlidePage(id: id) }
                        }
                        session.timer = timer
                        RunLoop.main.add(timer, forMode: .common)
                    }
                }
                symbolSlide = slide
                session.cell = index ?? -1
                sessions[id] = session
                continue
            }
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
            if var trace = session.trace, let last = trace.last {
                let step = hypot(point.x - last.x, point.y - last.y)
                if step >= 2 {
                    trace.append(point)
                    session.pathLength += step
                    session.trace = trace.count > 600 ? stride(from: 0, to: trace.count, by: 2).map { trace[$0] } : trace
                }
            }
            if !session.glide, cells.indices.contains(session.startCell), !cells[session.startCell].key.flicks.isEmpty {
                if let (_, value) = KeyboardGeometry.flick(on: cells[session.startCell], from: session.start, to: point) {
                    session.timer?.invalidate()
                    session.timer = nil
                    session.flick = value
                    session.cell = session.startCell
                    sessions[id] = session
                    continue
                }
                session.flick = nil
            }
            if session.trace != nil, !session.glide, index != session.startCell,
               cells.indices.contains(session.startCell),
               session.pathLength >= max(36, cells[session.startCell].hitFrame.width * 1.1) {
                session.glide = true
                session.timer?.invalidate()
                session.timer = nil
            }
            if index != session.cell {
                session.timer?.invalidate()
                session.timer = nil
                session.cell = index ?? -1
            }
            sessions[id] = session
        }
        setNeedsDisplay()
    }

    private func switchSlidePage(id: ObjectIdentifier) {
        guard var slide = symbolSlide, slide.owner == id,
              let session = sessions[id], cells.indices.contains(session.cell),
              cells[session.cell].key.action == .shift else { return }
        slide.page = slide.page == .numbers ? .symbols : .numbers
        symbolSlide = slide
        refresh()
        layoutIfNeeded()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let session = sessions.removeValue(forKey: id) else { continue }
            session.timer?.invalidate()
            if let slide = symbolSlide, slide.owner == id {
                let point = touch.location(in: self)
                let index = KeyboardGeometry.hit(at: point, cells: cells)
                let action = index.map { cells[$0].key.action }
                let isTap = !slide.moved && touch.timestamp - slide.began < 0.42
                    && hypot(point.x - session.start.x, point.y - session.start.y) < 10
                    && bounds.contains(point)
                symbolSlide = nil
                refresh()
                layoutIfNeeded()
                if isTap { emit(.page) }
                else if let action, case .text = action { emit(action, feedback: false); onGesture?(.symbolSlide) }
                // Holds, outside releases, and non-text targets restore letters silently.
            } else if let current = popup, current.owner == id {
                let isInside = bounds.contains(touch.location(in: self))
                popup = nil
                if isInside { emit(.text(current.values[current.selected])); onGesture?(.alternative) }
            } else if session.glide, var trace = session.trace {
                trace.append(touch.location(in: self))
                onGlide?(trace)
                onGesture?(.glide)
            } else if let digit = session.flick {
                emit(.text(digit), feedback: false)
                flash(session.original)
                onGesture?(.flick)
            } else if session.cursorMode {
                onGesture?(.spaceCursor)
            } else if session.original != .backspace,
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
            if symbolSlide?.owner == id { symbolSlide = nil; refresh() }
            if popup?.owner == id { popup = nil }
        }
        setNeedsDisplay()
    }
}

private extension UIColor {
    /// The same color with less light, for a keycap's skirt.
    func darkened(by amount: CGFloat) -> UIColor {
        var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * (1 - amount), alpha: alpha)
    }
}
