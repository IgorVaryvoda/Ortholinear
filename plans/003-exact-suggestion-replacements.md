# Plan 003: Accepting a suggestion replaces exactly the intended text

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- Core/Suggestions.swift SharedUI/SuggestionBar.swift KeyboardExtension/KeyboardViewController.swift App/PreviewSurface.swift Tests/SuggestionTests.swift`
> Plans 001–002 changed `KeyboardViewController.swift` and `PreviewSurface.swift` in their
> typing paths (`handle`, `expand`, `insert`) only; that drift is expected. If
> `applySuggestion`, `insertGlided` or the files `Core/Suggestions.swift` /
> `SharedUI/SuggestionBar.swift` differ from the excerpts below, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/002-expansions-and-marks-with-auto-spacing.md (same files; run after)
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09

## Why this matters

Two defects in how a chosen suggestion is turned into text edits:

1. **Glide alternatives delete text after the caret (data loss).** Put the caret right before an
   existing word, e.g. `the |cat`, and glide `hello`: the document becomes `the hello|cat` (glide
   adds no trailing space). The suggestion row offers other readings. Tapping one goes through
   `SuggestionEdit.make`, whose target is the *whole word around the caret* — `hellocat` — so it
   moves right over `cat`, deletes 8 characters, and inserts e.g. `help`: `cat` is gone.
   README: "other readings appear in the suggestion row, and tapping one replaces it" — "it"
   is the glided word only.
2. **Caret movement uses the wrong unit.** `SuggestionEdit.moveRight` is a count of Swift
   `Character`s (graphemes), but the system keyboard passes it to
   `textDocumentProxy.adjustTextPosition(byCharacterOffset:)`, which counts UTF-16 units.
   With decomposed text (e.g. `ca|fe\u{301}` — `é` as `e` + U+0301, common in pasted text),
   the right part is 2 graphemes but 3 UTF-16 units; the caret stops early, the safety check
   fails, the correction is silently abandoned, and the caret is left moved.

## Current state

- `Core/Suggestions.swift` lines 61–85:
  ```swift
  struct SuggestionEdit: Equatable, Sendable {
      var moveRight: Int
      var deleteCount: Int
      var replaceSelection: Bool
      var text: String

      static func make(suggestion: WordSuggestion, offered: SuggestionSnapshot,
                       current: SuggestionSnapshot) -> Self? {
          guard offered == current, let target = current.target else { return nil }
          ...
          return .init(moveRight: target.rightCount,
                       deleteCount: target.selected ? 0 : target.leftCount + target.rightCount,
                       replaceSelection: target.selected, text: suggestion.word + (addSpace ? " " : ""))
      }
  }
  ```
  `SuggestionTarget.leftCount/rightCount` are grapheme counts of the word parts before/after the
  caret (`SuggestionSnapshot.target`, lines 11–41). `SuggestionSnapshot` has `before`, `after`,
  `selection`, `document`, `language`.
- `KeyboardExtension/KeyboardViewController.swift` `applySuggestion` (around lines 133–152):
  ```swift
  if edit.moveRight != 0 {
      textDocumentProxy.adjustTextPosition(byCharacterOffset: edit.moveRight)
      // Some hosts don't honor cursor movement. Never delete from the old caret.
      let expected = snapshot.before + snapshot.after.prefix(edit.moveRight)
      guard textDocumentProxy.documentContextBeforeInput?.hasSuffix(expected.suffix(24)) == true else { return }
  }
  for _ in 0..<edit.deleteCount { textDocumentProxy.deleteBackward() }
  textDocumentProxy.insertText(edit.text)
  ```
  `deleteBackward()` removes one user-perceived character (grapheme), so `deleteCount` stays a
  grapheme count.
  `insertGlided(_:)` inserts `(needsSpace ? " " : "") + text` and returns `text` (no leading space).
- `App/PreviewSurface.swift` `applySuggestion` (around lines 241–260) does not use `moveRight`/
  `deleteCount`; it rebuilds the range from `snapshot.target`:
  ```swift
  guard suggestionSnapshot() == snapshot, let target = snapshot.target else { return }
  ...
  let prefix = String(snapshot.before.dropLast(target.leftCount))
  let range = NSRange(location: prefix.utf16.count, length: target.word.utf16.count)
  ... editor.replace(selection, withText: edit.text)
  ```
  So the preview has bug 1 too (it replaces the whole `hellocat`).
- `SharedUI/SuggestionBar.swift`, `SuggestionCoordinator`:
  - `private var glideOffer: (snapshot: SuggestionSnapshot, words: [WordSuggestion])?`
  - `init` sets `keyboard.suggestionBar.onSelect`:
    ```swift
    guard let self, let offered = self.offered, let current = self.snapshot?(),
          let edit = SuggestionEdit.make(suggestion: suggestion, offered: offered, current: current) else { return }
    self.cancel()
    self.glideOffer = nil
    self.apply?(edit, current)
    ```
  - `glide(_:)` ends with:
    ```swift
    let inserted = self.insertWord?(best.word) ...
    guard let after = self.snapshot?() else { self.refresh(force: true); return }
    let alternatives = words.dropFirst().map { WordSuggestion(word: SuggestionText.cased($0.word, like: inserted, language: current.language), kind: .correction) }
    if !alternatives.isEmpty { self.glideOffer = (after, Array(alternatives.prefix(3))) }
    ```
  - In `refresh`, when `glideOffer.snapshot == current`, the offer is shown and `offered = current`.
- Test pattern: `Tests/SuggestionTests.swift` `testTargetsAndSafeEdits` uses a
  `snapshot(_ before:after:selected:language:)` helper and asserts `edit.moveRight` etc.

## Repo facts

- Swift 6, iOS 17+. `Core/` is a SwiftPM package; `SharedUI/`, `KeyboardExtension/`, `App/` are
  Xcode-only — compile-check with xcodebuild.
- `adjustTextPosition(byCharacterOffset:)` and `NSRange` count UTF-16 units; the repo already
  does this right in `Core/TextNavigation.swift` (`.move(-$0.utf16.count)`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --filter SuggestionTests` | exit 0 (this suite is slow, a few minutes) |
| All core tests | `swift test` | `with 0 failures`; ~6 minutes |
| App + extension compile | `xcodebuild build -project Ortholinear.xcodeproj -scheme Ortholinear -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO -quiet` | exit 0, no `error:` lines |

## Scope

**In scope**:
- `Core/Suggestions.swift` (`SuggestionEdit` only)
- `SharedUI/SuggestionBar.swift` (`SuggestionCoordinator.onSelect` closure and `glideOffer`/`glide(_:)` only)
- `KeyboardExtension/KeyboardViewController.swift` (`applySuggestion` only)
- `App/PreviewSurface.swift` (`applySuggestion` only)
- `Tests/SuggestionTests.swift`

**Out of scope**:
- Glide task cancellation / stale results — that is plan 004; do not add cancellation here.
- `SuggestionSnapshot.target` rules, ranking, dictionaries, the suggestion bar layout.
- Space-bar cursor dragging (plan 005).

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence message,
e.g. `Replace only the intended text when a suggestion is chosen`.

## Steps

### Step 1: Make `SuggestionEdit` carry the exact text it replaces

Add two stored properties to `SuggestionEdit`: `var left: String` (text deleted before the
caret) and `var right: String` (text the caret moves over, then deleted). Define:
- `moveRight` = `right.utf16.count` (UTF-16 units, for `adjustTextPosition`)
- `deleteCount` = `left.count + right.count` (graphemes, one `deleteBackward` each)
Make `moveRight` and `deleteCount` **computed** properties derived from `left`/`right` (so they can
never disagree); `replaceSelection`, `text`, `left`, `right` are stored. `Equatable` stays synthesized.
In `make`: `left = target.selected ? "" : String(current.before.suffix(target.leftCount))`,
`right = target.selected ? "" : String(current.after.prefix(target.rightCount))`.

**Verify**: `swift test --filter SuggestionTests` → exit 0 (existing assertions such as
`moveRight == 3`, `deleteCount == 5` still pass).

### Step 2: An edit that replaces only a glided word

Add to `SuggestionEdit`:
```swift
/// Swaps the word a glide just inserted for another reading, leaving text on either side alone.
static func replacingGlide(_ suggestion: WordSuggestion, inserted: String,
                           offered: SuggestionSnapshot, current: SuggestionSnapshot) -> Self?
```
Return nil unless `offered == current`, `current.selection.isEmpty`, `!inserted.isEmpty`, and
`SuggestionText.isWord(suggestion.word)`. Then take the document's own text:
`let left = String(current.before.suffix(inserted.count))` and return nil unless
`left.unicodeScalars.elementsEqual(inserted.unicodeScalars)` — compare scalars, not `==`/`hasSuffix`,
because Swift string equality is canonical (`ї` equals `і`+U+0308) while their UTF-16 lengths differ,
and the preview converts `left` to a UTF-16 range. Return an edit with this `left`, `right = ""`,
`replaceSelection = false`, `text = suggestion.word` (no added space).

**Verify**: `swift test --filter SuggestionTests` → exit 0.

### Step 3: Coordinator uses it for glide alternatives

In `SharedUI/SuggestionBar.swift`:
- Change `glideOffer` to `(snapshot: SuggestionSnapshot, inserted: String, words: [WordSuggestion])?`
  and set `inserted` from the value `insertWord` returned in `glide(_:)`. Update the `refresh`
  use of `offer.words` / `offer.snapshot` accordingly.
- In `onSelect`: if `glideOffer` is non-nil, `glideOffer.snapshot == offered`, and
  `glideOffer.words.contains(suggestion)`, build the edit with
  `SuggestionEdit.replacingGlide(suggestion, inserted: offer.inserted, offered: offered, current: current)`;
  otherwise use `SuggestionEdit.make` as today. If the chosen builder returns nil, return (as today).

**Verify**: xcodebuild command → exit 0.

### Step 4: Extension and preview apply the edit's exact text

- Extension `applySuggestion`: replace `snapshot.after.prefix(edit.moveRight)` with `edit.right`
  in the `expected` string. Nothing else changes.
- Preview `applySuggestion`: stop rebuilding the range from `snapshot.target`. Compute it from
  the edit: if `edit.replaceSelection`, the range is the current selection
  (`location = snapshot.before.utf16.count`, `length = snapshot.selection.utf16.count`);
  otherwise `location = snapshot.before.utf16.count - edit.left.utf16.count`,
  `length = edit.left.utf16.count + edit.right.utf16.count`. Guard
  `snapshot.before.hasSuffix(edit.left) && snapshot.after.hasPrefix(edit.right)`; keep the
  `suggestionSnapshot() == snapshot` guard; drop the now-unused `target` binding.
  Keep the caret placement after `range.location + edit.text.utf16.count`. Use scalar-wise
  comparison for these two guards too (`snapshot.before.unicodeScalars.reversed().starts(with: edit.left.unicodeScalars.reversed())`,
  `snapshot.after.unicodeScalars.starts(with: edit.right.unicodeScalars)`), since `make` derives `left`/`right`
  from the snapshot itself and they must match its exact encoding.

**Verify**: xcodebuild command → exit 0.

### Step 5: Tests

In `Tests/SuggestionTests.swift` add:
- `testMovementCountsUTF16Units`: `snapshot("ca", after: "fe\u{301}")` with a correction
  `"cafe"` (kind `.correction`) → `moveRight == 3`, `deleteCount == 4`, `right == "fe\u{301}"`,
  `left == "ca"`. (If `snapshot("ca", after: "fe\u{301}").target` turns out nil, STOP and report.)
- `testGlideAlternativesReplaceOnlyTheGlidedWord`: `let s = snapshot("the hello", after: "cat")`;
  `replacingGlide(WordSuggestion(word: "help", kind: .correction), inserted: "hello", offered: s, current: s)`
  → `deleteCount == 5`, `moveRight == 0`, `left == "hello"`, `text == "help"`. Nil when `inserted: "world"`, when the
  snapshot has a selection, and when `offered != current`. Nil when the document holds a canonically equal
  but differently encoded word: `snapshot("the \u{0456}\u{0308}де")` with `inserted: "\u{0457}де"`.

**Verify**: `swift test --filter SuggestionTests` → exit 0 with the new tests.

### Step 6: Full suite and commit

`swift test` → `0 failures`; xcodebuild → exit 0; commit; `git status --porcelain` → empty.

## Done criteria

- [ ] `swift test` exits 0, `0 failures`, new tests included
- [ ] xcodebuild exits 0
- [ ] `grep -n "after.prefix(edit.moveRight)" KeyboardExtension/KeyboardViewController.swift` → no matches
- [ ] `grep -n "replacingGlide" SharedUI/SuggestionBar.swift Core/Suggestions.swift` → definition + use
- [ ] Only in-scope files changed by this plan's commits; `git status --porcelain` empty

## STOP conditions

- Excerpts don't match (beyond the expected plan 001–002 drift).
- The `left`/`right` change forces edits to `SuggestionSnapshot.target` or other out-of-scope code.
- If xcodebuild fails for environment reasons (sandbox denial, missing SDK, cannot write
  outside the worktree) rather than compile errors in files you touched, do NOT stop: finish the
  remaining steps and commit, then in NOTES write `BUILD UNVERIFIED:` followed by the exact error.
  The plan is not accepted until the reviewer gets a successful xcodebuild; NOTES belong in your
  final report, not in any file.

## Maintenance notes

- Plan 004 adds stale-glide cancellation in the same coordinator; it relies on `glideOffer`
  having the `inserted` field added here.
- Any new suggestion kind must set `left`/`right` explicitly; reviewers should reject an edit
  built from counts alone.
