# Pro implementation plan

Status: **phases 0–5 built**: custom layouts, the free Workshop, the edition seam, layers, saved setups and the paid unlock. Phase 6, the release work, remains. Read [PRO.md](PRO.md) for the product decisions. Code references in section 2 are to commit `084be31`.

## 1. Edition boundary

The public repository builds the Free app exactly as before. Pro lives in the private repository `IgorVaryvoda/OrtholinearPro`, checked out next to this one. Its sources compile into the containing app target. The keyboard extension never includes them.

The Pro code is not a separate Swift package. `Core/` compiles straight into the app target, so a package would see its own copy of every Core type, and the app's types and the package's types would not match.

- `project.yml` stays the public spec, and the checked-in Xcode project stays the Free edition.
- The private `project.pro.yml` uses XcodeGen's `include:` to pull in `../Ortholinear/project.yml`. It then adds the private `Sources/` to the `Ortholinear` target, sets the `PRO` compilation condition, and adds the Pro unit and UI test targets. Release builds use the generated `OrtholinearPro.xcodeproj`, which is not committed.
- The app reaches Pro through `App/ProHooks.swift`, whose hooks stay empty in the Free edition. `OrtholinearApp.swift` holds the only `#if PRO`, which calls `ProEdition.install()` to fill them.
- Engine code needed to *render* Pro data, such as layers, stays public in `Core/` and `SharedUI/`. The extension must be able to render whatever the app publishes.

| Public (MIT) | Private (`OrtholinearPro` sources) |
| --- | --- |
| Custom layout and layer model, validation, decoding | Layer editor and starters |
| Layout and geometry changes, glide and suggestion fixes | Phrase key editor and export preview |
| Free Workshop editor and single-layout files | Saved setups and setup files |
| Publishing to the App Group | StoreKit, purchase sheet, Pro settings row |

## 2. Custom letter layouts (public, Free)

Today a language's letters come from hard-coded strings in `KeyboardLayout.letterRows` (`Core/KeyboardModel.swift:261`). Long-press characters come from `letterAlternatives` (`:297`), and punctuation holds from `Key.alternatives` (`:194`). Add a data override in front of all three:

```swift
struct CustomKey: Codable, Equatable, Sendable {
    var output: String          // one grapheme on letter rows
    var alternatives: [String] = []
    var label: String? = nil    // phrase keys only
}

struct CustomLetterLayout: Codable, Equatable, Sendable {
    var rows: [[CustomKey]]     // exactly three
}
```

`KeyboardPreferences` gains `customLayouts`, encoded as `[String: CustomLetterLayout]` keyed by `KeyboardLanguage.rawValue`. Unknown languages are dropped on decode, as `languages` already does. Bump `schemaVersion` to 4 and keep decoding tolerant: a malformed layout is ignored, not fatal to the rest of the preferences.

In `KeyboardLayout.rows`, the letters page uses the custom rows when a usable layout exists for `state.language`. Shift placement, digit flicks and the number row already work on the resulting rows. Three things in the existing code needed changes:

- Delete was inserted only after a letter in the third row. A custom third row of punctuation alone now gets Delete at its end.
- `Key.alternatives` returned hard-coded punctuation holds before a key's own. A custom key's holds now win; an empty list keeps the defaults.
- Applying a preset replaced all preferences. It now keeps custom layouts.

Everything downstream already derives from these rows. `KeyboardGeometry.cells` (`:537`) builds hit frames from them. `SuggestionGeometry` (`Core/Suggestions.swift:135`) builds key centres from those cells. `GlideDecoder` (`Core/GlideDecoder.swift:54`) and `LayoutRecovery` use those centres. Two places assumed the built-in layouts:

1. `Suggestions.swift:147` always moved ґ onto г, which would give a custom ґ key wrong suggestion and glide distances. Held letters now take their key's centre only when they have no key of their own.
2. `SuggestionGeometry.isAlternative` (`Core/LayoutRecovery.swift:46`) hard-coded the same ґ/ї assumption. It now uses the held letters recorded by the geometry.

`unit` (`Suggestions.swift:145`) stays the width of the last letter key. Letter keys in a row have equal widths, and suggestion costs and glide scoring were tuned against that value.

Validation (`CustomLetterLayout.validated(for: KeyboardLanguage)`), shared by the editor, file import and the extension:

- Three rows of 1–12 keys. Each output is a single grapheme, with no duplicate outputs.
- Every character of `language.alphabet` is reachable directly or as an alternative. That property already exists for this purpose.
- At most 8 alternatives per key, each a single grapheme.
- Anything invalid makes the extension use the built-in layout for that language. It never crashes and never shows a partial grid.

Single-layout files: a `.ortholayout` JSON document with a declared UTType, opened via `fileImporter` and shared via `ShareLink`. Import runs the same validator and shows the result before replacing anything.

## 3. Layers (public engine, private editor)

```swift
struct CustomLayer: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var rows: [[CustomKey]]     // exactly three rows of up to 10 keys
}
```

Three rows keep a layer page exactly as tall as the numbers page. A fourth row would also be mistaken for the number row by `KeyboardGeometry.cells`.

- `KeyboardPage` gains `case layer(UUID)`. The existing page cycle (`KeyboardViewController.swift:298`) continues numbers → symbols → each layer → numbers.
- Optional control-row layer key (off by default) opens the first layer. The ABC key (`:304`) keeps returning to letters, and the language is untouched.
- Glide stays letters-only. Layers have no suggestions.
- Phrase keys: `label` is drawn and `output` is inserted. Output is limited to 200 characters with no newlines, enforced in validation.
- `InputState.consume` leaves layer output alone, so Shift never turns a phrase into capitals or π into Π.
- Up to 8 layers. Decoding drops damaged layers one by one. A layer with problems stays saved but is skipped by the page cycle, and a deleted layer that was open shows the numbers page.
- Starters (Writing, Math, Code, Phrases, Empty) and the editor are private. Until purchases exist, layers are stored in `KeyboardPreferences` like everything else; section 4's split applies once StoreKit lands.
- Keep the hold-123-and-slide gesture for numbers and symbols only.

## 4. Storage and publishing

The app writes and the extension only reads `geometry.json` (`SharedUI/PreferenceStore.swift`). Every write goes through `KeyboardPublisher.publish` in `App/ProHooks.swift`. It passes the preferences through `ProHooks.prepareForKeyboard`, which the Pro edition sets to switch `layersEnabled` off while Pro is locked.

- Layers stay in `KeyboardPreferences`. When `layersEnabled` is off, the keyboard offers none of them: they're out of the page cycle, there's no layer key, and an open layer shows the numbers page. They are never deleted, so a refund followed by a repurchase brings everything back. The flag replaces the separate `pro.json` planned earlier, which would have needed a second source of truth for layers.
- When access changes, `ProStore` posts `ProHooks.accessChanged` and the app publishes again. The home test drive previews the published copy, so it matches the keyboard.
- Saved setups live in the app's Application Support (`setups.json`). The keyboard only sees the setup that's switched in.

The extension has no idea Pro exists. It renders whatever valid configuration it reads. Without Full Access or StoreKit in the extension, a refund takes effect the next time the app runs. That is acceptable.

## 5. StoreKit (private)

- One non-consumable, placeholder ID `com.varyvoda.Ortholinear.pro`.
- Start a `Transaction.updates` listener at launch. Check `Transaction.currentEntitlements` at launch and when the app becomes active, and finish verified transactions.
- Unlocked means a verified, unrevoked entitlement for that product exists. `currentEntitlements` works offline from StoreKit's own cache, so no network heartbeat is involved.
- Call `AppStore.sync()` only from **Restore purchases**, because it can ask the person to sign in.
- Treat cancelled, pending, unverified and failed results distinctly; only a verified transaction unlocks. Pending shows "Waiting for approval" and changes nothing.
- StoreKit sits behind `ProPurchasing`. `AppStorePurchasing` is the real adapter; unit tests drive `ProStore` with a fake to cover unlocking, caching, cancel, pending, unverified, failure, Ask to Buy approval, refund and restore. `SKTestSession` returned no products under command-line `xcodebuild` on the simulator, even with a known-good configuration, so the real adapter is checked by hand: in Xcode, using `StoreKit/Pro.storekit` (wired to the scheme's Run action), then in sandbox on a device.
- The last verified answer is cached in `UserDefaults` (`pro.unlocked`), so Pro works at launch and offline before StoreKit answers.
- Development builds accept `-pro-unlocked` and `-pro-locked` for UI tests. Release builds ignore them.

## 6. Phases

| # | Work | Repo | Size |
| --- | --- | --- | --- |
| 0 | Edition seam: private sources, `project.pro.yml`, `ProHooks`. Public build unchanged. Done. | both | S |
| 1 | Custom layout model, validation, `rows` override, the geometry fixes, tolerant decoding. `swift test` coverage. Done. | public | M |
| 2 | Free Workshop editor and single-layout files. **Ship as a free update.** Interest in this tells you whether Pro is worth finishing. Done. | public | M–L |
| 3 | Layer engine (page cycle, layer key, phrase rendering) and layer editor with starters. Done. | both | M |
| 4 | Saved setups and setup files with phrase export preview. Done. | private | M |
| 5 | StoreKit, purchase sheet, Pro row, publishing rules. Done. | private | S–M |
| 6 | Release: sandbox purchases on device, review notes, privacy and README updates. | both | S |

Phase 2 is independently valuable and ships before any billing work.

## 7. Acceptance

| Case | Expected |
| --- | --- |
| Existing user updates | Same keyboard, no prompt, no setting changes. |
| Custom layout applied | Touch, long-press, glide, suggestions and wrong-layout recovery all follow the new positions. |
| ґ on its own key | Suggestion and glide distances use ґ's real position. |
| Layout missing a required letter | Apply blocked in the editor; an imported file is rejected with the missing letters listed. |
| Malformed or future-version `geometry.json` | Extension uses built-in layouts and valid remaining settings. |
| Free user opens a Pro feature | One sheet, closable, returns to the same place. Nothing auto-presents anywhere. |
| Purchase cancelled, pending or failed | Nothing unlocks; no automatic retry. |
| Purchase succeeds offline later | Unlock persists across launches without network. |
| Refund or revocation | Next app launch republishes without layers; `pro.json` is intact. Repurchase restores everything. |
| Restore on a new device | Unlocks Pro; setups come only from files the person exported. |
| Public repo build | Builds and passes all tests without the private package. |
| Keyboard extension | No StoreKit, no network, no commercial UI, `RequestsOpenAccess` still false. |

## 8. Release checklist

- [ ] Product created with final price, Family Sharing decided, review screenshot and notes.
- [ ] README: replace "The app and extension make no network requests" with the narrower truth: the app contacts the App Store only for purchases, and the keyboard makes no network requests.
- [ ] PRIVACY.md: same change, plus phrase keys and setups being stored on the device and exported only by the person.
- [ ] App Store description distinguishes Free and Pro features.
- [ ] Ukrainian and English strings for the Workshop and the purchase sheet.
