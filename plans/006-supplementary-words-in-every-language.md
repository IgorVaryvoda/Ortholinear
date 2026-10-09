# Plan 006: iOS text replacements and contact names work in every language

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- SharedUI/SuggestionBar.swift Core/Suggestions.swift Tests/SuggestionTests.swift`
> Plans 003 and 009 changed `SuggestionCoordinator` (`onSelect`, `glideOffer`, `glide(_:)`,
> `glideTask`, `cancelGlide`, `GlideContext`) and `SuggestionEdit`. That drift is expected. If `SupplementaryWords`,
> `SuggestionWorker.suggest`, or `refresh(force:)` differ from the excerpts below, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/009-cancel-glides-on-any-input.md (same file; run after)
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09

## Why this matters

README: "The system keyboard also offers your iOS text replacements and contact names (via
`requestSupplementaryLexicon`, which needs no Full Access)." That only happens for English and
Ukrainian. The 13 optional layouts (Polish, German, French, …) have no bundled dictionary, so
`refresh` takes an early branch that asks Apple's `UITextChecker` and returns before the text
replacement and contact-name lookup. Someone with `omw → On my way!` who types `omw` in French
never sees the replacement, though switching to English shows it.

## Current state

`SharedUI/SuggestionBar.swift`:
- `struct SupplementaryWords: Sendable` (around line 201) — `shortcuts: [String: String]`
  (normalized input → replacement text) and `names: [String]`, built by
  `init(entries: [(input: String, text: String)])`.
- `private actor SuggestionWorker`, `func suggest(...)` — after computing `words` from the
  engine and the wrong-layout recovery, it does:
  ```swift
  // Contact names fill spare slots as completions, keeping their capitals; they never correct.
  if words.count < 3, query.count >= 2, !target.selected, target.rightCount == 0 {
      let taken = Set(words.map { SuggestionText.normalize($0.word) })
      let matches = names.filter {
          let name = SuggestionText.normalize($0)
          return name.hasPrefix(query) && name != query && !taken.contains(name)
      }
      words += matches.sorted().prefix(3 - words.count).map { WordSuggestion(word: $0, kind: .completion) }
  }
  if let shortcut { words = [WordSuggestion(word: shortcut, kind: .replacement)] + words.prefix(2) }
  ```
  where `query = SuggestionText.normalize(target.word)`.
- `SuggestionCoordinator.refresh(force:)`:
  ```swift
  guard current.language.dictionaryCode != nil else {
      // Apple's checker covers the other layouts, on the main actor it requires.
      task = Task { [weak self] in
          ...
          let words = current.target.map {
              SystemSuggestions.suggest(target: $0, language: current.language, learned: learned, geometry: geometry)
          } ?? []
          self.offered = current
          keyboard.suggestionBar.show(words, word: teachable, learned: learned, tip: tip)
      }
      return
  }
  let alternate = alternate(to: current.language, preferences: preferences)
  let shortcut = word.flatMap { supplementary.shortcuts[SuggestionText.normalize($0)] }
  let names = supplementary.names.filter { SuggestionText.belongs($0, to: current.language) }
  ```
- `Core/Suggestions.swift` holds `WordSuggestion`, `SuggestionTarget`, `SuggestionText`
  (`normalize`, `isWord`, `belongs`). Every file in `Core/` is compiled into both the app and the
  keyboard extension by Xcode (see `project.yml` `sources`), and into the SwiftPM test module, so
  moving a pure type from `SharedUI/` into `Core/` needs no imports.

## Repo facts

- Swift 6, iOS 17+. `SharedUI/` is Xcode-only — compile-check with xcodebuild; `Core/` is
  unit-testable with `swift test`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --filter SuggestionTests` | exit 0 (slow suite, a few minutes) |
| All core tests | `swift test` | `with 0 failures`; ~6 minutes |
| App + extension compile | `xcodebuild build -project Ortholinear.xcodeproj -scheme Ortholinear -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO -quiet` | exit 0, no `error:` lines |

## Scope

**In scope**: `SharedUI/SuggestionBar.swift`, `Core/Suggestions.swift`, `Tests/SuggestionTests.swift`.

**Out of scope**: `SharedUI/SystemSuggestions.swift` (the checker itself), the ranking of
engine suggestions, recovery, `KeyboardViewController.swift`.

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence message,
e.g. `Offer text replacements and contact names in every language`.

## Steps

### Step 1: Move `SupplementaryWords` into Core and give it the merge

Move `struct SupplementaryWords` unchanged from `SharedUI/SuggestionBar.swift` to the end of
`Core/Suggestions.swift`. Add a method that holds the exact logic quoted above (names fill
spare slots, then the shortcut goes first):
```swift
/// Adds contact names to spare slots and puts a text replacement first, in any language.
func merged(into words: [WordSuggestion], target: SuggestionTarget, language: KeyboardLanguage) -> [WordSuggestion]
```
Inside it compute `shortcut = shortcuts[SuggestionText.normalize(target.word)]` and
`names = self.names.filter { SuggestionText.belongs($0, to: language) }`, then apply the quoted
logic with `query = SuggestionText.normalize(target.word)`.

**Verify**: `swift test --filter SuggestionTests` → exit 0.

### Step 2: Use it on both paths

- `SuggestionWorker.suggest`: replace its `names:` and `shortcut:` parameters with a
  `supplementary: SupplementaryWords` parameter and replace the quoted block with
  `words = supplementary.merged(into: words, target: target, language: snapshot.language)`.
- `refresh(force:)`: capture `let supplementary = self.supplementary` before creating either `Task`
  (the worker task holds `self` weakly), and pass that local to the worker instead of the precomputed
  `shortcut`/`names` (delete those two locals). In the checker branch, capture
  `let supplementary = self.supplementary` before the `Task` and change the words line to
  `current.target.map { supplementary.merged(into: SystemSuggestions.suggest(...), target: $0, language: current.language) } ?? []`.

**Verify**: xcodebuild → exit 0.

### Step 3: Tests

In `Tests/SuggestionTests.swift` add `testSupplementaryWordsJoinAnyLanguage`:
- `let words = SupplementaryWords(entries: [("omw", "On my way!"), ("Marie", "Marie")])`
- With `snapshot("omw", language: .french).target!`, `words.merged(into: [WordSuggestion(word: "omg", kind: .correction)], target:, language: .french)`
  starts with `WordSuggestion(word: "On my way!", kind: .replacement)`.
- With `snapshot("mar", language: .french).target!` and `into: []`, the result contains
  `WordSuggestion(word: "Marie", kind: .completion)`.
- With `snapshot("mar", language: .ukrainian).target!` and `into: []`, the result does not contain `Marie`
  (the prefix matches, so only the alphabet filter can exclude it). If that snapshot has no target, STOP.

**Verify**: `swift test --filter SuggestionTests` → exit 0.

### Step 4: Full suite and commit

`swift test` → `0 failures`; xcodebuild → exit 0; commit; `git status --porcelain` → empty.

## Done criteria

- [ ] `swift test` exits 0, new test included
- [ ] xcodebuild exits 0
- [ ] `grep -n "struct SupplementaryWords" -r Core SharedUI` → only `Core/Suggestions.swift`
- [ ] `grep -n "merged(into:" SharedUI/SuggestionBar.swift` → 2 matches (worker and checker branch)
- [ ] Only in-scope files changed by this plan's commit; `git status --porcelain` empty

## STOP conditions

- Excerpts don't match beyond expected drift.
- Existing suggestion tests change results (the English/Ukrainian behavior must be identical).
- If xcodebuild fails for environment reasons (sandbox denial, missing SDK, cannot write
  outside the worktree) rather than compile errors in files you touched, do NOT stop: finish the
  remaining steps and commit, then in NOTES write `BUILD UNVERIFIED:` followed by the exact error.
  The plan is not accepted until the reviewer gets a successful xcodebuild; NOTES belong in your
  final report, not in any file.

## Maintenance notes

- `SupplementaryWords.merged` is now the one place text replacements and names join the row.
