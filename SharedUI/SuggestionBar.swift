import UIKit
import Darwin

@MainActor
final class SuggestionBar: UIView {
    private(set) var buttons: [UIButton] = []
    private let more = UIButton(type: .system)
    private let hint = UILabel()
    var onSelect: ((WordSuggestion) -> Void)?
    var onTeach: ((String) -> Void)?
    var onForget: ((String) -> Void)?
    var onClear: (() -> Void)?
    var onDismiss: (() -> Void)?

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
        hint.text = "Suggestions · tap to use"
        hint.font = .systemFont(ofSize: 12)
        hint.textAlignment = .center
        hint.isUserInteractionEnabled = false
        addSubview(hint)
        more.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        more.accessibilityLabel = "Suggestion options"
        more.accessibilityIdentifier = "suggestion-options"
        more.showsMenuAsPrimaryAction = true
        addSubview(more)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(0, bounds.width - 44) / 3
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * width + 2, y: 3, width: max(0, width - 4), height: 38)
        }
        hint.frame = CGRect(x: 0, y: 0, width: bounds.width - 44, height: 44)
        more.frame = CGRect(x: bounds.width - 44, y: 0, width: 44, height: 44)
    }
    func style(_ palette: KeyboardPalette) {
        backgroundColor = palette.background
        hint.textColor = palette.secondary
        more.tintColor = palette.secondary
        for button in buttons {
            button.setTitleColor(palette.text, for: .normal)
            button.backgroundColor = palette.key
            button.layer.borderColor = palette.border.cgColor
            button.layer.borderWidth = palette.borderWidth
        }
    }
    func show(_ suggestions: [WordSuggestion], word: String?, learned: [String], message: String? = nil) {
        hint.text = message ?? "Suggestions · tap to use"
        hint.isHidden = !suggestions.isEmpty
        for (index, button) in buttons.enumerated() {
            button.removeAction(identifiedBy: .init("accept"), for: .touchUpInside)
            button.isHidden = index >= suggestions.count
            guard index < suggestions.count else { continue }
            let suggestion = suggestions[index]
            button.setTitle(suggestion.word, for: .normal)
            button.accessibilityLabel = "Use \(suggestion.word)"
            button.accessibilityHint = suggestion.kind == .nextWord ? "Insert next word" : "Replace the current word"
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
    private var language: KeyboardLanguage?
    private var engine: SuggestionEngine?
    func suggest(snapshot: SuggestionSnapshot, learned: [String], preferences: KeyboardPreferences, width: Double) throws -> SuggestionResponse {
        try Task.checkCancellation()
        #if DEBUG
        let loadStart = Date.timeIntervalSinceReferenceDate
        #endif
        if language != snapshot.language || engine == nil {
            engine = nil
            engine = try SuggestionResources.engine(language: snapshot.language)
            language = snapshot.language
            #if DEBUG
            coldLoad = (Date.timeIntervalSinceReferenceDate - loadStart) * 1000
            #endif
        }
        try Task.checkCancellation()
        guard let target = snapshot.target else { return .init(words: []) }
        #if DEBUG
        let began = Date.timeIntervalSinceReferenceDate
        #endif
        let words = engine?.suggest(target: target, language: snapshot.language, learned: learned,
                               geometry: SuggestionGeometry(language: snapshot.language, preferences: preferences, width: width),
                               nextWords: preferences.nextWordSuggestions, useContext: preferences.contextualSuggestions) ?? []
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
        response.diagnostics = String(format: "n=%d warm_p95_ms=%.2f cold_load_ms=%.2f peak_process_MiB=%.2f",
                                      sorted.count, sorted[Int(Double(sorted.count - 1) * 0.95)], coldLoad, peakFootprint)
        #endif
        return response
    }
    func unload() { engine = nil; language = nil }
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
    var snapshot: (() -> SuggestionSnapshot?)?
    var apply: ((SuggestionEdit, SuggestionSnapshot) -> Void)?

    init(keyboard: KeyboardView) {
        self.keyboard = keyboard
        keyboard.suggestionBar.onSelect = { [weak self] suggestion in
            guard let self, let offered = self.offered, let current = self.snapshot?(),
                  let edit = SuggestionEdit.make(suggestion: suggestion, offered: offered, current: current) else { return }
            self.cancel()
            self.apply?(edit, current)
            self.refresh(force: true)
        }
        keyboard.suggestionBar.onTeach = { [weak self] word in self?.teach(word) }
        keyboard.suggestionBar.onForget = { [weak self] word in self?.forget(word) }
        keyboard.suggestionBar.onClear = { [weak self] in
            guard let self, let language = self.snapshot?()?.language else { return }
            TaughtWordStore.save([], language: language); self.refresh(force: true)
        }
        keyboard.suggestionBar.onDismiss = { [weak keyboard] in keyboard?.onDismiss?() }
    }
    func suspend() {
        task?.cancel(); task = nil; generation += 1; offered = nil; requested = nil
    }
    func cancel() {
        suspend()
        keyboard?.suggestionBar.show([], word: nil, learned: [])
    }
    func releaseMemory() {
        suspend()
        Task { await worker.unload() }
    }
    func refresh(force: Bool = false) {
        guard let keyboard else { return }
        guard keyboard.preferences.suggestionsEnabled, keyboard.inputState.page == .letters,
              let current = snapshot?() else { cancel(); return }
        guard force || requested != current || preferences != keyboard.preferences else { return }
        cancel()
        requested = current; preferences = keyboard.preferences
        let learned = TaughtWordStore.words(current.language)
        let word = current.target?.word
        let teachable = word.flatMap { SuggestionText.belongs($0, to: current.language) ? $0 : nil }
        keyboard.suggestionBar.show([], word: teachable, learned: learned)
        let token = generation, preferences = keyboard.preferences, width = keyboard.bounds.width
        task = Task { [weak self, worker] in
            do {
                try await Task.sleep(for: .milliseconds(30))
                let result = try await worker.suggest(snapshot: current, learned: learned, preferences: preferences, width: width)
                try Task.checkCancellation()
                guard let self, token == self.generation, self.snapshot?() == current else { return }
                self.offered = current
                self.keyboard?.suggestionBar.accessibilityValue = result.diagnostics
                self.keyboard?.suggestionBar.show(result.words, word: teachable, learned: learned)
            } catch is CancellationError { } catch {
                guard let self, token == self.generation else { return }
                self.keyboard?.suggestionBar.show([], word: teachable, learned: learned, message: "Suggestions unavailable")
            }
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
