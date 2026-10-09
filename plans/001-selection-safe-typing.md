# Plan 001: Typing over selected text replaces it, and never deletes neighbouring text

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- Core/TextExpansion.swift Core/PunctuationSpacing.swift KeyboardExtension/KeyboardViewController.swift App/PreviewSurface.swift Tests/TextExpansionTests.swift Tests/PunctuationSpacingTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09

## Why this matters

When text is selected, `UITextDocumentProxy.deleteBackward()` (and `UITextView.deleteBackward()`)
deletes the selection first. Two typing rules ignore the selection and then delete or skip
the wrong thing:

1. **Text expansion** (Pro). With the shortcut `brb → be right back`, the text `brbXYZ` and
   `XYZ` selected, pressing Space asks for 3 deletions: the first removes `XYZ`, the next two
   remove `rb`, giving `bbe right back ` — the user's text is destroyed. Delete right after an
   expansion has the same problem (revert deletes more than the selection).
2. **Automatic punctuation spacing** (system keyboard only). Type `.` after `Hello` to get
   `Hello. ` (the keyboard "owns" that space). Then select `world` after it and press Space:
   the owned-space rule swallows the Space, so nothing happens and the selection is not
   replaced. Typing `,` instead deletes the selection via the owned-space removal and then
   inserts `, ` after the old space. The double-space-period rule has the same hazard.

After this plan, any typed key with a non-empty selection just replaces the selection.

## Current state

- `Core/TextExpansion.swift` — `TextExpander`, the pure expansion/undo engine.
  Lines 56–76:
  ```swift
  mutating func expand(before: String, trigger: String, expansions: [TextExpansion]) -> Edit? {
      undo = nil
      guard Self.triggers.contains(trigger) else { return nil }
      ...
  }
  mutating func revert(before: String) -> Edit? {
      defer { undo = nil }
      guard let undo, before.hasSuffix(undo.inserted) else { return nil }
      return Edit(deleteCount: undo.inserted.count, insert: undo.typed)
  }
  ```
- `Core/PunctuationSpacing.swift` — automatic spacing and double-space period. `reset()`
  clears all ownership. `edit(for:before:enabled:doubleSpacePeriod:at:shortcutStarts:)`
  returns `Edit(deleteBackward:text:)`.
- `KeyboardExtension/KeyboardViewController.swift` — the system keyboard.
  - Lines 304–317 (`handle`):
    ```swift
    case .text(let value):
        let typed = inputState.consume(value)
        expand(before: typed)
        insert(typed)
    case .space: expand(before: " "); insert(" ")
    case .backspace:
        punctuationSpacing.reset()
        if let edit = expander.revert(before: textDocumentProxy.documentContextBeforeInput ?? "") {
    ```
  - Lines 354–372: `expand(before:)` calls `expander.expand(before: textDocumentProxy.documentContextBeforeInput ?? "", ...)`;
    `insert(_:)` calls `punctuationSpacing.edit(...)` with no selection check.
  - `textDocumentProxy.selectedText` (String?) is the selection; nil or "" means none.
- `App/PreviewSurface.swift` — the in-app test keyboard, same rules over a `UITextView`.
  - `insert(_:)` (lines 327–337) ALREADY does the right thing for spacing:
    ```swift
    let selection = editor.selectedRange
    if selection.length > 0 { punctuationSpacing.reset() }
    ```
    Match this pattern in the extension.
  - `expand(before:)` (lines 319–325) and the `.backspace` revert (lines 276–283) do NOT check
    the selection. `editor.selectedRange.length > 0` means a selection.

## Repo facts

- Swift 6, iOS 17+. `Core/` is a SwiftPM package (`OrtholinearCore`; tests in `Tests/`, using
  `@testable import OrtholinearCore`). `SharedUI/`, `KeyboardExtension/` and `App/` are built only
  by Xcode, so `swift test` does not compile them — use the xcodebuild command below.
- Style: terse code, few comments; doc comments say *why*. Tests are compact XCTest; see
  `Tests/TextExpansionTests.swift` for the pattern.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --filter TextExpansionTests` and `swift test --filter PunctuationSpacingTests` | exit 0 |
| All core tests | `swift test` | `with 0 failures`; takes ~6 minutes |
| App + extension compile | `xcodebuild build -project Ortholinear.xcodeproj -scheme Ortholinear -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO -quiet` | exit 0, no `error:` lines |

## Scope

**In scope** (the only files you should modify):
- `Core/TextExpansion.swift`
- `KeyboardExtension/KeyboardViewController.swift`
- `App/PreviewSurface.swift`
- `Tests/TextExpansionTests.swift`

**Out of scope**:
- `Core/PunctuationSpacing.swift` — the spacing fix is done by calling the existing `reset()`
  from the extension, exactly as the preview does; do not change its API in this plan.
- `selectionDidChange` / `textDidChange` in the extension — do not add resets there; those
  callbacks also fire for the keyboard's own edits and would break consecutive punctuation.
- Any suggestion or glide code.

## Git workflow

Commit on the current branch (do not create or switch branches). Message style matches
`git log`: an imperative sentence, e.g. `Keep typing from deleting text next to a selection`.

## Steps

### Step 1: Make `TextExpander` selection-aware

In `Core/TextExpansion.swift` add a `selected: String = ""` parameter to both
`expand(before:trigger:expansions:selected:)` and `revert(before:selected:)`.
- `expand`: after `undo = nil`, return `nil` when `!selected.isEmpty`.
- `revert`: return `nil` (and still clear `undo` via the existing `defer`) when
  `!selected.isEmpty`.
Default value keeps existing call sites and tests compiling.

**Verify**: `swift test --filter TextExpansionTests` → exit 0.

### Step 2: Tests for the expander

In `Tests/TextExpansionTests.swift` add `testSelectionIsNeverExpandedOrReverted`:
- `expander.expand(before: "brb", trigger: " ", expansions: expansions, selected: "XYZ")` is nil.
- After a successful `expand(before: "brb", trigger: " ", expansions: expansions)`,
  `revert(before: "be right back ", selected: "x")` is nil, and a following
  `revert(before: "be right back ")` is also nil (the chance is gone).

**Verify**: `swift test --filter TextExpansionTests` → exit 0, new test passes.

### Step 3: System keyboard

In `KeyboardExtension/KeyboardViewController.swift`:
- Add `private var hasSelection: Bool { !(textDocumentProxy.selectedText ?? "").isEmpty }`.
- `expand(before:)`: pass `selected: textDocumentProxy.selectedText ?? ""`.
- `.backspace`: pass `selected: textDocumentProxy.selectedText ?? ""` to `expander.revert`.
- `insert(_:)`: before calling `punctuationSpacing.edit`, add
  `if hasSelection { punctuationSpacing.reset() }` (same as the preview's `insert`).

**Verify**: the xcodebuild command → exit 0.

### Step 4: In-app preview

In `App/PreviewSurface.swift`, pass the selected text to `expander.expand` (in `expand(before:)`)
and to `expander.revert` (in `.backspace`), using
`(editor.text as NSString).substring(with: editor.selectedRange)` guarded by
`editor.selectedRange.location != NSNotFound && NSMaxRange(editor.selectedRange) <= (editor.text as NSString).length`
(otherwise pass `""`). A small private computed property `selectedText` is fine.

**Verify**: the xcodebuild command → exit 0.

### Step 5: Full suite and commit

**Verify**: `swift test` → `with 0 failures`. Then commit; `git status --porcelain` → empty.

## Test plan

- New: `testSelectionIsNeverExpandedOrReverted` in `Tests/TextExpansionTests.swift` (step 2).
- Controller behavior can't be unit tested (Xcode-only target); the compile check plus the
  tested `TextExpander` contract cover it. Note this in your report.

## Done criteria

- [ ] `swift test` exits 0 with `0 failures`, including the new test
- [ ] xcodebuild command exits 0
- [ ] `grep -n "selected:" Core/TextExpansion.swift` shows the parameter on `expand` and `revert`
- [ ] `grep -n "hasSelection" KeyboardExtension/KeyboardViewController.swift` shows the property and its use in `insert`
- [ ] `git diff --stat 56c6fc1..HEAD` lists only in-scope files (plus `plans/` if already committed before you started)
- [ ] `git status --porcelain` is empty

## STOP conditions

- The excerpts above don't match the live code.
- Making the change appears to require editing `Core/PunctuationSpacing.swift` or any out-of-scope file.
- An existing test in `TextExpansionTests` or `PunctuationSpacingTests` fails after your change and the fix is not obvious.
- If xcodebuild fails for environment reasons (sandbox denial, missing SDK, cannot write
  outside the worktree) rather than compile errors in files you touched, do NOT stop: finish the
  remaining steps and commit, then in NOTES write `BUILD UNVERIFIED:` followed by the exact error.
  The plan is not accepted until the reviewer gets a successful xcodebuild; NOTES belong in your
  final report, not in any file.

## Maintenance notes

- Plan 002 changes `TextExpander` undo bookkeeping in the same file; it builds on this plan's
  `selected:` parameters.
- Reviewers: check both the extension and the preview get the expander change; the preview
  already resets spacing on selection.
