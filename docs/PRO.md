# Ortholinear Pro

Status: **proposed, not built.** Decisions recorded October 6, 2026. Implementation details are in [PRO-IMPLEMENTATION.md](PRO-IMPLEMENTATION.md).

## Decisions

- **Free stays the product.** Roughly 80% of customization is free, including a real Layout Workshop that changes the installed keyboard. Pro adds depth for people who want it; Free is never weakened to sell it.
- **Pro is for keyboard enthusiasts:** alternative-layout users, people who type a lot of symbols, programmers and writers. Ukrainian users are core to the free product but are not the expected buyers. App Store regional pricing handles local price levels; nothing in the app is priced per region.
- **One non-consumable unlock.** No subscription, no ads, no account, no Full Access. No free trial in v1 (see [Deferred: free trial](#deferred-free-trial)).
- **Pro source lives in a private package.** The public MIT repository keeps building the complete Free app. See [Licensing](#licensing).

## Free and Pro

| Capability | Free | Pro |
| --- | --- | --- |
| Everything the app does today: languages, layouts, sizes, themes, glide, suggestions, field memory | Yes | Yes |
| Layout Workshop: rearrange letters, put punctuation on the letter page, edit long-press characters | Yes | Yes |
| One custom letter layout per language, applied to the installed keyboard | Yes | Yes |
| Export and import a single letter layout file | Yes | Yes |
| Flicks on any key: swipe up, down, left or right for a symbol; one tap fills swipe-up with symbols | | Yes |
| Keycap colorways: eight sets plus a studio for keycap and legend colors, legend font and keycap shape | | Yes |
| Text expansions: shortcuts such as ;mail that become longer text; Delete right after undoes | | Yes |
| Custom layers: extra key pages with starters for Navigate, Writing, Math, Code and Phrases | | Yes |
| Navigation keys: move by word or line, delete words, pairs such as ( ) that leave the cursor inside | | Yes |
| Phrase keys: a labelled key that types a saved line of text | | Yes |
| Several saved setups, switched from the app | | Yes |
| Export and import a complete setup (layouts, layers and settings; phrases and expansions only if chosen) | | Yes |

Single-layout files are free on purpose: shared layouts are how a keyboard like this spreads, and someone who receives one should be able to use it without paying.

Later candidates, not part of the launch promise: split or thumb-zone geometry, and separate portrait/landscape layouts. Basic readability, key size and accessibility are never Pro.

Ruled out because they need Full Access, which the app never asks for: key sounds (custom mechanical sounds, and even the system click), haptics and clipboard history.

## Not obnoxious

- Never present Pro on its own: not on first launch, after an update, or after some number of uses.
- One **Ortholinear Pro** row in Settings. Pro features appear where they belong (for example, **Layers** under the Workshop) with a small Pro label. Tapping one opens the same short sheet; closing it returns to where the person was.
- Free features carry no badges, delays, watermarks or reduced versions.
- The keyboard extension has no commercial UI at all. Apple requires this anyway (App Review Guideline 4.4.1).
- Losing Pro, for example after a refund, never deletes anything. Saved layers and setups stay in the app; the installed keyboard keeps the Free part of the current setup.
- **Restore purchases** lives in the Pro row in Settings.

## Layout Workshop (Free)

Start from the current built-in layout for a language. A live test field sits above the editor and uses the same renderer as the extension. Select a key to change what it types and its long-press characters, or move it within or between the three letter rows. Movement works by drag and by explicit Move left/right/up/down actions for VoiceOver and Switch Control.

Constraints for v1:

- Three letter rows, up to 12 keys each. Letter keys in a row keep equal widths. Per-letter widths would break the grid the app is named after and would skew suggestion and glide distances.
- Delete, Shift, 123, the language key, Space and Return keep their positions. Digit flicks and the number row apply to the first row, whatever it contains.
- Every letter in the language's alphabet must stay reachable, directly or by holding a key. The editor shows what is missing and blocks Apply until it is fixed.
- Undo, **Revert to built-in**, and an explicit **Apply**. Editing never changes the installed keyboard until Apply.

Example: a Ukrainian user gives ґ its own key and puts ʼ next to ю. An English user puts `.` and `,` on the bottom row and moves `'` beside L.

## Layers (Pro)

A layer is a named extra page of keys, reached after the symbols page and, optionally, from a dedicated key in the control row. The ABC key always returns to letters in the current language. Starters:

| Starter | Contents |
| --- | --- |
| Writing | — … « » „ “ ” ‘ ’ and Markdown punctuation |
| Math | ≤ ≥ ≠ ≈ × ÷ ± √ ∞ π and common Greek letters |
| Code | ( ) [ ] { } < > \` \| \\ ~ ^ $ # and paired-quote keys |
| Phrases | Empty, ready for phrase keys |

A phrase key has a short label and types one line of text (up to 200 characters) when tapped. There are no macros, cursor actions, clipboard access, auto-send or app launching. Phrases can contain personal details, so exports show a preview and offer to leave them out.

## Saved setups (Pro)

A setup is a named snapshot of everything that shapes the keyboard: custom layouts, layers, sizes and appearance. Save, rename, duplicate, delete with confirmation, and switch in the app. Switching takes effect the next time the keyboard opens. Setup files are versioned data, validated on import. Invalid files change nothing. Files never contain purchase information, typed text or learned words.

## Purchase sheet

> **Ortholinear Pro**
>
> Layers for symbols, code and phrases. Saved setups you can switch between and share.
>
> **{localizedPrice}, once.** No subscription.
>
> **Unlock Pro**
>
> Restore purchases · Privacy

Show `Product.displayPrice`; never hard-code a price. While the product is loading or unavailable, show that state and keep the sheet closable. Cancelled, pending (Ask to Buy) and failed purchases return to the previous screen without unlocking anything or retrying automatically.

After purchase: **Pro unlocked. Thank you.** and return to the feature the person tapped.

## Price

One price point. Working hypothesis: between EUR 4.99 and 9.99, decided before the product is created in App Store Connect.

Family Sharing: recommended **on**, as it suits the generous positioning. Apple does not let you turn it off again for a product once it is on, so this needs a deliberate decision.

## Measuring

No analytics SDK is needed. App Store Connect reports downloads (App Analytics) and units sold of the Pro product. Those two numbers per version are the conversion rate. Ratings, reviews and support email show whether the Pro boundary feels fair.

## Licensing

- Public, MIT: the Free app and the keyboard engine, including rendering and validating custom layouts and layers. The extension has to render any setup the app publishes, so this code is public.
- Private: the layer editor, phrase keys, saved setups, setup import/export, the purchase sheet and StoreKit.

Code already published under MIT stays MIT. Someone can still fork the engine and build their own editors; the private package means they have to rebuild the editors instead of flipping a flag. It is a speed bump, not DRM, and the plan does not try to be more than that.

## Deferred: free trial

v1 has no trial. The Free Workshop already lets people try the main idea, a keyboard laid out the way they want, in real apps. Layers can be explored in the in-app test field before buying, and Apple handles refund requests.

If reviews or support email show that people won't buy without trying, the App Review Guideline 3.1.1 route is a zero-price non-consumable named "7-day Trial". It would add: a second product, a time window derived from the original trial transaction, an expiry check in the extension, and trial status screens. The September 2026 draft of this proposal specifies that design in detail; it is in this branch's history.

## Sources

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), 3.1.1 (in-app purchase and non-subscription trials) and 4.4.1 (keyboard extensions).
- [Configuring open access for a custom keyboard](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard).
- [StoreKit `Transaction`](https://developer.apple.com/documentation/storekit/transaction) and [`AppStore.sync()`](https://developer.apple.com/documentation/storekit/appstore/sync()).
- [Family Sharing for in-app purchases](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/turn-on-family-sharing-for-in-app-purchases).
