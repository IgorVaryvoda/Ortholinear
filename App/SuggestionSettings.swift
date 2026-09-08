import SwiftUI

struct SuggestionSettings: View {
    @Binding var preferences: KeyboardPreferences
    var body: some View {
        Form {
            Section {
                Toggle("Word suggestions", isOn: $preferences.suggestionsEnabled).accessibilityIdentifier("word-suggestions")
                Toggle("Next-word suggestions", isOn: $preferences.nextWordSuggestions)
                    .disabled(!preferences.suggestionsEnabled).accessibilityIdentifier("next-word-suggestions")
                Toggle("Use sentence context", isOn: $preferences.contextualSuggestions)
                    .disabled(!preferences.suggestionsEnabled).accessibilityIdentifier("contextual-suggestions")
            } footer: {
                Text("English and Ukrainian suggestions run on your device. Tap an offered word to use it. Space and punctuation never accept a suggestion automatically.")
            }
            Section("Fix a word") {
                Label("Place the cursor inside a word or select it to see alternatives above the keys.", systemImage: "text.cursor")
                Text("Suggestions use nearby keys, word frequency, and optional short sentence context. Names and unfamiliar words always remain as typed unless you choose a replacement.")
                    .foregroundStyle(.secondary)
            }
            Section("Teach it your words") {
                Label("Type a word, then tap ⋯ in the suggestion row and choose Teach.", systemImage: "plus.circle")
                Text("The same menu lets you forget a word or clear the list for the current language. Up to 200 words per language.")
                Text("Words taught in the system keyboard stay there. The app preview has its own word list. Neither list needs Full Access or leaves your device.")
                    .foregroundStyle(.secondary)
            }
            Section {
                NavigationLink("Dictionary credits") { DictionaryCreditsView() }
            }
        }
        .navigationTitle("Suggestions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DictionaryCreditsView: View {
    private var credits: String {
        guard let url = SuggestionResources.bundle.url(forResource: "DictionaryCredits", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "Dictionary credits unavailable." }
        return text
    }
    var body: some View {
        ScrollView { Text(credits).font(.footnote).textSelection(.enabled).padding() }
            .navigationTitle("Dictionary credits").navigationBarTitleDisplayMode(.inline)
    }
}
