# Ortholinear Pro: product and trial plan

Status: **proposed, not shipped**. Updated September 26, 2026. This is a product/design specification, not a StoreKit implementation or an App Store configuration change.

## Read this proposal

- [Upgrade flow and screen copy](PRO-UPGRADE-FLOW.md)
- [Implementation plan, platform risks, and acceptance tests](PRO-IMPLEMENTATION.md)
- [Interactive upgrade-flow prototype](pro-upgrade-prototype.html): download/open this HTML file in a browser, or serve the repository locally. It has no dependencies, network requests, or real purchases. GitHub's source viewer does not run it.

## Decision

Keep today's keyboard free. Sell **Ortholinear Pro**, a keyboard-building toolkit: Layout Workshop, custom layers, and saved/shareable profiles. Offer every eligible user an **explicitly started seven-day trial of all released Pro features**, followed by an optional **one-time purchase**. No subscription, automatic charge, account registration, or Full Access requirement.

The initial pricing hypothesis is **EUR 9.99 once**, subject to approval and App Store price-point configuration. The production interface must display StoreKit's localized price; it must never hard-code EUR 9.99 or imply a recurring charge. There is one paid edition, not separate feature packs. Advanced thumb/split arrangements are a later candidate, not something to advertise as available at launch.

Positioning: **Put every key where you want it.** The reason to buy is control over the keyboard, not the removal of annoyances deliberately added to Free.

## Existing Free baseline

The current [README](../README.md), [app](../App/ContentView.swift), and [preferences store](../SharedUI/PreferenceStore.swift) document an already functional keyboard with size/spacing controls, themes, languages, alternative English layouts, English/Ukrainian glide typing, suggestions, and local configuration sharing. Those existing capabilities stay free. Do not retroactively put current users' settings behind a purchase.

| Capability | Free | Seven-day trial | Purchased Pro |
| --- | --- | --- | --- |
| Existing keyboard, built-in languages/layouts, typing and accessibility | Yes | Yes | Yes |
| Existing size, spacing, appearance and typing settings | Yes | Yes | Yes |
| Unsaved in-app demonstration of Workshop | Yes | Yes | Yes |
| Create/edit/apply custom key arrangements | No | Yes | Yes |
| Create/edit/use custom symbol and phrase layers | No | Yes | Yes |
| Save, duplicate, import and switch custom profiles | No | Yes | Yes |
| Inspect/delete/export previously created personal configurations | Yes | Yes | Yes |
| Private typing without Full Access | Yes | Yes | Yes |

Exporting one's existing work remains free after expiry; importing or activating a Pro configuration requires access. The unsaved demonstration never modifies the installed keyboard or saves an activatable profile without access. Keeping a saved configuration is not the same as keeping permission to activate it.

## Launch bundle

### 1. Layout Workshop

Start by duplicating a built-in layout. Keep a live test surface above an inspector. Select a key, change its output or long-press alternatives, move it within/between supported rows, or adjust its relative width. Offer direct controls and accessible move actions as well as drag-and-drop.

Example: a Ukrainian user makes ґ a separate key, puts ї on long-press і, and moves an apostrophe beside Space. An English user places frequently used punctuation on the main page.

V1 is a constrained grid editor, not a freeform graphics canvas. Support custom character placement, row membership, per-key width, and long-press characters. Do not introduce arbitrary scripts, app launch actions, or firmware-style configuration. Geometry must be validated at supported widths; required navigation and typing controls cannot become unreachable. Provide Undo, Revert to base layout, and an explicit Apply action. Saving a draft must not silently replace the installed keyboard.

The new layout must be used by touch mapping, nearby-key suggestion ranking and glide decoding, not only rendering. A visually correct layout with stale input coordinates is a release blocker. Language support and missing required characters must be surfaced during validation; do not silently remove a language's reachable alphabet.

**Acceptance:** a person can modify a built-in layout, test it, save it, apply it, and recover their previous configuration without editing JSON.

### 2. Custom layers

Let people create named extra pages of keys. Supply editable starting points for Writing, Math, Symbols and Phrases; all belong to the same Pro purchase.

| Starter | Examples | Benefit |
| --- | --- | --- |
| Writing | —, …, « », quotation marks and Markdown punctuation | Familiar punctuation in predictable positions |
| Math | ≤, ≥, ≠, ×, ÷, π and Greek letters | Direct access to notation |
| Symbols | Brackets, braces, backticks, slash, backslash and pipe | Less hunting through symbol pages |
| Phrases | A labelled email-address key or a recurring short reply | Intentional reusable text, not typing-history capture |

V1 actions are literal text insertion and navigation between the keyboard's own layers. Phrase keys insert only after a deliberate tap. Start with single-line phrases; multiline snippets, cursor macros, clipboard integrations and dynamic template variables require separate design and host-field testing. No action may secretly submit a form, open an app or transmit text.

Layer entry must coexist with today's 123 hold/slide, digit flicks and glide typing. Prefer a dedicated optional layer control over stealing established gestures. Always retain a reliable way back to letters. Avoid promising that this makes the keyboard a universal terminal keyboard: host apps decide how input is interpreted.

**Acceptance:** create a Writing layer, add a custom symbol and a labelled phrase, reach them while typing, and return to letters without changing the current language.

### 3. Saved and shareable profiles

A profile combines a base language/layout, custom key definitions, layers and relevant geometry overrides. Names such as Everyday and Writing are user-chosen, not separate editions.

Support save, duplicate, rename, delete with confirmation, import/export a versioned data file, and deliberate profile selection. Exports contain only the configuration the person selected, never purchase evidence, trial dates, typed text, learned words or telemetry. Phrase keys may contain personal information: show an export preview/warning and offer to omit phrases before sharing. A file picker may use a user's cloud provider; do not describe user-initiated export as guaranteed to stay on the device.

Imported files are data, not executable code. Validate schema, sizes, identifiers, output lengths, required keys, geometry and supported actions before accepting them. Invalid imports leave existing settings untouched. Importing somebody else's profile never imports their entitlement.

Manual switching in the extension may persist a chosen profile ID in the extension's own container; profile definitions are written only by the containing app. Do not promise that this local choice automatically syncs back into the app. The app's explicit Apply action publishes a new selection generation that takes precedence on the next keyboard presentation.

**Acceptance:** export a profile, import it on another eligible device, review its contents, apply it, and recover cleanly from malformed or unsupported files.

## Later, not part of the initial sales promise

Advanced thumb arrangements could add split key groups, an adjustable centre gap, constrained left/right placement and separate portrait/landscape geometry. Prototype and test real typing comfort first. Basic readability, large-key settings and current accessibility are not premium upsells.

Do not promise automatic app/chat-specific profiles. The current [language-memory documentation](../README.md#languages-layouts-and-field-memory) explains the distinction between remembering a field kind and identifying an app or conversation. Do not build a community marketplace, cloud accounts, subscription, AI writing service or new language paywall merely to enlarge the Pro checklist.

## Trial contract

| Question | Product rule |
| --- | --- |
| When does it begin? | After the user chooses Start 7-day free trial and the zero-price StoreKit transaction is successfully verified. Never on download, update, opening Settings, previewing, or keyboard activation. |
| How long? | 168 elapsed hours from the original verified trial transaction timestamp. Store an absolute expiry; use localized date/time only for display. No reset at midnight or on timezone changes. |
| What is included? | The same released capabilities as purchased Pro. No reduced save limits or watered-down demo during the trial. |
| Is there an automatic charge? | No. A separate, explicit one-time purchase is required. There is no cancellation task and no recurring product. |
| Can the user skip it? | Yes. Continue with Free is always available; buying directly is also an option, not the default. |
| Can it be restarted? | Not by reinstalling, restoring purchases, upgrading the app or moving to another device using the same purchase account. Use the original transaction, not a local installation date. No promise of perfect anti-abuse across different Apple Accounts or modified binaries. |
| Does starting require internet? | Expect an App Store connection and possible Apple authentication. Say No charge, not No Apple sign-in needed. Existing validated access works offline within its time bounds. |
| What happens to work at expiry? | Drafts/profiles/layers remain locally stored, inspectable, deletable and exportable. Pro editing, importing and new activation stop. |
| What happens while typing? | Do not replace keys or interrupt a touch/word mid-presentation. On the next keyboard presentation after expiry, use the user's latest valid Free configuration. No upgrade advertising in the extension. |
| What happens after payment? | Unlock editing and activation, retain all work, and offer Apply saved keyboard. Do not silently activate an old profile over newer Free choices. |

Keep the latest **Free baseline** separately from Pro overrides. Free settings changed during the trial must survive its end. Expiry is not permission to reset everything to factory defaults.

Seven days is the entitlement window. Finishing an already-open keyboard presentation is a deliberate continuity exception, not a new trial. New premium edit/apply/import actions in the containing app are checked against the actual expiry and blocked immediately. An in-flight gesture or text insertion is allowed to complete without corrupting the host text.

## Upgrade experience principles

Let people enable and use the normal keyboard first. Place Pro discovery below the primary setup/test-drive actions and inside Settings. A person can explore an unsaved Workshop example before starting the timer. Ask at a meaningful boundary, such as Apply custom keyboard, and return them to that exact task after activation.

Show the duration, optional one-time price, lack of auto-charge, and expiry consequences before starting the trial. During the trial, use a quiet status row in the app with the exact ending date, not repeated modals. Do not send push notifications or email reminders in V1. After expiry, preserve work and provide both Buy Pro and Continue with Free. Restore purchases is available on every commercial screen and in Settings.

All commercial UI belongs to the containing app. Apple prohibits marketing and purchases in extensions, and keyboard extensions cannot launch other apps besides Settings. Do not add an Upgrade key or an Open Ortholinear deep-link workaround. [S1]

## Delivery and validation

Implementation sequence: (1) platform/billing feasibility spike, (2) entitlement and settings foundations, (3) Workshop, (4) layers/profiles, (5) purchase/trial UX, (6) real-device, sandbox and review verification. Shipping switches stay off until the advertised Pro features actually exist and both products work in sandbox.

Use voluntary testers to validate two outcomes: they can understand the trial without fearing a surprise charge, and they can still recover their work after expiry. V1 adds no analytics SDK, keyboard activity collection or developer backend. App-side debug diagnostics may record synthetic state transitions without personal text and remain local. Aggregate commercial performance must not be presented as a tracked install-to-trial funnel unless measurement actually supports it.

The implementation plan includes purchase errors, pending approval, restore, refunds, offline use, clock changes, migration and Full Access-off tests. Price and App Store product configuration remain release-owner tasks; this documentation does not create products or authorize a production release.

## Sources and scope of certainty

Repository baseline reviewed at commit `084be310671f366540fec1d23711ccc6d2643c34`. Features above are proposals; demand, conversion and pricing are hypotheses, not established measurements.

- **S1:** [Apple App Review Guidelines, 3.1.1 and 4.4–4.4.1](https://developer.apple.com/app-store/review/guidelines/) (checked September 26, 2026). Apple describes zero-price non-consumable trials for non-subscription apps and requires clear disclosures. Guideline compliance still requires implementation and review; this is not a promise of approval.
- **S2:** [Apple: configuring open access for a custom keyboard](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard). Documents read-only shared-container access without Full Access and restrictions on purchase participation. The feasibility spike must address both the technical path and these restrictions before monetization ships.
- **S3:** [Apple: Transaction](https://developer.apple.com/documentation/storekit/transaction). StoreKit transaction verification, current entitlements, history, updates and delivery/finishing responsibilities.
