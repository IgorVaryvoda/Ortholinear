# V0.2.1 verification — September 5, 2026

The ґ update passed all 13 core tests, the two affected preview tests (typing/Shift and landscape), and the system-extension integration test. The latter verifies tap г, hold г → ґ, Shift + hold Г → Ґ, and subsequent lowercase input. The separate ґ key is absent in all presets; remaining second-row letters expand. Version 0.2.1 (3) was signed and successfully installed on Igor’s iPhone 15 Pro. Results are retained in `build/G-long-press.xcresult`; the Ukrainian screenshot below reflects this update.

The full V0.2 baseline results follow; unaffected preview tests were not rerun for this small change.

Environment: Xcode 26.6, Swift 6.3.3, iOS 26.5 simulator, iPhone 17 Pro.

| Check | Result |
| --- | --- |
| Swift Package core tests | 13 passed |
| Preview XCUITests | 6 passed |
| Installed extension integration | 1 passed |
| iOS simulator build with ad-hoc signing | Passed |
| Signed iPhone Release build | Passed |
| Installation on iPhone 15 Pro | Passed, version 0.2.0 (2) |

The integration test enabled the extension through Settings and entered Ukrainian and English text through `textDocumentProxy`. It verified deletion and that an 88 pt key-height setting saved by the containing app produced 91 pt touch rows (88 pt key + 3 pt row spacing) in the extension, with a separate 59 pt control touch row. It also verified absent period/comma keys, wider bottom-row letters, substantial Return/Delete widths, and Shift immediately before Я on the same row. `RequestsOpenAccess` remained false.

Preview tests additionally verified Shift immediately before Я, customization persistence after relaunch, optional punctuation/apostrophe, and restoring the Big letters preset. Core tests cover Shift before both Я and Z, preference migration, presets, action widths, and geometry across supported width samples. Captured extension screenshots were visually inspected in both languages; they show the test's maximum 88 pt letter height, rather than the 72 pt default.

Two production issues found during validation were corrected: premature document-proxy access at extension startup, and virtual accessibility-element coordinate conversion across the remote view-service boundary. Native accessibility views now expose the keys, while the keyboard's single touch router continues to own physical touches. The preview's touch surface is a UIControl so the surrounding scroll view doesn't cancel punctuation selection.

Screenshots are in [screenshots](screenshots). Local Xcode result bundles are retained in the ignored `build` directory:

- `Customization-final.xcresult`
- `Customization-system-final.xcresult`

The updated app and embedded extension were signed with the configured development team and successfully installed on Igor’s iPhone 15 Pro running iOS 26.5. Physical-device typing is not yet verified.

Memory profiling, iPad floating keyboard behavior, and distribution checks remain on the [device checklist](DEVICE-CHECKS.md). No App Store upload was performed.
