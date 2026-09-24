import SwiftUI
import Security

@main
struct OrtholinearApp: App {
    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        var preferences = PreferenceStore.load()
        if arguments.contains("-suggestion-ui-tests") { preferences.suggestionsEnabled = true }
        // Tests written before automatic capitals type lowercase keys by identifier.
        if arguments.contains("-no-auto-capitals") { preferences.autoCapitalize = false }
        if arguments.contains("-auto-capitals") { preferences.autoCapitalize = true }
        if preferences != PreferenceStore.load() { try? PreferenceStore.save(preferences) }
        #endif
        // Remove private data left by the retired development-only voice feature.
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: "com.varyvoda.Ortholinear.groq",
                       kSecAttrAccount as String: "api-key"] as CFDictionary)
        if let shared = PreferenceStore.fileURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: shared.appendingPathComponent("voice-transcript.json"))
        }
        let files = (try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory,
                                                                  includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("dictation-") && ["wav", "m4a"].contains(file.pathExtension) {
            try? FileManager.default.removeItem(at: file)
        }
    }
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
