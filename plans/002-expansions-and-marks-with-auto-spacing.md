# Plan 002: Text expansions and closing quotes work with automatic punctuation spacing

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- Core/TextExpansion.swift Core/PunctuationSpacing.swift KeyboardExtension/KeyboardViewController.swift App/PreviewSurface.swift Tests/TextExpansionTests.swift Tests/PunctuationSpacingTests.swift`
> Plan 001 already changed `Core/TextExpansion.swift`, `KeyboardViewController.swift`,
> `PreviewSurface.swift` and `Tests/TextExpansionTests.swift` (it added `selected:` parameters
> to `TextExpander.expand`/`revert` and a `hasSelection` check in the extension's `insert`).
> That drift is expected. Any other mismatch with the excerpts below is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-selection-safe-typing.md
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09

## Why this matters

Automatic punctuation spacing is on by default. It breaks three documented behaviors:

1. **Undo of a punctuation-triggered expansion.** With `brb → be right back`, typing `brb.`
   leaves `be right back. ` (spacing adds the space), but `TextExpander` recorded the undo text
   as `be right back.`. Delete right after therefore only removes the space and the shortcut can
   never be restored. Verified with a probe: `revert(before: "be right back. ")` returns nil.
   `docs/PRO-IMPLEMENTATION.md` promises Delete right after an expansion restores the shortcut.
2. **Shortcuts after an opening bracket or quote.** `TextExpander` accepts `(`, `[`, `{`, `"`,
   `'`, `«`, `„`, `“`, `‘` before a shortcut (and `Tests/TextExpansionTests.swift` expects
   `(;shrug` to expand), but spacing only skips the automatic space after `;` at the start of the
   text or after whitespace. Probe: `edit(for: ";", before: "(", enabled: true, shortcutStarts: [";"]).text`
   is `"; "`, so `(;mail` becomes `(; mail` and never expands.
3. **Closing quotes after a suggestion's space.** README: "Between words, the suggestion row
   shows `. , ? ! :` and `« »` (Cyrillic) or `- "` (Latin) ... Marks attach to the word, even
   after a suggestion added a space." Accepting a suggestion inside `«прив` gives `«привіт `
   (the keyboard owns that space); tapping `»` then gives `«привіт »` because `»` is not in the
   spacing's mark set, so the owned space stays.

## Current state

- `Core/TextExpansion.swift` (after plan 001):
  ```swift
  struct TextExpander: Sendable {
      static let triggers: Set<String> = [" ", "\n", ".", ",", "!", "?", ":", ";"]
      private static let openers: Set<Character> = ["(", "[", "{", "\"", "'", "«", "„", "“", "‘"]
      ...
      private var undo: (typed: String, inserted: String)?
      mutating func expand(before: String, trigger: String, expansions: [TextExpansion], selected: String = "") -> Edit? {
          ...
              let boundary = before.dropLast(typed.count).last
              guard boundary == nil || boundary!.isWhitespace || Self.openers.contains(boundary!) else { continue }
              undo = (typed, expansion.expansion + trigger)
              return Edit(deleteCount: typed.count, insert: expansion.expansion)
      }
      mutating func revert(before: String, selected: String = "") -> Edit? {
          defer { undo = nil }
          guard ..., let undo, before.hasSuffix(undo.inserted) else { return nil }
          return Edit(deleteCount: undo.inserted.count, insert: undo.typed)
      }
  ```
  Note: revert deletes the expansion *and* the trigger, and puts back only the shortcut
  (`Tests/TextExpansionTests.swift` `testDeleteRightAfterPutsTheShortcutBack` expects
  `deleteCount: 15` for `me@example.com ` → `;Mail`). Keep that contract.
- `Core/PunctuationSpacing.swift` lines 47–63:
  ```swift
  guard enabled else { reset(); return Edit(text: value) }
  let marks = Set([".", ",", "!", "?", ":", ";", "…"])
  let ownsSpace = expectedSuffix.map { context?.hasSuffix($0) == true } ?? false
  let numericContinuation = ...
  let removeSpace = ownsSpace && (marks.contains(value) || value == "\n" || numericContinuation)
  reset()
  if ownsSpace && value == " " { return Edit(text: "") }
  let before = removeSpace ? context.map { String($0.dropLast()) } : context
  let startsWord = shortcutStarts.contains(value) && (before.map { $0.last?.isWhitespace ?? true } ?? false)
  let output = value + (marks.contains(value) && !startsWord ? " " : "")
  if marks.contains(value), !startsWord, let context { expectedSuffix = ...; punctuation = value }
  return Edit(deleteBackward: removeSpace, text: output)
  ```
  `adoptSpace(before:at:)` (lines 19–24) makes a suggestion-added space owned.
- `KeyboardExtension/KeyboardViewController.swift` — `handle(_:)` `.text`, `.space`, `.enter`
  cases call `expand(before: trigger)` then `insert(trigger)`; `insert(_:)` (end of the class)
  applies the spacing edit and returns nothing.
- `App/PreviewSurface.swift` — same structure: `handle(_:)`, `expand(before:)`, `insert(_:)`.
- Test pattern: `Tests/PunctuationSpacingTests.swift` has a `type(_ keys:initial:enabled:)` helper.

## Repo facts

- Swift 6, iOS 17+. `Core/` is a SwiftPM package (`OrtholinearCore`; tests in `Tests/`).
  `SharedUI/`, `KeyboardExtension/`, `App/` are Xcode-only — compile-check with xcodebuild.
- Style: terse, few comments; doc comments explain *why*.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --filter TextExpansionTests` and `swift test --filter PunctuationSpacingTests` | exit 0 |
| All core tests | `swift test` | `with 0 failures`; ~6 minutes |
| App + extension compile | `xcodebuild build -project Ortholinear.xcodeproj -scheme Ortholinear -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO -quiet` | exit 0, no `error:` lines |

## Scope

**In scope**:
- `Core/TextExpansion.swift`, `Core/PunctuationSpacing.swift`
- `KeyboardExtension/KeyboardViewController.swift`, `App/PreviewSurface.swift`
- `Tests/TextExpansionTests.swift`, `Tests/PunctuationSpacingTests.swift`

**Out of scope**:
- The hyphen `-`: after an owned space it stays separate (a dash), unchanged.
- Opening quotes `«`, `„`, `“` and an *opening* `"`: they must keep the space before them.
- `SharedUI/SuggestionBar.swift` and anything about suggestions or glide.

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence
messages, e.g. `Let expansions and closing quotes work with automatic spacing`.

## Steps

### Step 1: Shared shortcut boundary

In `Core/TextExpansion.swift`, add to `TextExpander`:
```swift
/// What may come right before a shortcut: the start of the text, white space, or an opener.
static func isShortcutBoundary(_ character: Character?) -> Bool {
    guard let character else { return true }
    return character.isWhitespace || openers.contains(character)
}
```
and use it in `expand` instead of the inline `boundary == nil || ...` check.

In `Core/PunctuationSpacing.swift`, compute `startsWord` with
`shortcutStarts.contains(value) && TextExpander.isShortcutBoundary(before?.last)` — but keep
today's behavior for a nil `before` context (currently `false`): use
`before.map { TextExpander.isShortcutBoundary($0.last) } ?? false`.

**Verify**: `swift test --filter PunctuationSpacingTests` and `swift test --filter TextExpansionTests` → exit 0.

### Step 2: Undo records what was actually typed

In `TextExpander`, store the expansion separately so the trigger's real output can be recorded:
`private var undo: (typed: String, expansion: String, inserted: String)?`. `expand` sets
`inserted = expansion.expansion + trigger` (unchanged default). Add:
```swift
/// The trigger as it actually went in, such as ". " once automatic spacing added a space.
mutating func triggerTyped(as output: String) {
    guard let pending = undo else { return }
    undo = (pending.typed, pending.expansion, pending.expansion + output)
}
```
`revert` is unchanged in behavior (deletes `inserted`, puts back `typed`).

**Verify**: `swift test --filter TextExpansionTests` → exit 0.

### Step 3: Closing quotes attach to the word

In `PunctuationSpacing.edit`, treat a *closing* mark like this: when `ownsSpace` is true and the
value is a closer, remove the owned space (`deleteBackward: true`) and output the mark with no
added space and no new ownership. Closers: `»`, `”`, and `"` only when the context before
(after dropping the owned space) contains an odd number of `"` on its current line (text after
the last `"\n"`), i.e. it closes an open quote. Implement as a small private helper, e.g.
`private static func closes(_ value: String, after text: String) -> Bool`.
Everything else (including the hyphen and an opening `"`) behaves exactly as today.

**Verify**: `swift test --filter PunctuationSpacingTests` → exit 0.

### Step 4: Wire the extension and the preview

In both `KeyboardExtension/KeyboardViewController.swift` and `App/PreviewSurface.swift`:
- Make `insert(_:)` return the text it inserted (`edit.text`; mark it `@discardableResult`).
- In `handle(_:)` `.text`, `.space` and `.enter`: after `expand(before: t)`, call
  `expander.triggerTyped(as: insert(t))`. (`triggerTyped` does nothing when no expansion is pending.)

**Verify**: xcodebuild command → exit 0.

### Step 5: Tests

Add to `Tests/TextExpansionTests.swift` a test `testUndoAfterPunctuationThatGotASpace` that
simulates the controller: expand `brb` with trigger `.`, apply the edit to a string, run
`PunctuationSpacing().edit(for: ".", before: text, enabled: true)` and append its `text`, call
`triggerTyped(as:)` with it, and assert `revert(before: "be right back. ")` equals
`.init(deleteCount: 15, insert: "brb")`. Also assert that without `triggerTyped` (raw trigger
` `) the existing behavior still holds.

Add to `Tests/PunctuationSpacingTests.swift`:
- `edit(for: ";", before: "(", enabled: true, shortcutStarts: [";"]).text == ";"`, and same for
  `"«"` and `"\""` before, while `before: "x"` still gives `"; "`.
- After `adoptSpace(before: "«привіт ")`, `edit(for: "»", before: "«привіт ", enabled: true)` ==
  `.init(deleteBackward: true, text: "»")`.
- After `adoptSpace(before: "say \"hello ")`, `edit(for: "\"", ...)` removes the space;
  after `adoptSpace(before: "say hello ")`, `edit(for: "\"", ...)` == `.init(deleteBackward: false, text: "\"")`.
- After `adoptSpace(before: "word ")`, `edit(for: "-", ...)` == `.init(deleteBackward: false, text: "-")` (unchanged).
- After `adoptSpace(before: "привіт ")`, `edit(for: "«", ...)` keeps the space (`deleteBackward: false`).

**Verify**: both focused test commands → exit 0.

### Step 6: Full suite and commit

**Verify**: `swift test` → `with 0 failures`; xcodebuild → exit 0. Commit; `git status --porcelain` → empty.

## Done criteria

- [ ] `swift test` exits 0, `0 failures`, including the new tests
- [ ] xcodebuild command exits 0
- [ ] `grep -n "isShortcutBoundary" Core/PunctuationSpacing.swift Core/TextExpansion.swift` shows both uses
- [ ] `grep -n "triggerTyped" KeyboardExtension/KeyboardViewController.swift App/PreviewSurface.swift` shows 3 call sites in each
- [ ] `git diff --stat` for this plan's commits lists only in-scope files
- [ ] `git status --porcelain` is empty

## STOP conditions

- The live code doesn't match the excerpts (beyond plan 001's expected changes).
- Any pre-existing test in `PunctuationSpacingTests` or `TextExpansionTests` must be changed to pass — stop, that means behavior beyond this plan changed.
- If xcodebuild fails for environment reasons (sandbox denial, missing SDK, cannot write
  outside the worktree) rather than compile errors in files you touched, do NOT stop: record the
  exact error in NOTES and continue.

## Maintenance notes

- `TextExpander.isShortcutBoundary` is now the single definition of where a shortcut may start;
  spacing and expansion must keep agreeing.
- The `"` closer rule is a heuristic (odd count on the current line). Hosts may share truncated
  context; worst case is today's behavior (space kept).
