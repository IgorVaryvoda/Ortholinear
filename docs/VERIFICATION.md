# V0.3 verification — September 5, 2026

Version 0.3.0 (9) puts Delete immediately after M / Ю, removes the Ukrainian letter-page apostrophe, and adds configurable punctuation spacing.

- 16 core tests pass, including punctuation clusters, Ukrainian/English spacing, explicit Space, decimals, times, newlines, disabled spacing, and unrelated cursor context.
- All six preview UI scenarios pass across `Final-keyboard-preview.xcresult` and `Final-keyboard-spacing.xcresult`. The first run exposed a settings layout issue that put the key-height slider offscreen; moving the Typing section below geometry fixed it, and both affected tests passed on rerun.
- The installed-extension integration passes in `Final-keyboard-system.xcresult`: Ukrainian and English insertion/deletion, enlarged keys, Shift placement, Delete placement, no Ukrainian apostrophe, and г/ґ/Ґ long press.
- Signed Release archive succeeds and the archived app installs on the paired iPhone 15 Pro, iOS 26.5. Its final punctuation behavior has not been exercised by an automated physical-device typing test.
- Final product privacy manifest declares no collected data; `RequestsOpenAccess=false`.

Environment: Xcode 26.6, Swift 6.3.3, iOS 26.5 simulator, iPhone 17 Pro. Results and signed artifacts remain in ignored build directories. Distribution status is tracked in [APP-STORE.md](APP-STORE.md).

Memory profiling and iPad floating-keyboard behavior remain manual checks listed in [DEVICE-CHECKS.md](DEVICE-CHECKS.md).
