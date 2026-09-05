# Before distribution

The simulator verifies layout and interaction. Signing and installation have also been verified on an iPhone 15 Pro; physical-device interaction and memory profiling remain separate checks.

- Run on a signed iPhone and iPad with the shared App Group enabled on both targets.
- Enable Ortholinear in Settings with no Full Access. Type Ukrainian, English, numbers, and punctuation in Notes, Safari, Messages, and the app's system test fields.
- Change presets, letter and control-row heights, letter size, Return/Delete width, Shift position, punctuation, apostrophe, header, spacing, gap-filling and starting language in the containing app. Dismiss and reopen the extension; verify every setting applies. Confirm settings survive terminating both processes.
- Exercise each usable edge and gutter; rapidly alternate two thumbs; slide from one key to another before release.
- Hold delete, slide away, release outside, switch apps, and rotate during the hold. Confirm repeating stops immediately.
- Double-tap shift; type several letters; unlock. Single shift should affect one letter, including Ukrainian ґ/ї/і/є.
- Hold punctuation and select each ribbon option; release outside to cancel.
- Swipe space in both directions in text containing emoji and Ukrainian; verify insertion at the resulting cursor. Test document boundaries and selections.
- Exercise numeric, email, URL, return-action, empty/disabled return, and multiline fields. Verify selection replacement and backspace across emoji.
- Verify native globe tap/hold where required, and the system-provided globe on Face ID devices. Switch away and back.
- Verify portrait, landscape, iPad docked and floating keyboards, light/dark appearance, and large accessibility text in the containing app.
- Use VoiceOver to type letters, select punctuation alternatives, switch language, and dismiss.
- Confirm iOS switches to its own keyboard for passwords and phone-pad fields.
- Profile extension memory with Instruments on the oldest supported device, including repeated show/hide and rotation. No fixed memory limit is assumed.
- Review identifiers, signing, display name, icon, privacy declarations, license, screenshots, and App Store metadata before uploading. No store upload is automated in this project.
