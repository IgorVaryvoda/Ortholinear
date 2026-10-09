# Plan 007: Letters held on any custom key are placed for suggestions and glide

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- Core/Suggestions.swift Tests/CustomLayoutTests.swift`
> Plans 003 and 006 changed `Core/Suggestions.swift` (`SuggestionEdit`, and `SupplementaryWords`
> appended at the end). That drift is expected. If `struct SuggestionGeometry`'s `init` differs
> from the excerpt below, STOP.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: MED
- **Depends on**: plans/006-supplementary-words-in-every-language.md (same file; run after)
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09

## Why this matters

Layout Workshop (Pro) accepts a custom layout when every letter is reachable "directly or by
holding a key" — including a hold on a non-letter key (`CustomLetterLayout.problems` counts every
key's alternatives). README: "Touch, long-press, digit flicks, suggestions, glide typing, and
wrong-layout recovery all follow the custom positions; a held letter such as ґ is placed on its
key unless it has a key of its own." But `SuggestionGeometry` only places held letters that sit
on *letter* keys. A letter held on, say, a `#` key gets no position, so the glide decoder rejects
every word containing it and typo-distance scoring treats it as unknown.

## Current state

`Core/Suggestions.swift`, `struct SuggestionGeometry` init:
```swift
init(language: KeyboardLanguage, preferences: KeyboardPreferences, width: Double) {
    var state = InputState(); state.language = language
    let cells = KeyboardGeometry.cells(width: max(width, 200), state: state,
                                      preferences: preferences, needsGlobe: false)
    var letterCells: [(Character, KeyCell)] = []
    for cell in cells {
        guard case .text(let text) = cell.key.action, let ch = text.first, ch.isLetter else { continue }
        centers[ch] = CGPoint(x: cell.hitFrame.midX, y: cell.hitFrame.midY)
        unit = cell.hitFrame.width
        letterCells.append((ch, cell))
    }
    for (ch, cell) in letterCells {
        for held in cell.key.alternatives.compactMap(\.first) where held.isLetter && centers[held] == nil {
            centers[held] = centers[ch]
            heldLetters.insert(held)
        }
    }
}
```
- `Key.alternatives` (`Core/KeyboardModel.swift`) returns a custom key's own holds when given.
- `Core/GlideDecoder.swift` rejects a candidate whose alphabetic scalars have no key position.
- `Core/LayoutRecovery.swift` excludes `heldLetters` from nearest-key targets (keep that).
- Test pattern: `Tests/CustomLayoutTests.swift` `testCustomLayoutDrivesTouchSuggestionsAndGlide`:
  ```swift
  var layout = CustomLetterLayout(builtIn: .english)
  layout.rows[0][0] = CustomKey("z")
  ...
  let custom = SuggestionGeometry(language: .english, preferences: preferences, width: 393)
  let builtIn = SuggestionGeometry(language: .english, preferences: .init(), width: 393)
  XCTAssertEqual(GlideDecoder.keyPath("zap", geometry: custom)?.first, builtIn.centers["q"])
  ```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --filter CustomLayoutTests` | exit 0 |
| All core tests | `swift test` | `with 0 failures`; ~6 minutes |

## Scope

**In scope**: `Core/Suggestions.swift` (`SuggestionGeometry.init` only), `Tests/CustomLayoutTests.swift`.

**Out of scope**: `SharedUI/KeyboardView.swift` — a glide still can't *start* on a non-letter
key; changing touch handling there risks the punctuation long-press. Record as a follow-up in NOTES.
`Core/CustomLayout.swift` validation, `Core/LayoutRecovery.swift`, `Core/GlideDecoder.swift`.

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence message,
e.g. `Place letters held on any key for suggestions and glide`.

## Steps

### Step 1: Place held letters from every text key

Keep the first loop as is (dedicated letter keys win). Change the second loop to walk every
cell whose action is `.text` (not only letter cells), using that cell's own center
(`CGPoint(x: cell.hitFrame.midX, y: cell.hitFrame.midY)`) for held letters that have no position
yet. Letter-key holds must still win over non-letter-key holds for the same letter: process
letter cells first, then the rest (e.g. two passes, or sort).

**Verify**: `swift test --filter CustomLayoutTests` → exit 0.

### Step 2: Test

Add `testLettersHeldOnPunctuationKeysArePlaced` to `Tests/CustomLayoutTests.swift`:
- `var layout = CustomLetterLayout(builtIn: .english)`; `layout.rows[0][0] = CustomKey("#", alternatives: ["q"])`.
- `XCTAssertTrue(layout.isUsable(for: .english))`.
- `custom.centers["q"] == builtIn.centers["q"]`, `custom.isAlternative("q")` is true.
- `GlideDecoder.keyPath("quit", geometry: custom)` is not nil.
- A letter that has its own key AND is held on a `#` key keeps its own key's center
  (e.g. also add `"e"` to the `#` key's alternatives and assert `custom.centers["e"] == builtIn.centers["e"]`
  and `custom.isAlternative("e")` is false).

**Verify**: `swift test --filter CustomLayoutTests` → exit 0.

### Step 3: Full suite and commit

`swift test` → `0 failures` (glide/suggestion accuracy suites must not regress for built-in
layouts); commit; `git status --porcelain` → empty.

## Done criteria

- [ ] `swift test` exits 0 including the new test
- [ ] Only in-scope files changed by this plan's commit; `git status --porcelain` empty

## STOP conditions

- The init doesn't match the excerpt.
- Any accuracy or benchmark assertion in `GlideTests`, `SuggestionTests` or `KeyboardCoreTests`
  fails after the change (built-in layouts must be unaffected — their held letters are all on letter keys).
- `CustomKey("#", alternatives: ["q"])` layout is not usable (validation disagrees with this plan's premise).

## Maintenance notes

- Follow-up (not done here): allow a glide to begin on a non-letter key that holds a letter, in
  `SharedUI/KeyboardView.swift` touchesBegan (`value.first?.isLetter == true`).
