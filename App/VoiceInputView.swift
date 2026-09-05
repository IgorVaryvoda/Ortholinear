import SwiftUI
import AVFoundation

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published var recording = false
    @Published var transcribing = false
    @Published var text = ""
    @Published var error: String?
    private var recorder: AVAudioRecorder?
    private var audioURL: URL?
    private var task: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var sessionKey = ""
    private var sessionLanguage: String?
    private var operationID = UUID()

    init() {
        // Clear only our own unfinished recordings left by an interrupted process.
        let urls = (try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory,
                                                                 includingPropertiesForKeys: nil)) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("dictation-") && url.pathExtension == "m4a" {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func start(language: String) async {
        guard !recording && !transcribing else { return }
        let id = UUID()
        operationID = id
        do {
            sessionKey = try GroqKeyStore.load()
            guard !sessionKey.isEmpty else { throw GroqTranscription.Failure.message("Save your Groq API key first.") }
            guard await AVAudioApplication.requestRecordPermission() else {
                throw GroqTranscription.Failure.message("Microphone access is off. Enable it for Ortholinear in iOS Settings.")
            }
            guard operationID == id, !Task.isCancelled, UIApplication.shared.applicationState == .active else {
                if operationID == id { sessionKey = "" }; return
            }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("dictation-\(UUID().uuidString).m4a")
            audioURL = url
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000])
            guard recorder.record() else { throw GroqTranscription.Failure.message("Recording could not start. Check microphone access and try again.") }
            self.recorder = recorder
            sessionLanguage = language == "auto" ? nil : language
            text = ""; error = nil; recording = true
            VoiceTranscriptStore.clear()
            deadline = Task { [weak self] in
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled else { return }
                self?.finish()
            }
        } catch {
            guard operationID == id else { return }
            self.error = error.localizedDescription; cleanAudio(); sessionKey = ""
        }
    }

    func finish() {
        guard recording, let url = audioURL else { return }
        let duration = recorder?.currentTime ?? 0
        recorder?.stop(); recording = false; recorder = nil
        deadline?.cancel(); deadline = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard duration > 0.3 else { error = "Recording was too short. Please try again."; sessionKey = ""; cleanAudio(); return }
        transcribing = true
        let key = sessionKey
        let language = sessionLanguage
        let id = operationID
        sessionKey = ""
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.operationID == id { self.transcribing = false; self.cleanAudio() } }
            do {
                let audio = try Data(contentsOf: url)
                guard audio.count < 25_000_000 else { throw GroqTranscription.Failure.message("Recording is too large. Try a shorter recording.") }
                let boundary = UUID().uuidString
                var request = URLRequest(url: GroqTranscription.endpoint)
                request.httpMethod = "POST"
                request.timeoutInterval = 90
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.httpBody = GroqTranscription.multipart(audio: audio, language: language, boundary: boundary)
                let session = URLSession(configuration: .ephemeral)
                defer { session.invalidateAndCancel() }
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard self.operationID == id else { return }
                self.text = try GroqTranscription.transcript(from: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
            } catch {
                if !Task.isCancelled && self.operationID == id { self.error = error.localizedDescription }
            }
        }
    }
    func cancel() {
        operationID = UUID()
        task?.cancel(); task = nil; deadline?.cancel(); deadline = nil
        recording = false; transcribing = false; sessionKey = ""
        cleanAudio()
    }
    private func cleanAudio() {
        recorder?.stop(); recorder = nil
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        audioURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var recorder = VoiceRecorder()
    @State private var key = ""
    @State private var hasKey = false
    @State private var language = "auto"
    @State private var saved = false
    @State private var starting = false
    private var busy: Bool { starting || recorder.recording || recorder.transcribing }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Record here, then return to your other app and tap the keyboard’s insert-dictation button.")
                    Text("Audio is sent directly to Groq using your key and Whisper Turbo. Groq usage is billed to your account. Your typed text is never sent.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("Groq’s data retention and privacy", destination: URL(string: "https://console.groq.com/docs/your-data")!)
                }
                Section("Your Groq API key") {
                    if hasKey { Label("Key saved securely", systemImage: "checkmark.shield") }
                    SecureField(hasKey ? "Replace API key" : "Groq API key", text: $key)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("groq-api-key")
                    Button("Save key") {
                        do { try GroqKeyStore.save(key); hasKey = true; key = ""; recorder.error = nil }
                        catch { recorder.error = error.localizedDescription }
                    }.disabled(key.isEmpty || busy).accessibilityIdentifier("save-groq-key")
                    if hasKey {
                        Button("Remove key", role: .destructive) {
                            do { try GroqKeyStore.remove(); hasKey = false; key = "" }
                            catch { recorder.error = error.localizedDescription }
                        }.disabled(busy)
                    }
                    Link("Get a Groq API key", destination: URL(string: "https://console.groq.com/keys")!)
                }
                Section("Dictate") {
                    Picker("Language", selection: $language) {
                        Text("Auto-detect").tag("auto"); Text("Українська").tag("uk"); Text("English").tag("en")
                    }.disabled(busy)
                    if recorder.recording {
                        Label("Recording · up to 2 minutes", systemImage: "waveform").foregroundStyle(.red)
                        Button("Stop and transcribe") { recorder.finish() }.accessibilityIdentifier("stop-transcription")
                    } else if recorder.transcribing {
                        ProgressView("Transcribing with Groq…")
                    } else {
                        Button {
                            starting = true; saved = false
                            Task { await recorder.start(language: language); starting = false }
                        } label: { Label(starting ? "Starting…" : "Start recording", systemImage: "mic.fill") }
                            .disabled(!hasKey || starting).accessibilityIdentifier("start-recording")
                    }
                    if recorder.recording || recorder.transcribing {
                        Button("Cancel", role: .cancel) { recorder.cancel() }
                    }
                    if let error = recorder.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("voice-error") }
                }
                if !recorder.text.isEmpty {
                    Section("Review your words") {
                        TextEditor(text: $recorder.text).frame(minHeight: 120).accessibilityIdentifier("voice-transcript")
                        Button("Use in keyboard") {
                            do { try VoiceTranscriptStore.save(recorder.text); saved = true }
                            catch { recorder.error = "The transcript could not be shared with the keyboard. Try again." }
                        }.disabled(recorder.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                            .accessibilityIdentifier("use-dictation")
                        if saved { Text("Ready. Return to your other app and tap Insert dictation on the keyboard. Available for 10 minutes.").foregroundStyle(.green) }
                    }
                }
                Section {
                    Button("Clear pending dictation", role: .destructive) { VoiceTranscriptStore.clear(); saved = false }
                }
            }
            .navigationTitle("Voice input").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { recorder.cancel(); dismiss() } } }
        }
        .onAppear {
            do { hasKey = !(try GroqKeyStore.load()).isEmpty }
            catch { recorder.error = error.localizedDescription }
            if VoiceTranscriptStore.pending() == nil { VoiceTranscriptStore.clear() }
        }
        .onDisappear { recorder.cancel() }
        .onChange(of: recorder.text) { _, _ in saved = false }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            if recorder.recording { recorder.cancel(); recorder.error = "Recording was interrupted. Please try again." }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active && recorder.recording { recorder.cancel() } }
    }
}
