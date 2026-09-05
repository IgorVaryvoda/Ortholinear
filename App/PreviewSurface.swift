import SwiftUI
import UIKit

extension Notification.Name {
    static let clearKeyboardPreview = Notification.Name("clearKeyboardPreview")
}

struct PreviewSurface: UIViewRepresentable {
    let preferences: KeyboardPreferences
    func makeUIView(context: Context) -> PreviewContainer { PreviewContainer() }
    func updateUIView(_ view: PreviewContainer, context: Context) { view.apply(preferences) }
}

final class PreviewContainer: UIView, UITextViewDelegate {
    let editor = UITextView()
    let keyboard = KeyboardView()
    private let placeholder = UILabel()
    private var state = InputState()
    private var height: NSLayoutConstraint!

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
        keyboard.onAction = { [weak self] in self?.handle($0) }
        keyboard.onDismiss = { [weak self] in self?.editor.resignFirstResponder() }
        keyboard.onCursor = { [weak self] offset in
            guard let self, let selection = self.editor.selectedTextRange,
                  let position = self.editor.position(from: selection.start, offset: offset) else { return }
            self.editor.selectedTextRange = self.editor.textRange(from: position, to: position)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(clear), name: .clearKeyboardPreview, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(_ preferences: KeyboardPreferences) {
        if keyboard.preferences.defaultLanguage != preferences.defaultLanguage { state.language = preferences.defaultLanguage }
        keyboard.preferences = preferences
        height.constant = preferences.keyboardHeight
        keyboard.inputState = state
    }

    @objc private func clear() {
        editor.text = ""
        placeholder.isHidden = false
    }

    func textViewDidChange(_ textView: UITextView) { placeholder.isHidden = !textView.text.isEmpty }

    private func handle(_ action: KeyAction) {
        switch action {
        case .text(let value): editor.insertText(state.consume(value))
        case .space: editor.insertText(" ")
        case .enter: editor.insertText("\n")
        case .backspace: editor.deleteBackward()
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
    }
}
