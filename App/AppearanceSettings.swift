import SwiftUI

struct AppearanceSettings: View {
    @Binding var preferences: KeyboardPreferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    HStack(spacing: 0) {
                        controls
                        preview(height: geometry.size.height - 50).frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        controls
                        preview(height: min(240, geometry.size.height * 0.34))
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Make it yours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.accessibilityIdentifier("appearance-done")
            } }
        }
    }

    private var controls: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(KeyboardTheme.allCases, id: \.self) { theme in
                        themeCard(theme)
                    }
                }.padding(.vertical, 6)
            } header: { Text("Keyboard theme") } footer: {
                Text("Automatic follows your device’s light or dark appearance. Every theme keeps your layout and touch targets.")
            }
            Section {
                Picker("Accent color", selection: $preferences.accent) {
                    ForEach(KeyboardAccent.allCases, id: \.self) { choice in
                        Text(choice.title).tag(choice)
                    }
                }.accessibilityIdentifier("keyboard-accent")
                HStack(spacing: 12) {
                    ForEach(KeyboardAccent.allCases, id: \.self) { choice in
                        let colors = KeyboardColors.resolve(theme: preferences.theme, accent: choice, systemDark: colorScheme == .dark)
                        Button { preferences.accent = choice } label: {
                            Circle().fill(Color(uiColor: UIColor(keyboardHex: colors.accent)))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if preferences.accent == choice {
                                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(colors.isDark ? .black : .white)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.title)
                        .accessibilityIdentifier("accent-\(choice.rawValue)")
                        .accessibilityAddTraits(preferences.accent == choice ? [.isSelected] : [])
                    }
                }
            } header: { Text("Accent") }
            Section {
                Toggle("Show long-press hints", isOn: $preferences.showLongPressHints)
                    .accessibilityIdentifier("show-long-press-hints")
            } header: { Label("Key hints", systemImage: "character.bubble") } footer: {
                Text("Small ґ and ї hints show which letters are available by holding a key. Enable ї on long-press і in Keyboard settings → Letters to move it off its separate key.")
            }
        }.accessibilityIdentifier("appearance-controls")
    }

    private func themeCard(_ theme: KeyboardTheme) -> some View {
        let colors = KeyboardColors.resolve(theme: theme, systemDark: colorScheme == .dark)
        let selected = preferences.theme == theme
        return Button { preferences.theme = theme } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 3) {
                    ForEach(["і", "ї", "⌫"], id: \.self) { letter in
                        Text(letter).font(.system(size: 19, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 31)
                            .background(Color(uiColor: UIColor(keyboardHex: letter == "⌫" ? colors.control : colors.key)),
                                        in: RoundedRectangle(cornerRadius: 5))
                    }
                }
                HStack(spacing: 4) {
                    Text(theme.title).font(.system(size: 12, weight: .semibold))
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)) }
                }
            }
            .foregroundStyle(Color(uiColor: UIColor(keyboardHex: colors.text)))
            .padding(10).frame(maxWidth: .infinity, minHeight: 85, alignment: .topLeading)
            .background(Color(uiColor: UIColor(keyboardHex: colors.background)), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(uiColor: UIColor(keyboardHex: selected ? colors.accent : colors.border)), lineWidth: selected ? 2 : 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityHint(theme.detail)
        .accessibilityIdentifier("theme-\(theme.rawValue)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func preview(height: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(preferences.theme.title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("Live preview").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 16)
            SettingsKeyboardPreview(preferences: preferences, language: .ukrainian)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}
