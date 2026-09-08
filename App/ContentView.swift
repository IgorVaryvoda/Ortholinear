import SwiftUI

private let accent = Color(red: 0.12, green: 0.43, blue: 0.38)
private let paper = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
    ? UIColor(red: 0.08, green: 0.10, blue: 0.10, alpha: 1)
    : UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1) })

struct ContentView: View {
    @State private var preferences = PreferenceStore.load()
    @State private var showGeometry = false
    @State private var showSetup = false
    @State private var showSystemTest = false
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 10) {
                    GridMark().frame(width: 30, height: 30)
                    Text("ortholinear").font(.system(size: 23, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("UA + EN").font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .overlay(Capsule().stroke(.primary.opacity(0.18)))
                    Button { showGeometry = true } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold)).frame(minHeight: 40)
                    }.accessibilityLabel("Customize keyboard").accessibilityIdentifier("customize-keyboard")
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Room for\nbigger letters.")
                        .font(.system(size: 43, weight: .medium, design: .rounded)).tracking(-2)
                        .lineSpacing(-5).fixedSize(horizontal: false, vertical: true)
                    Text("Give the letters more space. Make everything else optional.")
                        .font(.system(size: 16)).foregroundStyle(.secondary).lineSpacing(4)
                }

                HStack(spacing: 8) {
                    Label("Private typing", systemImage: "lock.shield")
                    Text("·")
                    Text("No tracking")
                    Text("·")
                    Text("No autocorrect")
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("YOUR TEST DRIVE").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
                        Spacer()
                        Button("Clear") { NotificationCenter.default.post(name: .clearKeyboardPreview, object: nil) }
                            .font(.system(size: 12, weight: .medium)).accessibilityIdentifier("clear-preview")
                    }
                    PreviewSurface(preferences: preferences)
                        .frame(height: 100 + preferences.keyboardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.08)))
                    Text("Hold 123, slide to a symbol, and release to type it. Slide on space to move the cursor. Double-tap shift for caps lock.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                }

                VStack(spacing: 10) {
                    Button { showSetup = true } label: {
                        HStack { Text("Enable keyboard"); Spacer(); Image(systemName: "arrow.up.right") }
                            .font(.system(size: 14, weight: .semibold)).padding(17)
                            .foregroundStyle(.white).background(accent, in: RoundedRectangle(cornerRadius: 12))
                    }.accessibilityIdentifier("enable-keyboard")
                    Button { showGeometry = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3").font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Keyboard settings").font(.system(size: 15, weight: .semibold))
                                Text("Themes, layout and typing").font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }.padding(17).frame(maxWidth: .infinity)
                            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }.accessibilityLabel("Keyboard settings, themes, layout and typing").accessibilityIdentifier("adjust-geometry")
                }

                VStack(spacing: 0) {
                    detailRow("01", title: "All the way to the edges.", subtitle: "No stagger or indents. Fewer keys in a row means wider letters.")
                    Divider().padding(.vertical, 17)
                    detailRow("02", title: "Make the space yours.", subtitle: "Size letters and controls separately. Choose which punctuation earns a key.")
                    Divider().padding(.vertical, 17)
                    detailRow("03", title: "Your words stay yours.", subtitle: "No network access, tracking, or Full Access. Your typing stays on your device.")
                }
                .padding(20).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))

                Button("Test the installed system keyboard") { showSystemTest = true }
                    .font(.system(size: 13, weight: .medium)).accessibilityIdentifier("system-test")
                HStack(spacing: 20) {
                    Link("Privacy policy", destination: URL(string: "https://github.com/IgorVaryvoda/Ortholinear/blob/main/PRIVACY.md")!)
                    Link("Support", destination: URL(string: "https://github.com/IgorVaryvoda/Ortholinear/blob/main/SUPPORT.md")!)
                }
                .font(.system(size: 13, weight: .medium))
                Text("BUILT FOR YOUR HANDS.  /  V0.3.2")
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5)
                    .foregroundStyle(.tertiary).padding(.bottom, 20)
            }
            .padding(.horizontal, 22).frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(paper).tint(accent)
        .sheet(isPresented: $showGeometry) { GeometrySettings(preferences: $preferences) }
        .sheet(isPresented: $showSetup) { SetupView() }
        .sheet(isPresented: $showSystemTest) { SystemKeyboardTest() }
        .onChange(of: preferences) { _, value in
            do { try PreferenceStore.save(value) }
            catch { saveError = "The preview was updated, but settings could not be shared with the extension. Check that both targets use the same App Group and signing team." }
        }
        .alert("Settings weren’t saved", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    private func detailRow(_ index: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(index).font(.system(size: 11, design: .monospaced)).foregroundStyle(accent).padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct GridMark: View {
    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<3) { row in
                GridRow { ForEach(0..<3) { column in
                    RoundedRectangle(cornerRadius: 1).fill(row == 2 && column == 2 ? accent.opacity(0.35) : accent)
                } }
            }
        }
    }
}

struct GeometrySettings: View {
    @Binding var preferences: KeyboardPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var previewLanguage: KeyboardLanguage = .ukrainian
    @State private var showAppearance = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    HStack(spacing: 0) {
                        controls.frame(maxWidth: .infinity)
                        livePreview(maxHeight: geometry.size.height - 60)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        controls
                        livePreview(maxHeight: geometry.size.height * 0.45)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Keyboard settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showAppearance) { AppearanceSettings(preferences: $preferences) }
        }.tint(accent)
    }

    private func livePreview(maxHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack {
                Label("Live preview", systemImage: "keyboard")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button { showAppearance = true } label: {
                    Image(systemName: "paintpalette").frame(width: 34, height: 34)
                }
                .accessibilityLabel("Choose keyboard theme")
                .accessibilityIdentifier("choose-theme")
                Picker("Preview language", selection: $previewLanguage) {
                    ForEach(KeyboardLanguage.allCases, id: \.self) { Text($0.badge).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 112)
                .accessibilityIdentifier("preview-language")
            }.padding(.horizontal, 16)
            SettingsKeyboardPreview(preferences: preferences, language: previewLanguage)
                .frame(height: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 8)
        }
        .padding(.top, 12).padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var controls: some View {
        Form {
            Section("Appearance") {
                Button { showAppearance = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "paintpalette.fill").font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Theme and colors").font(.body.weight(.medium))
                            Text("\(preferences.theme.title) · \(preferences.accent.title)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                .accessibilityIdentifier("theme-settings")
            }
            Section {
                HStack(spacing: 6) {
                    ForEach(KeyboardPreset.allCases) { preset in
                        Button(preset.title) { preferences.apply(preset) }
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("preset-\(preset.rawValue)")
                    }
                }
                Text(activePreset?.detail ?? "Your custom geometry")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Label("Layout · Presets", systemImage: "square.grid.3x3") }
            Section {
                slider("Key height", value: $preferences.keyHeight, range: 36...88)
                slider("Control row height", value: $preferences.controlHeight, range: 36...72)
                slider("Letter size", value: $preferences.letterSize, range: 18...36)
                VStack(alignment: .leading) {
                    HStack {
                        Text("Return and Delete width")
                        Spacer()
                        Text(preferences.actionKeyWidth, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $preferences.actionKeyWidth, in: 1.25...3.5, step: 0.05)
                        .accessibilityLabel("Return and Delete width")
                }
            } header: { Label("Layout · Size", systemImage: "textformat.size") } footer: {
                Text("Size letters and controls separately. The preview updates as you drag.")
            }
            Section {
                slider("Column spacing", value: $preferences.columnSpacing, range: 0...8)
                slider("Row spacing", value: $preferences.rowSpacing, range: 0...12)
                Toggle("Fill gaps between keys", isOn: $preferences.fillGaps)
                    .accessibilityIdentifier("fill-gaps")
            } header: { Label("Layout · Spacing", systemImage: "arrow.left.and.right") } footer: {
                Text("Fill gaps keeps the visual spacing while extending touch targets to meet. Turn it off to make only the visible keys respond.")
            }
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Shift position")
                    Picker("Shift position", selection: $preferences.shiftPlacement) {
                        ForEach(ShiftPlacement.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Toggle("Show header strip", isOn: $preferences.showHeader)
                    .accessibilityIdentifier("show-header")
            } header: { Label("Layout · Controls", systemImage: "rectangle.bottomthird.inset.filled") } footer: {
                Text("Hide the header to leave more room for letters.")
            }
            Section {
                Toggle("Dot, comma and question mark", isOn: $preferences.showPunctuation)
                    .accessibilityIdentifier("show-punctuation")
                Toggle("English apostrophe", isOn: $preferences.showApostrophe)
                    .accessibilityIdentifier("show-apostrophe")
                Toggle("ї on long-press і", isOn: $preferences.yiOnLongPress)
                    .accessibilityIdentifier("yi-on-long-press")
            } header: { Label("Letters · Optional keys", systemImage: "character.cursor.ibeam") } footer: {
                Text("Fewer keys means wider letters. Punctuation stays available under 123. Moving ї to long-press і removes its separate key; hold І with Shift for Ї.")
            }
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Starting language")
                    Picker("Language", selection: $preferences.defaultLanguage) {
                        ForEach(KeyboardLanguage.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Toggle("Space after punctuation", isOn: $preferences.autoSpacePunctuation)
                    .accessibilityIdentifier("auto-space-punctuation")
            } header: { Label("Typing", systemImage: "keyboard") } footer: {
                Text("The UA / EN key switches languages as you type. Automatic spacing adds a space after punctuation; apostrophes and numbers such as 3.14 stay together. Hold Delete to gradually delete faster.")
            }
            Section {
                Button("Reset to defaults") { preferences = KeyboardPreferences() }
            } footer: {
                Text("Settings save on this device. Dismiss and reopen the system keyboard to apply changes. The UA / EN key switches languages as you type.")
            }
        }
        .accessibilityIdentifier("geometry-controls")
    }

    private var activePreset: KeyboardPreset? {
        KeyboardPreset.allCases.first { preset in
            var candidate = preset.preferences
            candidate.defaultLanguage = preferences.defaultLanguage
            candidate.theme = preferences.theme
            candidate.accent = preferences.accent
            candidate.showLongPressHints = preferences.showLongPressHints
            return candidate == preferences
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue)) pt")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(accent.opacity(0.08), in: Capsule()) }
            Slider(value: value, in: range, step: 1).accessibilityLabel(title)
        }.padding(.vertical, 4)
    }
}

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Open Settings → General → Keyboard", systemImage: "1.circle")
                    Label("Choose Keyboards → Add New Keyboard", systemImage: "2.circle")
                    Label("Select Ortholinear", systemImage: "3.circle")
                    Label("In any text field, use the globe to switch to Ortholinear", systemImage: "4.circle")
                } header: { Text("A one-time setup") } footer: {
                    Text("Ortholinear does not request Full Access. Typing and geometry settings work without network access.")
                }
                Section {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } footer: { Text("If Settings opens the app page, return to the main Settings list and follow the steps above.") }
                Section("Where it works") {
                    Text("Use it in apps that allow third-party keyboards. iOS uses its own keyboard for passwords and phone-pad fields. Some apps disable third-party keyboards entirely.")
                    Text("There is no autocorrect or automatic capitalization. You can turn automatic spacing after punctuation on or off in customization.")
                }
            }
            .navigationTitle("Meet your new keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(accent)
    }
}

struct SystemKeyboardTest: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var email = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Use the globe to choose Ortholinear") {
                    TextEditor(text: $text).frame(minHeight: 150).accessibilityIdentifier("system-editor")
                }
                Section("Email input") {
                    TextField("name@example.com", text: $email).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).accessibilityIdentifier("email-editor")
                }
            }
            .navigationTitle("System keyboard test").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
