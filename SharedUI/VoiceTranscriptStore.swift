import Foundation

enum VoiceTranscriptStore {
    private static var url: URL? { PreferenceStore.fileURL?.deletingLastPathComponent().appendingPathComponent("voice-transcript.json") }
    private static var receiptURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("voice-consumed.json")
    }
    static func pending() -> VoiceTranscript? {
        guard let url, let data = try? Data(contentsOf: url),
              let transcript = try? JSONDecoder().decode(VoiceTranscript.self, from: data) else { return nil }
        let consumedID = (try? Data(contentsOf: receiptURL)).flatMap { try? JSONDecoder().decode(UUID.self, from: $0) }
        return transcript.isAvailable(consumedID: consumedID) ? transcript : nil
    }
    // App-only writes; extension requires no Full Access to read the transcript.
    static func save(_ text: String) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(VoiceTranscript(text: text)).write(to: url, options: [.atomic, .completeFileProtection])
    }
    static func clear() {
        if let url { try? FileManager.default.removeItem(at: url) }
    }
    // Receipt is in the current process's own sandbox, never the shared container.
    static func markConsumed(_ transcript: VoiceTranscript) throws {
        try FileManager.default.createDirectory(at: receiptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(transcript.id).write(to: receiptURL, options: [.atomic, .completeFileProtection])
    }
}
