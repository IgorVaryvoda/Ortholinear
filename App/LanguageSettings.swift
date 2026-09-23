import SwiftUI

struct LanguageSettings: View {
    @Binding var preferences: KeyboardPreferences

    var body: some View {
        Form {
            Section {
                ForEach(KeyboardLanguage.allCases.filter { $0 != .russian }, id: \.self) { language in
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
                switch preferences.invasionAnswer {
                case .unanswered:
                    Text("Do you support Russia’s invasion of Ukraine?")
                    HStack(spacing: 12) {
                        Button("Yes") { preferences.invasionAnswer = .supports }
                            .accessibilityIdentifier("invasion-supports")
                        Button("No") { preferences.invasionAnswer = .opposes }
                            .accessibilityIdentifier("invasion-opposes")
                    }
                    // Separate bordered buttons, or the whole row becomes one tap target.
                    .buttonStyle(.bordered)
                case .opposes:
                    Toggle(isOn: enabled(.russian)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(KeyboardLanguage.russian.title)
                            Text(detail(.russian)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(languages == [.russian])
                    .accessibilityIdentifier("language-russian")
                case .supports:
                    Text("Russian isn’t available.").foregroundStyle(.secondary)
                }
            } header: { Text("Русский") } footer: {
                if preferences.invasionAnswer == .unanswered {
                    Text("Answer to see the Russian layout.")
                }
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
        case .czech: "QWERTZ · hold for ě š č ř ž ý á í é ů and more"
        case .slovak: "QWERTZ · hold for á ä č ď é í ľ ň ô š ť ž and more"
        case .bcms: "Hrvatski, bosanski, crnogorski, srpski · QWERTZ with č ć đ š ž"
        case .serbianCyrillic: "Српски, црногорски · љ њ ђ ћ џ ј"
        case .swedish: "QWERTY with å ä ö · hold e for é"
        case .norwegian: "QWERTY with å ø æ · hold e for é"
        case .danish: "QWERTY with å æ ø · hold e for é"
        case .dutch: "QWERTY · hold for é ë ï ó ü and more"
        case .russian: "ЙЦУКЕН · hold е for ё and ь for ъ"
        }
    }
}
