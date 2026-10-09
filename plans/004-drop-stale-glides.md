# Plan 004: A glided word is never typed after its moment has passed

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- SharedUI/SuggestionBar.swift KeyboardExtension/KeyboardViewController.swift App/PreviewSurface.swift`
> Plans 001–003 changed these files (typing paths, `applySuggestion`, `onSelect`, and
> `glideOffer` gained an `inserted` field). That drift is expected. If `glide(_:)`,
> `releaseMemory()`, `beginSession()`, the `glideContext` property/providers, or the extension's
> `suggestionSnapshot()` differ otherwise from the excerpts below, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/003-exact-suggestion-replacements.md
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09 (revised after scrutiny round 1)

## Why this matters

When a glide lifts, `SuggestionCoordinator.glide(_:)` starts an untracked `Task` that awaits
the decoder actor, then unconditionally types the best word. Nothing cancels it or checks that
the insertion point is still the same. The decoder's dictionary is unloaded every time the
keyboard disappears (`releaseMemory()` → `worker.unload()`), so the first glide of each
appearance waits for a cold load (~60 ms). In that window:

- a fast tap (e.g. `.` right after lifting) goes in first and the word lands after it;
- the person focuses another field (keyboard stays up) — even an empty one with the same empty
  text before the caret — and the old word goes into the new field;
- the person selects text, and the late word replaces the selection;
- the keyboard is dismissed.

After this plan, a glide result is typed only if the language, document, text before the caret
and selection are all exactly as they were at lift, and the keyboard session hasn't ended.

A second, related crash is fixed on the way: at `56c6fc1` the extension reads
`textDocumentProxy.documentIdentifier` directly. That property is nil while the proxy is between
documents despite its non-optional Swift type, and bridging that nil to `UUID` traps. The
revalidation needs the document identity, so this plan adds the nil-safe accessor first.

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
// in refresh(force:):
keyboard.glideEnabled = preferences.glideTyping && keyboard.inputState.page == .letters
    && glideContext?()?.language.dictionaryCode != nil
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
- `suspend()` runs on every `refresh()` that sees changed text, and with suggestions turned off
  every `refresh()` calls `cancel()` → `suspend()`. So **do not** tie glide cancellation to
  `suspend()` or `generation`: with suggestions off that would drop every glide.
- Lifting a glide emits no other key (`SharedUI/KeyboardView.swift` touchesEnded: the
  `session.glide` branch only calls `onGlide` and `onGesture`).

`KeyboardExtension/KeyboardViewController.swift` (at `56c6fc1`):
```swift
private func suggestionSnapshot() -> SuggestionSnapshot? {
    ...
    let selected = textDocumentProxy.selectedText ?? ""
    // A completely unavailable context is not a safe replacement target.
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
```
`viewDidLoad` wires `suggestions.glideContext = { [weak self] in self?.glideContext() }`.

`App/PreviewSurface.swift` `init`:
```swift
suggestions.glideContext = { [weak self] in
    guard let self, self.isActive else { return nil }
    return (self.state.language, self.textBeforeCaret)
}
```
The preview has a stable `documentID` (used in its `suggestionSnapshot()`), and its selected text
is `(editor.text as NSString).substring(with: editor.selectedRange)` (guard the range as
`suggestionSnapshot()` does). Plan 001 may already have added a private `selectedText` helper
in `PreviewSurface` — reuse it if present.

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
- `SharedUI/SuggestionBar.swift` (`SuggestionCoordinator`, plus a new small `GlideContext` struct)
- `KeyboardExtension/KeyboardViewController.swift` (`suggestionSnapshot()`, `glideContext()`, a new `documentIdentifier` property)
- `App/PreviewSurface.swift` (the `suggestions.glideContext` closure only)

**Out of scope**: `KeyboardView.swift`, the decoder, `SuggestionWorker`, the suggestion
`task`/`generation`/`suspend()` logic, `insertGlided`.

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence messages,
e.g. `Read the document identifier without trapping` and `Drop glide results once the text has moved on`.

## Steps

### Step 1: Nil-safe document identifier in the extension

Apply this exact change to `KeyboardExtension/KeyboardViewController.swift` (use this text
verbatim — an identical change exists elsewhere and must merge cleanly):

In `suggestionSnapshot()` replace
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

### Step 2: A full glide context

In `SharedUI/SuggestionBar.swift` (above `SuggestionCoordinator`) add:
```swift
/// Where a glide will type. A decoded word goes in only if all of this is unchanged.
struct GlideContext: Equatable {
    var language: KeyboardLanguage
    var before: String
    var selection: String
    var document: UUID?
}
```
Change `var glideContext: (() -> (language: KeyboardLanguage, before: String)?)?` to
`var glideContext: (() -> GlideContext?)?` and keep its doc comment. Existing uses
(`.language`, `.before`) keep working.

Providers:
- Extension `glideContext()` returns `GlideContext(language: inputState.language,
  before: textDocumentProxy.documentContextBeforeInput ?? "", selection: textDocumentProxy.selectedText ?? "",
  document: documentIdentifier)` (same guards as today).
- Preview closure returns `GlideContext(language: state.language, before: textBeforeCaret,
  selection: <selected text>, document: documentID)`.

**Verify**: xcodebuild → exit 0.

### Step 3: Track, cancel and revalidate the glide task

In `SuggestionCoordinator`:
- Add `private var glideTask: Task<Void, Never>?` and
  ```swift
  /// A glide decoded after the keyboard left, or after other typing, would land in the wrong place.
  private func cancelGlide() { glideTask?.cancel(); glideTask = nil }
  ```
- Call `cancelGlide()` from `releaseMemory()` and `beginSession()` — not from `suspend()`.
- In `glide(_:)`: call `cancelGlide()` before starting; assign the new `Task` to `glideTask`.
- Inside the task, after the `await` and before `insertWord`, require
  `!Task.isCancelled` and `self.glideContext?() == current` (the full `GlideContext` captured at
  lift). If either fails, return without inserting. Restructure the existing `guard` so
  `insertWord` is only called after these checks; keep the rest of the body unchanged.

**Verify**: xcodebuild → exit 0; `swift test --filter GlideTests` → exit 0.

### Step 4: Commit

Commit; `git status --porcelain` → empty.

## Test plan

No unit-test target covers `SharedUI`/`KeyboardExtension`. In NOTES, walk through how each case
is now handled, citing the line that handles it: (1) dismissal — `releaseMemory` cancels and
`glideContext()` returns nil without a window; (2) a tap before the result — `before` differs;
(3) another field with identical empty text — `document` differs; (4) selection made meanwhile —
`selection` differs; (5) a second glide — the first task is cancelled; (6) suggestions turned
off — glides still insert, because nothing in `suspend()` touches `glideTask`.

## Done criteria

- [ ] xcodebuild exits 0
- [ ] `grep -n "textDocumentProxy.documentIdentifier" KeyboardExtension/KeyboardViewController.swift` → no matches
- [ ] `grep -n "struct GlideContext" SharedUI/SuggestionBar.swift` → 1 match
- [ ] `grep -n "cancelGlide()" SharedUI/SuggestionBar.swift` → calls in `releaseMemory`, `beginSession`, `glide`
- [ ] `git diff 56c6fc1 -- SharedUI/SuggestionBar.swift` shows no edit inside `suspend()`
- [ ] Only in-scope files changed by this plan's commits; `git status --porcelain` empty

## STOP conditions

- The excerpts don't match beyond the expected plan 001–003 drift.
- Swift 6 concurrency errors appear that can't be fixed inside the in-scope code.
- If xcodebuild fails for environment reasons (sandbox denial, missing SDK, cannot write
  outside the worktree) rather than compile errors in files you touched, do NOT stop: finish the
  remaining steps and commit, then in NOTES write `BUILD UNVERIFIED:` followed by the exact error.
  The plan is not accepted until the reviewer gets a successful xcodebuild; NOTES belong in your
  final report, not in any file.

## Maintenance notes

- Dropping a glide whenever anything changed is deliberate: a misplaced word is worse than a lost one.
- If a host reports a nil document identifier both times, `document` compares equal; the other
  three fields still guard the insertion.
