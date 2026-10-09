# Plan 009: Any input cancels a glide that hasn't been typed yet

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- SharedUI/SuggestionBar.swift KeyboardExtension/KeyboardViewController.swift App/PreviewSurface.swift`
> Plans 001–003 changed these files (typing paths `handle`/`expand`/`insert`, `applySuggestion`,
> `onSelect`, and `glideOffer` gained an `inserted` field). That drift is expected. If `glide(_:)`,
> `releaseMemory()`, `beginSession()`, the `glideContext` property/providers, `textDidChange`,
> `selectionDidChange`, `onCursor`, `onDismiss`, or the extension's `suggestionSnapshot()` differ
> otherwise from the excerpts below, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/003-exact-suggestion-replacements.md
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09. Replaces retired plan 004.

## Why this matters

When a glide lifts, `SuggestionCoordinator.glide(_:)` starts an untracked `Task` that awaits the
decoder actor, then unconditionally types the best word. The decoder's dictionary is unloaded each
time the keyboard disappears, so the first glide of each appearance waits for a cold load (~60 ms).
In that window a fast tap goes in before the word; focusing another field (keyboard stays up) puts
the word in the new field; selecting text lets the word replace the selection; dismissing the
keyboard (or the in-app preview) still lets it type.

Comparing "text before the caret" before and after is not enough on its own: some hosts hide
their context (the code already handles that: `updateAutoShift` treats `before == nil && hasText`),
two empty fields look identical, and document identifiers can be nil. So this plan makes
**events** authoritative: any key action, cursor drag, chosen suggestion, host-reported text or
selection change, dismissal, or session boundary cancels the pending glide. A full context
comparison remains as a second guard.

On the way it fixes a crash: at `56c6fc1` the extension reads `textDocumentProxy.documentIdentifier`
directly; it is nil between documents despite its non-optional Swift type, and bridging nil to
`UUID` traps.

## Current state

`SharedUI/SuggestionBar.swift`, `@MainActor final class SuggestionCoordinator`:
```swift
/// Glide needs only the language and the text before the caret. Hosts report no context
/// at all in an empty field, which rules out a suggestion snapshot but not a glide.
var glideContext: (() -> (language: KeyboardLanguage, before: String)?)?
...
func beginSession() { tipChosen = false; sessionTip = nil }
func suspend() {
    task?.cancel(); task = nil; generation += 1; offered = nil; requested = nil
}
func releaseMemory() {
    suspend()
    glideOffer = nil
    Task { await worker.unload() }
}
...
private func glide(_ points: [CGPoint]) {
    guard let keyboard, let current = glideContext?(), current.language.dictionaryCode != nil else { return }
    let learned = TaughtWordStore.words(current.language)
    let preferences = keyboard.preferences, width = keyboard.bounds.width
    suspend()
    glideOffer = nil
    Task { [weak self, worker] in
        guard let words = try? await worker.glide(points, language: current.language, learned: learned,
                                                  context: SuggestionText.context(current.before),
                                                  preferences: preferences, width: width),
              let self, let best = words.first,
              let inserted = self.insertWord?(best.word) else { return }
        ...
    }
}
```
- `suspend()` runs on every `refresh()` that sees changed text, and with suggestions off every
  `refresh()` calls `cancel()` → `suspend()`. So **do not** cancel glides from `suspend()`,
  `cancel()` or `refresh()`: with suggestions off that would drop every glide.
- Lifting a glide emits no key action (`SharedUI/KeyboardView.swift` touchesEnded: the
  `session.glide` branch only calls `onGlide` and `onGesture`). Text keys emit on touch end, so
  nothing the keyboard does between lift and decode is "own" input.

`KeyboardExtension/KeyboardViewController.swift` (at `56c6fc1`):
```swift
override func textDidChange(_ textInput: (any UITextInput)?) { if !applyingSuggestion { synchronize() } }
override func selectionDidChange(_ textInput: (any UITextInput)?) {
    guard !applyingSuggestion else { return }
    ...
}
...
keyboard.onCursor = { [weak self] in
    self?.punctuationSpacing.reset()
    ...
}
...
private func suggestionSnapshot() -> SuggestionSnapshot? {
    ...
    guard before != nil || after != nil || !selected.isEmpty else { return nil }
    return .init(document: textDocumentProxy.documentIdentifier, before: before ?? "", after: after ?? "",
                 selection: selected, language: inputState.language)
}
private func glideContext() -> (language: KeyboardLanguage, before: String)? {
    guard isViewLoaded, view.window != nil, lastKeyboardType != nil else { return nil }
    let allowed = Self.suggestionTypes
    guard allowed.contains(textDocumentProxy.keyboardType ?? .default),
          textDocumentProxy.isSecureTextEntry != true else { return nil }
    return (inputState.language, textDocumentProxy.documentContextBeforeInput ?? "")
}
...
private func handle(_ action: KeyAction) {
    switch action { ... }
```
`textDidChange` is also how the controller notices a new field (it re-reads `keyboardType` in
`synchronize()`), so cancelling there covers field switches even when both contexts look alike.

`App/PreviewSurface.swift` (`final class PreviewContainer: UIView, UITextViewDelegate`):
```swift
suggestions.glideContext = { [weak self] in
    guard let self, self.isActive else { return nil }
    return (self.state.language, self.textBeforeCaret)
}
...
keyboard.onDismiss = { [weak self] in self?.editor.resignFirstResponder() }
keyboard.onCursor = { [weak self] offset in ... }
...
func textViewDidChangeSelection(_ textView: UITextView) {
    guard !applyingSuggestion else { return }
    ...
}
private func handle(_ action: KeyAction) {
    applyingSuggestion = true
    ...
    case .dismiss: editor.resignFirstResponder()
```
It has a stable `documentID`. It has no `textViewDidEndEditing`. Plan 001 may have added a private
`selectedText` helper — reuse it if present; otherwise compute
`(editor.text as NSString).substring(with: editor.selectedRange)` with the same range guard its
`suggestionSnapshot()` uses.

## Repo facts

- Swift 6 strict concurrency; the coordinator is `@MainActor`; `SuggestionWorker` is an actor.
- `SharedUI/`, `KeyboardExtension/`, `App/` are Xcode-only: compile-check with xcodebuild.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| App + extension compile | `xcodebuild build -project Ortholinear.xcodeproj -scheme Ortholinear -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO -quiet` | exit 0, no `error:` lines |
| Core tests (sanity) | `swift test --filter GlideTests` | exit 0 |

## Scope

**In scope**:
- `SharedUI/SuggestionBar.swift` (`SuggestionCoordinator`, and a new small `GlideContext` struct)
- `KeyboardExtension/KeyboardViewController.swift` (`suggestionSnapshot()`, `glideContext()`, new
  `documentIdentifier` property, and one-line `cancelGlide()` calls in `handle`, `onCursor`,
  `textDidChange`, `selectionDidChange`, `onDismiss`)
- `App/PreviewSurface.swift` (the `glideContext` closure, one-line `cancelGlide()` calls in
  `handle`, `onCursor`, `onDismiss`, `textViewDidChangeSelection`, `clear()`, and a new `textViewDidEndEditing`)

**Out of scope**: `KeyboardView.swift`, the decoder, `SuggestionWorker`, `suspend()`/`cancel()`/
`refresh()` bodies (beyond the `glideContext` type change), `insertGlided`.

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence messages,
e.g. `Read the document identifier without trapping` and `Cancel a pending glide on any input`.

## Steps

### Step 1: Nil-safe document identifier in the extension

Apply this exact change to `KeyboardExtension/KeyboardViewController.swift` (verbatim — an
identical change exists on another branch and must merge cleanly). In `suggestionSnapshot()` replace
```swift
        guard before != nil || after != nil || !selected.isEmpty else { return nil }
        return .init(document: textDocumentProxy.documentIdentifier, before: before ?? "", after: after ?? "",
                     selection: selected, language: inputState.language)
    }
```
with
```swift
        guard before != nil || after != nil || !selected.isEmpty, let document = documentIdentifier else { return nil }
        return .init(document: document, before: before ?? "", after: after ?? "",
                     selection: selected, language: inputState.language)
    }

    /// documentIdentifier is nil while the proxy is between documents, despite its nonoptional
    /// Swift type, and bridging that nil to UUID traps. Asking through Objective-C allows nil.
    private var documentIdentifier: UUID? {
        let getter = #selector(getter: UITextDocumentProxy.documentIdentifier)
        guard textDocumentProxy.responds(to: getter) else { return nil }
        return textDocumentProxy.perform(getter)?.takeUnretainedValue() as? UUID
    }
```
Commit this step on its own.

**Verify**: xcodebuild → exit 0; `grep -n "textDocumentProxy.documentIdentifier" KeyboardExtension/KeyboardViewController.swift` → no matches.

### Step 2: Coordinator owns the pending glide

In `SharedUI/SuggestionBar.swift`:
- Above `SuggestionCoordinator` add
  ```swift
  /// Where a glide will type. A decoded word goes in only if all of this is unchanged.
  struct GlideContext: Equatable {
      var language: KeyboardLanguage
      var before: String
      var selection: String
      var document: UUID?
  }
  ```
  and change the property to `var glideContext: (() -> GlideContext?)?` (keep its doc comment;
  `.language`/`.before` uses keep working).
- Add `private var glideTask: Task<Void, Never>?` and an internal (not private) method
  ```swift
  /// Any input, or the keyboard leaving, makes a glide still being decoded land in the wrong place.
  func cancelGlide() { glideTask?.cancel(); glideTask = nil }
  ```
- Call `cancelGlide()` from `releaseMemory()`, `beginSession()`, at the start of `glide(_:)`, and at
  the start of the `onSelect` closure body (after unwrapping `self`). Never from `suspend()`.
- Assign the glide `Task` to `glideTask`. Inside it, after the `await` and before `insertWord`,
  require `!Task.isCancelled` and `self.glideContext?() == current`; otherwise return without
  inserting. Keep the rest of the body unchanged.

No build yet: the providers still return tuples until step 3. Do steps 2 and 3, then build.

### Step 3: Providers return the full context

- Extension `glideContext()` → `GlideContext(language: inputState.language,
  before: textDocumentProxy.documentContextBeforeInput ?? "", selection: textDocumentProxy.selectedText ?? "",
  document: documentIdentifier)`, same guards as today.
- Preview closure → keep today's `guard let self, self.isActive else { return nil }` (do NOT require
  `editor.isFirstResponder`: the preview glides without focusing the editor, and
  `UITests/KeyboardUITests.swift` relies on that), then
  `GlideContext(language: state.language, before: textBeforeCaret, selection: <selected text>, document: documentID)`.
  Preview dismissal is handled by explicit cancellation in step 4.

**Verify** (covers steps 2 and 3): xcodebuild → exit 0.

### Step 4: Every input cancels

Extension (`KeyboardViewController.swift`):
- First line of `handle(_:)`: `suggestions.cancelGlide()`.
- In the `keyboard.onCursor` closure: `self?.suggestions.cancelGlide()` first.
- `textDidChange`: `if !applyingSuggestion { suggestions.cancelGlide(); synchronize() }`.
- `selectionDidChange`: after its `guard !applyingSuggestion`, call `suggestions.cancelGlide()`.
- `keyboard.onDismiss` closure (the header dismiss button calls it directly, bypassing `handle`):
  `self?.suggestions.cancelGlide(); self?.dismissKeyboard()`.

Preview (`PreviewSurface.swift`):
- First line of `handle(_:)`: `suggestions.cancelGlide()`.
- `onCursor` closure: cancel first (after unwrapping self).
- `onDismiss` closure: `self?.suggestions.cancelGlide(); self?.editor.resignFirstResponder()`.
- `textViewDidChangeSelection`: after its guard, `suggestions.cancelGlide()`.
- Add `func textViewDidEndEditing(_ textView: UITextView) { suggestions.cancelGlide() }`.
- `clear()` (the Clear button's reset path): `suggestions.cancelGlide()` first.

**Verify**: xcodebuild → exit 0; `swift test --filter GlideTests` → exit 0.

### Step 5: Commit

Commit; `git status --porcelain` → empty.

## Test plan

No unit-test target covers these files. In NOTES, for each case cite the line that now prevents
the late insertion: (1) tap before the result, even on a host hiding context — `handle` cancels;
(2) other field, both empty, nil or equal ids — `textDidChange` cancels; (3) selection made
meanwhile — `selectionDidChange`/`textViewDidChangeSelection` cancels and `selection` differs;
(4) system keyboard dismissed — `onDismiss`/`.dismiss` in `handle` cancel immediately, `releaseMemory`
cancels on disappearance, `glideContext()` nil without a window; (5) preview dismissed —
`onDismiss`/`textViewDidEndEditing` cancel; (6) a second glide — cancelled at `glide(_:)` start; (7) suggestions turned off —
glides still insert, since nothing in `suspend()`/`refresh()` cancels them.

## Done criteria

- [ ] xcodebuild exits 0
- [ ] `grep -n "textDocumentProxy.documentIdentifier" KeyboardExtension/KeyboardViewController.swift` → no matches
- [ ] `grep -c "cancelGlide()" KeyboardExtension/KeyboardViewController.swift` → 5; `App/PreviewSurface.swift` → 6
- [ ] `grep -n "cancelGlide()" SharedUI/SuggestionBar.swift` shows calls in `releaseMemory`, `beginSession`, `glide`, `onSelect`
- [ ] `git diff 56c6fc1 -- SharedUI/SuggestionBar.swift` shows no edit inside `suspend()`
- [ ] Only in-scope files changed by this plan's commits; `git status --porcelain` empty

## STOP conditions

- The excerpts don't match beyond the expected plan 001–003 drift.
- `PreviewContainer` already implements `textViewDidEndEditing`.
- Swift 6 concurrency errors appear that can't be fixed inside the in-scope code.
- If xcodebuild fails for environment reasons (sandbox denial, missing SDK, cannot write
  outside the worktree) rather than compile errors in files you touched, do NOT stop: finish the
  remaining steps and commit, then in NOTES write `BUILD UNVERIFIED:` followed by the exact error.
  The plan is not accepted until the reviewer gets a successful xcodebuild; NOTES belong in your
  final report, not in any file.

## Maintenance notes

- Dropping a glide whenever anything happened is deliberate: a misplaced word is worse than a lost one.
- Device check before release: a host that sends `textDidChange` late for an earlier key could
  cancel a glide spuriously; the window is the decode time (≤ ~60 ms cold).
- Any new input path (a new key action route, a new gesture) must call `cancelGlide()`.
