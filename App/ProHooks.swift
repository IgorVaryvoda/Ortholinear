import SwiftUI

/// Where the private Pro sources plug into the app. The public repository builds the Free
/// edition, so every hook stays empty; release builds fill them at launch. See
/// docs/PRO-IMPLEMENTATION.md.
@MainActor
enum ProHooks {
    /// Rows for Keyboard settings' own Pro section, after Languages.
    static var settingsRows: ((Binding<KeyboardPreferences>) -> AnyView)?
    /// A section at the top of Theme and colors.
    static var appearanceSection: ((Binding<KeyboardPreferences>) -> AnyView)?
    /// Sections in the Layout Workshop: for the selected key, and for the whole draft.
    static var workshopKeySection: ((Binding<CustomKey>) -> AnyView)?
    static var workshopLayoutSection: ((Binding<CustomLetterLayout>) -> AnyView)?
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
