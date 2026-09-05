import SwiftUI

struct VoiceKeyboardButton: View {
    @Environment(\.openURL) private var openURL
    @State private var failed = false
    let ready: Bool
    let insert: () -> Void

    var body: some View {
        Button {
            if ready { insert() }
            else { openURL(URL(string: "ortholinear://voice")!) { accepted in failed = !accepted } }
        } label: {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ready ? "Insert dictation" : "Voice input")
        .accessibilityIdentifier(ready ? "key-Insert dictation" : "key-Voice input")
        .alert("Open Ortholinear to record", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("iOS could not open the recorder from this keyboard. Open Ortholinear → Voice input, record, then return here to insert your words.")
        }
    }
}
