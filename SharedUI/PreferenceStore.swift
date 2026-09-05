import Foundation

enum PreferenceStore {
    // Only the containing app writes. The extension reads this file without Full Access.
    static var fileURL: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "OrtholinearAppGroup") as? String else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("geometry.json")
    }

    static func load() -> KeyboardPreferences {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let preferences = try? JSONDecoder().decode(KeyboardPreferences.self, from: data) else {
            return KeyboardPreferences()
        }
        return preferences.validated
    }

    static func save(_ preferences: KeyboardPreferences) throws {
        guard let url = fileURL else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(preferences.validated).write(to: url, options: .atomic)
    }
}
