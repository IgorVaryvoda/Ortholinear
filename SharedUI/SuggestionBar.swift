import UIKit
import Darwin

@MainActor
final class SuggestionBar: UIView {
    private(set) var buttons: [UIButton] = []
    private(set) var punctuationButtons: [UIButton] = []
    private let more = UIButton(type: .system)
    private let hint = UILabel()
    private let tipButton = UIButton(type: .custom)
    private var tip: KeyboardTip?
    var onSelect: ((WordSuggestion) -> Void)?
    var onPunctuation: ((String) -> Void)?
    var onTip: ((KeyboardTip) -> Void)?
    var onTeach: ((String) -> Void)?
    var onForget: ((String) -> Void)?
    var onClear: (() -> Void)?
    var onDismiss: (() -> Void)?
    /// Shown between words, in stable positions, so a period is one tap away.
    var punctuation: [String] = [] {
        didSet { if oldValue != punctuation { rebuildPunctuation() } }
    }
    private var palette: KeyboardPalette?
    /// Between words, two next-word chips share the row with the first three marks.
    private var compact = false
    private static let compactMarks = 3

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "suggestion-bar"
        tintAdjustmentMode = .normal
        for index in 0..<3 {
            let button = FeedbackButton(type: .custom)
            button.highlightChanged = { [weak button] in button?.alpha = button?.isHighlighted == true ? 0.65 : 1 }
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.65
            button.layer.cornerRadius = 7
            button.accessibilityIdentifier = "suggestion-\(index)"
            button.isHidden = true
            addSubview(button); buttons.append(button)
        }
        hint.font = .systemFont(ofSize: 12)
        hint.textAlignment = .center
        hint.isUserInteractionEnabled = false
        hint.isHidden = true
        addSubview(hint)
        tipButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        tipButton.titleLabel?.adjustsFontSizeToFitWidth = true
        tipButton.titleLabel?.minimumScaleFactor = 0.7
        tipButton.accessibilityIdentifier = "keyboard-tip"
        tipButton.accessibilityHint = "Hides this tip"
        tipButton.isHidden = true
        tipButton.addAction(UIAction { [weak self] _ in
            guard let self, let tip = self.tip else { return }
            self.onTip?(tip)
        }, for: .touchUpInside)
        addSubview(tipButton)
        more.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        more.accessibilityLabel = "Suggestion options"
        more.accessibilityIdentifier = "suggestion-options"
        more.showsMenuAsPrimaryAction = true
        addSubview(more)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let content = max(0, bounds.width - 44)
        let words = compact ? content * 0.64 : content
        let width = words / (compact ? 2 : 3)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * width + 2, y: 3, width: max(0, width - 4), height: 38)
        }
        let marks = compact ? min(Self.compactMarks, punctuationButtons.count) : punctuationButtons.count
        let markOrigin = compact ? words : 0
        let markWidth = marks == 0 ? 0 : (content - markOrigin) / CGFloat(marks)
        for (index, button) in punctuationButtons.enumerated() {
            button.frame = CGRect(x: markOrigin + CGFloat(index) * markWidth + 2, y: 3, width: max(0, markWidth - 4), height: 38)
        }
        hint.frame = CGRect(x: 0, y: 0, width: content, height: 44)
        tipButton.frame = CGRect(x: 8, y: 0, width: max(0, content - 16), height: 44)
        more.frame = CGRect(x: bounds.width - 44, y: 0, width: 44, height: 44)
    }

    func style(_ palette: KeyboardPalette) {
        self.palette = palette
        backgroundColor = palette.background
        hint.textColor = palette.secondary
        tipButton.setTitleColor(palette.secondary, for: .normal)
        more.tintColor = palette.secondary
        for button in buttons + punctuationButtons {
            button.setTitleColor(palette.text, for: .normal)
            button.backgroundColor = palette.key
            button.layer.borderColor = palette.border.cgColor
            button.layer.borderWidth = palette.borderWidth
        }
    }

    private func rebuildPunctuation() {
        punctuationButtons.forEach { $0.removeFromSuperview() }
        punctuationButtons = punctuation.enumerated().map { index, mark in
            let button = FeedbackButton(type: .custom)
            button.highlightChanged = { [weak button] in button?.alpha = button?.isHighlighted == true ? 0.65 : 1 }
            button.setTitle(mark, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 20, weight: .regular)
            button.layer.cornerRadius = 7
            button.accessibilityLabel = Self.spokenName(mark)
            button.accessibilityIdentifier = "strip-\(index)"
            button.isHidden = true
            button.addAction(UIAction { [weak self] _ in self?.onPunctuation?(mark) }, for: .touchUpInside)
            insertSubview(button, belowSubview: more)
            return button
        }
        if let palette { style(palette) }
        setNeedsLayout()
    }

    private static func spokenName(_ mark: String) -> String {
        switch mark {
        case ".": "Period"
        case ",": "Comma"
        case "?": "Question mark"
        case "!": "Exclamation mark"
        case ":": "Colon"
        case "-": "Hyphen"
        case "\"": "Quotation mark"
        case "«": "Open quote"
        case "»": "Close quote"
        default: mark
        }
    }

    /// Words when there are any; otherwise a message, a tip, or punctuation, in that order.
    /// Next words leave room for . , ? so ending a sentence stays one tap.
    func show(_ suggestions: [WordSuggestion], word: String?, learned: [String], message: String? = nil, tip: KeyboardTip? = nil) {
        let idle = suggestions.isEmpty && message == nil
        let between = !suggestions.isEmpty && suggestions.allSatisfy { $0.kind == .nextWord }
        let suggestions = between ? Array(suggestions.prefix(2)) : suggestions
        if compact != between { compact = between; setNeedsLayout() }
        self.tip = idle ? tip : nil
        hint.text = message
        hint.isHidden = message == nil || !suggestions.isEmpty
        tipButton.setTitle(self.tip?.text, for: .normal)
        tipButton.accessibilityLabel = self.tip?.text
        tipButton.isHidden = self.tip == nil
        for (index, button) in punctuationButtons.enumerated() {
            button.isHidden = !((idle && self.tip == nil) || (between && index < Self.compactMarks))
        }
        for (index, button) in buttons.enumerated() {
            button.removeAction(identifiedBy: .init("accept"), for: .touchUpInside)
            button.isHidden = index >= suggestions.count
            guard index < suggestions.count else { continue }
            let suggestion = suggestions[index]
            let title = suggestion.language == nil ? suggestion.word : "\(suggestion.word) ⇄"
            button.setTitle(title, for: .normal)
            if let language = suggestion.language {
                button.accessibilityLabel = "Use \(suggestion.word) and switch to \(language.title)"
                button.accessibilityHint = "Replace the current word"
            } else {
                button.accessibilityLabel = "Use \(suggestion.word)"
                button.accessibilityHint = suggestion.kind == .nextWord ? "Insert next word" : "Replace the current word"
            }
            button.addAction(UIAction(identifier: .init("accept")) { [weak self] _ in self?.onSelect?(suggestion) }, for: .touchUpInside)
        }
        var actions: [UIMenuElement] = []
        if let word, SuggestionText.isWord(word) {
            let exists = learned.contains { SuggestionText.normalize($0) == SuggestionText.normalize(word) }
            actions.append(UIAction(title: exists ? "Forget “\(word)”" : "Teach “\(word)”",
                                    image: UIImage(systemName: exists ? "minus.circle" : "plus.circle")) { [weak self] _ in
                if exists { self?.onForget?(word) } else { self?.onTeach?(word) }
            })
        }
        if !learned.isEmpty {
            let words = learned.sorted().map { word in
                UIAction(title: word, image: UIImage(systemName: "minus.circle")) { [weak self] _ in self?.onForget?(word) }
            }
            actions.append(UIMenu(title: "Forget a taught word", children: words))
            actions.append(UIMenu(title: "Clear taught words…", children: [UIAction(title: "Clear words for this language", attributes: .destructive) { [weak self] _ in self?.onClear?() }]))
        }
        actions.append(UIAction(title: "Dismiss keyboard", image: UIImage(systemName: "keyboard.chevron.compact.down")) { [weak self] _ in self?.onDismiss?() })
        more.menu = UIMenu(title: "Words stay on this device", children: actions)
    }
}

/// Intentionally uses this process's own defaults. The keyboard can write here
/// without Full Access; it never attempts to write the shared App Group file.
@MainActor
enum TaughtWordStore {
    static let limit = 200
    static func words(_ language: KeyboardLanguage) -> [String] {
        (UserDefaults.standard.stringArray(forKey: "taught-words-\(language.rawValue)") ?? [])
            .filter { SuggestionText.isWord($0) && SuggestionText.belongs($0, to: language) }.prefix(limit).map { $0 }
    }
    static func save(_ words: [String], language: KeyboardLanguage) {
        UserDefaults.standard.set(Array(words.prefix(limit)), forKey: "taught-words-\(language.rawValue)")
    }
}

/// Text replacements and contact names from requestSupplementaryLexicon, which needs no Full Access.
struct SupplementaryWords: Sendable {
    var shortcuts: [String: String] = [:]
    var names: [String] = []

    init() {}
    /// Entries whose input equals their text are names; the others are text replacements.
    init(entries: [(input: String, text: String)]) {
        for (input, text) in entries {
            if input == text {
                if SuggestionText.isWord(text) { names.append(text) }
            } else if SuggestionText.isWord(input) {
                shortcuts[SuggestionText.normalize(input)] = text
            }
        }
    }
}

private struct SuggestionResponse: Sendable {
    var words: [WordSuggestion]
    var diagnostics: String = ""
}

private actor SuggestionWorker {
    #if DEBUG
    private var timings: [Double] = []
    private var peakFootprint = 0.0
    private var coldLoad = 0.0
    #endif
    /// Bilingual typists switch constantly, so the last two dictionaries stay loaded.
    private var engines: [(language: KeyboardLanguage, engine: SuggestionEngine)] = []

    private func engine(_ language: KeyboardLanguage) throws -> SuggestionEngine {
        if let index = engines.firstIndex(where: { $0.language == language }) {
            let entry = engines.remove(at: index)
            engines.insert(entry, at: 0)
            return entry.engine
        }
        #if DEBUG
        let loadStart = Date.timeIntervalSinceReferenceDate
        #endif
        if engines.count >= 2 { engines.removeLast() }
        let engine = try SuggestionResources.engine(language: language)
        engines.insert((language, engine), at: 0)
        #if DEBUG
        coldLoad = (Date.timeIntervalSinceReferenceDate - loadStart) * 1000
        #endif
        return engine
    }

    func suggest(snapshot: SuggestionSnapshot, learned: [String], names: [String], preferences: KeyboardPreferences, width: Double,
                 alternate: KeyboardLanguage?, shortcut: String?) throws -> SuggestionResponse {
        try Task.checkCancellation()
        let engine = try engine(snapshot.language)
        try Task.checkCancellation()
        guard let target = snapshot.target else { return .init(words: []) }
        #if DEBUG
        let began = Date.timeIntervalSinceReferenceDate
        #endif
        let geometry = SuggestionGeometry(language: snapshot.language, preferences: preferences, width: width)
        var words = engine.suggest(target: target, language: snapshot.language, learned: learned, geometry: geometry,
                                   nextWords: preferences.nextWordSuggestions, useContext: preferences.contextualSuggestions)
        let query = SuggestionText.normalize(target.word)
        // Only a word nothing in this language starts with; a half-typed word always has completions.
        if let alternate, !target.selected, target.rightCount == 0, query.count >= 4,
           engine.lexicon.range(prefix: query).isEmpty,
           !learned.contains(where: { SuggestionText.normalize($0).hasPrefix(query) }) {
            let other = try self.engine(alternate)
            let otherGeometry = SuggestionGeometry(language: alternate, preferences: preferences, width: width)
            if let word = LayoutRecovery.recover(target.word, from: geometry, to: otherGeometry, lexicon: other.lexicon) {
                let cased = SuggestionText.cased(word, like: target.word, language: alternate)
                words = [WordSuggestion(word: cased, kind: .correction, language: alternate)] + words.prefix(2)
            }
        }
        // Contact names fill spare slots as completions, keeping their capitals; they never correct.
        if words.count < 3, query.count >= 2, !target.selected, target.rightCount == 0 {
            let taken = Set(words.map { SuggestionText.normalize($0.word) })
            let matches = names.filter {
                let name = SuggestionText.normalize($0)
                return name.hasPrefix(query) && name != query && !taken.contains(name)
            }
            words += matches.sorted().prefix(3 - words.count).map { WordSuggestion(word: $0, kind: .completion) }
        }
        if let shortcut { words = [WordSuggestion(word: shortcut, kind: .replacement)] + words.prefix(2) }
        var response = SuggestionResponse(words: words)
        #if DEBUG
        timings.append((Date.timeIntervalSinceReferenceDate - began) * 1000)
        if timings.count > 1000 { timings.removeFirst() }
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if status == KERN_SUCCESS { peakFootprint = max(peakFootprint, Double(info.phys_footprint) / 1_048_576) }
        let sorted = timings.sorted()
        response.diagnostics = String(format: "n=%d warm_p95_ms=%.2f cold_load_ms=%.2f peak_process_MiB=%.2f engines=%d",
                                      sorted.count, sorted[Int(Double(sorted.count - 1) * 0.95)], coldLoad, peakFootprint, engines.count)
        #endif
        return response
    }

    func glide(_ points: [CGPoint], language: KeyboardLanguage, learned: [String], context: [String],
               preferences: KeyboardPreferences, width: Double) throws -> [WordSuggestion] {
        let engine = try engine(language)
        let geometry = SuggestionGeometry(language: language, preferences: preferences, width: width)
        return engine.glide(points, language: language, learned: learned, geometry: geometry,
                            context: preferences.contextualSuggestions ? context : [])
    }

    func unload() { engines.removeAll() }
}

@MainActor
final class SuggestionCoordinator {
    private let worker = SuggestionWorker()
    private weak var keyboard: KeyboardView?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var offered: SuggestionSnapshot?
    private var requested: SuggestionSnapshot?
    private var preferences: KeyboardPreferences?
    /// Alternatives to a glided word, offered while the text is exactly as it was inserted.
    private var glideOffer: (snapshot: SuggestionSnapshot, words: [WordSuggestion])?
    private var sessionTip: KeyboardTip?
    private var tipChosen = false
    var snapshot: (() -> SuggestionSnapshot?)?
    /// Glide needs only the language and the text before the caret. Hosts report no context
    /// at all in an empty field, which rules out a suggestion snapshot but not a glide.
    var glideContext: (() -> (language: KeyboardLanguage, before: String)?)?
    var apply: ((SuggestionEdit, SuggestionSnapshot) -> Void)?
    /// Inserts a glided word with the host's spacing and Shift state; returns the text inserted.
    var insertWord: ((String) -> String?)?
    var switchLanguage: ((KeyboardLanguage) -> Void)?
    var supplementary = SupplementaryWords()

    init(keyboard: KeyboardView) {
        self.keyboard = keyboard
        keyboard.suggestionBar.onSelect = { [weak self] suggestion in
            guard let self, let offered = self.offered, let current = self.snapshot?(),
                  let edit = SuggestionEdit.make(suggestion: suggestion, offered: offered, current: current) else { return }
            self.cancel()
            self.glideOffer = nil
            self.apply?(edit, current)
            if let language = suggestion.language { self.switchLanguage?(language) }
            self.refresh(force: true)
        }
        keyboard.suggestionBar.onTip = { [weak self] tip in
            TipStore.dismiss(tip)
            self?.sessionTip = nil
            self?.refresh(force: true)
        }
        keyboard.suggestionBar.onTeach = { [weak self] word in self?.teach(word) }
        keyboard.suggestionBar.onForget = { [weak self] word in self?.forget(word) }
        keyboard.suggestionBar.onClear = { [weak self] in
            guard let self, let language = self.snapshot?()?.language else { return }
            TaughtWordStore.save([], language: language); self.refresh(force: true)
        }
        keyboard.suggestionBar.onDismiss = { [weak keyboard] in keyboard?.onDismiss?() }
        keyboard.onGlide = { [weak self] points in self?.glide(points) }
    }

    /// A new keyboard appearance may show a tip again, up to its limit.
    func beginSession() { tipChosen = false; sessionTip = nil }

    func suspend() {
        task?.cancel(); task = nil; generation += 1; offered = nil; requested = nil
    }
    func cancel() {
        suspend()
        keyboard?.suggestionBar.show([], word: nil, learned: [])
    }
    func releaseMemory() {
        suspend()
        glideOffer = nil
        Task { await worker.unload() }
    }

    private func punctuation(for language: KeyboardLanguage) -> [String] {
        language.isLatin ? [".", ",", "?", "!", ":", "-", "\""] : [".", ",", "?", "!", ":", "«", "»"]
    }

    private func tip(for snapshot: SuggestionSnapshot, preferences: KeyboardPreferences) -> KeyboardTip? {
        guard snapshot.before.allSatisfy(\.isWhitespace), snapshot.after.isEmpty, snapshot.selection.isEmpty else { return nil }
        if !tipChosen {
            tipChosen = true
            sessionTip = TipStore.next(for: preferences, language: snapshot.language)
            if let sessionTip { TipStore.markShown(sessionTip) }
        }
        return sessionTip
    }

    /// The other bundled dictionary the user types in, for words typed on the wrong layout.
    private func alternate(to language: KeyboardLanguage, preferences: KeyboardPreferences) -> KeyboardLanguage? {
        guard language.dictionaryCode != nil else { return nil }
        let other: KeyboardLanguage = language == .english ? .ukrainian : .english
        return preferences.validated.languages.contains(other) ? other : nil
    }

    func refresh(force: Bool = false) {
        guard let keyboard else { return }
        let current = snapshot?()
        let preferences = keyboard.preferences
        keyboard.suggestionBar.punctuation = punctuation(for: current?.language ?? keyboard.inputState.language)
        keyboard.glideEnabled = preferences.glideTyping && keyboard.inputState.page == .letters
            && glideContext?()?.language.dictionaryCode != nil
        guard preferences.suggestionsEnabled, keyboard.inputState.page == .letters, let current else { cancel(); return }
        if let offer = glideOffer {
            if offer.snapshot == current {
                guard force || requested != current else { return }
                suspend()
                requested = current; offered = current; self.preferences = preferences
                keyboard.suggestionBar.show(offer.words, word: nil, learned: TaughtWordStore.words(current.language))
                return
            }
            glideOffer = nil
        }
        guard force || requested != current || self.preferences != preferences else { return }
        suspend()
        requested = current; self.preferences = preferences
        let learned = TaughtWordStore.words(current.language)
        let word = current.target?.word
        let teachable = word.flatMap { SuggestionText.belongs($0, to: current.language) ? $0 : nil }
        let tip = tip(for: current, preferences: preferences)
        let token = generation, width = keyboard.bounds.width
        guard current.language.dictionaryCode != nil else {
            // Apple's checker covers the other layouts, on the main actor it requires.
            task = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                guard let self, token == self.generation, self.snapshot?() == current, let keyboard = self.keyboard else { return }
                let geometry = SuggestionGeometry(language: current.language, preferences: preferences, width: width)
                let words = current.target.map {
                    SystemSuggestions.suggest(target: $0, language: current.language, learned: learned, geometry: geometry)
                } ?? []
                self.offered = current
                keyboard.suggestionBar.show(words, word: teachable, learned: learned, tip: tip)
            }
            return
        }
        let alternate = alternate(to: current.language, preferences: preferences)
        let shortcut = word.flatMap { supplementary.shortcuts[SuggestionText.normalize($0)] }
        let names = supplementary.names.filter { SuggestionText.belongs($0, to: current.language) }
        task = Task { [weak self, worker] in
            do {
                try await Task.sleep(for: .milliseconds(30))
                let result = try await worker.suggest(snapshot: current, learned: learned, names: names, preferences: preferences,
                                                      width: width, alternate: alternate, shortcut: shortcut)
                try Task.checkCancellation()
                guard let self, token == self.generation, self.snapshot?() == current else { return }
                self.offered = current
                self.keyboard?.suggestionBar.accessibilityValue = result.diagnostics
                self.keyboard?.suggestionBar.show(result.words, word: teachable, learned: learned, tip: tip)
            } catch is CancellationError { } catch {
                guard let self, token == self.generation else { return }
                self.keyboard?.suggestionBar.show([], word: teachable, learned: learned, message: "Suggestions unavailable")
            }
        }
    }

    private func glide(_ points: [CGPoint]) {
        guard let keyboard, let current = glideContext?(), current.language.dictionaryCode != nil else { return }
        let learned = TaughtWordStore.words(current.language)
        let preferences = keyboard.preferences, width = keyboard.bounds.width
        suspend()
        glideOffer = nil
        Task { [weak self, worker] in
            guard let words = try? await worker.glide(points, language: current.language, learned: learned,
                                                      context: SuggestionText.context(current.before),
                                                      preferences: preferences, width: width),
                  let self, let best = words.first,
                  let inserted = self.insertWord?(best.word) else { return }
            // Alternatives need a snapshot to replace safely; without host context, only the word goes in.
            guard let after = self.snapshot?() else { self.refresh(force: true); return }
            let alternatives = words.dropFirst().map {
                WordSuggestion(word: SuggestionText.cased($0.word, like: inserted, language: current.language), kind: .correction)
            }
            if !alternatives.isEmpty { self.glideOffer = (after, Array(alternatives.prefix(3))) }
            self.refresh(force: true)
        }
    }

    private func teach(_ word: String) {
        guard let current = snapshot?(), current.target?.word == word,
              SuggestionText.isWord(word), SuggestionText.belongs(word, to: current.language) else { return }
        var words = TaughtWordStore.words(current.language)
        guard !words.contains(where: { SuggestionText.normalize($0) == SuggestionText.normalize(word) }) else { return }
        guard words.count < TaughtWordStore.limit else {
            keyboard?.suggestionBar.show([], word: nil, learned: words, message: "Word list full · forget a word first")
            return
        }
        words.append(word); TaughtWordStore.save(words, language: current.language); refresh(force: true)
    }
    private func forget(_ word: String) {
        guard let language = snapshot?()?.language else { return }
        let words = TaughtWordStore.words(language).filter { SuggestionText.normalize($0) != SuggestionText.normalize(word) }
        TaughtWordStore.save(words, language: language); refresh(force: true)
    }
}
