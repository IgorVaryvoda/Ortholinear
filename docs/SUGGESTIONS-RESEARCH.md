# Suggestions without automatic replacement

Research date: September 8, 2026. This is a proposal for a future release; 0.3.2 (16) has already been submitted to App Review. No suggestion engine or dictionary has been added to the app. Device latency, memory, and suggestion quality have not yet been benchmarked.

## Recommendation

Build an offline dictionary baseline with our own ranking for English and Ukrainian. Add a compact bigram/trigram model as the first context experiment. Test a small neural model only against that baseline: it must earn its memory, latency, and maintenance cost through better suggestions in both languages.

These components can work together: dictionary lookup finds plausible corrections; a contextual model helps order them and proposes next words. Keeping generation, ranking, and text replacement separate lets us improve quality without changing the promise that text changes only when a suggestion is tapped.

| Approach | Main benefit | Main uncertainty | Proposed role |
| --- | --- | --- | --- |
| Dictionaries + custom ranking | Explicit control over nearby-key errors, vocabulary, and taught words | Dictionary coverage and ranking quality | First implementation |
| Pruned bigrams/trigrams | Short-context ranking and next-word prediction | Licensed conversational training data; table size | First context benchmark |
| Small neural language model | Potentially better longer-context predictions | Ukrainian quality, extension memory, startup, energy | Later experiment |

## Interaction contract

- Three generously sized suggestion buttons; preserve the typed word. Space and punctuation never silently accept a correction.
- While typing, offer completions/corrections. After a space, optionally offer next words.
- When the user places the caret in a word or selects it, show alternatives in our keyboard bar.
- Provide explicit Teach word, Forget word, and Clear learned words controls. Keep this data local; do not collect chat history.
- Preserve names, slang, profanity, casing, and Ukrainian letters. An unfamiliar word is not necessarily a typo.

iOS exposes surrounding/selected text and change callbacks through the keyboard's text document proxy. We can react to caret/selection changes, but cannot reliably provide our own red underlines or replacement popover inside arbitrary host apps. Available context can be incomplete. Only offer a replacement when the target can be identified safely. See [Apple's text interactions documentation](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards) and [UITextDocumentProxy](https://developer.apple.com/documentation/uikit/uitextdocumentproxy).

## Dictionary lookup and ranking

[SymSpell](https://github.com/wolfgarbe/SymSpell) is an MIT-licensed candidate-generation option using precomputed deletion variants. Its basic lookup orders by edit distance and frequency; our ranking would be additional. Its desktop speed claims are not measurements of a Swift implementation on an iPhone. Its compound lookup uses bigram information, but single-word lookup is not a complete next-word predictor.

Proposed ranking inputs: weighted edits, distance between keys in the actual configured layout, missing/repeated/transposed letters, word frequency, explicitly taught words, then contextual probability. Use a separate prefix index for completions. Benchmark candidate recall separately: reranking cannot recover a word that lookup never returned. Avoid merging і/ї or г/ґ into one spelling; treat them as possible errors while retaining their identity.

Use a native Swift implementation or audit a port for Unicode, transpositions, memory, and equivalence. Prebuild compact indexes outside the extension. For Ukrainian, compare a bounded common-word SymSpell index plus a morphology-aware fallback with indexing every inflected form. [Hunspell](https://github.com/hunspell/hunspell) already supports affix rules and rich morphology; its engine has LGPL/GPL/MPL license choices, which need their own integration review.

### Data candidates and licensing

| Source | Potential use | Findings |
| --- | --- | --- |
| [English Speller Database, formerly SCOWL](https://github.com/en-wl/wordlist) | English spelling vocabulary | Dialects, variants, and commonness tiers. Its [Copyright file](https://github.com/en-wl/wordlist/blob/v2/Copyright) describes MIT-like/BSD-compatible terms. Commonness tiers are not conversational frequency. |
| [VESUM / dict_uk](https://github.com/brown-uk/dict_uk) | Ukrainian morphology and vocabulary | Source dictionary data is CC BY-NC-SA 4.0; build software is GPL 3+. Do not assume the whole repository is permissively licensed. |
| [VESUM Hunspell derivative](https://github.com/brown-uk/dict_uk/blob/master/distr/hunspell/README.md) | Ukrainian spelling backend | Separately declares MPL 1.1. Verify the exact distributed artifact and preserve the required notices/source provenance before shipping. |
| [wordfreq](https://github.com/rspeer/wordfreq) | Initial English/Ukrainian frequency ranking | Supports both languages. Code is Apache 2.0; data is CC BY-SA 4.0 with attribution requirements. Data is a snapshot through approximately 2021. Filter noisy entries against spelling vocabulary; retain credits with derived data. |

Inspected the actual [Ukrainian v6.8.5 release](https://github.com/brown-uk/dict_uk/releases/tag/v6.8.5), specifically `hunspell-uk_UA_6.8.5.zip`:

- ZIP: 1,578,129 bytes; `uk_UA.aff`: 210,665 bytes; `uk_UA.dic`: 8,973,091 bytes.
- Dictionary header: 352,876 entries with affix flags; this is not the total number of expanded word forms.
- About 9.18 MB uncompressed on disk, not a runtime RAM estimate. A deletion index can be substantially larger.
- ZIP contains the two dictionary files, without a separate license/readme file. Packaging must supply the appropriate provenance and license material.
- ZIP SHA-256: `25563d417d1c114a9fb9cbca1b23a68289f7c2c7e0d622429b42b1ddededa12a`.

Downloads are research data under ignored `build/suggestion-research/`; nothing is bundled into the app.

## Context without a neural model

Start with pruned word bigrams/trigrams: estimate likely words from the previous one or two words, backing off when context is unfamiliar. This can support both next-word prediction and correction ranking. It still needs well-licensed text that resembles real messages; news-only training is unlikely to match casual bilingual typing well.

[KenLM](https://github.com/kpu/kenlm) provides a reference implementation with compact trie and faster probing representations, plus binary loading. Its [license](https://github.com/kpu/kenlm/blob/master/LICENSE) is mostly LGPL 2.1+ with exceptions. Use it as an offline benchmark first; shipping a small custom table reader is another option. Measure table size and quality after pruning rather than assuming statistical models are always small.

## Small neural model experiment

Evaluate a small recurrent model or transformer trained/distilled for English and Ukrainian. [Google's mobile language-model research](https://research.google/blog/synthetic-and-federated-privacy-preserving-domain-adaptation-with-llms-for-mobile-applications/) supports investigating small models and conversational domain adaptation. It does not establish expected gains for this keyboard.

An exploratory 5–20 million parameter model has roughly 5–20 MB of raw 8-bit weights, before tokenizer, activations, runtime buffers, and other overhead. These are arithmetic estimates, not measured memory budgets. [Core ML supports weight quantization](https://apple.github.io/coremltools/docs-guides/source/opt-quantization-overview.html), but smaller stored weights do not guarantee proportionally lower RAM or faster inference.

Avoid beginning with a generic chat model. For example, [SmolLM2-135M](https://huggingface.co/HuggingFaceTB/SmolLM2-135M) is primarily English; even nominal 4-bit weights alone are about 67.5 MB. That makes it a poor default candidate for our bilingual extension without compelling measurements.

Apple Foundation Models is worth an optional English control experiment on supported devices. [KeyboardKit reports using it for keyboard next-word prediction](https://keyboardkit.com/blog/2026/02/13/keyboardkit-10-3), so blanket claims that it cannot work in extensions would be wrong. However, [Apple's published language list](https://support.apple.com/en-us/121115) currently omits Ukrainian. Check [model language/locale availability](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models), runtime availability, and extension behavior on device. It cannot be our sole English/Ukrainian engine or our fallback for older iOS versions.

## Evaluation before choosing

Compare five configurations on the same held-out examples: UITextChecker as a spelling control, dictionary/frequency, dictionary plus geometry/taught words, added trigram context, then added neural context. UITextChecker is not equivalent to Apple's full system keyboard autocorrect.

Use English and Ukrainian cases covering nearby-key errors, transpositions, repeated/missing letters, inflections, apostrophes, casing, names, slang, profanity, and language switching. Include correct text, URLs, and email addresses to measure unwanted suggestions. [UA-GEC](https://github.com/grammarly/ua-gec) provides a CC BY 4.0 Ukrainian correction corpus; select spelling-only examples from its held-out data rather than scoring grammar rewrites as spelling improvements. Add independently prepared phone-typing cases; synthetic errors alone will overestimate quality.

Measure:

- Intended correction in the top three, reciprocal rank, candidate recall, and distracting suggestions on correct words.
- Next-word top-three accuracy, acceptance, and keystrokes saved, reported separately for English and Ukrainian.
- Cold startup, warm p50/p95 lookup, peak extension RAM, and sustained typing energy/temperature on the physical iPhone.
- Correctness when the caret moves, the host changes text, the language switches, or an old asynchronous result arrives.

Initial proposed goals: warm suggestions below 50 ms at p95, input that never waits for prediction, and approximately 10–15 MB incremental memory for the dictionary baseline. These are targets to validate, not promises. Apple's [custom keyboard guidance](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard) describes device-dependent memory limits; there is no universal extension budget to assume. [Available process memory](https://developer.apple.com/documentation/os/os_proc_available_memory) is dynamic and advisory.

Run lookups off the main thread with bounded caches; discard stale results. Snapshot document identity, selection, and context, then revalidate before applying a tapped candidate. Multi-step proxy edits are not atomic. Abstain if the target is ambiguous, and unload optional context models first under memory pressure.

The next concrete experiment should be an offline corpus harness and physical-device dictionary prototype. Add context only if it improves held-out quality without making typing slower or the extension less reliable.
