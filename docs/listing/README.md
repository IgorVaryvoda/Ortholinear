# Localized App Store listings

The English (U.S.) listing in [APP-STORE.md](../APP-STORE.md) is the source. Each `<locale>.json` here is one App Store Connect localization, named by its App Store Connect locale code, and `Tools/asc-listing.py` uploads them to the version being prepared.

| Locale | Language | Keyboard layout it leads with |
| --- | --- | --- |
| `uk` | Ukrainian | Українська |
| `pl` | Polish | Polski |
| `cs` | Czech | Čeština |
| `sk` | Slovak | Slovenčina |
| `hr` | Croatian | Latinica |
| `de-DE` | German | Deutsch |
| `nl-NL` | Dutch | Nederlands |
| `da` | Danish | Dansk |
| `sv` | Swedish | Svenska |
| `no` | Norwegian | Norsk |
| `fr-FR` | French | Français |
| `fr-CA` | French (Canada) | Français |
| `es-ES` | Spanish (Spain) | Español |
| `es-MX` | Spanish (Mexico) | Español |

App Store Connect has no Serbian, Bosnian or Montenegrin localization; `hr` serves the Latinica layout. There is deliberately no Russian listing.

## Fields

```json
{
  "name": "≤ 30 characters",
  "subtitle": "≤ 30 characters",
  "keywords": "≤ 100 characters, comma-separated, no spaces after commas",
  "promotionalText": "≤ 170 characters",
  "description": "≤ 4000 characters",
  "whatsNew": "≤ 4000 characters, for the version being prepared",
  "iapName": "≤ 30 characters",
  "iapDescription": "≤ 55 characters"
}
```

Writing rules:

- Each listing leads with its own language: a Polish iPhone now starts Ortholinear with the Polish layout (`KeyboardPreferences.suggested(for:)`), so the Polish page says so first. Ukrainian + English stays the app's identity in every listing.
- Keep the English names of things the app shows on screen, because the app's interface is in English: Layout Workshop, Big letters, Balanced, Original grid, the theme names, and Settings paths. Each description says the settings are in English.
- Keywords are in the listing's language, never repeat a word already in the name or subtitle, and name no other apps or trademarks.
- Ortholinear and Ortholinear Pro are never translated.

## What's New for the next version

The English source:

> • A new install starts with the languages your iPhone or iPad already uses: on a Polish iPhone, Ortholinear starts with the Polish layout. Change them any time in Settings > Languages and layouts.

Each locale names its own language in place of Polish. Add the release's other changes to every locale before submitting.
