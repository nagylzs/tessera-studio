# Store listing texts

One YAML file per app language (`<code>.yaml`, the codes of `lib/l10n`),
each with every store's fields. `en.yaml` is the master; the others
translate it. `test/store_listing_test.dart` checks every file against
the limits below and that all 14 languages are here.

| Field | Google Play | App Store | Microsoft Store | Limit |
|---|---|---|---|---|
| `name` | Title | – | (the reserved name) | 30 |
| `app_store_name` | – | Name (plain "Tessera Studio" is taken there, 2026-10-19; the name under the icon stays). English in every language: App Store Connect refused the localized names it was given (Czech, German) as "already being used" (2026-10-20) | – | 30 |
| `short` | Short description | – | – | 80 |
| `subtitle` | – | Subtitle | – | 30 |
| `promo` | – | Promotional text | – | 170 |
| `keywords` | – | Keywords (comma-separated, no spaces after commas, not repeating the name) | – | 100 |
| `summary` | – | – | Short description (1000 allowed, 270 shown) | 270 |
| `description` | Full description | Description | Description (10 000 allowed) | 4000 |
| `features` | – | – | Product features | 20 × 200 |
| `search_terms` | – | – | Search terms, if offered | 7 × 30 |

Limits count characters (Unicode code points). Plain text everywhere:
no HTML, no URLs (Microsoft asks for links in their own fields). The
Microsoft Store's "What's new" stays empty for the first submission.

**Microsoft Store: no typing.** Partner Center → Application overview →
"Export listings" gives a .csv with a column per package language;
`dart run tool/ms_listing.dart <export.csv> <folder>` fills it from these
files (`summary` is the short description) and puts the screenshots of
`store/screenshots/microsoft` and the 300 px logo next to it; then
"Import listings" → **Import folder** on that folder. Partner Center
wants image paths starting with the folder's own name (the tool writes
them so) and shows no reason when a .csv fails — an empty "View errors"
was a wrong image path (2026-10-11).

## Store locale codes

| File | Google Play | App Store | Microsoft Store |
|---|---|---|---|
| `cs` | cs-CZ | cs | cs-cz |
| `de` | de-DE | de-DE | de-de |
| `en` | en-US | en-US | en-us |
| `es` | es-ES | es-ES | es-es |
| `fr` | fr-FR | fr-FR | fr-fr |
| `hu` | hu-HU | hu | hu-hu |
| `it` | it-IT | it | it-it |
| `ja` | ja-JP | ja | ja-jp |
| `nl` | nl-NL | nl-NL | nl-nl |
| `pl` | pl-PL | pl | pl-pl |
| `pt` | pt-BR | pt-BR | pt-br |
| `ru` | ru-RU | ru | ru-ru |
| `tr` | tr-TR | tr | tr-tr |
| `zh` | zh-CN | zh-Hans | zh-cn |

`pt` is Brazilian Portuguese and `zh` Simplified Chinese, as in the app.
English is American English everywhere: the listing (the stores label
it en-US), the app's texts and the privacy policy.

## Keep it true

The listing may only claim what the app does on that store's platform.
Before each release check:

- **"Open with" / share from other apps** works on Android, Windows,
  iOS and macOS (Apple since 2026-10-19: Finder's Open With and double
  click, the iOS share sheet and Files; AirDrop saves into Files first).
  Not for JSON Lines on Apple (no system type) or plain `.txt` files.
- **Drag and drop**: Windows, Linux, web and macOS (tried 2026-10-19);
  not iOS.
- **Full screen on phones**: Android and iOS.
- No charts yet: the charts pane is still in TODO.md.
- When a feature, a format or a language is added or removed, the
  description, the features and the keywords follow, in every language.

Account and submission steps are logged in the owner's vault
(`Projektek/fejlesztoi_fiokok`); the privacy policy is
`../privacy/index.html`.
