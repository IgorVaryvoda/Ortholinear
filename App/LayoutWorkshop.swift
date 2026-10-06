import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let ortholinearLayout = UTType(exportedAs: "com.varyvoda.ortholinear.layout", conformingTo: .json)
}

/// Rearranges a language's letters. Edits stay a draft until Apply puts them in the keyboard.
struct LayoutWorkshop: View {
    @Binding var preferences: KeyboardPreferences
    @State private var language: KeyboardLanguage
    @State private var drafts: [KeyboardLanguage: CustomLetterLayout] = [:]
    @State private var history: [KeyboardLanguage: [CustomLetterLayout]] = [:]
    @State private var selection: KeyPosition?
    @State private var swapping = false
    @State private var showTry = false
    @State private var showImporter = false
    @State private var notice: String?

    init(preferences: Binding<KeyboardPreferences>) {
        _preferences = preferences
        _language = State(initialValue: preferences.wrappedValue.validated.defaultLanguage)
    }

    var body: some View {
        Form {
            if languages.count > 1 {
                Section {
                    Picker("Language", selection: $language) {
                        ForEach(languages, id: \.self) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("workshop-language")
                }
            }
            Section {
                KeyGrid(rows: draft.rows, selection: selection, swapping: swapping, tap: tap)
                    .listRowInsets(EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8))
            } header: {
                Text(isCustom || hasChanges ? "\(language.title) · your layout" : "\(language.title) · built-in layout")
            } footer: {
                Text(swapping ? "Tap the key to swap with. Tap the same key to cancel."
                     : "Tap a key to change what it types and holds, or to move it. Delete, Shift and the bottom row stay where they are.")
            }
            if let selection, draft.contains(selection) {
                keySection(selection)
                if let extra = ProHooks.workshopKeySection { extra(keyBinding(selection)) }
            }
            if let extra = ProHooks.workshopLayoutSection { extra(draftBinding) }
            Section("Check") {
                if problems.isEmpty {
                    Label("Every letter is reachable", systemImage: "checkmark.circle")
                        .foregroundStyle(.tint)
                        .accessibilityIdentifier("workshop-ready")
                } else {
                    ForEach(problems, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            Section {
                Button("Apply to keyboard", action: apply)
                    .font(.body.weight(.semibold))
                    .disabled(!problems.isEmpty || !hasChanges)
                    .accessibilityIdentifier("workshop-apply")
                Button("Try it") { showTry = true }
                    .accessibilityIdentifier("workshop-try")
                Button("Undo") { undo() }
                    .disabled(history[language, default: []].isEmpty)
                    .accessibilityIdentifier("workshop-undo")
                Button("Start over from built-in") {
                    edit { $0 = builtIn }
                    selection = nil
                }
                .disabled(draft == builtIn)
                .accessibilityIdentifier("workshop-start-over")
            } footer: {
                if let notice { Text(notice).accessibilityIdentifier("workshop-notice") }
                else if hasChanges { Text("Not applied yet. Try it here first if you like.") }
            }
            Section {
                ShareLink(item: LayoutExport(file: LayoutFile(language: language, layout: draft)),
                          preview: SharePreview("\(language.title) layout")) {
                    Label("Share layout", systemImage: "square.and.arrow.up")
                }
                .disabled(!problems.isEmpty)
                .accessibilityIdentifier("workshop-share")
                Button { showImporter = true } label: {
                    Label("Open a layout file", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("workshop-import")
            } header: { Text("Share") } footer: {
                Text("A layout file holds only the letters and what they hold, never your text or settings. Opening one changes nothing until you apply it.")
            }
            if isCustom {
                Section {
                    Button("Use the built-in layout", role: .destructive) {
                        preferences.customLayouts[language] = nil
                        drafts[language] = nil
                        history[language] = nil
                        selection = nil
                        notice = "Back to the built-in \(language.title) layout. Reopen the keyboard to see it."
                    }
                    .accessibilityIdentifier("workshop-use-built-in")
                } footer: {
                    Text("Your layout replaces \(language.title)’s built-in letters, so the optional key and English layout settings don’t change it.")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("workshop-controls")
        .navigationTitle("Layout Workshop")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: language) { selection = nil; swapping = false; notice = nil }
        .onChange(of: preferences.validated.languages) { _, enabled in
            if !enabled.contains(language) { language = preferences.validated.defaultLanguage }
        }
        .sheet(isPresented: $showTry) { tryItSheet }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.ortholinearLayout, .json]) { result in
            if case .success(let url) = result { open(url) }
        }
    }

    // MARK: Selected key

    private func keySection(_ position: KeyPosition) -> some View {
        Section {
            LabeledContent("Types") {
                CharacterField(value: draft[position].output) { value in
                    edit { if $0.contains(position) { $0[position].output = value } }
                }
                .id(position)
                .accessibilityIdentifier("workshop-output")
            }
            LabeledContent("Hold for") {
                TextField("None", text: alternatives(position))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("workshop-alternatives")
            }
            HStack(spacing: 8) {
                moveButton(position, .left, "arrow.left", "Move left")
                moveButton(position, .right, "arrow.right", "Move right")
                moveButton(position, .up, "arrow.up", "Move up a row")
                moveButton(position, .down, "arrow.down", "Move down a row")
            }
            .buttonStyle(.bordered)
            Button(swapping ? "Cancel swap" : "Swap with another key…") { swapping.toggle() }
                .accessibilityIdentifier("workshop-swap")
            Button("Add a key after this one") {
                edit { selection = $0.insertKey(after: position) ?? selection }
            }
            .disabled(draft.rows[position.row].count >= CustomLetterLayout.maximumRowLength)
            .accessibilityIdentifier("workshop-add-key")
            Button("Remove this key", role: .destructive) {
                edit { selection = $0.removeKey(at: position) }
            }
            .disabled(draft.rows[position.row].count <= 1)
            .accessibilityIdentifier("workshop-remove-key")
        } header: {
            Text("Row \(position.row + 1), key \(position.column + 1)")
        } footer: {
            Text("Holding a key offers its hold characters; releasing in place types the first. Leave Hold for empty on punctuation to keep the usual choices.")
        }
    }

    private func moveButton(_ position: KeyPosition, _ direction: MoveDirection, _ icon: String, _ title: String) -> some View {
        Button {
            edit { selection = $0.move(position, direction) ?? selection }
        } label: {
            Image(systemName: icon).frame(maxWidth: .infinity, minHeight: 32)
        }
        .disabled(draft.destination(of: position, direction) == nil)
        .accessibilityLabel(title)
        .accessibilityIdentifier("workshop-move-\(direction)")
    }

    private func alternatives(_ position: KeyPosition) -> Binding<String> {
        Binding {
            draft.contains(position) ? draft[position].alternatives.joined(separator: " ") : ""
        } set: { text in
            let values = CustomKey.characters(in: text.lowercased()).prefix(CustomLetterLayout.maximumAlternatives)
            edit { if $0.contains(position) { $0[position].alternatives = Array(values) } }
        }
    }

    private func keyBinding(_ position: KeyPosition) -> Binding<CustomKey> {
        Binding {
            draft.contains(position) ? draft[position] : CustomKey("")
        } set: { key in
            edit { if $0.contains(position) { $0[position] = key } }
        }
    }

    private var draftBinding: Binding<CustomLetterLayout> {
        Binding { draft } set: { layout in edit { $0 = layout } }
    }

    private func tap(_ position: KeyPosition) {
        if swapping, let selection {
            if selection != position { edit { $0.swapKeys(selection, position) } }
            swapping = false
        }
        selection = position
    }

    // MARK: Draft

    private var languages: [KeyboardLanguage] { preferences.validated.languages }
    private var isCustom: Bool { preferences.customLayouts[language] != nil }
    private var builtIn: CustomLetterLayout { CustomLetterLayout(builtIn: language, preferences: preferences) }
    private var applied: CustomLetterLayout { preferences.customLayouts[language] ?? builtIn }
    private var draft: CustomLetterLayout { drafts[language] ?? applied }
    private var hasChanges: Bool { draft != applied }

    private var problems: [String] {
        var seen: Set<String> = []
        return draft.problems(for: language).map(describe).filter { seen.insert($0).inserted }
    }

    private func edit(_ change: (inout CustomLetterLayout) -> Void) {
        var layout = draft
        let before = layout
        change(&layout)
        guard layout != before else { return }
        history[language, default: []].append(before)
        drafts[language] = layout
        notice = nil
    }

    private func undo() {
        guard let previous = history[language]?.popLast() else { return }
        drafts[language] = previous
        if let selection, !previous.contains(selection) { self.selection = nil }
        swapping = false
    }

    private func apply() {
        // A layout identical to the built-in one would only freeze it against later setting changes.
        preferences.customLayouts[language] = draft == builtIn ? nil : draft
        drafts[language] = nil
        notice = "Applied. Dismiss and reopen the keyboard to use it."
    }

    private func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > LayoutFile.maximumSize {
                throw LayoutFile.ReadError.tooLarge
            }
            let file = try LayoutFile.read(Data(contentsOf: url))
            guard languages.contains(file.language) else {
                notice = "This layout is for \(file.language.title). Turn that language on in Languages, then open it again."
                return
            }
            language = file.language
            edit { $0 = file.layout }
            selection = nil
            notice = "Opened a \(file.language.title) layout. Check it, then apply it."
        } catch let error as LayoutFile.ReadError {
            notice = switch error {
            case .tooLarge: "That file is too large to be a layout."
            case .notALayout: "That file isn’t an Ortholinear layout."
            case .newerVersion: "That layout was made by a newer version of Ortholinear. Update the app to open it."
            case .unknownLanguage: "That layout is for a language this version doesn’t have."
            case .malformed: "That layout file is damaged."
            }
        } catch {
            notice = "The file couldn’t be read."
        }
    }

    private func describe(_ problem: CustomLetterLayout.Problem) -> String {
        switch problem {
        case .rowCount: "A layout needs exactly three rows of letters."
        case .rowLength(let row, 0): "Row \(row + 1) is empty."
        case .rowLength(let row, let count): "Row \(row + 1) has \(count) keys; the most is \(CustomLetterLayout.maximumRowLength)."
        case .notOneCharacter(""): "A key doesn’t type anything yet."
        case .notOneCharacter(let value): "“\(value)” is more than one character."
        case .notLowercase(let value): "“\(value)” is a capital. Keys hold lowercase letters; Shift makes capitals."
        case .duplicate(let value): "Two keys type “\(value)”."
        case .tooManyAlternatives(let value): "“\(value)” holds more than \(CustomLetterLayout.maximumAlternatives) characters."
        case .missingLetters(let letters):
            "Missing: \(letters.map(String.init).joined(separator: " ")). Add \(letters.count == 1 ? "it" : "them") as a key, or to a key’s Hold for."
        }
    }

    // MARK: Try it

    private var tryItSheet: some View {
        var trial = preferences
        trial.languages = [language]
        trial.defaultLanguage = language
        trial.customLayouts[language] = draft
        return NavigationStack {
            VStack(spacing: 12) {
                if !problems.isEmpty {
                    Label("Fix the problems in the Workshop to try your layout. This is the built-in one.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange).padding(.horizontal)
                }
                PreviewSurface(preferences: trial, isActive: true)
                    .frame(height: 100 + trial.keyboardHeight)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Try \(language.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showTry = false } } }
        }
    }
}

/// A one-character field: whatever is typed replaces the old character, wherever the cursor was.
private struct CharacterField: View {
    let value: String
    let commit: (String) -> Void
    @State private var text = ""

    var body: some View {
        TextField("Character", text: $text)
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .onAppear { text = value }
            .onChange(of: value) { _, new in if new != text { text = new } }
            .onChange(of: text) { old, new in
                let typed = new.lowercased().filter { !$0.isWhitespace }.map(String.init)
                var inserted = typed
                for character in old.map(String.init) {
                    if let index = inserted.firstIndex(of: character) { inserted.remove(at: index) }
                }
                let chosen = typed.count <= 1 ? typed.first ?? "" : inserted.last ?? typed.last ?? ""
                if chosen != new { text = chosen }
                if chosen != value { commit(chosen) }
            }
    }
}

/// Editable keys, sized like the keyboard: equal widths within each row.
struct KeyGrid: View {
    let rows: [[CustomKey]]
    let selection: KeyPosition?
    let swapping: Bool
    let tap: (KeyPosition) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(rows[row].indices, id: \.self) { column in
                        keyButton(KeyPosition(row: row, column: column))
                    }
                }
            }
        }
    }

    private func keyButton(_ position: KeyPosition) -> some View {
        let key = rows[position.row][position.column]
        let selected = position == selection
        return Button { tap(position) } label: {
            Text(key.label ?? key.command?.symbol ?? (key.output.isEmpty ? "?" : key.output))
                .lineLimit(1).minimumScaleFactor(0.5)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(key.output.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(alignment: .topTrailing) {
                    if let hint = key.alternatives.first {
                        Text(hint).font(.system(size: 9)).foregroundStyle(.secondary).padding(.top, 2).padding(.trailing, 3)
                    }
                }
                .background(selected ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.primary.opacity(0.07)),
                            in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear),
                                      style: StrokeStyle(lineWidth: 1.5, dash: selected && swapping ? [4, 3] : []))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.label ?? key.command?.title ?? (key.output.isEmpty ? "Empty key" : key.output))
        .accessibilityValue(key.alternatives.isEmpty ? "" : "Holds \(key.alternatives.joined(separator: " "))")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("workshop-key-\(position.row)-\(position.column)")
    }
}

/// A layout shared as a `.ortholayout` file named after its language.
private struct LayoutExport: Transferable {
    let file: LayoutFile

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .ortholinearLayout) { export in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("\(export.file.language.title) layout.ortholayout")
            try export.file.data().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
