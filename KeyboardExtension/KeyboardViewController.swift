import UIKit

final class KeyboardViewController: UIInputViewController {
    private let keyboard = KeyboardView()
    private var heightConstraint: NSLayoutConstraint?
    private var inputState = InputState()
    private var punctuationSpacing = PunctuationSpacing()
    private var lastKeyboardType: UIKeyboardType?

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboard.accessibilityIdentifier = "system-keyboard-surface"
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)
        NSLayoutConstraint.activate([
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.topAnchor.constraint(equalTo: view.topAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let height = view.heightAnchor.constraint(equalToConstant: keyboard.preferences.keyboardHeight)
        height.priority = .init(999)
        height.isActive = true
        heightConstraint = height
        keyboard.globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        keyboard.onAction = { [weak self] in self?.handle($0) }
        keyboard.onCursor = { [weak self] in
            self?.punctuationSpacing.reset()
            self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: $0)
        }
        keyboard.onDismiss = { [weak self] in self?.dismissKeyboard() }
        inputState.language = PreferenceStore.load().defaultLanguage
        keyboard.inputState = inputState
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        punctuationSpacing.reset()
        let preferences = PreferenceStore.load()
        if keyboard.preferences.defaultLanguage != preferences.defaultLanguage {
            inputState.language = preferences.defaultLanguage
        }
        keyboard.preferences = preferences
        heightConstraint?.constant = preferences.keyboardHeight
        lastKeyboardType = nil
        synchronize()
    }

    override func viewWillDisappear(_ animated: Bool) {
        keyboard.cancelTouches()
        super.viewWillDisappear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if keyboard.needsGlobe != needsInputModeSwitchKey { keyboard.needsGlobe = needsInputModeSwitchKey }
    }

    override func textDidChange(_ textInput: (any UITextInput)?) { synchronize() }

    private func synchronize() {
        guard isViewLoaded else { return }
        let type = textDocumentProxy.keyboardType ?? .default
        // The proxy is not attached to a document during viewDidLoad. In particular,
        // documentIdentifier can be nil in Objective-C despite its nonoptional Swift API.
        if lastKeyboardType != type {
            keyboard.cancelTouches()
            lastKeyboardType = type
            inputState.shift = .off
            switch type {
            case .numberPad, .decimalPad, .numbersAndPunctuation, .asciiCapableNumberPad:
                inputState.page = .numbers
            case .emailAddress, .URL, .asciiCapable:
                inputState.page = .letters
                inputState.language = .english
            default: inputState.page = .letters
            }
        }
        primaryLanguage = inputState.language.code
        keyboard.needsGlobe = needsInputModeSwitchKey
        keyboard.returnTitle = returnLabel
        keyboard.returnEnabled = !(textDocumentProxy.enablesReturnKeyAutomatically ?? false) || textDocumentProxy.hasText
        keyboard.inputState = inputState
    }

    private var returnLabel: String {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: "go"
        case .search, .google, .yahoo: "search"
        case .send: "send"
        case .next: "next"
        case .done: "done"
        case .join: "join"
        case .route: "route"
        default: "return"
        }
    }

    private func handle(_ action: KeyAction) {
        switch action {
        case .text(let value): insert(inputState.consume(value))
        case .space: insert(" ")
        case .backspace: punctuationSpacing.reset(); textDocumentProxy.deleteBackward()
        case .enter: insert("\n")
        case .shift:
            if inputState.page == .letters { inputState.tapShift(at: Date.timeIntervalSinceReferenceDate) }
            else { inputState.page = inputState.page == .numbers ? .symbols : .numbers }
        case .language:
            inputState.language = inputState.language.next
            inputState.page = .letters
        case .page: inputState.page = inputState.page == .letters ? .numbers : .letters
        case .globe: advanceToNextInputMode()
        case .dismiss: dismissKeyboard()
        }
        primaryLanguage = inputState.language.code
        keyboard.returnEnabled = !(textDocumentProxy.enablesReturnKeyAutomatically ?? false) || textDocumentProxy.hasText
        keyboard.inputState = inputState
    }

    private func insert(_ value: String) {
        // URL/email fields need literal punctuation, never automatic spaces.
        let literalTypes: [UIKeyboardType] = [.URL, .emailAddress, .webSearch]
        let enabled = keyboard.preferences.autoSpacePunctuation && !literalTypes.contains(textDocumentProxy.keyboardType ?? .default)
        let edit = punctuationSpacing.edit(for: value, before: textDocumentProxy.documentContextBeforeInput, enabled: enabled)
        if edit.deleteBackward { textDocumentProxy.deleteBackward() }
        if !edit.text.isEmpty { textDocumentProxy.insertText(edit.text) }
    }
}
