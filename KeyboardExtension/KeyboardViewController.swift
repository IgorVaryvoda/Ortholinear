import UIKit

final class KeyboardViewController: UIInputViewController {
    private let keyboard = KeyboardView()
    private var heightConstraint: NSLayoutConstraint?
    private var inputState = InputState()
    private var punctuationSpacing = PunctuationSpacing()
    private var lastKeyboardType: UIKeyboardType?
    private var reportedLanguage: KeyboardLanguage?
    /// iOS builds a new controller each time the keyboard appears and may unload the
    /// process between uses, so the language memory is kept in the keyboard's defaults.
    private static var memory = LanguageMemoryStore.load()
        ?? LanguageMemory(startingLanguage: KeyboardPreferences().defaultLanguage)
    private var languageContext: LanguageContext?
    private lazy var suggestions = SuggestionCoordinator(keyboard: keyboard)
    private var applyingSuggestion = false

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
        suggestions.snapshot = { [weak self] in self?.suggestionSnapshot() }
        suggestions.apply = { [weak self] edit, snapshot in self?.applySuggestion(edit, snapshot: snapshot) }
        keyboard.onAction = { [weak self] in self?.handle($0) }
        keyboard.onCursor = { [weak self] in
            self?.punctuationSpacing.reset()
            self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: $0)
            self?.suggestions.refresh()
        }
        keyboard.onDismiss = { [weak self] in self?.dismissKeyboard() }
        adoptLanguageSettings(PreferenceStore.load())
        inputState.language = Self.memory.fallback
        keyboard.inputState = inputState
        suggestions.refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        punctuationSpacing.reset()
        let preferences = PreferenceStore.load()
        adoptLanguageSettings(preferences)
        keyboard.preferences = preferences
        heightConstraint?.constant = preferences.keyboardHeight
        lastKeyboardType = nil
        synchronize()
    }

    override func viewWillDisappear(_ animated: Bool) {
        keyboard.cancelTouches()
        suggestions.releaseMemory()
        super.viewWillDisappear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if keyboard.needsGlobe != needsInputModeSwitchKey { keyboard.needsGlobe = needsInputModeSwitchKey }
    }

    override func textDidChange(_ textInput: (any UITextInput)?) { if !applyingSuggestion { synchronize() } }
    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        guard !applyingSuggestion else { return }
        suggestions.refresh()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        suggestions.releaseMemory()
    }

    private func suggestionSnapshot() -> SuggestionSnapshot? {
        guard isViewLoaded, view.window != nil, lastKeyboardType != nil else { return nil }
        let allowed: [UIKeyboardType] = [.default, .asciiCapable, .twitter]
        guard allowed.contains(textDocumentProxy.keyboardType ?? .default),
              textDocumentProxy.isSecureTextEntry != true else { return nil }
        let before = textDocumentProxy.documentContextBeforeInput
        let after = textDocumentProxy.documentContextAfterInput
        let selected = textDocumentProxy.selectedText ?? ""
        // A completely unavailable context is not a safe replacement target.
        guard before != nil || after != nil || !selected.isEmpty else { return nil }
        return .init(document: textDocumentProxy.documentIdentifier, before: before ?? "", after: after ?? "",
                     selection: selected, language: inputState.language)
    }

    private func applySuggestion(_ edit: SuggestionEdit, snapshot: SuggestionSnapshot) {
        guard suggestionSnapshot() == snapshot else { return }
        applyingSuggestion = true
        defer { applyingSuggestion = false }
        punctuationSpacing.reset()
        if edit.moveRight != 0 {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: edit.moveRight)
            // Some hosts don't honor cursor movement. Never delete from the old caret.
            let expected = snapshot.before + snapshot.after.prefix(edit.moveRight)
            guard textDocumentProxy.documentContextBeforeInput?.hasSuffix(expected.suffix(24)) == true else { return }
        }
        for _ in 0..<edit.deleteCount { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(edit.text)
    }

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
            default: inputState.page = .letters
            }
            languageContext = nil
        }
        let context = currentLanguageContext(type: type)
        if context != languageContext { resolveLanguage(in: context) }
        reportLanguageIfNeeded()
        keyboard.needsGlobe = needsInputModeSwitchKey
        keyboard.returnTitle = returnLabel
        keyboard.returnEnabled = !(textDocumentProxy.enablesReturnKeyAutomatically ?? false) || textDocumentProxy.hasText
        keyboard.inputState = inputState
        suggestions.refresh()
    }

    private func currentLanguageContext(type: UIKeyboardType) -> LanguageContext {
        var context = LanguageContext(requiresLatin: [.emailAddress, .URL, .asciiCapable].contains(type))
        guard keyboard.preferences.rememberLanguage else { return context }
        // Keyboards never learn the app, window or chat (conversationContext isn't
        // delivered to them), and documentIdentifier is new on every focus. These traits
        // survive refocusing, so a message box, a search box and an address bar each
        // keep their own language. Capitalization isn't used: it changes on resign.
        context.field = [String(type.rawValue), String((textDocumentProxy.returnKeyType ?? .default).rawValue),
                         (textDocumentProxy.textContentType ?? nil)?.rawValue ?? ""].joined(separator: "|")
        return context
    }

    private func resolveLanguage(in context: LanguageContext) {
        languageContext = context
        let preferences = keyboard.preferences
        let suggested = preferences.rememberLanguage
            ? textDocumentProxy.documentInputMode?.primaryLanguage.flatMap(KeyboardLanguage.init(languageCode:)) : nil
        let language = Self.memory.resolve(context, enabled: preferences.validated.languages, suggested: suggested)
        inputState.language = language
        updateMemory { $0.record(language, in: context, chosen: false) }
    }

    private func adoptLanguageSettings(_ preferences: KeyboardPreferences) {
        updateMemory {
            $0.adopt(startingLanguage: preferences.defaultLanguage, generation: preferences.languageMemoryGeneration,
                     enabled: preferences.validated.languages)
        }
    }

    private func updateMemory(_ change: (inout LanguageMemory) -> Void) {
        var memory = Self.memory
        change(&memory)
        guard memory != Self.memory else { return }
        Self.memory = memory
        LanguageMemoryStore.save(memory)
    }

    private func reportLanguageIfNeeded() {
        // The proxy can echo an older/normalized primaryLanguage while host updates
        // are in flight. Track what we sent, so text callbacks cannot feed back
        // another language notification for an unchanged keyboard language.
        guard reportedLanguage != inputState.language else { return }
        reportedLanguage = inputState.language
        primaryLanguage = inputState.language.code
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
            inputState.language = keyboard.preferences.language(after: inputState.language)
            inputState.page = .letters
            let language = inputState.language, context = languageContext ?? LanguageContext()
            updateMemory { $0.record(language, in: context, chosen: true) }
        case .page: inputState.page = inputState.page == .letters ? .numbers : .letters
        case .globe: advanceToNextInputMode()
        case .dismiss: dismissKeyboard()
        }
        reportLanguageIfNeeded()
        keyboard.returnEnabled = !(textDocumentProxy.enablesReturnKeyAutomatically ?? false) || textDocumentProxy.hasText
        keyboard.inputState = inputState
        suggestions.refresh()
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

/// The keyboard's own defaults: writable without Full Access, unlike the App Group
/// the app shares settings through.
private enum LanguageMemoryStore {
    private static let key = "language-memory"
    static func load() -> LanguageMemory? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(LanguageMemory.self, from: $0) }
    }
    static func save(_ memory: LanguageMemory) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
