# V0.4.0 verification — September 23, 2026

Version 0.4.0 (19) adds Polish, German, French, Spanish, Czech, Slovak, Latinica, Serbian Cyrillic, Swedish, Norwegian, Danish, Dutch, and gated Russian layouts, English Colemak/Colemak-DH/Dvorak/Workman variants, per-field-kind language memory, and the tap-only suggestions described in [suggestion verification and benchmarks](SUGGESTIONS-VERIFICATION.md). Build 18 put Languages and layouts first in Keyboard settings; build 19 adds the later layouts and replaces both.

- All 41 core tests pass (`swift test`), including the Russian gate and ґ held on г in Ukrainian only, covering each language's full alphabet with held alternatives, every English variant, the enabled-language cycle, tolerant settings decoding, ẞ for shifted ß, and language memory resolution, persistence, and Forget.
- Installed-extension tests pass on a disposable iPhone 17 Pro simulator (iOS 26.5): `testInstalledExtensionTypesInHostField` and `testInstalledKeyboardRemembersLanguagePerKindOfField`. The second covers email starting in English, no English leak into the editor, each field kind keeping its chosen language, and reopening the dismissed keyboard. A one-off check showed the editor's English and the email field's Ukrainian surviving a full simulator shutdown.
- Probing the installed extension showed iOS gives it no app, window, or chat identity: one keyboard process serves every host app, `documentIdentifier` changes on every focus, the text proxy does not implement `conversationContext`, and `conversationContext(_:didChange:)` is never delivered, even when the host calls it. Memory is therefore keyed by field kind (keyboard type, return key, content type). Autocapitalization is excluded because it changes while a field resigns.
- All 14 in-app UI tests pass, including the Languages and layouts test and the Russian question (Yes hides Russian; No unlocks it and holding е types ё). Two tests that already failed before this release are fixed. `testPunctuationHoldAndCapsLock` dragged to the first key row, but the suggestion row moved the keys below the 38 pt alternatives strip; it now aims at the top of the keyboard. `testCustomizationPersistsAndMakesRoomForLetters` tapped toggles without scrolling them into view. With Languages first, the presets start below the fold, so settings tests scroll to each preset and the scroll helper tries the other direction halfway.
- Signed Release archive succeeds at `build/release-040-19/Ortholinear.xcarchive` with the App Group entitlement on both targets and `RequestsOpenAccess` false. The archived app installed on the paired iPhone 15 Pro, which reports 0.4.0 (19); build 18 also launched there.

# V0.3.2 verification — September 8, 2026

Version 0.3.2 (16) adds optional ї on long-press і, accelerating held Delete, a persistent settings preview, keyboard themes and accents, and organized settings with a prominent Theme and colors entry.

- All 22 core tests pass (`keyboard-032-core-release.log`), including optional-letter layout and migration, capped delete acceleration, appearance persistence, and normal/pressed text and hint contrast across every theme and accent.
- Ten preview scenarios pass in `Keyboard-032-isolated-preview.xcresult`, including Ukrainian long-press case handling and cancellation, deletion acceleration and cancellation, live spacing preview, landscape, and existing typing interactions.
- Final settings checks pass in `Keyboard-organized-settings.xcresult`: themes are visible on opening Settings, all six explicit themes render, accent and hint preferences persist after relaunch, presets and setup work, and spacing changes update a stationary preview in portrait and landscape. Theme appearance screenshots are retained in the result bundle.
- Installed-extension testing exposed a language-update feedback loop after held Delete. Sampling showed repeated host/extension text-state synchronization. The controller now tracks the last reported language and sets primaryLanguage only when that language changes, avoiding asynchronous proxy echoes, and the renderer skips unchanged state refreshes. The final installed-extension run passes in `Keyboard-032-language-loop-fix-v3.xcresult`, including shared theme/height, language switching, uppercase alternatives, symbol slides, deletion to empty, subsequent typing, and host dismissal. Final renderer typing and symbol-slide regressions also pass in `Keyboard-032-final-renderer.xcresult`.
- Signed Release archive succeeds at `build/keyboard-032-release16/Ortholinear.xcarchive`; app and extension both report 0.3.2 (16). The archived app installed successfully on the paired iPhone 15 Pro, recorded in `build/keyboard-032-release16-install.json`. The final build subsequently launched successfully, recorded in `build/keyboard-032-release16-launch.log`.
- App Store description now explicitly describes bigger fingers and generous touch targets. Distribution status is recorded in [APP-STORE.md](APP-STORE.md).

Environment: Xcode 26.6, iOS 26.5, dedicated iPhone 17 Pro simulators for preview and installed-extension checks. Build artifacts and result bundles are local and ignored by Git. Physical-device typing, iPad floating-keyboard behavior, and memory profiling remain manual checks.

# V0.3.1 verification — September 6, 2026

Version 0.3.1 (10) adds stable key feedback, a far-left 123 / ABC switch, and hold/slide symbol entry that returns to letters.

- All 17 core tests pass, including page-switch placement across languages, pages, Shift placements, and globe configurations.
- All seven preview scenarios pass across `Keyboard-preview-release.xcresult` and `Keyboard-customization-release-v2.xcresult`. This includes long holds, quick slides, cancellation outside the keyboard, latched number entry, settings persistence, landscape, delete repeat, cursor movement, punctuation holds, and caps lock. The settings test now targets the switch thumb consistently when SwiftUI exposes either the row or the switch as its accessibility frame.
- `Keyboard-system-interactions-v3.xcresult` passes the installed-extension test, including shared settings, Ukrainian/English typing, г/ґ/Ґ holds, far-left page switching, symbol selection, and return to letter typing. Its settings assertion compares against the actual saved preview size because XCUITest's slider can stop short of its requested endpoint.
- Signed Release archive succeeds at `build/keyboard-interactions-app-store/Ortholinear.xcarchive`. App and extension both report 0.3.1 (10), and `RequestsOpenAccess=false` remains in the extension.
- Physical-device installation and App Store submission are tracked in [APP-STORE.md](APP-STORE.md). The paired iPhone 15 Pro reports 0.3.1 (10) installed. Remote launch was declined because the phone was locked. The App Store upload succeeds, and 0.3.1 (10) is Waiting for Review with automatic release after approval.

Environment: Xcode 26.6, iOS 26.5 simulator, iPhone 17 Pro. Results and signed artifacts are local and ignored by Git.

# V0.3 verification — September 5, 2026

Version 0.3.0 (9) puts Delete immediately after M / Ю, removes the Ukrainian letter-page apostrophe, and adds configurable punctuation spacing.

- 16 core tests pass, including punctuation clusters, Ukrainian/English spacing, explicit Space, decimals, times, newlines, disabled spacing, and unrelated cursor context.
- All six preview UI scenarios pass across `Final-keyboard-preview.xcresult` and `Final-keyboard-spacing.xcresult`. The first run exposed a settings layout issue that put the key-height slider offscreen; moving the Typing section below geometry fixed it, and both affected tests passed on rerun.
- The installed-extension integration passes in `Final-keyboard-system.xcresult`: Ukrainian and English insertion/deletion, enlarged keys, Shift placement, Delete placement, no Ukrainian apostrophe, and г/ґ/Ґ long press.
- Signed Release archive and App Store upload succeed; version 0.3.0 (9) is Waiting for Review. The archived app installs on the paired iPhone 15 Pro, iOS 26.5. Its final punctuation behavior has not been exercised by an automated physical-device typing test.
- Final product privacy manifest declares no collected data; `RequestsOpenAccess=false`.

Environment: Xcode 26.6, Swift 6.3.3, iOS 26.5 simulator, iPhone 17 Pro. Results and signed artifacts remain in ignored build directories. Distribution status is tracked in [APP-STORE.md](APP-STORE.md).

Memory profiling and iPad floating-keyboard behavior remain manual checks listed in [DEVICE-CHECKS.md](DEVICE-CHECKS.md).
