# App Store listing

- Name: Ortholinear Keyboard
- Subtitle: Big keys. Ukrainian + English
- Primary language: English (U.S.)
- Bundle ID: com.varyvoda.Ortholinear
- SKU: ortholinear-ios
- Version: 0.6.0 (21)
- Primary category: Utilities
- Secondary category: Productivity
- Support URL: https://github.com/IgorVaryvoda/Ortholinear/blob/main/SUPPORT.md
- Privacy URL: https://github.com/IgorVaryvoda/Ortholinear/blob/main/PRIVACY.md
- Marketing URL: https://github.com/IgorVaryvoda/Ortholinear
- Copyright: 2026 Igor Varyvoda
- Keywords: polish,german,french,spanish,czech,slovak,croatian,serbian,bosnian,swedish,norwegian,danish,dutch

## Promotional text

New: a free Layout Workshop. And Ortholinear Pro, once: flicks on every key, keycap colorways, navigation keys and text expansions. No Full Access, no tracking.

## In-app purchase

- Ortholinear Pro, non-consumable, product ID `com.varyvoda.Ortholinear.pro` (App Store Connect ID 6819696774)
- Price: USD 9.99 base (USA), automatic prices elsewhere (EUR 9.99 in Germany); all 175 territories, including new ones
- Family Sharing: on (cannot be turned off again)
- Display name and description: English (U.S.) and Ukrainian
- Review screenshot: the purchase screen, captured by `ReviewScreenshotTests` in the private Pro repository with a demonstration price
- Built from the private Pro edition: `xcodegen generate --spec project.pro.yml` in `OrtholinearPro`, then archive the `OrtholinearPro` scheme in Release

## Description

Big fingers deserve room to type.

Standard keys feel cramped under your thumbs? Ortholinear is built for bigger fingers, with wider keys, larger letters, and adjustable spacing. Give your hands more generous touch targets and a layout that fits the way you type.

Ortholinear is a Ukrainian and English keyboard for iPhone and iPad, with optional layouts for Polish, German, French, Spanish, Czech, Slovak, Croatian, Bosnian, Montenegrin, Serbian (Latin and Cyrillic), Swedish, Norwegian, Danish, Dutch, and Russian. Straight rows and equal-width letter cells make the most of the available space. Choose a preset or adjust the keyboard to suit your hands.

MAKE THE SPACE YOURS
• Start with Big letters, Balanced, or Original grid.
• Adjust letter size, key height, control-row height, and spacing with a live preview.
• Give Return and Delete more room, with Delete immediately after M / Ю.
• Keep Ukrainian letters free of an apostrophe key.
• Add a space after punctuation automatically, or turn it off.
• Choose Shift placement and optional punctuation keys.
• Extend touch targets into the gaps between keys.
• Choose Warm Light, Soft Dark, High Contrast, Tokyo Night, Catppuccin Mocha, Nord, or Automatic themes, plus your own accent color.

TYPE FASTER
• Glide typing in English and Ukrainian: slide across the letters of a word and lift.
• Sentences start with a capital on their own, and two Spaces end a sentence with a period.
• Punctuation waits in the suggestion row between words, one tap away.
• Flick a top-row key down for its digit, or turn on a number row.
• Typed a Ukrainian word with the English layout on? One tap fixes it and switches language.

UKRAINIAN + ENGLISH
• Switch languages with one tap.
• Type the full Ukrainian alphabet; hold г for ґ and Г for Ґ.
• Optionally move ї to long-press і for a wider top row, with small hints to help you find held letters.
• Access numbers, symbols, and punctuation alternatives.
• Hold 123, slide to a symbol, and release to type it and return to letters.
• Keep 123 / ABC at the far left, with clear feedback on keyboard controls.
• Slide on Space to move the cursor.
• Double-tap Shift for caps lock. Hold Delete to erase gradually faster.

MORE LANGUAGES AND LAYOUTS
• Add Polish, German, French, Spanish, Czech, Slovak, Croatian, Bosnian, Montenegrin, Serbian (Latin and Cyrillic), Swedish, Norwegian, Danish, Dutch, and Russian; the language key cycles through the ones you turn on.
• Hold letters for accented forms such as ą, ß, é, ř, and ё.
• Type English in QWERTY, Colemak, Colemak-DH, Dvorak, or Workman.
• Message, search, email, and web address fields each reopen in the language you last used in them.

MAKE IT YOURS
• Layout Workshop: move letters, choose what each key holds, and try it before applying. Free.
• Share a layout as a file, or open one someone else made.

ORTHOLINEAR PRO: ONE PURCHASE, NO SUBSCRIPTION
• Flicks on any key: swipe up, down, left or right for a symbol. One tap puts ! @ # on every letter.
• Keycap colorways: eight keycap sets, or your own colors, fonts and sculpted keycaps.
• Navigation keys: move by word or line, delete whole words, type ( ) with the cursor inside.
• Text expansions: type ;mail and get your email address.
• Layers for math, code and writing, phrase keys, and saved setups you can switch and share.
Everything that was free stays free.

YOUR WORDS STAY YOURS
Typing works without Full Access. No analytics, ads, app accounts, or typed-text collection. Typing and settings stay on your device. Nothing is autocorrected: optional word suggestions run on your device and change a word only when you tap one.

TRY IT BEFORE ENABLING
Use the interactive keyboard preview inside the app, customize your layout, then follow the setup guide to enable Ortholinear in iOS Settings.

Works in apps that allow third-party keyboards. iOS uses its own keyboard for password and phone-pad fields. Some apps disable third-party keyboards.

Open source under the MIT license.

## App Review notes

No account or sign-in is required. Launch the containing app to use the interactive keyboard preview and customize geometry. To enable the system extension: Settings > General > Keyboard > Keyboards > Add New Keyboard > Ortholinear. Then select Ortholinear using the globe in a text field. The containing app includes “Test the installed system keyboard” with host text fields for review.

The extension does not request Full Access (RequestsOpenAccess=false). The app writes geometry and typing preferences into its App Group; the keyboard only reads them. No network requests, microphone recording, or typed-text collection. For ґ, hold г; for Ґ, enable Shift and hold Г. Delete follows M / Ю; Ukrainian has no letter-page apostrophe. Automatic punctuation spacing is enabled by default and configurable. URL and email fields use literal punctuation.

Version 0.6.0: Keyboard settings > Layout Workshop (free) rearranges a language's letters: tap a key, change what it types and holds, move or swap it, Try it, then Apply. Keyboard settings > Ortholinear Pro offers one non-consumable in-app purchase, com.varyvoda.Ortholinear.pro ("Unlock Pro"), with Restore purchases on the same screen; nothing that was free before is locked. Pro adds: flicks (Layout Workshop > Fill swipe-up with symbols, then Apply; swipe a letter up in the test drive), keycap colorways (Theme and colors), layers including a Navigate layer with word and line movement (Layers > add Navigate, turn on Layer key), text expansions (Text expansions > ;ty, then type ;ty and Space), and saved setups. Without Pro these rows show a PRO label and open the purchase screen. Purchases use StoreKit in the containing app only; the keyboard extension still has no Full Access (RequestsOpenAccess=false), no StoreKit and no network access. Layers and text expansions the user creates are stored on the device in the App Group and are only read by the keyboard.

Version 0.5.0: in the app's test drive and in the installed keyboard, sentences start with a capital automatically (following the text field's own capitalization setting; email and web address fields stay lowercase), two Spaces type a period, and the row above the keys shows punctuation between words. Flick a top-row key down to type its digit (Keyboard settings > Letters · Digits offers a number row instead). Glide typing works in English and Ukrainian: slide across a word's letters and lift; other readings appear above the keys. Suggestions still change text only when tapped. Other layouts get suggestions from UITextChecker, and the keyboard reads the user's text replacements and contact names with requestSupplementaryLexicon. Both work without Full Access. There is still no network access, and nothing leaves the device.

## What’s New in 0.6.0

Layout Workshop, free:
• Move letters, choose what each key holds, and try the result before applying it.
• Share a layout as a file, or open one someone else made.

Ortholinear Pro, an optional one-time purchase:
• Flicks on any key: swipe for a symbol. One tap puts ! @ # on every letter.
• Keycap colorways: eight sets, or your own colors, fonts and sculpted keycaps.
• Navigation keys: move by word or line, delete words, type ( ) with the cursor inside.
• Text expansions: type ;mail and get your email address.
• Layers, phrase keys and saved setups.

Everything that was free stays free. Still no Full Access, and the keyboard still makes no network requests.

## What’s New in 0.5.0

Typing basics:
• Sentences start with a capital automatically, following each text field. Email and web addresses stay lowercase.
• Tap Space twice to end a sentence with a period.
• Between words, the suggestion row shows punctuation next to the next-word suggestions, so a period is one tap.
• Flick a top-row key down for its digit, or turn on a number row.
• Glide typing for English and Ukrainian: slide across the letters of a word.
• Typed a Ukrainian word with the English layout? Tap the offered word to fix it and switch language.
• Suggestions for Polish, German, French, Spanish, Czech, Slovak, and the other layouts, from the spell checker built into iOS, plus your own text replacements.
• Suggestions add missing apostrophes: whos → who's, память → памʼять.
• Suggestions and glide typing work in Safari's address bar, but never on web addresses.
Fixes:
• Letters you get by holding a key, such as ґ and accents, are now visible above the keys while you hold.

## What’s New in 0.4.0

New languages and layouts:
• Polish, German, French, Spanish, Czech, Slovak, Croatian, Bosnian, Montenegrin, Serbian (Latin and Cyrillic), Swedish, Norwegian, Danish, Dutch, and Russian join Ukrainian and English. Choose which languages the language key cycles through in Settings > Languages and layouts, first in the list.
• English can use QWERTY, Colemak, Colemak-DH, Dvorak, or Workman.
• Hold letters for accented characters, with small hints on the keys.
• Ortholinear remembers the language you last used in each kind of field, such as messages, search, email, and web addresses, even after iOS closes the keyboard. Forget it any time in settings.
• Optional word suggestions for English and Ukrainian run entirely on your device and change a word only when you tap one.

## Version 0.4.0 changes

- Polish (QWERTY), German (QWERTZ), French (AZERTY), and Spanish layouts with held accents; choose the languages the language key cycles through.
- English Colemak, Colemak-DH (matrix bottom row), Dvorak, and Workman.
- The language last used in each kind of field is remembered in the keyboard's own container, with Forget remembered languages in settings. iOS gives keyboards no app, window, or chat identity; see [VERIFICATION.md](VERIFICATION.md).
- Czech, Slovak, Latinica (Croatian, Bosnian, Montenegrin, Serbian Latin), Serbian Cyrillic, Swedish, Norwegian, Danish, and Dutch layouts, added in build 19.
- Russian, offered only after answering “No” to “Do you support Russia’s invasion of Ukraine?”.
- Tap-only English and Ukrainian word suggestions (never automatic).
- The name and subtitle already index keyboard, big, keys, ukrainian, and english, so the keywords now name the new layouts.

## Version 0.3.2 changes

- Optional ї on long-press і, including Shift + hold І for Ї; removing the dedicated ї key widens the top row.
- Held Delete gradually accelerates, with immediate cancellation on release or slide-away.
- Persistent live preview in customization, with size and spacing sliders, UA/EN switching, and landscape layout.
- Softer key styling, consistent control icons, optional long-press hints, seven themes including Tokyo Night/Catppuccin Mocha/Nord, and six accent choices.
- Clearly labeled Settings entry and a first-position Theme and colors row; controls grouped into layout, letters, and typing.
- Version 0.3.2 (16) is installed and launched on the paired iPhone, passes the final installed-extension checks, and is Waiting for Review.

## Version 0.3.1 changes

- Clear pressed-key feedback and stable release fades, including globe and dismiss controls.
- The 123 / ABC switch stays at the far left on every page.
- Hold or slide from 123 to type one symbol and return to letters. Release outside to cancel; pause over #+= to reach more symbols.
- Faster touch delivery in the in-app preview.

## Submission status

Version **0.5.0 (20)** was submitted to App Review on September 24, 2026, with automatic release after approval. App Store Connect reports **Waiting for Review**. Version 0.4.0 (19) is live (Ready for Sale).

Build 20 was archived from commit `350b4a6`, then signed and uploaded with the team's Admin App Store Connect API key (`xcodebuild -exportArchive` with `destination: upload`); it processed as valid. The description, What's New, promotional text and review notes above were saved through the App Store Connect API. The six iPhone 6.9-inch screenshots and the 19-second app preview come from goldie (`goldie/goldie.config.ts`, captured by `Tools/store-capture.py`) and replace the single 0.3 screenshot. The iPad screenshot, keywords, pricing, availability, age rating and the Data Not Collected declaration are unchanged.

Submission ID: `73258f3a-28cf-42eb-8f3d-637fa92e36b2`. App record: `6808996711`. Version ID: `694585a5-a059-469a-9c2d-960aa5e5036c`. Build ID: `cab792cc-8cc6-4cc9-ba17-4f59b395309a`. Version 0.4.0 (19): version `77413922-4c88-43eb-893c-ca2566bd0f0c`, submission `05f0752b-139b-4da8-85bd-8537da50c1e3`.

## Prepared artifacts

- `build/release-050-20/Ortholinear.xcarchive`: signed Release archive for 0.5.0 (20).
- `build/release-040-19/Ortholinear.xcarchive`: signed Release archive for 0.4.0 (19).
- `build/release-040-18/Ortholinear.xcarchive`: signed Release archive for 0.4.0 (18), withdrawn.
- `build/release-040-17/Ortholinear.xcarchive`: signed Release archive for 0.4.0 (17), withdrawn.
- `build/keyboard-032-release16/Ortholinear.xcarchive`: signed Release archive for 0.3.2 (16).
- [iPhone 6.9-inch screenshot](screenshots/app-store/iphone-home.png): 1320 × 2868.
- [iPad 13-inch screenshot](screenshots/app-store/ipad-home.png): 2064 × 2752.

The screenshots show the default letter layout, with the same default letter arrangement retained in 0.3.2. Build artifacts remain local and are ignored by Git. The owner approved free pricing and the app-record User Access setting. Version 0.4.0 is waiting for review. App Store Connect: https://appstoreconnect.apple.com/apps/6808996711/distribution/ios/version/inflight
