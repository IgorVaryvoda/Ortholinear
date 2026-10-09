# Plan 005: Dragging on Space moves the caret by whole characters

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- Core/TextNavigation.swift Tests/TextNavigationTests.swift KeyboardExtension/KeyboardViewController.swift App/PreviewSurface.swift`
> Plans 001–003 and 009 changed `KeyboardViewController.swift` and `PreviewSurface.swift`; that
> drift is expected. Plan 009 added a `suggestions.cancelGlide()` call to both `onCursor` closures;
> the excerpts below already show that. If the `keyboard.onCursor` closures or
> `Core/TextNavigation.swift` differ from the excerpts below, STOP.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: MED
- **Depends on**: plans/009-cancel-glides-on-any-input.md (same files; run after)
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09

## Why this matters

README: "Swipe horizontally on space: 12 points per cursor step." Each step is passed as an
offset of 1 to `adjustTextPosition(byCharacterOffset:)` (system keyboard) and to
`UITextView.position(from:offset:)` (in-app preview). Both count UTF-16 units, so one step over
`👍🏽` (4 units), `é` written as `e`+U+0301 (2 units), or most emoji (2 units) lands *inside* the
character. The host may split it or snap unpredictably, and the next typed text goes in the
wrong place. The keyboard's own navigation keys already do this right (`Core/TextNavigation.swift`
uses `.utf16.count` of whole characters).

## Current state

- `SharedUI/KeyboardView.swift` (do not change) emits `onCursor?(offset)` where `offset` is a
  number of 12 pt steps (negative = left), possibly more than 1 per touch move.
- `KeyboardExtension/KeyboardViewController.swift` `viewDidLoad`:
  ```swift
  keyboard.onCursor = { [weak self] in
      self?.suggestions.cancelGlide()
      self?.punctuationSpacing.reset()
      self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: $0)
      self?.updateAutoShift()
      self?.suggestions.refresh()
  }
  ```
- `App/PreviewSurface.swift` `init`:
  ```swift
  keyboard.onCursor = { [weak self] offset in
      guard let self else { return }
      self.suggestions.cancelGlide()
      guard let selection = self.editor.selectedTextRange,
            let position = self.editor.position(from: selection.start, offset: offset) else { return }
      self.punctuationSpacing.reset()
      self.editor.selectedTextRange = self.editor.textRange(from: position, to: position)
      ...
  }
  ```
- `Core/TextNavigation.swift` — `enum TextNavigation` with
  `static func edit(for command: KeyCommand, before: String, after: String) -> TextEdit?`;
  `.left` is `before.last.map { .move(-$0.utf16.count) }`. Exemplar for the new helper.
- `Tests/TextNavigationTests.swift` — test pattern to follow.

## Repo facts

- Swift 6, iOS 17+. `Core/` is a SwiftPM package; `KeyboardExtension/`, `App/` are Xcode-only.
- Hosts may share only part of the document (`documentContextBeforeInput`/`AfterInput` can be
  truncated or nil). Beyond the shared text, fall back to today's behavior: 1 unit per step.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --filter TextNavigationTests` | exit 0 |
| All core tests | `swift test` | `with 0 failures`; ~6 minutes |
| App + extension compile | `xcodebuild build -project Ortholinear.xcodeproj -scheme Ortholinear -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO -quiet` | exit 0, no `error:` lines |

## Scope

**In scope**: `Core/TextNavigation.swift`, `Tests/TextNavigationTests.swift`, the `onCursor`
closure in `KeyboardExtension/KeyboardViewController.swift`, the `onCursor` closure in
`App/PreviewSurface.swift`.

**Out of scope**: `SharedUI/KeyboardView.swift` (step size and gesture), navigation keys.

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence message,
e.g. `Move the caret by whole characters when dragging on Space`.

## Steps

### Step 1: Core helper

Add to `enum TextNavigation`:
```swift
/// The UTF-16 offset for moving the caret `steps` whole characters, negative to the left.
/// Past the text the host shares, each step counts as one unit, as before.
static func offset(steps: Int, before: String, after: String) -> Int
```
For `steps < 0`: `let known = before.suffix(-steps)`; return
`-(String(known).utf16.count + (-steps - known.count))`. For `steps > 0`: same with
`after.prefix(steps)`. `0` returns `0`.

**Verify**: `swift test --filter TextNavigationTests` → exit 0.

### Step 2: Tests

In `Tests/TextNavigationTests.swift` add `testCursorStepsCrossWholeCharacters`:
- `offset(steps: -1, before: "ok👍🏽", after: "")` == `-4`
- `offset(steps: -2, before: "ok👍🏽", after: "")` == `-5`
- `offset(steps: 1, before: "", after: "e\u{301}x")` == `2`
- `offset(steps: 2, before: "", after: "ab")` == `2`
- `offset(steps: -3, before: "a", after: "")` == `-3` (1 known + 2 fallback units)
- `offset(steps: 0, before: "abc", after: "def")` == `0`
- `offset(steps: 3, before: "", after: "a")` == `3` (rightward fallback)
- `offset(steps: -2, before: "", after: "")` == `-2` and `offset(steps: 2, before: "", after: "")` == `2` (no context: today's behavior)

**Verify**: `swift test --filter TextNavigationTests` → exit 0.

### Step 3: Use it in both keyboards

- Extension: `adjustTextPosition(byCharacterOffset: TextNavigation.offset(steps: $0, before: proxy.documentContextBeforeInput ?? "", after: proxy.documentContextAfterInput ?? ""))`
  (read `textDocumentProxy` once into a local; keep the closure's other lines, including `cancelGlide()` first).
- Preview: compute `before`/`after` from `editor.text as NSString` split at
  `editor.selectedRange.location` (guard `location != NSNotFound` and `<= length`), and pass
  `TextNavigation.offset(steps: offset, before:, after:)` to `editor.position(from: selection.start, offset:)`.

**Verify**: xcodebuild → exit 0.

### Step 4: Full suite and commit

`swift test` → `0 failures`; commit; `git status --porcelain` → empty.

## Done criteria

- [ ] `swift test` exits 0 including `testCursorStepsCrossWholeCharacters`
- [ ] xcodebuild exits 0
- [ ] `grep -n "TextNavigation.offset" KeyboardExtension/KeyboardViewController.swift App/PreviewSurface.swift` → one match each
- [ ] Only in-scope files changed by this plan's commit; `git status --porcelain` empty

## STOP conditions

- Excerpts don't match beyond expected drift.
- If xcodebuild fails for environment reasons (sandbox denial, missing SDK, cannot write
  outside the worktree) rather than compile errors in files you touched, do NOT stop: finish the
  remaining steps and commit, then in NOTES write `BUILD UNVERIFIED:` followed by the exact error.
  The plan is not accepted until the reviewer gets a successful xcodebuild; NOTES belong in your
  final report, not in any file.

## Maintenance notes

- This assumes `documentContextBeforeInput` reflects the previous `adjustTextPosition` by the
  next drag event — the same assumption `applySuggestion` already makes. Needs a device check on
  emoji-heavy text (Messages, Notes) before release; note it for the reviewer.
