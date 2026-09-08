import SwiftUI
import UIKit

/// Uses the same renderer as the extension, fitted into a persistent settings panel.
struct SettingsKeyboardPreview: UIViewRepresentable {
    let preferences: KeyboardPreferences
    let language: KeyboardLanguage

    func makeUIView(context: Context) -> SettingsPreviewContainer { SettingsPreviewContainer() }

    func updateUIView(_ view: SettingsPreviewContainer, context: Context) {
        view.keyboard.preferences = preferences
        view.keyboard.inputState.language = language
        view.accessibilityValue = "\(language.badge), theme \(preferences.theme.title), accent \(preferences.accent.title), key height \(Int(preferences.keyHeight)), column spacing \(Int(preferences.columnSpacing)), row spacing \(Int(preferences.rowSpacing))"
        view.setNeedsLayout()
    }
}

final class SettingsPreviewContainer: UIView {
    let keyboard = KeyboardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        keyboard.needsGlobe = false
        keyboard.isUserInteractionEnabled = false
        keyboard.accessibilityElementsHidden = true
        addSubview(keyboard)
        isAccessibilityElement = true
        accessibilityLabel = "Live keyboard preview"
        accessibilityIdentifier = "settings-keyboard-preview"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = keyboard.preferences.keyboardHeight
        let scale = min(1, bounds.height / height)
        guard scale > 0 else { return }
        keyboard.transform = .identity
        keyboard.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: height)
        keyboard.center = CGPoint(x: bounds.midX, y: bounds.midY)
        keyboard.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}

extension Notification.Name {
    static let clearKeyboardPreview = Notification.Name("clearKeyboardPreview")
}

struct PreviewSurface: UIViewRepresentable {
    let preferences: KeyboardPreferences
    let isActive: Bool
    func makeUIView(context: Context) -> PreviewContainer { PreviewContainer() }
    func updateUIView(_ view: PreviewContainer, context: Context) { view.apply(preferences, isActive: isActive) }
}

final class PreviewContainer: UIView, UITextViewDelegate {
    let editor = UITextView()
    let keyboard = KeyboardView()
    private let placeholder = UILabel()
    private var state = InputState()
    private var punctuationSpacing = PunctuationSpacing()
    private var height: NSLayoutConstraint!
    private let documentID = UUID()
    private lazy var suggestions = SuggestionCoordinator(keyboard: keyboard)
    private var applyingSuggestion = false
    private var isActive = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        editor.backgroundColor = .clear
        editor.font = .systemFont(ofSize: 21)
        editor.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 12, right: 12)
        editor.accessibilityIdentifier = "preview-editor"
        editor.accessibilityLabel = "Typing preview"
        editor.inputView = UIView(frame: .zero)
        editor.inputAssistantItem.leadingBarButtonGroups = []
        editor.inputAssistantItem.trailingBarButtonGroups = []
        editor.autocorrectionType = .no
        editor.spellCheckingType = .no
        editor.smartQuotesType = .no
        editor.smartDashesType = .no
        editor.delegate = self
        placeholder.text = "Спробуй. Make yourself at home."
        placeholder.font = .systemFont(ofSize: 16)
        placeholder.textColor = .placeholderText
        placeholder.isUserInteractionEnabled = false
        placeholder.isAccessibilityElement = false
        [editor, keyboard, placeholder].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        height = keyboard.heightAnchor.constraint(equalToConstant: keyboard.preferences.keyboardHeight)
        NSLayoutConstraint.activate([
            editor.topAnchor.constraint(equalTo: topAnchor), editor.leadingAnchor.constraint(equalTo: leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: trailingAnchor), editor.heightAnchor.constraint(equalToConstant: 100),
            keyboard.topAnchor.constraint(equalTo: editor.bottomAnchor), keyboard.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: trailingAnchor), height,
            placeholder.topAnchor.constraint(equalTo: editor.topAnchor, constant: 18),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            placeholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
        ])
        keyboard.needsGlobe = false
        suggestions.snapshot = { [weak self] in self?.suggestionSnapshot() }
        suggestions.apply = { [weak self] edit, snapshot in self?.applySuggestion(edit, snapshot: snapshot) }
        keyboard.onAction = { [weak self] in self?.handle($0) }
        keyboard.onDismiss = { [weak self] in self?.editor.resignFirstResponder() }
        keyboard.onCursor = { [weak self] offset in
            guard let self, let selection = self.editor.selectedTextRange,
                  let position = self.editor.position(from: selection.start, offset: offset) else { return }
            self.punctuationSpacing.reset()
            self.editor.selectedTextRange = self.editor.textRange(from: position, to: position)
            self.suggestions.refresh()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(clear), name: .clearKeyboardPreview, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { suggestions.releaseMemory() }
        // Deliver presses immediately so a quick symbol slide belongs to the keyboard,
        // instead of becoming a scroll before UIScrollView's touch delay expires.
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                scrollView.delaysContentTouches = false
                break
            }
            ancestor = view.superview
        }
    }

    func apply(_ preferences: KeyboardPreferences, isActive: Bool) {
        self.isActive = isActive
        if !isActive { suggestions.suspend() }
        if keyboard.preferences.defaultLanguage != preferences.defaultLanguage { state.language = preferences.defaultLanguage }
        keyboard.preferences = preferences
        height.constant = preferences.keyboardHeight
        keyboard.inputState = state
        if isActive { suggestions.refresh() }
    }

    @objc private func clear() {
        punctuationSpacing.reset()
        editor.text = ""
        placeholder.isHidden = false
        suggestions.refresh(force: true)
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
        if !applyingSuggestion { suggestions.refresh() }
    }
    func textViewDidChangeSelection(_ textView: UITextView) {
        if !applyingSuggestion { punctuationSpacing.reset(); suggestions.refresh() }
    }
    private func suggestionSnapshot() -> SuggestionSnapshot? {
        guard isActive else { return nil }
        let text = editor.text as NSString
        let range = editor.selectedRange
        guard range.location != NSNotFound, NSMaxRange(range) <= text.length else { return nil }
        return .init(document: documentID, before: text.substring(to: range.location),
                     after: text.substring(from: NSMaxRange(range)), selection: text.substring(with: range), language: state.language)
    }
    private func applySuggestion(_ edit: SuggestionEdit, snapshot: SuggestionSnapshot) {
        guard suggestionSnapshot() == snapshot, let target = snapshot.target else { return }
        applyingSuggestion = true
        defer { applyingSuggestion = false }
        punctuationSpacing.reset()
        let prefix = String(snapshot.before.dropLast(target.leftCount))
        let range = NSRange(location: prefix.utf16.count, length: target.word.utf16.count)
        guard let start = editor.position(from: editor.beginningOfDocument, offset: range.location),
              let end = editor.position(from: start, offset: range.length),
              let selection = editor.textRange(from: start, to: end) else { return }
        editor.replace(selection, withText: edit.text)
        if let caret = editor.position(from: editor.beginningOfDocument, offset: range.location + edit.text.utf16.count) {
            editor.selectedTextRange = editor.textRange(from: caret, to: caret)
        }
        placeholder.isHidden = !editor.text.isEmpty
    }

    private func handle(_ action: KeyAction) {
        applyingSuggestion = true
        defer { applyingSuggestion = false }
        switch action {
        case .text(let value): insert(state.consume(value))
        case .space: insert(" ")
        case .enter: insert("\n")
        case .backspace: punctuationSpacing.reset(); editor.deleteBackward()
        case .shift:
            if state.page == .letters { state.tapShift(at: Date.timeIntervalSinceReferenceDate) }
            else { state.page = state.page == .numbers ? .symbols : .numbers }
        case .page: state.page = state.page == .letters ? .numbers : .letters
        case .language: state.language = state.language.next; state.page = .letters
        case .dismiss: editor.resignFirstResponder()
        default: break
        }
        placeholder.isHidden = !editor.text.isEmpty
        keyboard.inputState = state
        if isActive { suggestions.refresh() }
    }

    private func insert(_ value: String) {
        let selection = editor.selectedRange
        if selection.length > 0 { punctuationSpacing.reset() }
        let context = (editor.text as NSString).substring(to: selection.location)
        let edit = punctuationSpacing.edit(for: value, before: context, enabled: keyboard.preferences.autoSpacePunctuation)
        if edit.deleteBackward { editor.deleteBackward() }
        if !edit.text.isEmpty { editor.insertText(edit.text) }
    }
}
