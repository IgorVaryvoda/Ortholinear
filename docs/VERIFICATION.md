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
