import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {
    private let keyboard = KeyboardView()
    private var heightConstraint: NSLayoutConstraint?
    private var inputState = InputState()
    private var lastKeyboardType: UIKeyboardType?
    private var voiceHost: UIHostingController<VoiceKeyboardButton>?

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
        keyboard.onCursor = { [weak self] in self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: $0) }
        keyboard.onDismiss = { [weak self] in self?.dismissKeyboard() }
        inputState.language = PreferenceStore.load().defaultLanguage
        keyboard.inputState = inputState
        let host = UIHostingController(rootView: voiceButton())
        host.view.backgroundColor = .clear
        addChild(host)
        keyboard.addSubview(host.view)
        host.didMove(toParent: self)
        keyboard.voiceOverlay = host.view
        voiceHost = host
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let preferences = PreferenceStore.load()
        if keyboard.preferences.defaultLanguage != preferences.defaultLanguage {
            inputState.language = preferences.defaultLanguage
        }
        keyboard.preferences = preferences
        heightConstraint?.constant = preferences.keyboardHeight
        lastKeyboardType = nil
        synchronize()
        refreshVoice()
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
        case .text(let value): textDocumentProxy.insertText(inputState.consume(value))
        case .space: textDocumentProxy.insertText(" ")
        case .backspace: textDocumentProxy.deleteBackward()
        case .enter: textDocumentProxy.insertText("\n")
        case .shift:
            if inputState.page == .letters { inputState.tapShift(at: Date.timeIntervalSinceReferenceDate) }
            else { inputState.page = inputState.page == .numbers ? .symbols : .numbers }
        case .language:
            inputState.language = inputState.language.next
            inputState.page = .letters
        case .page: inputState.page = inputState.page == .letters ? .numbers : .letters
        case .globe: advanceToNextInputMode()
        case .dismiss: dismissKeyboard()
        case .voice: insertDictation()
        }
        primaryLanguage = inputState.language.code
        keyboard.returnEnabled = !(textDocumentProxy.enablesReturnKeyAutomatically ?? false) || textDocumentProxy.hasText
        keyboard.inputState = inputState
    }

    private func voiceButton() -> VoiceKeyboardButton {
        VoiceKeyboardButton(ready: VoiceTranscriptStore.pending() != nil) { [weak self] in self?.insertDictation() }
    }
    private func refreshVoice() {
        keyboard.voiceReady = VoiceTranscriptStore.pending() != nil
        voiceHost?.rootView = voiceButton()
    }
    private func insertDictation() {
        guard let transcript = VoiceTranscriptStore.pending() else { refreshVoice(); return }
        do {
            try VoiceTranscriptStore.markConsumed(transcript)
            textDocumentProxy.insertText(transcript.text)
        } catch {
            let alert = UIAlertController(title: "Could not insert dictation", message: "Please try again.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
        refreshVoice()
    }
}
