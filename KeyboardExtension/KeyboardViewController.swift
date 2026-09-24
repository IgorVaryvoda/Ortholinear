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
    /// Shift that automatic capitals turned on, so they may also turn it off.
    private var autoShifted = false
    /// The text before the caret when the person last pressed Shift themselves.
    private var manualShiftContext: String?
    /// Safari's address bar is a web search field: mostly searches, so it gets suggestions
    /// and glide. URL-looking tokens never get suggestions, whatever the field.
    private static let suggestionTypes: [UIKeyboardType] = [.default, .asciiCapable, .twitter, .webSearch]
    /// URL/email fields need literal punctuation, never automatic spaces or capitals.
    private static let literalTypes: [UIKeyboardType] = [.URL, .emailAddress, .webSearch]

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
        suggestions.insertWord = { [weak self] in self?.insertGlided($0) }
        suggestions.glideContext = { [weak self] in self?.glideContext() }
        suggestions.switchLanguage = { [weak self] in self?.switchLanguage(to: $0) }
        keyboard.onAction = { [weak self] in self?.handle($0) }
        keyboard.onCursor = { [weak self] in
            self?.punctuationSpacing.reset()
            self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: $0)
            self?.updateAutoShift()
            self?.suggestions.refresh()
        }
        keyboard.onDismiss = { [weak self] in self?.dismissKeyboard() }
        adoptLanguageSettings(PreferenceStore.load())
        inputState.language = Self.memory.fallback
        keyboard.inputState = inputState
        suggestions.refresh()
        // The completion arrives on an XPC queue, not the main thread.
        requestSupplementaryLexicon { @Sendable [weak self] lexicon in
            let words = SupplementaryWords(entries: lexicon.entries.map { ($0.userInput, $0.documentText) })
            Task { @MainActor in self?.suggestions.supplementary = words }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        punctuationSpacing.reset()
        let preferences = PreferenceStore.load()
        adoptLanguageSettings(preferences)
        keyboard.preferences = preferences
        heightConstraint?.constant = preferences.keyboardHeight
        lastKeyboardType = nil
        suggestions.beginSession()
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
        updateAutoShift()
        keyboard.inputState = inputState
        suggestions.refresh()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        suggestions.releaseMemory()
    }

    private func suggestionSnapshot() -> SuggestionSnapshot? {
        guard isViewLoaded, view.window != nil, lastKeyboardType != nil else { return nil }
        let allowed = Self.suggestionTypes
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

    private func glideContext() -> (language: KeyboardLanguage, before: String)? {
        guard isViewLoaded, view.window != nil, lastKeyboardType != nil else { return nil }
        let allowed = Self.suggestionTypes
        guard allowed.contains(textDocumentProxy.keyboardType ?? .default),
              textDocumentProxy.isSecureTextEntry != true else { return nil }
        return (inputState.language, textDocumentProxy.documentContextBeforeInput ?? "")
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
        if edit.text.hasSuffix(" ") {
            punctuationSpacing.adoptSpace(before: textDocumentProxy.documentContextBeforeInput ?? "", at: ProcessInfo.processInfo.systemUptime)
        }
        updateAutoShift()
        keyboard.inputState = inputState
    }

    private func insertGlided(_ word: String) -> String? {
        guard isViewLoaded, inputState.page == .letters else { return nil }
        applyingSuggestion = true
        defer { applyingSuggestion = false }
        var text = word
        switch inputState.shift {
        case .once: text = word.prefix(1).uppercased() + word.dropFirst(); inputState.shift = .off; autoShifted = false
        case .locked: text = word.uppercased()
        case .off: break
        }
        // Glides are whole words: separate them from the word or mark before.
        let needsSpace = textDocumentProxy.documentContextBeforeInput?.last.map { !$0.isWhitespace && !"([{«„“'\"".contains($0) } ?? false
        punctuationSpacing.reset()
        textDocumentProxy.insertText((needsSpace ? " " : "") + text)
        updateAutoShift()
        keyboard.inputState = inputState
        return text
    }

    private func switchLanguage(to language: KeyboardLanguage) {
        guard keyboard.preferences.validated.languages.contains(language) else { return }
        inputState.language = language
        inputState.page = .letters
        let context = languageContext ?? LanguageContext()
        updateMemory { $0.record(language, in: context, chosen: true) }
        reportLanguageIfNeeded()
        keyboard.inputState = inputState
    }

    private var autocapitalization: AutoCapitalization {
        guard keyboard.preferences.autoCapitalize,
              !Self.literalTypes.contains(textDocumentProxy.keyboardType ?? .default) else { return .none }
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none: return .none
        case .words: return .words
        case .allCharacters: return .allCharacters
        default: return .sentences
        }
    }

    /// Turns Shift on for one letter where the field's own capitalization asks for it.
    private func updateAutoShift() {
        guard inputState.page == .letters, inputState.shift != .locked else { return }
        let before = textDocumentProxy.documentContextBeforeInput
        guard manualShiftContext != (before ?? "") else { return }
        manualShiftContext = nil
        // A host that hides its context must not get a capital on every letter.
        let wanted = !(before == nil && textDocumentProxy.hasText) && autocapitalization.shouldCapitalize(before: before)
        if wanted, inputState.shift == .off {
            inputState.shift = .once
            autoShifted = true
        } else if !wanted, autoShifted, inputState.shift == .once {
            inputState.shift = .off
            autoShifted = false
        }
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
        updateAutoShift()
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
            if inputState.page == .letters {
                inputState.tapShift(at: Date.timeIntervalSinceReferenceDate)
                autoShifted = false
                manualShiftContext = textDocumentProxy.documentContextBeforeInput ?? ""
            } else { inputState.page = inputState.page == .numbers ? .symbols : .numbers }
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
        if action != .shift { updateAutoShift() }
        keyboard.inputState = inputState
        suggestions.refresh()
    }

    private func insert(_ value: String) {
        let literal = Self.literalTypes.contains(textDocumentProxy.keyboardType ?? .default)
        let preferences = keyboard.preferences
        let edit = punctuationSpacing.edit(for: value, before: textDocumentProxy.documentContextBeforeInput,
                                           enabled: preferences.autoSpacePunctuation && !literal,
                                           doubleSpacePeriod: preferences.doubleSpacePeriod && !literal,
                                           at: ProcessInfo.processInfo.systemUptime)
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
