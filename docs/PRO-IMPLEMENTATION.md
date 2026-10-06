# Pro implementation plan

Status: **proposed, not built.** Read [PRO.md](PRO.md) for the product decisions. Code references are to commit `084be31`.

## 1. Edition boundary

The public repository builds the Free app exactly as today. Pro is a private Swift package, `OrtholinearPro`, used only by the containing app. The keyboard extension never links it.

- `project.yml` stays the public spec, and the checked-in Xcode project stays the Free edition.
- A private `project.pro.yml` uses XcodeGen's `include:` to pull in `project.yml`, then adds the `OrtholinearPro` package (a local path to the private checkout) as a dependency of the `Ortholinear` target. Release builds regenerate from it and do not commit the result.
- The app talks to Pro through one protocol in `App/`, for example `ProEdition`, with a Free implementation that reports `isUnlocked == false` and provides no Pro screens. `OrtholinearApp.swift` holds the only `#if canImport(OrtholinearPro)`.
- Engine code needed to *render* Pro data, such as layers, stays public in `Core/` and `SharedUI/`. The extension must be able to render whatever the app publishes.

| Public (MIT) | Private (`OrtholinearPro`) |
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

In `KeyboardLayout.rows`, the letters page uses the custom rows when a valid layout exists for `state.language`. Delete insertion, Shift placement, digit flicks and the number row already operate on the resulting rows and need no special case.

Everything downstream already derives from these rows. `KeyboardGeometry.cells` (`:537`) builds hit frames from them. `SuggestionGeometry` (`Core/Suggestions.swift:135`) builds key centres from those cells. `GlideDecoder` (`Core/GlideDecoder.swift:54`) and `LayoutRecovery` use those centres. Three places assume the built-in layouts and must change:

1. `Suggestions.swift:147` always moves ґ onto г. Only alias ґ and ї when they have no key of their own; otherwise a custom ґ key gets wrong suggestion and glide distances.
2. `Suggestions.swift:145` takes `unit` from whichever letter cell came last. Use the median letter width so a short or punctuation-ended row cannot skew it.
3. `SuggestionGeometry.isAlternative` (`Core/LayoutRecovery.swift:46`) hard-codes the same ґ/ї assumption. Derive it from the geometry instead.

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
    var rows: [[CustomKey]]     // up to four rows of up to 10 keys
}
```

- `KeyboardPage` gains `case layer(UUID)`. The existing page cycle (`KeyboardViewController.swift:298`) continues numbers → symbols → each layer → numbers.
- Optional control-row layer key (off by default) opens the first layer. The ABC key (`:304`) keeps returning to letters, and the language is untouched.
- Glide stays letters-only. Layers have no suggestions.
- Phrase keys: `label` is drawn and `output` is inserted. Output is limited to 200 characters with no newlines, enforced in validation.
- Keep the hold-123-and-slide gesture for numbers and symbols only.

## 4. Storage and publishing

Keep today's model: the app writes, the extension only reads `geometry.json` (`SharedUI/PreferenceStore.swift`). Add one app-private file:

- `geometry.json` (App Group) is the **published** configuration: Free preferences, custom layouts, and the active layers only when Pro is unlocked.
- `pro.json` (app's Application Support) holds the source of truth for layers, phrase keys and saved setups. The extension never reads it.

Publishing is one function: Free preferences, plus (if unlocked) the active setup's layers, written atomically as today. Refunds and revocations republish without layers. Nothing in `pro.json` is deleted. No migration is needed for existing users, because their `geometry.json` is already a valid Free configuration.

The extension has no idea Pro exists. It renders whatever valid configuration it reads. Without Full Access or StoreKit in the extension, a refund takes effect the next time the app runs. That is acceptable.

## 5. StoreKit (private)

- One non-consumable, placeholder ID `com.varyvoda.Ortholinear.pro`.
- Start a `Transaction.updates` listener at launch. Check `Transaction.currentEntitlements` at launch and when the app becomes active, and finish verified transactions.
- Unlocked means a verified, unrevoked entitlement for that product exists. `currentEntitlements` works offline from StoreKit's own cache, so no network heartbeat is involved.
- Call `AppStore.sync()` only from **Restore purchases**, because it can ask the person to sign in.
- Treat cancelled, pending, unverified and failed results distinctly; only a verified transaction unlocks. Pending shows "Waiting for approval" and changes nothing.
- Use a `.storekit` configuration file for local testing, plus unit tests against a fake `ProStore` protocol.

## 6. Phases

| # | Work | Repo | Size |
| --- | --- | --- | --- |
| 0 | Edition seam: private package skeleton, `project.pro.yml`, `ProEdition` protocol. Public build unchanged. | both | S |
| 1 | Custom layout model, validation, `rows` override, the three geometry fixes, tolerant decoding. `swift test` coverage. | public | M |
| 2 | Free Workshop editor and single-layout files. **Ship as a free update.** Interest in this tells you whether Pro is worth finishing. | public | M–L |
| 3 | Layer engine (page cycle, layer key, phrase rendering) and layer editor with starters. | both | M |
| 4 | Saved setups and setup files with phrase export preview. | private | M |
| 5 | StoreKit, purchase sheet, Pro row, publishing rules. | private | S–M |
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
