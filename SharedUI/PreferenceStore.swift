import Foundation
import UIKit

enum PreferenceStore {
    // Only the containing app writes. The extension reads this file without Full Access.
    static var fileURL: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "OrtholinearAppGroup") as? String else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("geometry.json")
    }

    /// Nothing saved yet: a new install, or one whose settings were never changed.
    static var isEmpty: Bool {
        guard let url = fileURL else { return true }
        return !FileManager.default.fileExists(atPath: url.path)
    }

    /// The settings a new install starts with, from the device's keyboards and languages.
    @MainActor static var suggested: KeyboardPreferences {
        .suggested(for: UITextInputMode.activeInputModes.compactMap(\.primaryLanguage) + Locale.preferredLanguages)
    }

    @MainActor static func load() -> KeyboardPreferences {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return suggested }
        guard let preferences = try? JSONDecoder().decode(KeyboardPreferences.self, from: data) else {
            return KeyboardPreferences()
        }
        return preferences.validated
    }

    static func save(_ preferences: KeyboardPreferences) throws {
        guard let url = fileURL else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(preferences.validated).write(to: url, options: .atomic)
    }
}
