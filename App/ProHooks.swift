import SwiftUI

/// Where the private Pro sources plug into the app. The public repository builds the Free
/// edition, so every hook stays empty; release builds fill them at launch. See
/// docs/PRO-IMPLEMENTATION.md.
@MainActor
enum ProHooks {
    /// Extra rows for Keyboard settings, below Languages and the Layout Workshop.
    static var settingsRows: ((Binding<KeyboardPreferences>) -> AnyView)?
    /// Adjusts the copy of the preferences the keyboard reads, such as switching layers off.
    static var prepareForKeyboard: (@MainActor (KeyboardPreferences) -> KeyboardPreferences)?
    /// Posted when what `prepareForKeyboard` allows changes, so the app publishes again.
    static let accessChanged = Notification.Name("ProAccessChanged")
}

/// Writes the preferences the keyboard reads. The app's own copy keeps everything; the
/// published one is what the edition allows.
@MainActor
enum KeyboardPublisher {
    /// What the keyboard will use; the test drive previews the same.
    static func published(_ preferences: KeyboardPreferences) -> KeyboardPreferences {
        ProHooks.prepareForKeyboard?(preferences) ?? preferences
    }

    static func publish(_ preferences: KeyboardPreferences) throws {
        try PreferenceStore.save(published(preferences))
    }
}
