import SwiftUI

/// Where the private Pro sources plug into the app. The public repository builds the Free
/// edition, so every hook stays empty; release builds fill them at launch. See
/// docs/PRO-IMPLEMENTATION.md.
@MainActor
enum ProHooks {
    /// Extra rows for Keyboard settings, below Languages and the Layout Workshop.
    static var settingsRows: ((Binding<KeyboardPreferences>) -> AnyView)?
}
