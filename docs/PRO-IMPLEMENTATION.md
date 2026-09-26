# Pro implementation and verification plan

Status: proposed implementation, not production code. Read [product decisions](PRO.md) and [screen design](PRO-UPGRADE-FLOW.md) first. The HTML prototype is a design aid only.

## 1. Platform feasibility gate before feature work

Build a minimal native spike that verifies these requirements on real iPhone/iPad hardware with **Full Access off**:

1. A containing-app-only StoreKit flow acquires/restores a zero-price non-consumable trial and a paid non-consumable unlock.
2. The containing app writes configuration into the existing App Group; the extension reads and uses that configuration without network or StoreKit calls.
3. The extension can fall back from an expired trial configuration at its next presentation without launching the app, writing to the shared container, or showing commercial UI.
4. Restoring the same trial product yields its original start date, including after reinstall and on another device. Test original-date semantics, not just the happy-path purchase result.

**Policy risk, not a solved assumption:** Apple's current sandbox documentation both permits read-only shared configuration without Full Access and describes restrictions on direct/indirect participation in purchases. Keep commerce wholly in the containing app, document the configuration-consumer architecture in review notes, and resolve review questions before launch. An on-device technical success is not approval. Do not silently turn on `RequestsOpenAccess` to bypass a problem. [S1][S2]

## 2. Product configuration

Configure two products in App Store Connect; the identifiers below are logical placeholders, not claimed registered IDs:

| Logical product | Type | Display / price | Meaning |
| --- | --- | --- | --- |
| `pro.trial.7days` | Non-consumable | `7-day Trial`, zero price | One recorded acquisition starts 168 hours of Pro access. |
| `pro.unlock` | Non-consumable | Ortholinear Pro, approved localized price | A one-time purchase with no subscription expiry. |

Guideline 3.1.1 describes a zero-price non-consumable trial with the XX-day Trial naming pattern. Confirm the exact product naming/localisation, price-point availability and store metadata in App Store Connect before implementation release. Do not implement this as an auto-renewable subscription introductory offer or as a seven-day non-renewing subscription. [S1][S4]

Trial access is an **application-derived time window**. The trial product itself remains a non-consumable purchase; simply finding it in current entitlements does not mean the trial is still active. Never use a subscription-renewal flag or assume StoreKit will expire the free trial product for us.

Use one stable trial product identifier across releases. Resetting settings, changing version or restoring purchases must never reissue a trial. Paid access takes priority over any trial. Configure Family Sharing off for V1 for both products; reconsider explicitly after eligibility/revocation testing. Do not advertise family access by implication.

Use `Product.displayPrice` for UI and load both products before enabling the trial CTA, since the optional subsequent price must be disclosed. Neither price nor product existence is established by this PR. No product should be offered while the features it advertises are incomplete.

## 3. Access reducer and StoreKit ownership

Keep billing operations separate from access. A loading spinner or failed price request cannot overwrite purchased access.

Proposed core model:

```text
Access = checking(previousKnownAccess?)
       | freeEligible
       | trialActive(originalStart, expiresAt)
       | trialEnded(originalStart, expiresAt)
       | purchased
       | freeAfterRevocation

Operation = idle | loadingProducts | startingTrial | buying
          | restoring | pendingApproval | publicationError | recoverableError
```

`checking` does not grant a new entitlement or pretend the user has no purchase. Retain previously verified access while reconciliation is unavailable, still enforcing any known trial deadline. With no usable evidence, the keyboard remains functional in Free and the app offers checking/retry/restore.

Proposed app-only StoreKit service responsibilities:

- Observe transaction updates from startup and reconcile current entitlements when the app becomes active; inspect verified history as needed to distinguish a spent trial from never acquired.
- Accept only verified transactions for the exact configured products and environment. A debug/sandbox override cannot leak into a release build.
- Preserve the original trial acquisition timestamp from the verified transaction. Define `expiresAt = originalStart + 604800 seconds`. Validate original-date behaviour in the spike. Never use today's date on restore or a preference reset.
- Check revocation/refund information and reconcile removed entitlements. An empty or failed network/product request alone is not proof of revocation.
- Idempotently persist verified access, publish the current configuration/access snapshot, and finish delivered transactions. Process unfinished transactions on relaunch. A failed shared-container write must be retried without repurchasing or forgetting verified ownership. [S3]
- Handle cancelled, pending, unverified and failed results as distinct outcomes. Pending approval is not activation and is not a reason to start a local timer.
- Invoke `AppStore.sync()` for an explicit Restore purchases action, not every launch; the API can prompt for authentication. Normal access reconciliation uses StoreKit's transaction information. [S5]

Access precedence: a verified non-revoked paid purchase wins. Otherwise use a genuine non-revoked original trial only while its original time remains. Once spent, it remains spent. Revoking a paid unlock never creates a new trial; if a genuine older trial has time left it may supply only that remaining time. Surface refund/revocation accurately rather than labelling it Trial ended when no trial existed.

Purchase restoration and configuration restoration are different: Apple can restore entitlement; it does not restore local profiles we never synced. State that reinstall may remove personal configurations and recommend deliberate export, not an invented cloud backup.

## 4. App Group and extension boundary

The current [PreferenceStore](../SharedUI/PreferenceStore.swift) atomically writes `geometry.json` from the app and reads it from both targets. The [app](../App/ContentView.swift) already reports sharing errors. Extend this design without turning entitlement checks into per-keystroke work.

Propose a single atomically published, versioned runtime bundle containing:

```text
schemaVersion
configurationGeneration
freeBaseline
customProfileDefinitions
appSelectedProfileID
selectionGeneration
accessKind: free | trial | purchased
trialExpiresAt: absolute timestamp or null
```

Keep StoreKit/JWS evidence, transaction IDs and purchase diagnostics in the containing app's private storage; do not export or make the keyboard process payment evidence. The runtime bundle is a derived cache from the trusted containing app, **not** a self-verifying receipt. A JSON flag is not an anti-piracy boundary against a modified binary.

Store the latest Free preferences independently of premium overrides. Migration from the existing format creates a Free baseline identical to the user's current settings. Loading an old or malformed bundle must fall back to validated existing Free settings, never grant Pro or erase work. Use an atomic whole-bundle replacement so access and profile generations cannot mismatch. If publication fails, retain the previous coherent bundle and the newly purchased entitlement in the app; expose Retry sharing.

Extension behaviour:

- Read/validate a snapshot on presentation. Resolve access and a usable layout before accepting input; retain it for that presentation.
- With an active trial, compare against the absolute deadline locally. If expired before presentation, select Free even when the containing app has not run recently.
- Do not change layout geometry, delete-repeat state or active gestures at the expiry instant. The existing presentation may finish normally; the next uses Free. App-side premium edits and Apply are not granted this grace.
- Snapshot refresh is bounded and outside the per-touch hot path. Never make network requests, invoke StoreKit, open a commercial sheet or launch the containing app.
- Any manual profile choice is stored only in the extension's private container. An app-side Apply increments selectionGeneration to supersede it. Do not pretend the extension can write this selection back into the shared group without Full Access. [S2]
- Missing/unreadable access data yields a working Free layout, not a keyboard lock screen. Already loaded coherent state may finish its presentation.

Purchased access should not need an arbitrary online heartbeat. Refresh revocation/account information when the containing app can reconcile it. Without a backend and extension networking, instant offline refund revocation cannot be guaranteed; accept that boundary rather than breaking offline typing or demanding Full Access.

## 5. Timekeeping and anti-abuse

Store trial times as absolute instants and compare elapsed seconds. DST/timezone changes affect labels, not the duration. Inject a clock into the reducer and tests. Use monotonic elapsed time within a running process to avoid backwards jumps extending that session; retain the original signed start across restores.

A private offline app cannot perfectly enforce wall-clock honesty across reboots, device-clock manipulation, account changes or modified source. Do not promise otherwise. Avoid a permanent lockout triggered by an accidental forward clock jump; support retry/reconciliation and explain clock inconsistencies in the app without accusing the user. Do not add a fingerprinting backend, hidden account or invasive telemetry for a EUR 9.99 utility. A more sophisticated trusted-time design would need a separate privacy/product decision.

## 6. Draft safety, profiles and layout correctness

Separate `FreeBaseline`, `CustomProfile`, `Draft` and `Access`; do not flatten premium keys destructively into the only copy of the user's free preferences. Gate premium mutations in the domain/service layer and the renderer's resolved capability input, not solely by hiding buttons. Import/export never mutates billing state.

Before expiry blocks editing, persist the in-progress draft. Retain saved definitions after expiry/refund and allow inspection, deletion and privacy-reviewed export. Apply after purchase is explicit. Export defaults to omitting entitlement metadata and offers omission of personal phrase keys; imports accept an allowlisted data schema, never executable actions.

Update geometry, hit testing, long-press output, glide coordinates and correction ranking together. Require reachable control keys and alphabet outputs, non-overlapping cells, validated dimensions, stable layer switching and test coverage across the existing 320–1024 pt geometry range. Preserve the current 123 quick-symbol slide, digit flick, globe, deletion, shift and cursor behaviours.

Do not use host-app identity heuristics for automatic commercial/profile targeting. Field traits and orientation can be used only within documented, tested capability limits. V1 does not include macros, scripts, auto-paste history or cross-app commands.

## 7. Proposed code integration map

These are intended new components, not existing files or commitments to exact type names.

| Area | Proposed work |
| --- | --- |
| `Core/` | Pure access reducer/clock abstraction, versioned profile/layer schema, capability resolution, validation and migration. Keep StoreKit out of the Swift Package core. |
| `App/` | StoreKit coordinator, purchase/restore state, Workshop, layers/profiles, offer/status screens and non-sensitive return intents. |
| `App/ContentView.swift` | Optional entry/status card below setup, preserve initial Free experience and existing save-error behaviour. |
| `SharedUI/PreferenceStore.swift` | Versioned atomic runtime publication plus migration from geometry.json; Free fallback and explicit error propagation. |
| `SharedUI/KeyboardView.swift` and core geometry | Render custom layouts/layers from resolved, validated profiles; keep hit mapping and gesture behaviour aligned. |
| `KeyboardExtension/` | Resolve access at presentation boundaries, own-container selection persistence, stable in-flight keyboard operation. |
| `Tests/` | Pure clock/reducer/schema/migration/geometry/expiry tests. |
| `UITests/` | Offer, dismiss, intent return, pending/failure, draft survival, accessibility and pricing states using injected billing fixtures. |
| `IntegrationTests/` | Real extension reads/access expiry/Free fallback with Full Access disabled. |
| Project and release docs | Target membership, StoreKit test configuration, localized strings, privacy/metadata and reviewer instructions. |

## 8. Implementation phases

1. **Spike:** prove zero-price restore/original dates, non-networked extension configuration and expiry. Document policy/review uncertainties. Stop before monetization launch if Full Access-off cannot be preserved.
2. **Foundation:** access reducer, StoreKit service with mock provider, atomic bundle/migration and baseline retention. No visible purchase offer yet.
3. **Workshop:** constrained editor, preview, safe Apply and geometry/suggestion/glide parity.
4. **Layers/profiles:** create and switch layers, private phrase keys, validated import/export, saved drafts and expiry recovery.
5. **Commercial UX:** exact trial/one-time copy, eligibility-aware entry, localized pricing, return intent, restore and all error states. Offer only implemented features.
6. **Release gate:** sandbox + actual iPhone/iPad + accessibility/regression tests, product/review metadata, transparent privacy updates and deliberate release approval.

No separate trial-experiment SDK or backend is part of this plan. Use StoreKit testing and voluntary usability studies, not instrumentation of typed text. A development-only state picker may simulate outcomes; it must be impossible to enable from the release UI.

## 9. Acceptance matrix

| Test | Expected result |
| --- | --- |
| Fresh install, no trial | All existing Free functionality works; no auto-presented paywall or ticking trial. |
| Dismiss from draft-triggered offer | Exact draft and source screen survive; nothing purchased or applied. |
| Trial transaction succeeds | Original start recorded once; expiry exactly +604800 s; full released Pro available. |
| Trial purchase cancelled/failed/unverified | No local trial begins; prior access/work unchanged. |
| Trial or paid purchase pending | Waiting state; no new entitlement, no duplicate automatic attempt. |
| Restore active trial, same/second device | Original deadline, only remaining time; no new seven days. |
| Restore ended trial/reinstall/reset preferences | Spent trial stays spent; Free remains usable. |
| Paid purchase during trial | Paid access wins immediately; no later trial-expiry downgrade. |
| Purchase interrupted by app termination | Verified transaction is recovered/delivered idempotently on relaunch. |
| Verify paid purchase, fail shared write | Purchased state retained; Retry sharing, never Buy again. |
| Offline with cached purchased access | Pro continues; no arbitrary online expiry. |
| Offline active/expired trial | Known time window enforced locally; no extension network requirement. |
| Offline new user / failed products request | Free/preview works; no guessed price or fabricated activation. |
| Restore cannot connect | Could not check, not No purchases found; retain valid cached access. |
| Refund/revocation or account change | Reconcile verified facts; preserve work; no new trial; no false revocation from a request failure. |
| Expiry while extension open | No mid-gesture/key rearrangement; next presentation uses Free without opening app. |
| Expiry while app editing | Persist draft; no new premium mutation/apply; inspect/export/delete still work. |
| Change Free settings during trial | Latest Free choices survive expiry, not the factory defaults or an old snapshot. |
| Missing/corrupt/old bundle | Validated Free keyboard; no entitlement escalation or profile deletion. |
| Changed timezone/DST | Same absolute deadline; localized label changes only. |
| Clock backwards/forwards | No rewritten trial start; bounded handling and recovery rather than permanent punitive lockout. |
| Invalid/imported profile with billing fields | Reject/ignore forbidden metadata; never unlock Pro or overwrite a valid configuration. |
| Phrase-containing export | Warn/preview, allow omission; no hidden telemetry, learned words or purchase data. |
| New geometry/language/layer | Touch map, glide and suggestions agree; globe and core gestures work. |
| VoiceOver/Dynamic Type/dark/landscape/iPad | Clear actions, complete terms, readable local prices and non-drag editing alternatives. |
| Full Access disabled throughout | Free and validated Pro configuration work; no commerce or upgrade prompts in extension. |

Run core tests and native UI/integration suites using the [README commands](../README.md#validate), plus StoreKit sandbox cases above. StoreKit mock success is not a substitute for zero-price trial behaviour on the actual store. This documentation PR does not claim those native tests have run.

## 10. App Store and privacy release checklist

- [ ] Confirm both actual product IDs, names, types, availability and approved localized prices.
- [ ] Verify trial-original-date/reinstall/second-device behaviour in sandbox and document results.
- [ ] No subscription product, auto-renew consent, hidden charge or Full Access request.
- [ ] All marketed Pro capabilities implemented; feature screenshots distinguish Free and Pro.
- [ ] Trial terms disclose duration, optional payment and exact features that stop at expiry.
- [ ] Restore, cancellation, pending, publication errors and refunds tested.
- [ ] Reviewer notes explain the two products, setup steps, no-commerce extension and expiry fallback.
- [ ] Update `PRIVACY.md`, README and App Store metadata for containing-app StoreKit communication with Apple and explicitly saved phrase/profile data. Do not claim the whole app never communicates with any service once purchases exist.
- [ ] Retain the narrower accurate claim: typing stays local, no analytics/tracking backend, keyboard requires no Full Access.
- [ ] No forced notification permissions, accounts, email capture, clipboard-history collection or transaction data in public diagnostics.
- [ ] Normal Free keyboard remains usable after expiry or any billing failure.

## Primary sources

Checked September 26, 2026; recheck before release. The proposal is not a guarantee of App Review approval.

- **S1:** [Apple App Review Guidelines, 3.1.1, 4.4 and 4.4.1](https://developer.apple.com/app-store/review/guidelines/).
- **S2:** [Configuring open access for a custom keyboard](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard) ([machine-readable documentation](https://developer.apple.com/tutorials/data/documentation/uikit/configuring-open-access-for-a-custom-keyboard.json)).
- **S3:** [StoreKit Transaction](https://developer.apple.com/documentation/storekit/transaction) ([machine-readable documentation](https://developer.apple.com/tutorials/data/documentation/storekit/transaction.json)).
- **S4:** [Create consumable or non-consumable In-App Purchases](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/).
- **S5:** [AppStore.sync()](https://developer.apple.com/documentation/storekit/appstore/sync()) ([machine-readable documentation](https://developer.apple.com/tutorials/data/documentation/storekit/appstore/sync%28%29.json)).
