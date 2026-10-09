# Plan 004: A glided word is never typed after its moment has passed

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- SharedUI/SuggestionBar.swift`
> Plan 003 changed `SuggestionBar.swift` (`glideOffer` gained an `inserted` field; `onSelect`
> may call `SuggestionEdit.replacingGlide`). That drift is expected. If `glide(_:)`,
> `suspend()`, `releaseMemory()` or `beginSession()` differ otherwise from the excerpts below, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MED
- **Depends on**: plans/003-exact-suggestion-replacements.md
- **Category**: bug
- **Planned at**: commit `56c6fc1`, 2026-10-09

## Why this matters

When a glide lifts, `SuggestionCoordinator.glide(_:)` starts an untracked `Task` that awaits
the decoder actor, then unconditionally types the best word. Nothing cancels it or checks that
the text is still where it was. The decoder's dictionary is unloaded every time the keyboard
disappears (`releaseMemory()` → `worker.unload()`), so the first glide of each appearance waits
for a cold load (~60 ms measured in `swift test` benchmarks). In that window:

- a fast tap (e.g. `.` right after lifting) goes in first and the word lands after it
  (`.` then ` hello`), or
- dismissing the keyboard or moving to another field lets the old word be typed into the new
  place.

After this plan, a glide result is dropped if the keyboard went away, another glide started, or
the text before the caret changed since the lift.

## Current state

`SharedUI/SuggestionBar.swift`, `@MainActor final class SuggestionCoordinator`:
```swift
private let worker = SuggestionWorker()
private var task: Task<Void, Never>?
private var generation = 0
...
var glideContext: (() -> (language: KeyboardLanguage, before: String)?)?
var insertWord: ((String) -> String?)?

func beginSession() { tipChosen = false; sessionTip = nil }

func suspend() {
    task?.cancel(); task = nil; generation += 1; offered = nil; requested = nil
}
func releaseMemory() {
    suspend()
    glideOffer = nil
    Task { await worker.unload() }
}

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
- `glideContext` is provided by `KeyboardExtension/KeyboardViewController.swift`
  (`glideContext()` returns nil when `view.window == nil`, i.e. after dismissal) and by
  `App/PreviewSurface.swift` (nil when the preview isn't active).
- `suspend()` is called by every `refresh()` that sees changed text, and `refresh()` with
  suggestions turned off calls `cancel()` → `suspend()` on every refresh. So **do not** tie glide
  cancellation to `suspend()` or `generation`: with suggestions off that would drop every glide.
- Lifting a glide emits no other key (see `SharedUI/KeyboardView.swift` touchesEnded: the
  `session.glide` branch only calls `onGlide` and `onGesture`), so the text before the caret is
  unchanged between lift and decode unless the person did something else.

## Repo facts

- Swift 6 strict concurrency; the coordinator is `@MainActor`; `SuggestionWorker` is an actor.
- `SharedUI/` is Xcode-only: compile-check with xcodebuild. There is no unit-test target for it.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| App + extension compile | `xcodebuild build -project Ortholinear.xcodeproj -scheme Ortholinear -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO -quiet` | exit 0, no `error:` lines |
| Core tests (sanity) | `swift test --filter GlideTests` | exit 0 |

## Scope

**In scope**: `SharedUI/SuggestionBar.swift` (`SuggestionCoordinator` only).

**Out of scope**: `KeyboardViewController.swift`, `PreviewSurface.swift`, `KeyboardView.swift`,
the decoder (`Core/GlideDecoder.swift`), `SuggestionWorker`, suggestion `task`/`generation` logic.

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence message,
e.g. `Drop glide results once the text has moved on`.

## Steps

### Step 1: Track the glide task

Add `private var glideTask: Task<Void, Never>?`. In `glide(_:)`, `glideTask?.cancel()` before
starting, and assign the new `Task` to `glideTask`. Add:
```swift
/// A glide decoded after the keyboard left, or after other typing, would land in the wrong place.
private func cancelGlide() { glideTask?.cancel(); glideTask = nil }
```
Call `cancelGlide()` from `releaseMemory()` and `beginSession()` (not from `suspend()`; see
Current state).

**Verify**: xcodebuild → exit 0.

### Step 2: Revalidate before typing

Inside the task, after the `await` and before `insertWord`, require all of:
- `!Task.isCancelled`
- `let now = self.glideContext?()`, with `now.language == current.language` and
  `now.before == current.before`

If any fails, return without inserting. Restructure the existing `guard` so `insertWord` is only
called after these checks; keep the rest of the body (alternatives, `glideOffer`, `refresh`)
unchanged. Clear `glideTask` at the end of a task that is still the current one only if that is
simple; otherwise leaving the finished task stored is fine.

**Verify**: xcodebuild → exit 0; `swift test --filter GlideTests` → exit 0.

### Step 3: Commit

`git status --porcelain` → empty after committing.

## Test plan

No unit-test target covers `SharedUI`. The reviewer will check the diff by reading it. In NOTES,
describe the three cases: dismissal (context nil), a tap before the result (before changed),
and a second glide (previous task cancelled).

## Done criteria

- [ ] xcodebuild exits 0
- [ ] `grep -n "glideTask" SharedUI/SuggestionBar.swift` shows the property, cancel, and assignment
- [ ] `grep -n "cancelGlide()" SharedUI/SuggestionBar.swift` shows calls in `releaseMemory` and `beginSession`
- [ ] `suspend()` body is unchanged (`git diff 56c6fc1 -- SharedUI/SuggestionBar.swift` shows no edit inside it)
- [ ] Only `SharedUI/SuggestionBar.swift` changed by this plan's commit; `git status --porcelain` empty

## STOP conditions

- The excerpts don't match beyond plan 003's expected changes.
- Swift 6 concurrency errors appear that can't be fixed inside `SuggestionCoordinator`.
- If xcodebuild fails for environment reasons (sandbox denial, missing SDK, cannot write
  outside the worktree) rather than compile errors in files you touched, do NOT stop: finish the
  remaining steps and commit, then in NOTES write `BUILD UNVERIFIED:` followed by the exact error.
  The plan is not accepted until the reviewer gets a successful xcodebuild; NOTES belong in your
  final report, not in any file.

## Maintenance notes

- Comparing `before` means a glide is dropped if anything typed in between. That is deliberate:
  a misplaced word is worse than a lost one.
- Hosts that truncate context return the same truncated `before` twice, so the check still holds.
