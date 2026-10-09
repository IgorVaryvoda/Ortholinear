# Plan 008: The wrong-layout example and the suggestion-row description match the keyboard

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 56c6fc1..HEAD -- README.md SUPPORT.md App/SuggestionSettings.swift Core/LayoutRecovery.swift Tests/SuggestionTests.swift`
> Plans 003 and 006 added tests to `Tests/SuggestionTests.swift`; that is expected. Any other
> change to these files is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/006-supplementary-words-in-every-language.md (shares `Tests/SuggestionTests.swift`)
- **Category**: docs
- **Planned at**: commit `56c6fc1`, 2026-10-09

## Why this matters

1. The in-app settings, README, SUPPORT and a code comment all promise that typing "ghbdsn" with
   English active offers "привіт ⇄". That example is the *desktop* QWERTY/ЙЦУКЕН habit. On this
   straight-row keyboard the English and Ukrainian rows have different key counts, and recovery
   maps by finger position, so `ghbdsn` maps to `потвіь` and nothing is offered. Verified at widths
   375, 393, 430 and 820 pt: `LayoutRecovery.recover("ghbdsn", ...)` is nil. Touching the
   positions of `привіт` on the English layout types `ghvdsb`, which recovers to `привіт` at all
   four widths. The feature works; the example is wrong. People who try the example think it's broken.
2. README says: "Between words, the suggestion row shows `. , ? ! :` and `« »` (Cyrillic) or
   `- "` (Latin) in fixed positions, so a period is one tap." When next-word predictions are
   showing, the code deliberately keeps only `. , ?` (to the right of two predictions) —
   `SharedUI/SuggestionBar.swift` `show(...)`: "Next words leave room for . , ? so ending a
   sentence stays one tap." The README should say so.

## Current state

- `App/SuggestionSettings.swift:22`:
  `Label("Typed “ghbdsn” in English? Tap “привіт ⇄” to fix the word and switch to Ukrainian.", systemImage: "arrow.left.arrow.right")`
- `README.md:50`: `- A word typed on the wrong layout, such as “ghbdsn” while English is active, gets a “привіт ⇄” offer that fixes the word and switches language, when English and Ukrainian are both on.`
- `README.md:47`: `- Between words, the suggestion row shows \`. , ? ! :\` and \`« »\` (Cyrillic) or \`- "\` (Latin) in fixed positions, so a period is one tap. Marks attach to the word, even after a suggestion added a space.`
- `SUPPORT.md:25`: `- **Typed on the wrong layout:** with English and Ukrainian both on, a word like “ghbdsn” gets a “привіт ⇄” offer that fixes it and switches language.`
- `Core/LayoutRecovery.swift:4`: `/// Recovers a word typed with the other layout active, such as “ghbdsn” for “привіт”:`
- Test pattern: `Tests/SuggestionTests.swift`, the test containing
  `XCTAssertEqual(LayoutRecovery.recover(mistype("привіт", on: en, meant: uk), from: en, to: uk, lexicon: ukrainian.lexicon), "привіт")`
  — it builds `en`/`uk` as `SuggestionGeometry(language:preferences:width:)` and loads
  `let ukrainian = try SuggestionResources.engine(language: .ukrainian)`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --filter SuggestionTests` | exit 0 (slow suite) |
| App + extension compile | `xcodebuild build -project Ortholinear.xcodeproj -scheme Ortholinear -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO -quiet` | exit 0 |

## Scope

**In scope**: `README.md`, `SUPPORT.md`, `App/SuggestionSettings.swift` (the one string),
`Core/LayoutRecovery.swift` (the doc comment only), `Tests/SuggestionTests.swift`.

**Out of scope**: recovery logic; `design/` (untracked marketing drafts); `docs/` App Store
copy (owner decides store text); `SharedUI/SuggestionBar.swift` layout.

## Git workflow

Commit on the current branch (do not create or switch branches). Imperative-sentence message,
e.g. `Use a wrong-layout example this keyboard actually fixes`.

## Steps

### Step 1: Lock the example with a test

Add `testDocumentedWrongLayoutExampleRecovers` to `Tests/SuggestionTests.swift`: for each width
in `[375.0, 393.0, 430.0, 820.0]`, with default `KeyboardPreferences()`,
`LayoutRecovery.recover("ghvdsb", from: en, to: uk, lexicon: ukrainian.lexicon)` == `"привіт"`.

**Verify**: `swift test --filter SuggestionTests` → exit 0. If the assertion fails, STOP.

### Step 2: Replace the example everywhere

Replace `ghbdsn` with `ghvdsb` in the four places quoted above. In `README.md:50` and
`SUPPORT.md:25`, add a short clause that recovery follows key positions on this keyboard, e.g.
"such as “ghvdsb” (the keys where привіт sits) while English is active". Keep the in-app string
short; just swap the word.

**Verify**: `grep -rn "ghbdsn" README.md SUPPORT.md App Core` → no matches;
`grep -rn "ghvdsb" README.md SUPPORT.md App/SuggestionSettings.swift Core/LayoutRecovery.swift` → 4 matches.

### Step 3: Describe the suggestion row accurately

Rewrite `README.md:47` so it says: with no word suggestions, the row shows `. , ? ! :` and
`« »` (Cyrillic) or `- "` (Latin); while next-word predictions show, `. , ?` stay at the right so
a period is still one tap. Keep the final sentence about marks attaching to the word.

**Verify**: `grep -n "next-word" README.md` shows the new wording on that line.

### Step 4: Compile and commit

xcodebuild → exit 0; commit; `git status --porcelain` → empty.

## Done criteria

- [ ] `swift test --filter SuggestionTests` exits 0 including the new test
- [ ] xcodebuild exits 0
- [ ] grep checks in step 2 hold
- [ ] Only in-scope files changed by this plan's commit; `git status --porcelain` empty

## STOP conditions

- `recover("ghvdsb", ...)` is not `"привіт"` at any listed width.
- Any in-scope file differs from the quoted lines (other than expected test additions).

## Maintenance notes

- The new test fails if a layout change moves keys enough to break the documented example —
  update the example and test together.
