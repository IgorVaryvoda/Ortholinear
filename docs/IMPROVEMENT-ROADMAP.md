# Ortholinear improvement roadmap

This roadmap focuses on making Ortholinear more predictable, comfortable, and genuinely useful as a daily Ukrainian + English keyboard. The priority is not adding more surface area; it is reducing unintended edits, helping users find geometry that fits their hands, and strengthening the evidence behind typing decisions.

## Principles

1. **Never damage correct input.** Convenience features must be conservative around URLs, email addresses, filenames, numbers, emoticons, mixed tokens, selections, and host fields with incomplete context.
2. **Stable geometry beats clever geometry.** Customization should help users find a predictable layout rather than silently moving targets underneath them.
3. **Ukrainian is first-class.** Ukrainian convenience, localization, accessibility, and evaluation should receive the same attention as English.
4. **Explicit suggestions remain explicit.** Preserve tap-only corrections and avoid silent replacement or automatic learning from typed text.
5. **Measure real typing outcomes.** Prefer correction rate, keystrokes saved, latency, preservation failures, and physical-device behavior over feature count.

## P0 — typing correctness and interaction conflicts

### Make punctuation spacing token-aware

`PunctuationSpacing` currently reasons primarily about punctuation sequences and numeric continuations, while the extension relies partly on `UIKeyboardType` to suppress spacing in URL/email fields. That is insufficient when users type a URL, email address, filename, emoticon, or similar token inside an ordinary text field.

Implement conservative token-aware spacing that protects at least:

- URLs and URL-like fragments (`https://sirv.com`, `example.com/path`)
- email addresses (`name@example.com`)
- filenames/extensions (`file.swift`, `photo.jpg`)
- decimal/time continuations already supported by the current implementation
- emoticons and punctuation clusters where a space would alter the intended token
- text around selections and cursor moves where ownership of an automatically inserted space is uncertain

The policy should prefer *not* inserting a space when context is ambiguous. Add regression fixtures for these cases in addition to the existing sentence/number tests.

### Give the keyboard header area one presentation state

Suggestions and long-press alternatives currently share the top region. Model this explicitly rather than independently hiding/drawing pieces of UI.

Suggested states:

- normal/header
- suggestions
- alternatives

Opening alternatives should synchronously remove the suggestion surface from presentation, hit testing, and accessibility. Closing/cancelling should restore the appropriate state consistently. Add interaction tests that verify alternatives are visible and selectable with suggestions enabled, not merely that a long-press eventually emits the right character.

### Separate user language from temporary field language

Do not let an email/URL/ASCII field permanently overwrite the user's selected UA/EN language. Track something equivalent to:

- `userLanguage`: explicit UA/EN choice
- `effectiveLanguage`: temporary language required/preferred for the current host field

When the host field no longer requires English, restore the user's language. Add extension tests covering Ukrainian → email/URL → ordinary text.

## P1 — make customization solve an actual typing problem

### Add “Find your fit”

Turn geometry settings from raw sliders into an optional calibration flow:

1. choose a starting goal (larger targets / balanced / more text space)
2. type a short supplied Ukrainian or English passage at actual keyboard size
3. identify the problem (neighbor misses, awkward Delete, too much vertical space, etc.)
4. compare two configurations
5. keep the preferred configuration

Any measurements should be local, limited to the explicit practice exercise, and easy to discard. Useful metrics include completion time and correction count; do not collect normal typed text in the background.

### Add orientation profiles

Allow independent portrait and landscape geometry, with a simple default such as “Use portrait settings in landscape” until the user customizes landscape. Landscape should not merely inherit a large portrait vertical budget by accident.

### Separate Delete and Return widths

Replace the shared `actionKeyWidth` preference with independent Delete and Return widths, including preference migration. They occupy different rows on the default letter layout and have different ergonomic tradeoffs.

### Add named personal presets

Keep the built-in presets, but let users save and restore a small number of local configurations. This makes experimentation reversible and supports configurations such as “My Ukrainian” and “Landscape”.

## P1 — Ukrainian-first convenience

### Optional Ukrainian apostrophe on the letter page

Add a Ukrainian-specific apostrophe option independent of the existing English apostrophe setting. Users who prioritize wider letters should still be able to leave it off and access the apostrophe through the numbers/alternative path.

### Localize the containing app and accessibility strings

Add Ukrainian localization for onboarding, settings, suggestion actions, test surfaces, and accessibility labels/hints. Keyboard language support should extend beyond key glyphs.

### Clarify and improve personal vocabulary

Today the preview and keyboard extension intentionally keep separate taught-word stores. Make this distinction visible to users. Investigate an app-managed read-only vocabulary available to the extension plus an extension-local overlay for words taught while typing, while retaining the no-Full-Access design.

### Missing-space repair, later and explicit

Cases such as `будласка` → `будь ласка` are useful but exceed the current single-word edit model. Treat multi-token repair as a later tap-only feature with strict surrounding-text preservation tests rather than expanding replacement behavior casually.

## P1 — suggestion quality and regression gates

The current suggestion baseline is deliberately conservative and should remain so. Improve evidence before increasing model complexity.

Build independent evaluation fixtures for:

- real neighboring-key errors and transpositions
- Ukrainian inflections and apostrophe variants
- English/Ukrainian switching
- names, slang, technical words, and intentionally informal language
- completions measured by keystrokes saved
- preservation of punctuation, selections, URLs, emoji, and surrounding text

Keep diagnostic benchmarks, but add stable regression gates with justified thresholds for behaviors that must not regress. In particular, distinguish correction recall from preservation: a suggestion engine that offers fewer corrections can still be better if it stops interfering with correct/unfamiliar text.

Do not adopt a neural model until measurements show a problem the current indexed engine cannot solve within the extension's latency/memory constraints.

## P2 — calmer suggestion presentation

Avoid visually blanking the suggestion strip on every debounced request. Keep layout/presentation stable while new results are pending, but never allow a stale suggestion to remain actionable against a changed document snapshot.

When suggestions are unavailable for the current page or field, use an intentional neutral state rather than a transient-looking empty bar. Do not move the letter grid merely because a request is in flight.

## P1 — fast typing and feature-combination tests

Define and test explicit semantics for overlapping touches. Cover at least:

- A down → B down → B up → A up
- Shift overlapping a letter
- a held letter while another finger interacts with page controls
- Delete held while the host field changes or the keyboard disappears
- language/page changes while suggestion work is pending
- long-press alternatives with suggestions enabled
- selection/cursor changes with automatic punctuation spacing

The goal is not to optimize for exotic multitouch tricks; it is to make rapid real typing deterministic.

## P2 — reduce preview/extension behavior drift

The preview and extension correctly share the renderer but still duplicate parts of input/editing policy. Extract the behavior most likely to diverge into a shared policy layer, while keeping small adapters for `UITextView` and `UITextDocumentProxy`.

Candidates include:

- punctuation-spacing state/reset rules
- page/language/shift transitions
- insertion policy
- suggestion snapshot/edit policy where host APIs permit it

Do not rewrite the UIKit renderer or force the two hosts into an artificial common abstraction where their editing APIs genuinely differ.

## P1 — end-to-end physical-device performance

Continue the existing physical-device discipline, but measure user-visible paths in Release builds:

- touch → visible key feedback
- touch → host text insertion
- text change → usable suggestion
- cold/warm language switching
- repeated keyboard open/close
- rotation
- sustained typing sessions
- memory-warning recovery
- energy use over a representative session

Treat lookup time, debounce time, rendering, and host insertion as separate measurements. Profile before retaining more suggestion engines in memory.

## P2 — activation and settings UX

Reframe the containing app around a simple progression:

**Try it → Enable it → Verify it → Find your fit**

Make the difference between the in-app preview and the installed system extension explicit. After successful setup, emphasize the user's current configuration and immediate typing test rather than repeatedly presenting introductory marketing copy.

Add small interactive lessons for symbol slide, spacebar cursor movement, caps lock, and Ukrainian long-press characters.

## Documentation cleanup

Reconcile README sections that describe autocorrect/suggestions as future work with the 0.4.0 suggestion-only implementation. Clearly distinguish released/submitted 0.3.x behavior from development 0.4.0 behavior so the repository has one coherent statement of current scope.

## Suggested execution order

### Milestone A — trust

- token-aware punctuation spacing + preservation fixtures
- suggestion/alternatives presentation-state fix
- user-language restoration after temporary field overrides
- cross-feature regression tests for those fixes

### Milestone B — ergonomics

- independent Delete/Return widths + migration
- portrait/landscape profiles
- Ukrainian apostrophe option
- “Find your fit” calibration prototype
- named presets if calibration proves useful

### Milestone C — evidence

- larger independent correction/preservation fixtures
- explicit quality gates
- overlapping-touch tests
- sustained Release physical-device profiling

### Milestone D — polish

- Ukrainian app/accessibility localization
- vocabulary UX
- calmer suggestion-strip transitions
- onboarding/setup progression
- README/release-state cleanup

## Non-goals for now

- silent autocorrect
- background typing-history collection
- requiring Full Access for ordinary keyboard features
- a neural prediction model without measured justification
- invisible adaptive touch-target movement
- a renderer rewrite

The product target is simple: users should be able to tune Ortholinear to their hands, trust it not to mutate correct input, and then stop thinking about the keyboard while they type.