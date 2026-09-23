import SwiftUI

struct LanguageSettings: View {
    @Binding var preferences: KeyboardPreferences

    var body: some View {
        Form {
            Section {
                ForEach(KeyboardLanguage.allCases, id: \.self) { language in
                    Toggle(isOn: enabled(language)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(language.title)
                            Text(detail(language)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(languages == [language])
                    .accessibilityIdentifier("language-\(language.rawValue)")
                }
            } header: { Text("Languages") } footer: {
                Text("The language key cycles through the languages you turn on. Hold a letter for its accented forms. Word suggestions are available in English and Ukrainian.")
            }
            Section {
                Picker("English layout", selection: $preferences.englishLayout) {
                    ForEach(EnglishLayout.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("english-layout")
                SettingsKeyboardPreview(preferences: preferences, language: .english)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            } footer: {
                Text("Colemak, Colemak-DH, Dvorak and Workman rearrange the English letters. Colemak-DH uses the ortholinear bottom row. Suggestions follow the layout you choose.")
            }
            Section {
                Picker("Starting language", selection: $preferences.defaultLanguage) {
                    ForEach(languages, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("starting-language")
                Toggle("Remember for each kind of field", isOn: $preferences.rememberLanguage)
                    .accessibilityIdentifier("remember-language")
                Button("Forget remembered languages") { preferences.languageMemoryGeneration += 1 }
                    .accessibilityIdentifier("forget-languages")
            } header: { Text("Switching") } footer: {
                Text("Message, search, email and web address fields each reopen in the language you last used in that kind of field. Email and web address fields start in a Latin layout; other new fields continue in your last language. iOS doesn’t tell keyboards which app, window or chat they’re in, so this memory is shared by all apps. The keyboard keeps it on this device, as field types and language names, never text. Forgetting, or changing the starting language, starts over from the starting language.")
            }
        }
        .accessibilityIdentifier("language-controls")
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var languages: [KeyboardLanguage] { preferences.validated.languages }

    private func enabled(_ language: KeyboardLanguage) -> Binding<Bool> {
        Binding {
            languages.contains(language)
        } set: { isOn in
            var chosen = languages.filter { $0 != language }
            if isOn { chosen.append(language) }
            guard !chosen.isEmpty else { return }
            preferences.languages = KeyboardLanguage.allCases.filter(chosen.contains)
            preferences.defaultLanguage = preferences.validated.defaultLanguage
        }
    }

    private func detail(_ language: KeyboardLanguage) -> String {
        switch language {
        case .ukrainian: "ЙЦУКЕН · hold г for ґ"
        case .english: preferences.englishLayout.title
        case .polish: "QWERTY · hold for ą ć ę ł ń ó ś ź ż"
        case .german: "QWERTZ with ä ö ü · hold s for ß"
        case .french: "AZERTY · hold for é è ê à ç and more"
        case .spanish: "QWERTY with ñ · hold for á é í ó ú ü"
        }
    }
}
