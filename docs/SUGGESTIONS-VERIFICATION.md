# Suggestion-only baseline — 0.4.0 (17)

September 8, 2026. This development version adds offline corrections, completions, next-word suggestions, and explicit local teaching/forgetting for English and Ukrainian. It does not add a neural model or automatic replacement.

## Behavior and implementation

- Three large suggestion buttons occupy a separate 44-point row; existing letter/control heights are preserved. The row follows the selected theme.
- Space and punctuation never accept a suggestion. Tapping an offered correction replaces only the identified word. Accepting a completion/next word at the document end also inserts a space.
- Moving the caret inside a word or selecting a complete word refreshes alternatives. Stale offers are rejected using document identity and exact surrounding/selected text. Partial selections, long/ambiguous tokens, mixed-alphabet words, email/URL-like tokens, and numeric input are excluded.
- English/UA candidate lookup uses a native prefix-five symmetric-delete index, full edit-distance verification, frequency and actual-layout key-distance ranking, plus optional short-context ranking. Low-scoring alternatives are omitted rather than always filling three slots.
- Suggestions run on a background actor. Pending queries are debounced/cancelled, stale results are discarded, and only one language engine is retained. A memory warning or keyboard dismissal releases the engine.
- Explicitly taught words live in this process's local defaults (200 per language). The system keyboard and app preview keep separate lists, so the extension does not need to write to the shared App Group or request Full Access. The suggestion menu offers Teach, Forget, and Clear. There is no automatic learning or saved typing history.
- Settings expose Word suggestions, Next-word suggestions, and Use sentence context near the top. Editing uses local settings state with immediate file persistence, then updates the parent preview on dismissal. Save errors remain within the settings page.

## Bundled data

40,001 English and 40,006 Ukrainian surface forms, selected from wordfreq 3.1.1 and checked with SCOWL/VESUM Hunspell spelling rules using Spylls at build time. Common informal language is retained explicitly. No Hunspell engine, Python runtime, raw corpus, or network client ships in the keyboard.

Context tables use only training data: Universal Dependencies English EWT r2.18 and the corrected `gec-only` training split of UA-GEC revision `4757f72f192c4a41e4c8fb1d9690a948f87cf6d6`. The second annotation of a document is excluded. Models retain up to eight next words per context occurring at least twice, with trigram-to-bigram backoff and frequency fallback. There are 10,749 English and 19,843 Ukrainian contexts.

The initial Ukrainian IU corpus experiment was discarded after checking its noncommercial license. It is not a source of any shipped asset. English EWT/wordfreq data carry CC BY-SA 4.0 terms; UA-GEC carries CC BY 4.0 terms. Generated assets are distributed under CC BY-SA 4.0, with source credits and notices embedded in each resource and exposed in the app. The VESUM Hunspell derivative has its own MPL 1.1 notice; the noncommercial VESUM source database is not bundled.

All five language resources total **12,783,968 bytes** (about 12.8 MB decimal), not a runtime-memory estimate. The app and extension each embed their own copy. [The asset/source manifest](../Tools/suggestion-data-manifest.json) records hashes. [The generator](../Tools/build_suggestion_data.py) and [pinned dependencies](../Tools/suggestion-data-requirements.txt) reproduce the data.

## Quality measurements

Next-word evaluation uses untouched test splits with the same tokenizer and backoff policy as the prototype. Each position with preceding word context is scored; out-of-vocabulary targets still count. Sentence punctuation resets context. These are corpus benchmarks, not observed phone-typing acceptance rates.

| Language / held-out corpus | Positions | Frequency-only top 3 | Context + fallback top 3 |
| --- | ---: | ---: | ---: |
| English / EWT test | 19,162 | 1,984 (10.4%) | 4,050 (21.1%) |
| Ukrainian / UA-GEC test, first annotation | 31,274 | 1,537 (4.9%) | 3,610 (11.5%) |

A separate hand-authored diagnostic correction sample has 15 cases per language. Both frequency/edit-distance and geometry ranking found the intended word in the top three for **15/15 English** and **13/15 Ukrainian** cases. This small sample does not demonstrate a measurable quality gain from geometry, nor establish population accuracy. The Ukrainian misses are a missing-space repair (`будласка` → `будь ласка`, outside the single-word scope) and an ambiguous typo (`друез` → `друже`). No tuning used the held-out next-word test split.

Release-mode Mac lookup timings on this sample were around 1 ms English and 3 ms Ukrainian at the reported sample p95. These are not iPhone measurements. Exact case outputs and timings are retained in `build/suggestions-core-verified.log`.

## Verification

- 29 core tests pass in Release mode, covering edit targets, selected/midword replacements, stale context/document rejection, explicit acceptance/spacing, case/apostrophes, Ukrainian letter identity, geometry, settings migration, bundled data, and taught-word ranking.
- The signed installed-extension simulator test passes in `build/Suggestions-signed-system.xcresult` and the final button-style check in `build/Suggestions-final-renderer.xcresult`. It verifies English and Ukrainian tap-only corrections, Space preserving a typo, cursor movement into a word before replacement, deletion, teaching, reopening the keyboard, and forgetting.
- Simulator extension diagnostics (Debug, 20 completed queries) reported approximately 8.6 ms warm p95, 90 ms last cold load, and 57.6 MiB maximum sampled **whole extension process** footprint. This is neither incremental model memory nor a physical iPhone memory budget. Diagnostics contain numbers only and are excluded from Release builds.
- All three signed preview/settings regressions pass in `build/Suggestions-signed-preview.xcresult`: selected earlier-word replacement, teaching/forgetting across app relaunch, toggle behavior, all themes/accents and persistence, and live spacing in portrait/landscape.
- Signed Release build succeeds. Version 0.4.0 (17) was installed on the paired iPhone, confirmed by `build/suggestions-install-final.json`. Remote launch was also declined while locked (`build/suggestions-launch.log`). Physical automated typing could not start because Xcode requires the iPhone to be unlocked. A later physical-device run remains necessary for on-device latency, memory, and sustained typing checks.

Simulator tests must retain ad-hoc signing. Initial unsigned test builds lacked App Group entitlements and could not validate shared settings; those runs are superseded by the signed results above.

## Limits and next work

No sentence rewriting, grammar correction, missing-space repair, automatic language detection, or neural prediction. Vocabulary coverage is bounded, particularly for Ukrainian inflections and new slang. Suggested words can still be wrong; unfamiliar text is never silently replaced. The keyboard cannot draw typo underlines or own correction popovers inside arbitrary host apps. Proxy edits are not atomic and cannot repair hosts that expose insufficient context.

Before considering a neural model, expand independent spelling/preservation fixtures, evaluate acceptance/keystrokes saved on volunteered examples, and measure warm/cold latency, memory headroom, and a sustained session on the physical iPhone. The existing 0.3.2 (16) App Review submission is separate from this development build.
